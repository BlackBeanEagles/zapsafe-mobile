"""Day 361 - an INDEPENDENT corpus for glass and gunshot.

WHY THIS EXISTS
===============
Day 359 and 359B shipped two models and measured both of them on FSD50K:

    m_glass_breaking_v4   0.684 -> 0.866   trained FSD50K dev, eval FSD50K eval
    mg_gunshot_v2         0.729 -> 0.846   trained FSD50K dev, eval FSD50K eval

Train and eval are disjoint *splits of one corpus*. Every speech result this
week showed that a disjoint split of the same corpus does not answer the
generalisation question -- corpus-ID AUC ran 0.98-1.00 across six speech
corpora, meaning a pooled model partitions by corpus rather than learning the
construct. Nothing has tested whether these two audio models survive a corpus
change, and both of them ship as SOS contributors.

AudioSet is already on this disk (9,927 clips) and neither model has ever
seen it. It is a different collection process entirely: 10 s YouTube excerpts,
weakly labelled by human raters, versus FSD50K's Freesound uploads with
uploader tags. That is exactly the shift that matters.

Selection yields 59 glass positives and 77 gunshot positives. That gives wide
confidence intervals, so this is a DIRECTION check, not a precise number, and
the bootstrap CI is reported so the width is visible rather than implied.

EACH MODEL GETS ITS OWN PREPROCESSING. THIS IS NOT A DETAIL.
============================================================
    glass   2.0 s,  96 mels    train_glass_permissive.py  DUR=2.0 N_MELS=96
    gun     3.0 s, 128 mels    build_train_gunshot.py     DUR=3.0 SIZE=128

Two versions of this script got that wrong. The first built 128 mels for
both and crashed on glass with "Got 128 but expected 96" -- which was luck,
because a resize would have run clean and returned a plausible wrong number.
The second fixed the mel count but still fed glass 3.0 s of audio, and
produced a confident, damning, WRONG glass result (FPR 0.975) that was
almost written up. GlassBreakDetector's own class doc warns about precisely
this:

    "gunshot's 3 s window would feed the model 50% more audio than it has
     ever seen and produce a confident wrong answer."

Both parameters now come from a per-task spec, and eval asserts the mel size
against the interpreter's declared input shape.

Stored as ONE channel, float16. The models take 3 channels, but the gate
builds them with np.stack([img] * 3) -- three identical copies -- so storing
one and expanding at eval time is lossless and cuts the fixture 3x. That
matters here: C: is 100% full, the pagefile cannot grow, and an earlier run
lost 70% of its clips to MemoryError inside the workers.

HARD NEGATIVES ARE DELIBERATE
=============================
Explosion and Fireworks stay in the negative pool for both tasks. They are
loud broadband transients -- the thing a glass/gunshot detector most plausibly
false-positives on, and the thing a random negative sample would miss.

WINDOWING
=========
AudioSet clips are 10 s; the models take 2-3 s. Taking only the first window
would score a detector on whether the rater's event happened to start at
t=0. The shipped Dart path runs a rolling buffer, so max-over-sliding-windows
(hop = half the window) is the faithful analogue. The single-window reading
is kept too, so "the model is weak" can be told apart from "max over N
windows inflates the false-positive rate".
"""
from __future__ import annotations

import csv
import glob
import io
import os
import time
from concurrent.futures import ProcessPoolExecutor

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
A = r"C:\Users\hridy\Desktop\zapsafe\ml_datasets\audio_events\DS07_AudioSet"
WAVDIR = os.path.join(A, "train_wav")
SR, N_FFT, HOP, FMAX = 16000, 2048, 512, 8000

# task -> (n_mels / image size, window seconds). Must match the training
# scripts exactly; see the module docstring.
SPECS = {"glass": (96, 2.0), "gun": (128, 3.0)}

WORKERS = 2                # 6 OOMed and silently lost 70% of the rows
MAX_WIN = 6
N_NEG = 1400
SEED = 42
QUOTE = chr(34)

GLASS_POS = {"Glass", "Shatter"}
GUN_POS = {"Gunshot, gunfire", "Machine gun", "Artillery fire"}
HARD_NEG = {"Explosion", "Fireworks"}


def mel_img(y, size, need, librosa):
    """One channel of the gate's mel-image preprocessing, at `size` mels
    over exactly `need` samples.

    np.resize TILES rather than interpolating. That is the behaviour the
    shipped models and the Dart path were built around, so it is reproduced
    deliberately rather than "fixed".
    """
    y = np.pad(y, (0, need - len(y))) if len(y) < need else y[:need]
    mel = librosa.feature.melspectrogram(y=y, sr=SR, n_mels=size,
                                         hop_length=HOP, n_fft=N_FFT,
                                         fmax=FMAX)
    db = librosa.power_to_db(mel, ref=np.max)
    rng = db.max() - db.min()
    nz = (db - db.min()) / (rng if rng > 1e-8 else 1.0)
    return np.resize(nz, (size, size)).astype(np.float16)


def _one(path):
    """Returns {task: (first, windows)}, or a REASON string on failure.

    On failure it returns the reason, not None. An earlier run silently
    dropped 1,122 of 1,598 clips -- the workers hit MemoryError while C: had
    no room to grow the pagefile, `except Exception` swallowed it, and the
    result was a 476-clip fixture with 14 glass positives that looked
    entirely plausible. main() now aborts on the drop rate rather than
    reporting an AUC over the survivors.
    """
    import librosa
    try:
        y, _ = librosa.load(path, sr=SR, mono=True)
    except Exception as e:
        return "load:%s" % type(e).__name__
    if len(y) < SR * 0.2:
        return "short:%d" % len(y)
    out = {}
    for task, (size, dur) in SPECS.items():
        need = int(SR * dur)
        step = int(SR * dur / 2.0)
        starts = list(range(0, max(1, len(y) - need + 1), step))[:MAX_WIN]
        starts = starts or [0]
        out[task] = (mel_img(y, size, need, librosa),
                     np.stack([mel_img(y[s:s + need], size, need, librosa)
                               for s in starts]))
    return out


def labels_by_ytid():
    lab = {r["mid"]: r["display_name"] for r in
           csv.DictReader(io.open(os.path.join(A, "class_labels_indices.csv"),
                                  encoding="utf-8"))}
    out = {}
    for f in ("balanced_train_segments.csv", "unbalanced_train_segments.csv",
              "eval_segments.csv"):
        p = os.path.join(A, f)
        if not os.path.exists(p):
            continue
        for line in io.open(p, encoding="utf-8"):
            if line.startswith("#"):
                continue
            parts = line.split(",", 3)
            if len(parts) < 4:
                continue
            names = {lab.get(m.strip(), "") for m in
                     parts[3].replace(QUOTE, "").split(",")}
            out.setdefault(parts[0].strip(), set()).update(names)
    return out


def main():
    cache = os.path.join(HERE, "audioset_fixture.npz")
    if os.path.exists(cache):
        print("fixture already built:", cache)
        return
    by = labels_by_ytid()
    files = sorted(glob.glob(os.path.join(WAVDIR, "*.wav")))
    print("wavs on disk: %d" % len(files))
    print("specs: %s" % ", ".join(
        "%s=%d mels/%.1fs" % (t, s, d) for t, (s, d) in SPECS.items()))

    rows = [(p, by.get(os.path.splitext(os.path.basename(p))[0], set()))
            for p in files]
    rows = [r for r in rows if r[1]]

    def is_pos(n):
        return bool(n & GLASS_POS) or bool(n & GUN_POS)

    pos_any = [r for r in rows if is_pos(r[1])]
    hard = [r for r in rows if (r[1] & HARD_NEG) and not is_pos(r[1])]
    rest = [r for r in rows if not is_pos(r[1]) and not (r[1] & HARD_NEG)]
    rng = np.random.RandomState(SEED)
    take = list(rng.permutation(len(rest))[:N_NEG])
    sel = pos_any + hard + [rest[i] for i in take]
    print("positives(any) %d  hard-neg %d  random-neg %d  total %d"
          % (len(pos_any), len(hard), len(take), len(sel)))

    yg = np.array([1 if (n & GLASS_POS) else 0 for _, n in sel])
    yk = np.array([1 if (n & GUN_POS) else 0 for _, n in sel])
    print("  glass pos %d (base %.3f) | gun pos %d (base %.3f)"
          % (yg.sum(), yg.mean(), yk.sum(), yk.mean()))

    F = {t: [] for t in SPECS}
    W = {t: [] for t in SPECS}
    keep, drops = [], {}
    t0 = time.time()
    with ProcessPoolExecutor(max_workers=WORKERS) as ex:
        for k, r in enumerate(ex.map(_one, [p for p, _ in sel], chunksize=4)):
            if isinstance(r, str):
                key = r.split(":")[0]
                drops[key] = drops.get(key, 0) + 1
                continue
            for t in SPECS:
                F[t].append(r[t][0])
                W[t].append(r[t][1])
            keep.append(k)
            if (k + 1) % 300 == 0:
                print("  %d/%d %ds" % (k + 1, len(sel), int(time.time() - t0)),
                      flush=True)
    keep = np.asarray(keep)
    rate = 1.0 - len(keep) / float(len(sel))
    print("dropped %d/%d (%.1f%%): %s"
          % (len(sel) - len(keep), len(sel), 100 * rate, drops or "none"))
    if rate > 0.05:
        raise SystemExit(
            "ABORT: %.1f%% of clips failed to decode. These files are known "
            "good (9,927 wavs, median 1.76 MB, 40/40 load single-threaded), "
            "so this is resource exhaustion in the workers, not bad data. "
            "C: is 100%% full so the pagefile cannot grow -- free space or "
            "lower WORKERS, then re-run. Refusing to write a fixture that "
            "silently lost most of its positives." % (100 * rate))

    out = {"yg": yg[keep], "yk": yk[keep],
           "ytid": np.asarray([os.path.basename(sel[i][0]) for i in keep])}
    for t in SPECS:
        out["first_%s" % t] = np.stack(F[t])
        out["win_%s" % t] = np.concatenate(W[t])
        out["nwin_%s" % t] = np.asarray([w.shape[0] for w in W[t]], np.int32)
        out["mels_%s" % t] = np.int32(SPECS[t][0])
        out["dur_%s" % t] = np.float32(SPECS[t][1])
    np.savez_compressed(cache, **out)
    print("built: %d clips, glass pos %d, gun pos %d"
          % (len(keep), int(yg[keep].sum()), int(yk[keep].sum())))
    for t in SPECS:
        print("  %-6s %d mels %.1fs -> windows %s"
              % (t, SPECS[t][0], SPECS[t][1], out["win_%s" % t].shape))


if __name__ == "__main__":
    main()
