"""Day 359 - permissive glass detector, A/B'd against the shipped one.

WHAT IS BEING TESTED
====================
`m_glass_breaking_v3` carries UrbanSound8K (CC BY-NC 3.0) and cannot ship
commercially. Its own report records the training set:

    train_pos 92   train_neg 1709   eval_real_pos 13
    chosen_threshold 0.8754 (selected on those 13 positives)
    gate, real labelled data: AUC 0.782

This trains on **CC0/CC-BY FSD50K only**: 872 positives and 2,352 negatives,
9.5x the positives, with no NC clip anywhere in it.

The comparison is honest by construction: the training data is FSD50K **dev**
and the evaluation is the gate's own FSD50K **eval** fixture -- disjoint
splits, and the SAME rows the shipped model is scored on. Both models are run
through their real .tflite / Keras path on those identical rows.

RECOVERING THE DATA WAS THE REAL WORK. The extracted FSD50K on disk was
**69.9% zero-byte files** (28,618 of 40,966) -- a silently failed extraction
that had been capping every count at ~30% of the corpus. The spanned archive
would not open (`zipfiles that span multiple disks are not supported`), so
the clips were recovered by scanning local file headers past the unusable
central directory: 3,703 of 3,703 written, 0 CRC failures.

SHIP RULE, fixed before running: the permissive model must match or beat the
shipped model's AUC on the shared fixture. A licence fix that costs accuracy
on a safety detector is not a fix, and would be reported as a trade rather
than shipped.

ARCHITECTURE is copied from work/glass_retrain/train_glass.py so the only
variables are the data and its licence.
"""
from __future__ import annotations

import json
import os

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
EVALDIR = r"C:\Users\hridy\Desktop\zapsafe\work\fsd50k_eval"
ASSETS = (r"C:\Users\hridy\Desktop\zapsafe\letsstartbuilding"
          r"\zapsafe_mobile_main_reconcile\assets\models")
SR, DUR, N_MELS, N_FFT, HOP, FMAX, IMG = 16000, 2.0, 96, 2048, 512, 8000, 96
NEED = int(SR * DUR)
SEEDS = (42, 7, 123)
POS_LABEL = "Glass"


def mel_img(y, librosa):
    y = np.pad(y, (0, NEED - len(y))) if len(y) < NEED else y[:NEED]
    mel = librosa.feature.melspectrogram(y=y, sr=SR, n_mels=N_MELS,
                                         hop_length=HOP, n_fft=N_FFT,
                                         fmax=FMAX)
    db = librosa.power_to_db(mel, ref=np.max)
    rng = db.max() - db.min()
    nz = (db - db.min()) / (rng if rng > 1e-8 else 1.0)
    img = np.resize(nz, (IMG, IMG))
    return np.stack([img] * 3, axis=-1).astype(np.float32)


def load_eval_fixture():
    """The gate's own rows: FSD50K eval, disjoint from the dev training set."""
    import librosa
    man = json.load(open(os.path.join(EVALDIR, "manifest.json"),
                         encoding="utf-8"))
    X, y = [], []
    for m in man:
        p = os.path.join(EVALDIR, "audio", m["fname"])
        if not os.path.exists(p) or os.path.getsize(p) == 0:
            continue
        try:
            w, _ = librosa.load(p, sr=SR, mono=True)
        except Exception:
            continue
        if len(w) < SR * 0.2:
            continue
        X.append(mel_img(w, librosa))
        y.append(1 if POS_LABEL in m.get("labels", []) else 0)
    return np.stack(X), np.asarray(y, np.int64)


def build_net(seed):
    import tensorflow as tf
    tf.keras.backend.clear_session()
    tf.random.set_seed(seed)
    np.random.seed(seed)
    inp = tf.keras.Input(shape=(IMG, IMG, 3))
    x = inp
    for f in (16, 32, 64):
        x = tf.keras.layers.Conv2D(f, 3, padding="same", activation="relu")(x)
        x = tf.keras.layers.MaxPooling2D(2)(x)
    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    x = tf.keras.layers.Dropout(0.3)(x)
    x = tf.keras.layers.Dense(64, activation="relu")(x)
    out = tf.keras.layers.Dense(1, activation="sigmoid", name="glass")(x)
    return tf.keras.Model(inp, out, name="m_glass_permissive_v1")


def main():
    import tensorflow as tf
    from sklearn.metrics import roc_auc_score

    d = np.load(os.path.join(HERE, "glass_dev_mel.npz"), allow_pickle=True)
    Xtr = d["X"].astype(np.float32)
    ytr = np.asarray(d["y"]).astype(int)
    print("permissive train %s pos=%d (CC0/CC-BY only)"
          % (Xtr.shape, ytr.sum()), flush=True)

    print("loading the gate's FSD50K eval fixture ...", flush=True)
    Xe, ye = load_eval_fixture()
    print("eval fixture %s pos=%d (base rate %.3f)"
          % (Xe.shape, ye.sum(), ye.mean()), flush=True)
    if ye.sum() < 30:
        print("too few positives in the fixture to measure; stopping")
        return

    # --- the shipped NC model, on the identical rows
    it = tf.lite.Interpreter(
        model_path=os.path.join(ASSETS, "m_glass_breaking_v3.tflite"))
    it.allocate_tensors()
    i0, o0 = it.get_input_details()[0], it.get_output_details()[0]
    ps = np.zeros(len(Xe), np.float64)
    for k in range(len(Xe)):
        it.set_tensor(i0["index"], Xe[k:k + 1].astype(i0["dtype"]))
        it.invoke()
        ps[k] = float(it.get_tensor(o0["index"]).ravel()[0])
    auc_shipped = float(roc_auc_score(ye, ps))
    print("\n  shipped m_glass_breaking_v3 (NC): AUC %.4f" % auc_shipped,
          flush=True)

    # --- the permissive model
    n1, n0 = int(ytr.sum()), int((1 - ytr).sum())
    aucs, models = [], []
    for s in SEEDS:
        m = build_net(s)
        m.compile(optimizer=tf.keras.optimizers.Adam(1e-3),
                  loss="binary_crossentropy",
                  metrics=[tf.keras.metrics.AUC(name="auc")])
        m.fit(Xtr, ytr, epochs=30, batch_size=32, verbose=0,
              class_weight={0: len(ytr) / (2.0 * max(n0, 1)),
                            1: len(ytr) / (2.0 * max(n1, 1))})
        a = float(roc_auc_score(ye, m.predict(Xe, verbose=0).ravel()))
        aucs.append(a)
        models.append(m)
        print("  permissive seed %-5d AUC %.4f" % (s, a), flush=True)

    a = np.array(aucs)
    print("\n  permissive mean %.4f  min %.4f  max %.4f (%d seeds)"
          % (a.mean(), a.min(), a.max(), len(a)))
    print("  shipped (NC)    %.4f" % auc_shipped)
    print("  delta (mean)    %+.4f   delta (worst seed) %+.4f"
          % (a.mean() - auc_shipped, a.min() - auc_shipped))

    ship = bool(a.min() >= auc_shipped)
    print("  SHIP (worst seed matches or beats the NC model) -> %s" % ship)
    rep = {"shipped_nc_auc": round(auc_shipped, 4),
           "permissive_seeds": [round(x, 4) for x in aucs],
           "permissive_mean": round(float(a.mean()), 4),
           "permissive_min": round(float(a.min()), 4),
           "train_pos": int(ytr.sum()), "train_neg": int((1 - ytr).sum()),
           "shipped_train_pos": 92, "eval_n": int(len(ye)),
           "eval_pos": int(ye.sum()), "ships": ship,
           "licence": "CC0 + CC BY only (attribution required)"}
    if ship:
        pick = int(np.argsort(aucs)[len(aucs) // 2])
        conv = tf.lite.TFLiteConverter.from_keras_model(models[pick])
        conv.optimizations = [tf.lite.Optimize.DEFAULT]
        conv.target_spec.supported_types = [tf.float16]
        blob = conv.convert()
        open(os.path.join(HERE, "m_glass_permissive_v1.tflite"),
             "wb").write(blob)
        rep["exported_seed"] = SEEDS[pick]
        rep["exported_auc"] = round(aucs[pick], 4)
        rep["float16_kb"] = round(len(blob) / 1024, 1)
        print("  exported MEDIAN seed %d (%.4f), %s KB"
              % (SEEDS[pick], aucs[pick], rep["float16_kb"]))
    json.dump(rep, open(os.path.join(HERE, "glass_permissive_report.json"),
                        "w"), indent=2)
    print("report written")


if __name__ == "__main__":
    main()
