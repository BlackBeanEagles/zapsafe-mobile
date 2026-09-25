"""Day 358 - WavLM embeddings for MELD. Is the FEATURE SPACE the ceiling?

THE CLAIM BEING TESTED
======================
Day 356 rejected six corpora (~150k clips) and concluded the limit is not
data but the 38-dim hand-crafted vector: corpus-ID AUC measured 0.98-1.00
in that space, so a pooled model can identify the recording channel and
partition instead of generalising.

If that diagnosis is right, a learned speech representation -- trained to be
invariant to channel and speaker -- should beat 38-dim prosodics ON THE SAME
MELD ROWS, with no new data at all. If it does not, the diagnosis was wrong
and the models are simply near the ceiling of the task.

This is deliberately the cheapest possible test of an expensive idea. No new
corpus, no new labels, identical train/eval rows to every A/B run this week.

WHY MULTIPLE LAYERS
===================
For emotion, the final transformer layer of a self-supervised speech model
is usually NOT the best -- the top layers specialise toward the pretraining
objective (masked prediction / ASR-like content), while paralinguistic
information peaks in the middle. Picking only the last layer is a standard
way to under-measure these models, so several layers are extracted in one
forward pass and each is tested.

POOLING: mean AND std over time. Mean alone discards how much a feature
varies across the clip, which for affect is often the signal -- a steady
loud voice and a voice that spikes have the same mean.

DEPLOYMENT IS NOT SOLVED HERE, and that is on purpose. WavLM-base is ~94M
parameters (~377 MB fp32) against a current largest asset of 4.7 MB. If this
test says the representation helps, the shipping problem (distillation, or a
much smaller encoder) becomes worth solving. If it says no, there is nothing
to ship and the question is closed cheaply.
"""
from __future__ import annotations

import glob
import os
import re
import sys
import time

import numpy as np

# C: has under 2 GB free; the checkpoint must not land in the default cache.
os.environ.setdefault("TORCH_HOME", r"D:\zapsafe\torch_cache")

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = r"C:\Users\hridy\Desktop\zapsafe"
MELD = os.path.join(ROOT, r"ml_datasets\vocal_stress\DS_MELD\preprocessed_data")

SR = 16000
CLIP = 3.0                 # identical window to the 38-dim pipeline
NEED = int(SR * CLIP)
BATCH = 8
LAYERS = (0, 4, 6, 8, 12)  # 0 = feature-extractor output, 12 = final
KEEP = {"angry", "anger", "sad", "sadness", "neutral", "happy",
        "happiness", "joy", "fear", "fearful", "disgust", "disgusted"}
CANON = {"angry": "anger", "anger": "anger", "sad": "sad",
         "sadness": "sad", "neutral": "neutral", "happy": "happy",
         "happiness": "happy", "joy": "happy", "fear": "fear",
         "fearful": "fear", "disgust": "disgust", "disgusted": "disgust"}


def load_clip(path, torch):
    """Same audio contract as featurise_meld_emotions.py: 16 kHz, 3 s."""
    import librosa
    d = torch.load(path, map_location="cpu", weights_only=False)
    emo = str(d.get("emotion", "")).lower()
    if emo not in KEEP:
        return None
    sr = int(d.get("audio_sample_rate", SR))
    w = d["audio"]
    w = w.numpy() if hasattr(w, "numpy") else np.asarray(w)
    w = w.reshape(-1).astype(np.float32)
    if sr != SR:
        w = librosa.resample(w, orig_sr=sr, target_sr=SR)
    if len(w) < int(SR * 0.3):
        return None
    w = np.pad(w, (0, NEED - len(w))) if len(w) < NEED else w[:NEED]
    m = re.match(r"(dia\d+)", os.path.basename(path))
    return w, CANON[emo], "meld_" + (m.group(1) if m else "unk")


def main():
    import torch
    import torchaudio

    dev = "cuda" if torch.cuda.is_available() else "cpu"
    print("device: %s | TORCH_HOME=%s" % (dev, os.environ["TORCH_HOME"]),
          flush=True)
    bundle = torchaudio.pipelines.WAVLM_BASE_PLUS
    print("downloading / loading WAVLM_BASE_PLUS ...", flush=True)
    model = bundle.get_model().to(dev).eval()
    print("  loaded. sample_rate=%d" % bundle.sample_rate, flush=True)

    split = sys.argv[1] if len(sys.argv) > 1 else "train"
    # Day 358: the first train run died silently at 3,000/9,988 with no
    # traceback -- a clean process kill. Rather than guess at the cause, the
    # work is CHUNKED and each chunk writes its own file, so a death costs
    # one chunk and a rerun skips what already exists.
    lo_i = int(sys.argv[2]) if len(sys.argv) > 2 else 0
    hi_i = int(sys.argv[3]) if len(sys.argv) > 3 else 10 ** 9
    dirs = ["train"] if split == "train" else ["test", "dev"]
    files = []
    for s in dirs:
        files += sorted(glob.glob(os.path.join(MELD, s, "*.pt")))
    files = files[lo_i:hi_i]
    tag = "%s_%06d" % (split, lo_i)
    done = os.path.join(HERE, "meld_%s_wavlm_L%d.npz" % (tag, LAYERS[0]))
    if os.path.exists(done):
        print("[%s] already done, skipping" % tag, flush=True)
        return
    print("[%s] %d files (%d..%d)" % (tag, len(files), lo_i, hi_i),
          flush=True)

    feats = {l: [] for l in LAYERS}
    emo, spk = [], []
    buf, bemo, bspk = [], [], []
    bad = 0
    t0 = time.time()

    def flush():
        if not buf:
            return
        x = torch.from_numpy(np.stack(buf)).to(dev)
        with torch.inference_mode():
            hs, _ = model.extract_features(x)
        for l in LAYERS:
            h = hs[l] if l < len(hs) else hs[-1]
            mu = h.mean(dim=1)
            sd = h.std(dim=1)
            feats[l].append(torch.cat([mu, sd], dim=1).cpu().numpy()
                            .astype(np.float32))
        emo.extend(bemo)
        spk.extend(bspk)
        buf.clear()
        bemo.clear()
        bspk.clear()

    for i, f in enumerate(files):
        r = load_clip(f, torch)
        if r is None:
            bad += 1
            continue
        w, e, s = r
        buf.append(w)
        bemo.append(e)
        bspk.append(s)
        if len(buf) >= BATCH:
            flush()
        if (i + 1) % 1000 == 0:
            print("  %d/%d  kept=%d  %ds"
                  % (i + 1, len(files), len(emo), int(time.time() - t0)),
                  flush=True)
    flush()

    emo = np.array(emo)
    spk = np.array(spk)
    import collections
    print("\n[%s] kept %d  dropped %d  dim=%d"
          % (split, len(emo), bad,
             feats[LAYERS[0]][0].shape[1] if feats[LAYERS[0]] else 0))
    print("  emotions:", dict(collections.Counter(emo.tolist())))
    os.makedirs(HERE, exist_ok=True)
    for l in LAYERS:
        X = np.vstack(feats[l])
        np.savez_compressed(
            os.path.join(HERE, "meld_%s_wavlm_L%d.npz" % (tag, l)),
            X=X, emo=emo, spk=spk)
        print("  wrote layer %-2d %s" % (l, X.shape))
    print("done in %ds" % int(time.time() - t0))


if __name__ == "__main__":
    main()
