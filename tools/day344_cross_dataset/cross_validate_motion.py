"""Day 344 — does motion_fall_v2 generalise beyond UniMiB?

Day 340 showed its 0.999 is not split luck (mean 0.9901 over six held-out
UniMiB subject sets). But every one of those numbers came from the dataset it
was TRAINED on. Robust across subjects is not the same as robust across
datasets, devices or wear positions, and the app ships this as its strongest
detector.

The ASSIST-IoT/SRIPAS multimodal fall dataset is a genuinely independent
test: different subjects (22), different hardware (a waist tag and two
smartwatches), different sampling rate, collected by a different group. If
motion_fall_v2 holds here, its 0.999 means something on a real phone. If it
collapses, the number describes UniMiB rather than falling.

TWO CONVERSIONS, BOTH OF WHICH HAVE BITTEN THIS PROJECT BEFORE
==============================================================
* **Units.** This dataset is in **g** (measured median |acc| = 1.003).
  UniMiB — and therefore the model — is in **m/s^2 with gravity** (median
  9.41). Feeding g directly would be the exact 9.8x error that made
  i_vehicle_crash score 0.5000, so it is multiplied by 9.80665.
* **Rate.** Timestamps are ~8 ms apart (~125 Hz); the model wants 100
  samples at 50 Hz. Windows are resampled by timestamp rather than by
  decimating every Nth row, because the stream has gaps.

The model's own norm constants are applied, since `MotionDetectorV2`'s doc
calls that "the trap here".
"""
from __future__ import annotations

import io
import zipfile

import numpy as np

ZIP = r"F:\zapsafe\multimodal-fall-detection-dataset-v1.0.0.zip"
MODEL = (r"C:\Users\hridy\Desktop\zapsafe\letsstartbuilding"
         r"\zapsafe_mobile_main_reconcile\assets\models\motion_fall_v2.tflite")
NORM = MODEL.replace(".tflite", "_norm.json")

WINDOW, CHANNELS, RATE_HZ = 100, 3, 50
G = 9.80665


def load_rows():
    """-> per (participant, source) ordered lists of (t_ms, x, y, z, is_fall)."""
    z = zipfile.ZipFile(ZIP)
    out = {}
    from datetime import datetime
    for name in [n for n in z.namelist() if n.endswith("acceleration.csv")]:
        txt = z.read(name).decode("utf-8", "replace")
        for ln in txt.split("\n")[1:]:
            f = ln.split("|")
            # TYPE is the recording SCENARIO, not the sensor: 'A' = ADL
            # sessions (3.2M rows, zero falls), 'F' = fall sessions (1.67M
            # rows, 164,820 falls), 'M' = mannequin. Filtering to 'A' --
            # which the first version of this did, reading it as
            # "acceleration" -- excludes every fall in the dataset and
            # yields a single-class set. 'M' is dropped because a dropped
            # mannequin is not a falling person.
            if len(f) < 10 or f[7] not in ("A", "F"):
                continue
            try:
                t = datetime.strptime(f[2][:23], "%Y-%m-%d %H:%M:%S.%f")
                rec = (t.timestamp() * 1000.0, float(f[4]), float(f[5]),
                       float(f[6]), int(f[9]))
            except Exception:
                continue
            out.setdefault((f[1], f[3]), []).append(rec)
    return out


def windows_for(rows, source_filter=None, centred=True):
    """Resample each stream to 50 Hz and window it.

    `centred=True` matches UniMiB's convention and is the honest comparison.
    The first version of this labelled a window positive if ANY sample in it
    was a fall, sliding at 50% overlap — so a fall clipping the very edge of
    a window counted as a full positive, while UniMiB crops each window
    *centred on the event*. That inflated the hard-positive count and made
    recall look worse than the model deserves, which is why the first number
    (0.687) is a floor rather than an estimate.

    Centred mode instead emits:
      * one window per fall event, centred on the middle of that event;
      * non-overlapping negative windows from stretches with no fall at all,
        keeping a margin so a window adjacent to a fall is not labelled
        negative.
    """
    X, y, subj = [], [], []
    step_ms = 1000.0 / RATE_HZ
    span_ms = WINDOW * step_ms
    for (participant, source), recs in rows.items():
        if source_filter and source != source_filter:
            continue
        recs.sort(key=lambda r: r[0])
        t = np.array([r[0] for r in recs])
        a = np.array([[r[1], r[2], r[3]] for r in recs], dtype=np.float64)
        fall = np.array([r[4] for r in recs], dtype=np.int32)
        if len(t) < 4:
            continue

        def emit(centre_ms, label):
            start = centre_ms - span_ms / 2.0
            if start < t[0] or start + span_ms > t[-1]:
                return
            grid = start + np.arange(WINDOW) * step_ms
            idx = np.clip(np.searchsorted(t, grid), 1, len(t) - 1)
            if np.max(np.abs(t[idx] - grid)) > 200:   # stream gap
                return
            w = np.stack([np.interp(grid, t, a[:, c]) for c in range(3)],
                         axis=-1) * G                 # g -> m/s^2
            X.append(w.astype(np.float32))
            y.append(float(label))
            subj.append(participant)

        # --- one centred window per contiguous fall event ---------------
        events, i = [], 0
        while i < len(fall):
            if fall[i] == 1:
                j = i
                while j + 1 < len(fall) and fall[j + 1] == 1:
                    j += 1
                events.append((t[i], t[j]))
                i = j + 1
            else:
                i += 1
        for lo, hi in events:
            emit((lo + hi) / 2.0, 1)

        # --- negatives: non-overlapping, kept clear of any fall ---------
        margin = span_ms
        start = t[0]
        while start + span_ms <= t[-1]:
            centre = start + span_ms / 2.0
            if all(abs(centre - (lo + hi) / 2.0) > span_ms + margin
                   for lo, hi in events):
                emit(centre, 0)
            start += span_ms
    return np.stack(X), np.asarray(y, np.float32), np.asarray(subj)


def main():
    import json
    import tensorflow as tf
    from sklearn.metrics import roc_auc_score

    print("reading acceleration CSVs from the zip (no extraction) ...")
    rows = load_rows()
    print(f"  streams: {len(rows)}  "
          f"participants {len({p for p, _ in rows})}  "
          f"sources {sorted({s for _, s in rows})}")

    norm = json.load(open(NORM))
    mean = np.asarray(norm["mean"], np.float32)
    std = np.asarray(norm["std"], np.float32)
    print(f"  model norm mean {np.round(mean,3).tolist()} std {np.round(std,3).tolist()}")

    it = tf.lite.Interpreter(model_path=MODEL)
    i0 = it.get_input_details()[0]
    o0 = it.get_output_details()[0]

    # WATCH_L/WATCH_R report LINEAR acceleration (gravity removed: raw
    # median 0.128/0.133 g) while TAG reports gravity-present (1.007 g), the
    # convention the model was trained on. Feeding the watches through a
    # gravity-present conversion tested the model on a quantity it has never
    # seen and it emitted a constant. They are excluded as an invalid
    # comparison, not a model result.
    for source in ("TAG",):
        X, y, subj = windows_for(rows, source)
        if len(set(y.tolist())) < 2:
            print(f"\n[{source or 'ALL'}] single-class, skipped")
            continue
        it.resize_tensor_input(i0["index"], [len(X), WINDOW, CHANNELS])
        it.allocate_tensors()
        Xn = ((X - mean) / std).astype(np.float32)
        it.set_tensor(i0["index"], Xn)
        it.invoke()
        p = np.ravel(it.get_tensor(o0["index"]))
        auc = roc_auc_score(y, p)
        pos, neg = p[y == 1], p[y == 0]
        print(f"\n[{source or 'ALL SOURCES'}]  n={len(y)}  "
              f"falls={int(y.sum())} ({y.mean()*100:.1f}%)")
        print(f"   median |acc| = {np.median(np.linalg.norm(X, axis=2)):.2f} m/s^2"
              f"   (UniMiB was 9.41)")
        print(f"   AUC = {auc:.4f}   sep = {pos.mean()-neg.mean():+.4f}"
              f"   span = {p.max()-p.min():.4f}")
        for t in (0.9, 0.7, 0.5, 0.3):
            pred = p >= t
            tp = float((pred & (y == 1)).sum())
            print(f"     t={t:.1f}  recall {tp/max(1,y.sum()):.3f}  "
                  f"precision {tp/max(1,pred.sum()):.3f}")


if __name__ == "__main__":
    main()
