"""Day 357 - train the phone-concealed detector that replaces k_confinement.

CONTRACT, matched to the slot it takes over
===========================================
    imu    [1, 128, 6]  float32   acc xyz + gyro xyz, m/s^2 and rad/s
    light  [1,  32, 1]  float32   log-lux, broadcast scalar
    out    [1, 1]       float32   P(phone concealed)

Identical to `k_confinement_decorrelated.tflite`'s tensor shapes, so the
existing Dart plumbing and the gate's dual-input path need no change. Only
the NAME changes, because only the name was dishonest.

SPLIT BY UUID. The 60 participants each carry one phone in one pocket with
one gait; a random split over minutes would put the same device on both
sides and report memorisation. Held-out participants are the only honest
measure of "will this work for a new user".

NORMALISATION IS FITTED ON TRAIN ONLY and exported. Day 318 measured a
sibling model dropping 0.844 -> 0.52 when its norm was skipped, so the
stats ship with the asset and the loader must fail without them.

PRE-REGISTERED BARS, fixed before the run:
    held-out-participant AUC >= 0.75 and CI lower bound > 0.50
Below that it is not shipped, and the slot stays empty rather than gaining
a second model that looks like it works.

THE CONTROL THAT COULD SINK IT: light alone. If a single lux value scores
as well as the full model, the IMU contributes nothing and this is a
darkness sensor with extra steps -- worth knowing before it is called a
detector.
"""
from __future__ import annotations

import json
import os

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "enclosure_dataset.npz")
SEED = 42
HOLDOUT = 0.25
BAR_AUC = 0.75


def ci(y, p, n=4000):
    from sklearn.metrics import roc_auc_score
    rng = np.random.RandomState(0)
    b = []
    for _ in range(n):
        i = rng.randint(0, len(y), len(y))
        if len(set(y[i].tolist())) < 2:
            continue
        b.append(roc_auc_score(y[i], p[i]))
    return float(np.percentile(b, 2.5)), float(np.percentile(b, 97.5))


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
    print("IMU %s  light %s  pos=%d (%.1f%%)  participants=%d"
          % (X.shape, L.shape, int(y.sum()), 100 * y.mean(),
             len(set(uu.tolist()))))

    rng = np.random.RandomState(SEED)
    users = np.unique(uu)
    held = set(rng.permutation(users)[:max(1, int(round(len(users) *
                                                       HOLDOUT)))].tolist())
    te = np.array([u in held for u in uu])
    tr = ~te
    print("participant-disjoint: train %d / held-out %d (%d of %d users)"
          % (int(tr.sum()), int(te.sum()), len(held), len(users)))

    imu_mean = X[tr].reshape(-1, 6).mean(axis=0)
    imu_std = X[tr].reshape(-1, 6).std(axis=0) + 1e-8
    lt_mean = float(L[tr].mean())
    lt_std = float(L[tr].std()) + 1e-8

    def ZX(A):
        return ((A - imu_mean) / imu_std).astype(np.float32)

    def ZL(A):
        return ((A - lt_mean) / lt_std).astype(np.float32)

    imu_in = tf.keras.Input(shape=(128, 6), name="imu")
    lt_in = tf.keras.Input(shape=(32, 1), name="light")
    h = tf.keras.layers.Conv1D(32, 5, padding="same", activation="relu")(imu_in)
    h = tf.keras.layers.MaxPooling1D(2)(h)
    h = tf.keras.layers.Conv1D(64, 5, padding="same", activation="relu")(h)
    h = tf.keras.layers.GlobalAveragePooling1D()(h)
    g = tf.keras.layers.GlobalAveragePooling1D()(lt_in)
    z = tf.keras.layers.Concatenate()([h, g])
    z = tf.keras.layers.Dense(64, activation="relu")(z)
    z = tf.keras.layers.Dropout(0.3)(z)
    out = tf.keras.layers.Dense(1, activation="sigmoid", name="concealed")(z)
    m = tf.keras.Model([imu_in, lt_in], out, name="phone_enclosure_v1")
    tf.random.set_seed(SEED)
    np.random.seed(SEED)
    m.compile(optimizer=tf.keras.optimizers.Adam(1e-3),
              loss="binary_crossentropy",
              metrics=[tf.keras.metrics.AUC(name="auc")])
    n1, n0 = int(y[tr].sum()), int((1 - y[tr]).sum())
    m.fit([ZX(X[tr]), ZL(L[tr])], y[tr],
          validation_data=([ZX(X[te]), ZL(L[te])], y[te]),
          epochs=60, batch_size=128, verbose=0,
          class_weight={0: len(y[tr]) / (2.0 * max(n0, 1)),
                        1: len(y[tr]) / (2.0 * max(n1, 1))},
          callbacks=[tf.keras.callbacks.EarlyStopping(
              monitor="val_auc", mode="max", patience=10,
              restore_best_weights=True)])

    p = m.predict([ZX(X[te]), ZL(L[te])], verbose=0).ravel()
    auc = float(roc_auc_score(y[te], p))
    lo, hi = ci(y[te], p)
    print("\n  held-out participants  AUC %.4f  CI [%.4f, %.4f]  n=%d"
          % (auc, lo, hi, int(te.sum())))

    # CONTROL: does the light value alone do just as well?
    lx_tr = L[tr][:, 0, 0].reshape(-1, 1)
    lx_te = L[te][:, 0, 0].reshape(-1, 1)
    lr = LogisticRegression(max_iter=2000, class_weight="balanced")
    lr.fit(lx_tr, y[tr])
    auc_light = float(roc_auc_score(
        y[te], lr.predict_proba(lx_te)[:, 1]))
    print("  CONTROL light-only logistic: %.4f" % auc_light)
    gain = auc - auc_light
    print("  the IMU is worth %+.4f over light alone" % gain)
    if gain < 0.02:
        print("  -> the IMU adds nothing; this is a darkness sensor and "
              "should be described as one")

    ship = bool(auc >= BAR_AUC and lo > 0.50)
    print("\n  CLEARS BARS (AUC>=%.2f and CI>0.50) -> %s" % (BAR_AUC, ship))
    rep = {"auc": round(auc, 4), "ci95": [round(lo, 4), round(hi, 4)],
           "light_only_auc": round(auc_light, 4),
           "imu_gain_over_light": round(gain, 4),
           "n_test": int(te.sum()), "n_train": int(tr.sum()),
           "held_out_users": len(held), "total_users": len(users),
           "pos_rate": round(float(y.mean()), 4), "ships": ship}
    if ship:
        conv = tf.lite.TFLiteConverter.from_keras_model(m)
        conv.optimizations = [tf.lite.Optimize.DEFAULT]
        conv.target_spec.supported_types = [tf.float16]
        blob = conv.convert()
        open(os.path.join(HERE, "m_phone_enclosure_v1.tflite"),
             "wb").write(blob)
        json.dump({"imu_mean": imu_mean.tolist(),
                   "imu_std": imu_std.tolist(),
                   "light_mean": lt_mean, "light_std": lt_std},
                  open(os.path.join(HERE,
                                    "m_phone_enclosure_v1_norm.json"), "w"))
        rep["float16_kb"] = round(len(blob) / 1024, 1)
        print("  exported m_phone_enclosure_v1.tflite (%s KB) + norm"
              % rep["float16_kb"])
    else:
        print("  NOT EXPORTED -- the slot stays empty rather than gaining a "
              "second model that looks like it works")
    json.dump(rep, open(os.path.join(HERE, "enclosure_report.json"), "w"),
              indent=2)
    print("report written")


if __name__ == "__main__":
    main()
