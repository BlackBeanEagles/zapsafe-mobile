"""Day 361D - can scream go fully NC-free if the lost diversity is REPLACED?

WHAT DAY 361B ESTABLISHED
=========================
Dropping ESC-50 (360 negatives, 2.4% of rows, zero positives) cost 0.0195
AUC against a -0.005 ship rule. Seed ranges did not overlap, so it is real.
The reading was that ESC-50 supplies negative DIVERSITY the other sources
lack: FSD50K negatives are Freesound uploads, while ASVP-ESD and
VocalAffectBench are both vocal.

That suggested a specific fix rather than a vague one: **replace the
diversity, do not just delete the corpus.**

WHY FSD50K's CC0 POOL AND NOT DEMAND
====================================
DEMAND was the obvious candidate -- 16 environments (kitchen, car, metro,
traffic, office, park), far better matched to a phone's deployment domain
than ESC-50's curated clips. Its licence was read from the source PDF rather
than assumed, after the EmotionTalk mistake:

    "the audio recordings and the MATLAB scripts are licensed under the
     Creative Commons Attribution-ShareAlike 3.0 Unported License"

CC BY-SA has no NC clause, so it is commercially usable. But ShareAlike says
a work that "builds upon" it may only be distributed under the same licence,
and whether a trained model is a derivative of its training audio is
genuinely unsettled. For a commercial app that trades an NC problem for a
copyleft one. Not used, and not recommended without a lawyer.

**FSD50K's CC0 slice has no such question.** CC0 is public-domain dedication:
no attribution, no share-alike, no NC. And it is already on disk.

THE KEY OBSERVATION
===================
scream v5 used 4,257 FSD50K dev negatives. FSD50K dev holds ~35,000
permissive clips (CC0 14,959 + CC BY 20,017). So roughly 33,000 permissive
clips were never touched. The replacement diversity does not need to be
downloaded -- it needs to be SELECTED, and selected for label spread rather
than at random, since spread is the thing ESC-50 was contributing.

WHAT THIS BUILDS
================
    drop   esc_neg                      CC BY-NC 3.0
    drop   fsd_dev_neg / fsd_dev_pos    ~15% of FSD50K is CC BY-NC per-clip,
                                        and the v5 cache has no filenames,
                                        so these cannot be filtered in place
    keep   asvp_*, as_*, VocalAffectBench (research / AudioSet / MIT)
    add    the CC0+CC-BY scream lists   217 pos / 2,299 neg, re-extracted
    add    FRESH CC0/CC-BY dev negatives, sampled for LABEL DIVERSITY and
           excluding anything already used and anything scream-adjacent

That clears both open NC items at once: the named NC corpus (ESC-50) and the
unnamed per-clip NC slice inside FSD50K.

SHIP RULE, fixed before running
===============================
Arm A (the shipped composition, with ESC-50 and unfiltered FSD50K) measured
**0.7823** under this recipe on 2026-09-26. Arm C ships as "NC-free at no
cost" only if it reaches **>= 0.7773** (A - 0.005), the same tolerance
Day 361B used. Anything less is reported as a licence-for-accuracy trade,
with the size of the trade stated.

Evaluation deliberately uses the SAME FSD50K eval fixture as arms A and B,
so the three are comparable. Eval-set licence is irrelevant to what the
shipped model may be used for; only training data is.
"""
from __future__ import annotations

import collections
import csv
import io
import json
import os
import time
from concurrent.futures import ProcessPoolExecutor

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
SV5 = r"C:\Users\hridy\Desktop\zapsafe\work\scream_v5"
F = (r"C:\Users\hridy\Desktop\zapsafe\ml_datasets\audio_events\DS08_FSD50K")
DEV_AUDIO = os.path.join(F, "FSD50K.dev_audio")
GT = os.path.join(F, "FSD50K.ground_truth", "dev.csv")
INFO = os.path.join(F, "FSD50K.metadata", "dev_clips_info_FSD50K.json")

SR, DURATION, N_MELS, N_FFT, HOP, FRAMES = 22050, 3, 128, 2048, 512, 131
NEED = SR * DURATION
WORKERS = 2                  # C: pagefile headroom; see machine notes
SEEDS = (42, 7, 123)
ARM_A_MEAN = 0.7823          # measured 2026-09-26, same recipe
TOLERANCE = 0.005
N_FRESH = 2500               # fresh CC0/CC-BY negatives to add

# Anything scream-adjacent is excluded from the fresh NEGATIVE pool: a
# mislabelled positive sitting in the negatives is worse than no extra data.
SCREAM_ADJACENT = {
    "Screaming", "Shout", "Yell", "Bellow", "Battle_cry", "Children_shouting",
    "Crying_and_sobbing", "Whoop", "Wail", "Groan", "Grunt", "Squeal",
    "Human_voice", "Speech", "Singing", "Laughter", "Baby_cry_and_infant_cry",
}
PERMISSIVE = ("CC0", "CC BY")


def licence_of(url):
    """Same mapping as build_permissive_sets.py. Order matters: the BY-NC
    and BY-SA tests must precede the plain BY test, because every one of
    those URLs also contains '/licenses/by'."""
    u = (url or "").lower()
    if "creativecommons.org/publicdomain/zero" in u:
        return "CC0"
    if "creativecommons.org/licenses/by-nc/" in u:
        return "CC BY-NC"
    if "creativecommons.org/licenses/by-sa/" in u:
        return "CC BY-SA"
    if "creativecommons.org/licenses/by/" in u:
        return "CC BY"
    return "other"


def mel_from(y, librosa):
    """Verbatim from build_train_scream.py::mel_from, which is itself
    verbatim from tools/day345_fsd50k/evaluate_scream.py. Must not drift:
    these features feed a model trained on the original."""
    y = np.pad(y, (0, NEED - len(y))) if len(y) < NEED else y[:NEED]
    mel = librosa.feature.melspectrogram(y=y, sr=SR, n_mels=N_MELS,
                                         n_fft=N_FFT, hop_length=HOP)
    db = librosa.power_to_db(mel, ref=np.max)
    rng = db.max() - db.min()
    db = (db - db.min()) / (rng if rng > 1e-8 else 1.0)
    if db.shape[1] < FRAMES:
        db = np.pad(db, ((0, 0), (0, FRAMES - db.shape[1])))
    return db[:, :FRAMES].astype(np.float16)


def _one(path):
    """Returns the mel, or a REASON string. Never None -- a silent drop
    produced a plausible-looking fixture that had lost 70% of its rows once
    already this week."""
    import librosa
    try:
        y, _ = librosa.load(path, sr=SR, mono=True)
    except Exception as e:
        return "load:%s" % type(e).__name__
    if len(y) < SR * 0.2:
        return "short:%d" % len(y)
    return mel_from(y, librosa)


def read_list(p):
    with io.open(p, encoding="utf-8") as fh:
        return [x.strip() for x in fh if x.strip()]


def extract(paths, tag):
    X, drops = [], {}
    t0 = time.time()
    with ProcessPoolExecutor(max_workers=WORKERS) as ex:
        for k, r in enumerate(ex.map(_one, paths, chunksize=8)):
            if isinstance(r, str):
                key = r.split(":")[0]
                drops[key] = drops.get(key, 0) + 1
                continue
            X.append(r)
            if (k + 1) % 500 == 0:
                print("    %s %d/%d %ds" % (tag, k + 1, len(paths),
                                            int(time.time() - t0)), flush=True)
    rate = 1.0 - len(X) / float(max(len(paths), 1))
    print("  %s: %d/%d extracted, dropped %.1f%% %s"
          % (tag, len(X), len(paths), 100 * rate, drops or ""), flush=True)
    if rate > 0.05:
        raise SystemExit(
            "ABORT: %s lost %.1f%% of clips. Known-good files, so this is "
            "resource exhaustion, not bad data. Lower WORKERS or free C:."
            % (tag, 100 * rate))
    return np.stack(X) if X else np.zeros((0, N_MELS, FRAMES), np.float16)


def fresh_negatives(used, rng):
    """CC0/CC-BY dev clips that are NOT already used and NOT scream-adjacent,
    sampled round-robin across LABELS so the result spreads over the
    vocabulary instead of piling into whichever class happens to be large.
    Spread is the property being replaced."""
    lic = {}
    info = json.load(io.open(INFO, encoding="utf-8"))
    for fid, meta in info.items():
        lic[str(fid)] = licence_of(meta.get("license", ""))

    by_label = collections.defaultdict(list)
    kept = 0
    with io.open(GT, encoding="utf-8") as fh:
        for row in csv.DictReader(fh):
            fid = row["fname"].strip()
            if fid in used:
                continue
            if lic.get(fid) not in PERMISSIVE:
                continue
            labels = set(row["labels"].split(","))
            if labels & SCREAM_ADJACENT:
                continue
            p = os.path.join(DEV_AUDIO, "%s.wav" % fid)
            if not os.path.exists(p) or os.path.getsize(p) == 0:
                continue
            kept += 1
            for lb in labels:
                by_label[lb].append(fid)

    print("  eligible fresh CC0/CC-BY non-scream clips: %d across %d labels"
          % (kept, len(by_label)))
    for lb in by_label:
        rng.shuffle(by_label[lb])
    order = sorted(by_label, key=lambda k: -len(by_label[k]))
    picked, seen = [], set()
    i = 0
    while len(picked) < N_FRESH and order:
        lb = order[i % len(order)]
        while by_label[lb] and by_label[lb][-1] in seen:
            by_label[lb].pop()
        if by_label[lb]:
            fid = by_label[lb].pop()
            seen.add(fid)
            picked.append(fid)
        i += 1
        if i > 40 * N_FRESH:
            break
    print("  sampled %d fresh negatives spanning %d labels"
          % (len(picked), len({l for l in order if by_label[l] is not None})))
    return picked


def net(shape, seed):
    import tensorflow as tf
    tf.keras.backend.clear_session()
    tf.random.set_seed(seed)
    np.random.seed(seed)
    inp = tf.keras.Input(shape=shape)
    x = tf.keras.layers.Reshape(shape + (1,))(inp) if len(shape) == 2 else inp
    for f in (16, 32, 64):
        x = tf.keras.layers.Conv2D(f, 3, padding="same", activation="relu")(x)
        x = tf.keras.layers.MaxPooling2D(2)(x)
    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    x = tf.keras.layers.Dropout(0.3)(x)
    x = tf.keras.layers.Dense(64, activation="relu")(x)
    out = tf.keras.layers.Dense(1, activation="sigmoid", name="scream")(x)
    return tf.keras.Model(inp, out, name="scream_ncfree_v2")


def main():
    import tensorflow as tf
    from sklearn.metrics import roc_auc_score

    d = np.load(os.path.join(SV5, "features_v5.npz"), allow_pickle=True)
    X, y, src = d["X"], np.asarray(d["y"]).astype(int), np.asarray(d["src"])
    Xf, yf = d["Xf"].astype(np.float32), np.asarray(d["yf"]).astype(int)

    DROP = {"esc_neg", "fsd_dev_neg", "fsd_dev_pos"}
    keep = np.array([s not in DROP for s in src])
    print("v5 pooled %s pos=%d" % (X.shape, y.sum()))
    print("dropping %s -> %d rows (%d pos) removed"
          % (sorted(DROP), int((~keep).sum()), int(y[~keep].sum())))

    rng = np.random.RandomState(42)
    perm_pos = read_list(os.path.join(HERE, "scream_dev_pos.txt"))
    perm_neg = read_list(os.path.join(HERE, "scream_dev_neg.txt"))
    used = set(perm_pos) | set(perm_neg)
    fresh = fresh_negatives(used, rng)

    print("re-extracting FSD50K at 22.05kHz/128mel (this is the slow part)")
    Xp = extract([os.path.join(DEV_AUDIO, "%s.wav" % f) for f in perm_pos],
                 "perm_pos")
    Xn = extract([os.path.join(DEV_AUDIO, "%s.wav" % f) for f in perm_neg],
                 "perm_neg")
    Xr = extract([os.path.join(DEV_AUDIO, "%s.wav" % f) for f in fresh],
                 "fresh_neg")

    Xc = np.concatenate([X[keep].astype(np.float16), Xp, Xn, Xr])
    yc = np.concatenate([y[keep], np.ones(len(Xp), int),
                         np.zeros(len(Xn) + len(Xr), int)])
    print("\narm C: %s pos=%d (%.1f%% positive)"
          % (Xc.shape, yc.sum(), 100 * yc.mean()))

    aucs, models = [], []
    n1, n0 = int(yc.sum()), int((1 - yc).sum())
    for s in SEEDS:
        m = net(Xc.shape[1:], s)
        m.compile(optimizer=tf.keras.optimizers.Adam(1e-3),
                  loss="binary_crossentropy",
                  metrics=[tf.keras.metrics.AUC(name="auc")])
        m.fit(Xc.astype(np.float32), yc, epochs=12, batch_size=64, verbose=0,
              class_weight={0: len(yc) / (2.0 * max(n0, 1)),
                            1: len(yc) / (2.0 * max(n1, 1))})
        a = float(roc_auc_score(yf, m.predict(Xf, verbose=0).ravel()))
        aucs.append(a)
        models.append(m)
        print("  seed %-4d AUC %.4f" % (s, a), flush=True)

    a = np.array(aucs)
    delta = a.mean() - ARM_A_MEAN
    holds = bool(a.mean() >= ARM_A_MEAN - TOLERANCE)
    print("\n  arm A (shipped composition)  %.4f" % ARM_A_MEAN)
    print("  arm B (drop ESC-50 only)     0.7628")
    print("  arm C (fully NC-free + fresh CC0/CC-BY diversity) "
          "mean %.4f (min %.4f max %.4f)" % (a.mean(), a.min(), a.max()))
    print("  C - A  %+.4f   ship rule >= -%.3f  ->  %s"
          % (delta, TOLERANCE, "HOLDS" if holds else "FAILS"))
    if holds:
        print("  -> scream can be made FULLY NC-free (ESC-50 AND the FSD50K "
              "per-clip slice) at no measured cost")
    else:
        print("  -> licence-for-accuracy trade of %.4f AUC; reporting, "
              "not shipping" % -delta)

    out = {"arm_A_mean": ARM_A_MEAN, "arm_B_mean": 0.7628,
           "arm_C_mean": round(float(a.mean()), 4),
           "arm_C_min": round(float(a.min()), 4),
           "arm_C_max": round(float(a.max()), 4),
           "delta_vs_A": round(float(delta), 4),
           "n_train": int(len(yc)), "n_pos": int(yc.sum()),
           "fresh_negatives": len(fresh),
           "perm_pos": len(Xp), "perm_neg": len(Xn),
           "ship_rule": ">= A - %.3f" % TOLERANCE, "holds": holds,
           "note": ("arm C removes BOTH NC exposures: ESC-50 (CC BY-NC 3.0) "
                    "and FSD50K's ~15% per-clip CC BY-NC slice, by "
                    "re-extracting from the CC0/CC-BY lists instead of "
                    "reusing the v5 cache, which has no filenames. DEMAND "
                    "was rejected: CC BY-SA, and ShareAlike on a trained "
                    "model is unsettled.")}
    if holds:
        conv = tf.lite.TFLiteConverter.from_keras_model(models[1])
        conv.optimizations = [tf.lite.Optimize.DEFAULT]
        conv.target_spec.supported_types = [tf.float16]
        blob = conv.convert()
        open(os.path.join(HERE, "scream_ncfree_v2.tflite"), "wb").write(blob)
        out["float16_kb"] = round(len(blob) / 1024, 1)
        print("  exported scream_ncfree_v2.tflite (%s KB)" % out["float16_kb"])
    json.dump(out, open(os.path.join(HERE, "scream_ncfree_v2.json"), "w"),
              indent=2)
    print("report written")


if __name__ == "__main__":
    main()
