"""Day 359 - fine-tune WavLM, to settle the embedding question properly.

WHAT THE FROZEN TEST LEFT OPEN
==============================
Day 358 compared FROZEN WavLM features against the 38-dim vector:

    WavLM L12, frozen, mean+std pooled   0.7054
    38-dim, properly tuned head          0.6875
    delta                                +0.018

and rejected the encoder on cost -- +0.018 for 377 MB. But frozen features
are the WEAKEST way to use a self-supervised speech model. The literature
consistently finds fine-tuning worth far more than probing, because the
pretraining objective (masked prediction) is not the task, and the layers
have to be moved toward it.

So the frozen number is a LOWER BOUND on what this representation can do,
and rejecting the whole direction on a lower bound would be premature.

WHAT THIS DECIDES
=================
    >= 0.78   the representation is genuinely much stronger and DISTILLATION
              becomes worth scoping -- train a small student on this model's
              outputs and ship the student, not the 377 MB teacher.
    0.72-0.78 real but awkward: too good to dismiss, not good enough to
              justify a new encoder pipeline on its own.
    <= 0.72   fine-tuning adds little over probing. The representation is
              not the lever, the frozen +0.018 was the whole story, and
              item 7 closes for good.

Same task, same rows, same eval as every comparison this week: aggressive
(anger/fear/disgust) vs calm (neutral/happy), MELD train -> MELD test+dev.

PRACTICAL NOTES
===============
* 8.6 GB GPU. WavLM-base at 3 s, batch 8, fp32 fits; batch is small and the
  LR is low (1e-5 encoder / 1e-4 head) because fine-tuning a 94M model on
  ~8.6k clips overfits in a couple of epochs otherwise.
* The feature extractor (CNN front end) is FROZEN, which is standard -- it
  encodes low-level acoustics and fine-tuning it on this little data mostly
  destroys it.
* Early stopping on eval AUC, and the best epoch is reported rather than the
  last, because a fine-tune that peaks at epoch 2 and degrades is still a
  valid measurement of the ceiling.
"""
from __future__ import annotations

import glob
import json
import os
import re
import sys
import time

import numpy as np

os.environ.setdefault("TORCH_HOME", r"D:\zapsafe\torch_cache")
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = r"C:\Users\hridy\Desktop\zapsafe"
MELD = os.path.join(ROOT, r"ml_datasets\vocal_stress\DS_MELD\preprocessed_data")

SR, CLIP = 16000, 3.0
NEED = int(SR * CLIP)
POS = {"anger", "fear", "disgust"}
NEG = {"neutral", "happy"}
KEEP = {"angry": "anger", "anger": "anger", "sad": "sad",
        "sadness": "sad", "neutral": "neutral", "happy": "happy",
        "happiness": "happy", "joy": "happy", "fear": "fear",
        "fearful": "fear", "disgust": "disgust", "disgusted": "disgust"}
# Day 359: batch 8 died during epoch 1 with no traceback on an 8.6 GB card.
# Fine-tuning 94M params needs activation memory for the BACKWARD pass that
# the frozen forward pass never allocated. Batch 4 plus autocast, with
# gradient accumulation so the effective batch stays 8.
BATCH = 4
ACCUM = 2
EPOCHS = 6
FROZEN_BASELINE = 0.7054
DIM38_BASELINE = 0.6875


def collect(split, torch):
    import librosa
    dirs = ["train"] if split == "train" else ["test", "dev"]
    files = []
    for s in dirs:
        files += sorted(glob.glob(os.path.join(MELD, s, "*.pt")))
    W, Y = [], []
    for f in files:
        try:
            d = torch.load(f, map_location="cpu", weights_only=False)
        except Exception:
            continue
        e = KEEP.get(str(d.get("emotion", "")).lower())
        if e is None or e not in (POS | NEG):
            continue
        sr = int(d.get("audio_sample_rate", SR))
        w = d["audio"]
        w = w.numpy() if hasattr(w, "numpy") else np.asarray(w)
        w = w.reshape(-1).astype(np.float32)
        if sr != SR:
            w = librosa.resample(w, orig_sr=sr, target_sr=SR)
        if len(w) < int(SR * 0.3):
            continue
        w = np.pad(w, (0, NEED - len(w))) if len(w) < NEED else w[:NEED]
        W.append(w)
        Y.append(1 if e in POS else 0)
    return np.stack(W), np.asarray(Y, np.int64)


def main():
    import torch
    import torch.nn as nn
    import torchaudio
    from sklearn.metrics import roc_auc_score

    dev = "cuda" if torch.cuda.is_available() else "cpu"
    print("device:", dev, flush=True)
    print("collecting audio ...", flush=True)
    Xtr, ytr = collect("train", torch)
    Xte, yte = collect("eval", torch)
    print("train %s pos=%d | eval %s pos=%d"
          % (Xtr.shape, ytr.sum(), Xte.shape, yte.sum()), flush=True)

    bundle = torchaudio.pipelines.WAVLM_BASE_PLUS
    enc = bundle.get_model().to(dev)
    # freeze the CNN front end -- standard, and fine-tuning it on 8.6k clips
    # mostly destroys the low-level acoustics it already encodes
    for p in enc.feature_extractor.parameters():
        p.requires_grad = False

    head = nn.Sequential(nn.Linear(768 * 2, 128), nn.ReLU(), nn.Dropout(0.3),
                         nn.Linear(128, 1)).to(dev)
    opt = torch.optim.AdamW([
        {"params": [p for p in enc.parameters() if p.requires_grad],
         "lr": 1e-5},
        {"params": head.parameters(), "lr": 1e-4},
    ], weight_decay=0.01)
    pos_w = torch.tensor([(ytr == 0).sum() / max((ytr == 1).sum(), 1)],
                         dtype=torch.float32, device=dev)
    lossf = nn.BCEWithLogitsLoss(pos_weight=pos_w)

    def embed(batch):
        hs, _ = enc.extract_features(batch)
        h = hs[-1]
        return torch.cat([h.mean(dim=1), h.std(dim=1)], dim=1)

    @torch.inference_mode()
    def evaluate():
        enc.eval()
        head.eval()
        ps = []
        for i in range(0, len(Xte), BATCH):
            xb = torch.from_numpy(Xte[i:i + BATCH]).to(dev)
            ps.append(torch.sigmoid(head(embed(xb))).squeeze(-1).cpu()
                      .numpy())
        return float(roc_auc_score(yte, np.concatenate(ps)))

    print("epoch 0 (frozen init) AUC %.4f" % evaluate(), flush=True)
    best, best_ep = 0.0, -1
    oom, step = 0, 0
    scaler = torch.amp.GradScaler("cuda", enabled=(dev == "cuda"))
    rng = np.random.RandomState(42)
    t0 = time.time()
    for ep in range(EPOCHS):
        enc.train()
        head.train()
        order = rng.permutation(len(Xtr))
        tot = 0.0
        for k in range(0, len(order), BATCH):
            idx = order[k:k + BATCH]
            xb = torch.from_numpy(Xtr[idx]).to(dev)
            yb = torch.from_numpy(ytr[idx].astype(np.float32)).to(dev)
            try:
                with torch.autocast(device_type="cuda",
                                    dtype=torch.float16,
                                    enabled=(dev == "cuda")):
                    loss = lossf(head(embed(xb)).squeeze(-1), yb) / ACCUM
                scaler.scale(loss).backward()
                step += 1
                if step % ACCUM == 0:
                    scaler.unscale_(opt)
                    torch.nn.utils.clip_grad_norm_(
                        [p for p in enc.parameters() if p.requires_grad] +
                        list(head.parameters()), 1.0)
                    scaler.step(opt)
                    scaler.update()
                    opt.zero_grad(set_to_none=True)
                tot += float(loss) * ACCUM * len(idx)
            except torch.cuda.OutOfMemoryError:
                # report rather than die silently -- the first attempt gave no
                # traceback at all, which cost a full run to diagnose
                oom += 1
                opt.zero_grad(set_to_none=True)
                torch.cuda.empty_cache()
                if oom > 20:
                    print("  ABORTING: %d OOMs even at batch %d -- this card "
                          "cannot fine-tune this model" % (oom, BATCH),
                          flush=True)
                    raise
        a = evaluate()
        if a > best:
            best, best_ep = a, ep + 1
        print("  epoch %d  loss %.4f  eval AUC %.4f  oom=%d  %ds"
              % (ep + 1, tot / len(order), a, oom, int(time.time() - t0)),
              flush=True)

    print("\n  best AUC %.4f at epoch %d" % (best, best_ep))
    print("  frozen WavLM probe   %.4f" % FROZEN_BASELINE)
    print("  38-dim tuned head    %.4f" % DIM38_BASELINE)
    print("  fine-tune gain over frozen  %+.4f" % (best - FROZEN_BASELINE))
    print("  fine-tune gain over 38-dim  %+.4f" % (best - DIM38_BASELINE))
    if best >= 0.78:
        v = ("STRONG - distillation is worth scoping; train a small student "
             "on this teacher and ship the student")
    elif best >= 0.72:
        v = ("AWKWARD - too good to dismiss, not enough to justify a new "
             "encoder pipeline by itself")
    else:
        v = ("CLOSED - fine-tuning adds little over probing; the "
             "representation is not the lever and item 7 is settled")
    print("  -> %s" % v)
    json.dump({"best_auc": round(best, 4), "best_epoch": best_ep,
               "frozen": FROZEN_BASELINE, "dim38": DIM38_BASELINE,
               "gain_vs_frozen": round(best - FROZEN_BASELINE, 4),
               "gain_vs_38dim": round(best - DIM38_BASELINE, 4),
               "verdict": v},
              open(os.path.join(HERE, "finetune_report.json"), "w"), indent=2)
    print("report written")


if __name__ == "__main__":
    main()
