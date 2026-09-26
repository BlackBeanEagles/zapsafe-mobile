"""Day 360 - k_confinement, with the identity shortcut removed by design.

WHAT KILLED IT ON DAY 357
=========================
The enclosure model cleared its bar (AUC 0.753) and was refused, because:

    participants that are 100% one class   11 of 16
    AUC of PARTICIPANT IDENTITY alone       0.8804

Knowing who the person is scored 0.88 -- better than the model. Eleven of
sixteen participants never varied, so "concealed" was very nearly a property
of the participant rather than the situation, and the model could score by
recognising the person.

THE FIX THAT WAS NOT TRIED
==========================
Restrict to participants who have **both** classes. For those, concealment
varies WITHIN the person, so identity carries no information about the label
and the shortcut is gone by construction rather than by hoping.

    4E98F91F   751 clips    49 pos   (6.5%)
    59EEFAE0  3370 clips   864 pos  (25.6%)
    806289BC  3624 clips   764 pos  (21.1%)
    86A4F379   625 clips   279 pos  (44.6%)
    B7F9D634  3092 clips   506 pos  (16.4%)

Five participants, 11,462 clips, 2,462 positives. Fewer people but every one
of them contrasts with themselves.

HOW IT IS JUDGED
================
Leave-one-participant-out across all five, reported as a distribution, plus
the identity control re-run on the restricted set -- which should now sit
near chance. If identity still predicts the label, the restriction did not
work and the result means nothing.

SHIP RULE, fixed before running:
    LOPO median >= 0.75, worst fold >= 0.65, AND identity-alone <= 0.60
Five folds is few; a median that depends on one good participant is not a
model, so the worst fold has to hold too.
"""
from __future__ import annotations

import json
import os

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "enclosure_dataset.npz")
SEED = 42


def build(dim_imu=(128, 6), dim_lt=(32, 1), seed=SEED):
    import tensorflow as tf
    tf.keras.backend.clear_session()
    tf.random.set_seed(seed)
    np.random.seed(seed)
    imu_in = tf.keras.Input(shape=dim_imu, name="imu")
    lt_in = tf.keras.Input(shape=dim_lt, name="light")
    h = tf.keras.layers.Conv1D(32, 5, padding="same",
                               activation="relu")(imu_in)
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

    # keep only participants who contrast with themselves
    both = [u for u in np.unique(uu)
            if 0 < float(y[uu == u].mean()) < 1]
    m = np.array([u in set(both) for u in uu])
    X, L, y, uu = X[m], L[m], y[m], uu[m]
    print("participants with BOTH classes: %d of %d"
          % (len(both), len(np.unique(d["uuid"]))))
    print("restricted set: %d clips, %d positives (%.1f%%)"
          % (len(y), y.sum(), 100 * y.mean()))
    for u in both:
        k = uu == u
        print("    %-9s %5d clips  %5d pos  (%.1f%%)"
              % (u[:8], int(k.sum()), int(y[k].sum()),
                 100 * float(y[k].mean())))

    # THE CONTROL: can identity still predict the label?
    rate = np.array([y[uu == u].mean() for u in uu])
    id_auc = float(roc_auc_score(y, rate))
    print("\n  identity-alone AUC on the restricted set: %.4f "
          "(was 0.8804 on all 16)" % id_auc)
    if id_auc > 0.60:
        print("  -> identity STILL predicts the label; the restriction did "
              "not remove the shortcut and the result below means nothing")

    rows = []
    for held in both:
        te = uu == held
        tr = ~te
        if len(set(y[te].tolist())) < 2:
            continue
        imu_mean = X[tr].reshape(-1, 6).mean(axis=0)
        imu_std = X[tr].reshape(-1, 6).std(axis=0) + 1e-8
        lm, ls = float(L[tr].mean()), float(L[tr].std()) + 1e-8

        def ZX(A):
            return ((A - imu_mean) / imu_std).astype(np.float32)

        def ZL(A):
            return ((A - lm) / ls).astype(np.float32)

        mdl = build()
        mdl.compile(optimizer=tf.keras.optimizers.Adam(1e-3),
                    loss="binary_crossentropy",
                    metrics=[tf.keras.metrics.AUC(name="auc")])
        n1, n0 = int(y[tr].sum()), int((1 - y[tr]).sum())
        mdl.fit([ZX(X[tr]), ZL(L[tr])], y[tr], epochs=25, batch_size=128,
                verbose=0,
                class_weight={0: len(y[tr]) / (2.0 * max(n0, 1)),
                              1: len(y[tr]) / (2.0 * max(n1, 1))})
        p = mdl.predict([ZX(X[te]), ZL(L[te])], verbose=0).ravel()
        auc = float(roc_auc_score(y[te], p))

        lr = LogisticRegression(max_iter=2000, class_weight="balanced")
        lr.fit(L[tr][:, 0, 0].reshape(-1, 1), y[tr])
        al = float(roc_auc_score(
            y[te], lr.predict_proba(L[te][:, 0, 0].reshape(-1, 1))[:, 1]))
        rows.append({"user": held[:8], "n": int(te.sum()),
                     "pos_rate": round(float(y[te].mean()), 3),
                     "auc": round(auc, 4), "light_only": round(al, 4)})
        print("  %-9s n=%-5d pos=%.2f  AUC %.4f   light-only %.4f"
              % (held[:8], int(te.sum()), float(y[te].mean()), auc, al),
              flush=True)

    a = np.array([r["auc"] for r in rows])
    lo = np.array([r["light_only"] for r in rows])
    print("\n  folds %d  AUC median %.4f  mean %.4f  min %.4f  max %.4f"
          % (len(a), np.median(a), a.mean(), a.min(), a.max()))
    print("  light-only median %.4f   IMU gain median %+.4f"
          % (np.median(lo), np.median(a - lo)))
    ship = bool(np.median(a) >= 0.75 and a.min() >= 0.65 and id_auc <= 0.60)
    print("  SHIP (median>=0.75, worst>=0.65, identity<=0.60) -> %s" % ship)
    if not ship:
        why = []
        if np.median(a) < 0.75:
            why.append("median %.3f < 0.75" % np.median(a))
        if a.min() < 0.65:
            why.append("worst fold %.3f < 0.65" % a.min())
        if id_auc > 0.60:
            why.append("identity %.3f > 0.60" % id_auc)
        print("  -> NOT SHIPPED: %s" % "; ".join(why))
    json.dump({"participants": both, "identity_auc": round(id_auc, 4),
               "folds": rows, "median": round(float(np.median(a)), 4),
               "min": round(float(a.min()), 4),
               "median_light_only": round(float(np.median(lo)), 4),
               "ships": ship},
              open(os.path.join(HERE, "within_participant_report.json"), "w"),
              indent=2)
    print("report written")


if __name__ == "__main__":
    main()
