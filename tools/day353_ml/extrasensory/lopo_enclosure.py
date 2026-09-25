"""Day 357 - leave-one-participant-out, because 16 people is not many.

WHY THE SINGLE SPLIT IS NOT ENOUGH
==================================
The light sensor is only exposed by Android phones, so of ExtraSensory's 60
participants just 16 survive into this dataset, and they are badly skewed:

    3624 3370 3092 1427 1032 985 751 646 625 502 313 304 201 89 52 41

Three people are 59% of the rows. A 25% holdout is FOUR participants, so a
single split answers "does this work for these four" -- and depending on
which four, the test set is either dominated by one person or is a few
dozen clips. Either way one number from it is close to meaningless.

WHAT THIS DOES INSTEAD
======================
Leave-one-participant-out across all 16. Every participant takes a turn as
the held-out test set, trained from scratch on the other 15. That yields a
DISTRIBUTION of per-person AUCs, which is the thing worth knowing for a
model that has to work on a stranger's phone:

  * the median says what a typical new user gets
  * the minimum says how bad it gets for the worst-served person
  * the spread says whether "it works" is even a stable statement

A model that averages 0.85 but collapses to 0.55 for a quarter of people is
not a 0.85 model for a safety feature, and a single split would have hidden
that.

Participants with fewer than MIN_TEST clips or only one class present are
skipped for testing (they still train), and that is reported rather than
silently dropped.

THE LIGHT-ONLY CONTROL runs per fold too. If lux alone matches the full
model across folds, the IMU is decoration and the honest name is a darkness
sensor, not a concealment detector.
"""
from __future__ import annotations

import json
import os

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "enclosure_dataset.npz")
SEED = 42
MIN_TEST = 60


def build(dim_imu=(128, 6), dim_lt=(32, 1)):
    import tensorflow as tf
    imu_in = tf.keras.Input(shape=dim_imu, name="imu")
    lt_in = tf.keras.Input(shape=dim_lt, name="light")
    h = tf.keras.layers.Conv1D(32, 5, padding="same", activation="relu")(imu_in)
    h = tf.keras.layers.MaxPooling1D(2)(h)
    h = tf.keras.layers.Conv1D(64, 5, padding="same", activation="relu")(h)
    h = tf.keras.layers.GlobalAveragePooling1D()(h)
    g = tf.keras.layers.GlobalAveragePooling1D()(lt_in)
    z = tf.keras.layers.Concatenate()([h, g])
    z = tf.keras.layers.Dense(64, activation="relu")(z)
    z = tf.keras.layers.Dropout(0.3)(z)
    out = tf.keras.layers.Dense(1, activation="sigmoid")(z)
    return tf.keras.Model([imu_in, lt_in], out)


def main():
    import tensorflow as tf
    from sklearn.metrics import roc_auc_score
    from sklearn.linear_model import LogisticRegression

    d = np.load(DATA, allow_pickle=True)
    X = np.nan_to_num(d["X"].astype(np.float32), nan=0.0, posinf=0.0,
                      neginf=0.0)
    L = np.nan_to_num(d["L"].astype(np.float32), nan=0.0, posinf=0.0,
                      neginf=0.0)
    y = np.asarray(d["y"]).astype(int)
    uu = np.asarray(d["uuid"])
    users = sorted(set(uu.tolist()))
    print("participants: %d   clips %d   pos %d" % (len(users), len(y),
                                                    int(y.sum())))

    rows, skipped = [], []
    for k, held in enumerate(users):
        te = uu == held
        tr = ~te
        if int(te.sum()) < MIN_TEST or len(set(y[te].tolist())) < 2:
            skipped.append((held[:8], int(te.sum()),
                            len(set(y[te].tolist()))))
            continue
        imu_mean = X[tr].reshape(-1, 6).mean(axis=0)
        imu_std = X[tr].reshape(-1, 6).std(axis=0) + 1e-8
        lm, ls = float(L[tr].mean()), float(L[tr].std()) + 1e-8
        ZX = lambda A: ((A - imu_mean) / imu_std).astype(np.float32)
        ZL = lambda A: ((A - lm) / ls).astype(np.float32)

        tf.keras.backend.clear_session()
        tf.random.set_seed(SEED)
        np.random.seed(SEED)
        m = build()
        m.compile(optimizer=tf.keras.optimizers.Adam(1e-3),
                  loss="binary_crossentropy",
                  metrics=[tf.keras.metrics.AUC(name="auc")])
        n1, n0 = int(y[tr].sum()), int((1 - y[tr]).sum())
        m.fit([ZX(X[tr]), ZL(L[tr])], y[tr], epochs=25, batch_size=128,
              verbose=0,
              class_weight={0: len(y[tr]) / (2.0 * max(n0, 1)),
                            1: len(y[tr]) / (2.0 * max(n1, 1))})
        p = m.predict([ZX(X[te]), ZL(L[te])], verbose=0).ravel()
        auc = float(roc_auc_score(y[te], p))

        lr = LogisticRegression(max_iter=2000, class_weight="balanced")
        lr.fit(L[tr][:, 0, 0].reshape(-1, 1), y[tr])
        auc_l = float(roc_auc_score(
            y[te], lr.predict_proba(L[te][:, 0, 0].reshape(-1, 1))[:, 1]))

        rows.append({"user": held[:8], "n": int(te.sum()),
                     "pos_rate": round(float(y[te].mean()), 3),
                     "auc": round(auc, 4), "light_only": round(auc_l, 4),
                     "imu_gain": round(auc - auc_l, 4)})
        print("  %-9s n=%-5d pos=%.2f  AUC %.4f   light-only %.4f   "
              "IMU %+.4f" % (held[:8], int(te.sum()), float(y[te].mean()),
                             auc, auc_l, auc - auc_l), flush=True)

    if not rows:
        print("no evaluable folds")
        return
    a = np.array([r["auc"] for r in rows])
    lo = np.array([r["light_only"] for r in rows])
    print("\n  folds evaluated: %d  (skipped %d: %s)"
          % (len(rows), len(skipped), skipped))
    print("  AUC        median %.4f  mean %.4f  min %.4f  max %.4f"
          % (np.median(a), a.mean(), a.min(), a.max()))
    print("  light-only median %.4f  mean %.4f" % (np.median(lo), lo.mean()))
    print("  IMU gain   median %+.4f" % np.median(a - lo))
    below = int((a < 0.70).sum())
    print("  participants below 0.70: %d of %d" % (below, len(a)))
    verdict = ("USABLE - median clears 0.75 and the worst fold is not at "
               "chance" if np.median(a) >= 0.75 and a.min() >= 0.60 else
               "UNSTABLE ACROSS PEOPLE - a single-split number would have "
               "hidden this")
    print("  -> %s" % verdict)
    json.dump({"folds": rows, "median_auc": round(float(np.median(a)), 4),
               "mean_auc": round(float(a.mean()), 4),
               "min_auc": round(float(a.min()), 4),
               "max_auc": round(float(a.max()), 4),
               "median_light_only": round(float(np.median(lo)), 4),
               "median_imu_gain": round(float(np.median(a - lo)), 4),
               "below_070": below, "n_folds": len(rows),
               "skipped": skipped, "verdict": verdict},
              open(os.path.join(HERE, "lopo_report.json"), "w"), indent=2)
    print("lopo_report written")


if __name__ == "__main__":
    main()
