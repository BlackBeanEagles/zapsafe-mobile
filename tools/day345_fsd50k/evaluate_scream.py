"""Day 345 — re-run the scream v3-vs-v4 comparison on 8x the eval data.

Day 339 concluded v4 was indistinguishable from v3: delta +0.0156 with a 95%
bootstrap CI of [-0.0287, +0.0617]. That verdict was correct but weak — with
only **45** real held-out positives the CI was ~±0.05, wide enough to hide
any improvement worth having. The eval set was the blocker, not the model.

FSD50K's eval split is independent of AudioSet (Freesound-sourced, different
annotation pipeline) and properly held out, giving:

    Screaming 123 + Shout 177 + Yell 60  = 360 positives
    Speech/Chatter/Laughter/Singing/Cough/Sneeze/... = 2,561 hard negatives

Those negatives matter as much as the positives: a scream detector's real
failure is firing on a laugh or a shouted conversation, not on silence.

Same preprocessing as `scream_v3`'s own training: 22.05 kHz, 3 s, 128 mels,
n_fft 2048, hop 512, 131 frames, per-clip min-max to [0,1].
"""
import collections
import json
import os

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
AUDIO = os.path.join(HERE, "audio")
REPO = (r"C:\Users\hridy\Desktop\zapsafe\letsstartbuilding"
        r"\zapsafe_mobile_main_reconcile")
V3 = os.path.join(REPO, "assets", "models", "scream_classifier_v3.tflite")
V4 = r"C:\Users\hridy\Desktop\zapsafe\work\scream_v4\m1_scream_v3_float16.tflite"

SR, DURATION, N_MELS, N_FFT, HOP, FRAMES = 22050, 3, 128, 2048, 512, 131
NEED = SR * DURATION

POS = {"Screaming", "Shout", "Yell"}
NEG = {"Speech", "Chatter", "Laughter", "Singing", "Cough", "Sneeze",
       "Conversation", "Male_speech_and_man_speaking",
       "Female_speech_and_woman_speaking"}


def mel_from(y, sr):
    import librosa
    if y.ndim > 1:
        y = y.mean(axis=1)
    if sr != SR:
        y = librosa.resample(y, orig_sr=sr, target_sr=SR)
    if len(y) < SR * 0.2:
        return None
    y = np.pad(y, (0, NEED - len(y))) if len(y) < NEED else y[:NEED]
    mel = librosa.feature.melspectrogram(y=y, sr=SR, n_mels=N_MELS,
                                         n_fft=N_FFT, hop_length=HOP)
    db = librosa.power_to_db(mel, ref=np.max)
    rng = float(db.max() - db.min())
    if rng < 1e-6:
        return None
    db = (db - db.min()) / (rng + 1e-9)
    if db.shape[1] < FRAMES:
        db = np.pad(db, ((0, 0), (0, FRAMES - db.shape[1])))
    return db[:, :FRAMES].astype(np.float32)


def main():
    import librosa
    import tensorflow as tf
    from sklearn.metrics import roc_auc_score

    manifest = json.load(open(os.path.join(HERE, "manifest.json")))
    rows = []
    for m in manifest:
        labs = set(m["labels"])
        if labs & POS:
            rows.append((m["fname"], 1))
        elif labs & NEG and not (labs & POS):
            rows.append((m["fname"], 0))
    print(f"eval rows: {len(rows)}  pos {sum(r[1] for r in rows)}  "
          f"neg {sum(1-r[1] for r in rows)}")

    X, y = [], []
    for fname, lab in rows:
        p = os.path.join(AUDIO, fname)
        if not os.path.exists(p):
            continue
        try:
            wav, sr = librosa.load(p, sr=None, mono=True)
        except Exception:
            continue
        mel = mel_from(wav, sr)
        if mel is None:
            continue
        X.append(mel)
        y.append(lab)
        if len(X) % 400 == 0:
            print(f"  featurised {len(X)} ...", flush=True)
    X = np.stack(X)
    y = np.asarray(y)
    print(f"\nfeaturised {len(y)}  pos {int(y.sum())}  neg {int((1-y).sum())}")

    def scores(path, batch=64):
        """Batched inference.

        Resizing the input to the full set and invoking once returned FEWER
        outputs than inputs (228 for 1,764) -- the output tensor does not
        always follow a resize. Batching sidesteps that, and the assert
        makes a silent length mismatch impossible rather than letting it
        surface later as an sklearn shape error.
        """
        it = tf.lite.Interpreter(model_path=path)
        out = []
        for i in range(0, len(X), batch):
            chunk = X[i:i + batch]
            it.resize_tensor_input(it.get_input_details()[0]["index"],
                                   [len(chunk), N_MELS, FRAMES, 1])
            it.allocate_tensors()
            i0, o0 = it.get_input_details()[0], it.get_output_details()[0]
            it.set_tensor(i0["index"], chunk[..., None].astype(np.float32))
            it.invoke()
            r = np.ravel(it.get_tensor(o0["index"]))
            assert len(r) == len(chunk), f"{len(r)} outputs for {len(chunk)} inputs"
            out.append(r)
        p = np.concatenate(out)
        assert len(p) == len(X), f"{len(p)} scores for {len(X)} clips"
        return p

    p3, p4 = scores(V3), scores(V4)
    a3, a4 = roc_auc_score(y, p3), roc_auc_score(y, p4)
    print(f"\n  v3 AUC = {a3:.4f}")
    print(f"  v4 AUC = {a4:.4f}    delta {a4-a3:+.4f}")

    rng = np.random.RandomState(0)
    d = []
    for _ in range(2000):
        i = rng.randint(0, len(y), len(y))
        if len(set(y[i].tolist())) < 2:
            continue
        d.append(roc_auc_score(y[i], p4[i]) - roc_auc_score(y[i], p3[i]))
    d = np.array(d)
    lo, hi = np.percentile(d, [2.5, 97.5])
    print(f"  bootstrap delta: mean {d.mean():+.4f}  95% CI [{lo:+.4f}, {hi:+.4f}]")
    print(f"  P(v4 > v3) = {(d > 0).mean():.3f}")
    print(f"  (Day 339 on 45 positives: CI [-0.0287, +0.0617], width "
          f"{0.0617+0.0287:.4f}; now width {hi-lo:.4f})")

    print(f"\n  operating points, v3 (app ships t=0.20):")
    for t in (0.40, 0.30, 0.25, 0.20, 0.15, 0.10):
        pred = p3 >= t
        tp = float((pred & (y == 1)).sum())
        mark = "  <- shipped" if abs(t - 0.20) < 1e-9 else ""
        print(f"    t={t:.2f}  recall {tp/max(1,y.sum()):.3f}  "
              f"precision {tp/max(1,pred.sum()):.3f}{mark}")

    json.dump({"n": int(len(y)), "pos": int(y.sum()), "neg": int((1-y).sum()),
               "v3_auc": round(float(a3), 4), "v4_auc": round(float(a4), 4),
               "delta": round(float(a4-a3), 4),
               "ci95": [round(float(lo), 4), round(float(hi), 4)],
               "p_v4_better": round(float((d > 0).mean()), 3)},
              open(os.path.join(HERE, "scream_fsd50k_report.json"), "w"),
              indent=2)


if __name__ == "__main__":
    main()
