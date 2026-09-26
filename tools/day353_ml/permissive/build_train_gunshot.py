"""Day 359 - permissive gunshot: can CC0/CC-BY FSD50K match the NC model?

THE STARTING POINT IS DIFFERENT FROM GLASS
==========================================
Glass was a landslide because its shipped model trained on 92 positives and
scored 0.684. `mg_gunshot_retrain` reads **0.807** on the gate and is a far
stronger baseline, so this is expected to be close. It is run as a genuine
A/B, not as a formality, and if the permissive model loses it is reported as
a licence-for-accuracy trade rather than shipped.

PREPROCESSING is copied from the gate's own `real_mel_images_fsd50k(128)`,
which is what the shipped model is scored with:

    16 kHz, 3.0 s, 128 mels, n_fft 2048, hop 512, fmax 8000
    power_to_db(ref=max) -> per-clip min-max -> np.resize(128,128) -> 3ch

np.resize TILES rather than interpolating. That is the behaviour the shipped
model and the Dart path were built around, so it is reproduced deliberately.

TRAIN: FSD50K **dev**, CC0/CC-BY only -- 320 positives, 2,663 negatives.
EVAL:  the gate's FSD50K **eval** fixture. Disjoint split, identical rows for
both models, each through its real inference path.

The permissive positives only exist because Day 359 repaired the extraction:
69.9% of the local FSD50K was zero-byte files, and the clips were recovered
by scanning local zip headers past an unusable central directory.
"""
from __future__ import annotations

import io
import json
import os
import time
from concurrent.futures import ProcessPoolExecutor

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
F = r"C:\Users\hridy\Desktop\zapsafe\ml_datasets\audio_events\DS08_FSD50K"
DEV_AUDIO = os.path.join(F, "FSD50K.dev_audio")
EVALDIR = r"C:\Users\hridy\Desktop\zapsafe\work\fsd50k_eval"
ASSETS = (r"C:\Users\hridy\Desktop\zapsafe\letsstartbuilding"
          r"\zapsafe_mobile_main_reconcile\assets\models")

SR, DUR, SIZE, N_FFT, HOP, FMAX = 16000, 3.0, 128, 2048, 512, 8000
NEED = int(SR * DUR)
WORKERS = 6
SEEDS = (42, 7, 123)
POS_LABEL = "Gunshot_and_gunfire"
SHIPPED = "mg_gunshot_retrain.tflite"


def mel_img(y, librosa):
    y = np.pad(y, (0, NEED - len(y))) if len(y) < NEED else y[:NEED]
    mel = librosa.feature.melspectrogram(y=y, sr=SR, n_mels=SIZE,
                                         hop_length=HOP, n_fft=N_FFT,
                                         fmax=FMAX)
    db = librosa.power_to_db(mel, ref=np.max)
    rng = db.max() - db.min()
    nz = (db - db.min()) / (rng if rng > 1e-8 else 1.0)
    img = np.resize(nz, (SIZE, SIZE))
    return np.stack([img] * 3, axis=-1).astype(np.float32)


def _one(item):
    import librosa
    path, lab = item
    try:
        y, _ = librosa.load(path, sr=SR, mono=True)
        if len(y) < SR * 0.2:
            return None
        return mel_img(y, librosa), lab
    except Exception:
        return None


def read_list(p):
    with io.open(p, encoding="utf-8") as fh:
        return [x.strip() for x in fh if x.strip()]


def build_train():
    cache = os.path.join(HERE, "gunshot_dev_mel.npz")
    if os.path.exists(cache):
        d = np.load(cache, allow_pickle=True)
        return d["X"].astype(np.float32), np.asarray(d["y"]).astype(int)
    pos = read_list(os.path.join(HERE, "gunshot_dev_pos.txt"))
    neg = read_list(os.path.join(HERE, "gunshot_dev_neg.txt"))
    rng = np.random.RandomState(42)
    neg = list(rng.permutation(neg)[:min(len(neg), 3 * len(pos))])
    items = ([(os.path.join(DEV_AUDIO, "%s.wav" % f), 1) for f in pos] +
             [(os.path.join(DEV_AUDIO, "%s.wav" % f), 0) for f in neg])
    items = [(p, l) for p, l in items
             if os.path.exists(p) and os.path.getsize(p) > 0]
    print("train clips: %d (%d pos)" % (len(items),
                                        sum(l for _, l in items)), flush=True)
    X, y = [], []
    bad = 0
    t0 = time.time()
    with ProcessPoolExecutor(max_workers=WORKERS) as ex:
        for k, r in enumerate(ex.map(_one, items, chunksize=8)):
            if r is None:
                bad += 1
                continue
            X.append(r[0])
            y.append(r[1])
            if (k + 1) % 500 == 0:
                print("  %d/%d %ds" % (k + 1, len(items),
                                       int(time.time() - t0)), flush=True)
    X = np.stack(X)
    y = np.asarray(y, np.int64)
    print("built %s pos=%d dropped=%d" % (X.shape, y.sum(), bad), flush=True)
    np.savez_compressed(cache, X=X.astype(np.float16), y=y)
    return X, y


def load_eval():
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


def net(seed):
    import tensorflow as tf
    tf.keras.backend.clear_session()
    tf.random.set_seed(seed)
    np.random.seed(seed)
    inp = tf.keras.Input(shape=(SIZE, SIZE, 3))
    x = inp
    for f in (16, 32, 64):
        x = tf.keras.layers.Conv2D(f, 3, padding="same", activation="relu")(x)
        x = tf.keras.layers.MaxPooling2D(2)(x)
    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    x = tf.keras.layers.Dropout(0.3)(x)
    x = tf.keras.layers.Dense(64, activation="relu")(x)
    out = tf.keras.layers.Dense(1, activation="sigmoid", name="gunshot")(x)
    return tf.keras.Model(inp, out, name="mg_gunshot_permissive_v1")


def main():
    import tensorflow as tf
    from sklearn.metrics import roc_auc_score, precision_recall_fscore_support

    Xtr, ytr = build_train()
    print("loading the gate's eval fixture ...", flush=True)
    Xe, ye = load_eval()
    print("eval %s pos=%d (base rate %.3f)"
          % (Xe.shape, ye.sum(), ye.mean()), flush=True)

    it = tf.lite.Interpreter(model_path=os.path.join(ASSETS, SHIPPED))
    it.allocate_tensors()
    i0, o0 = it.get_input_details()[0], it.get_output_details()[0]
    ps = np.zeros(len(Xe))
    for k in range(len(Xe)):
        it.set_tensor(i0["index"], Xe[k:k + 1].astype(i0["dtype"]))
        it.invoke()
        ps[k] = float(it.get_tensor(o0["index"]).ravel()[0])
    auc_ship = float(roc_auc_score(ye, ps))
    print("\n  shipped %s (NC): AUC %.4f" % (SHIPPED, auc_ship), flush=True)

    n1, n0 = int(ytr.sum()), int((1 - ytr).sum())
    aucs, models = [], []
    for s in SEEDS:
        m = net(s)
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
    print("\n  permissive mean %.4f  min %.4f  max %.4f" % (a.mean(),
                                                            a.min(), a.max()))
    print("  shipped (NC)    %.4f" % auc_ship)
    print("  delta mean %+.4f   worst seed %+.4f"
          % (a.mean() - auc_ship, a.min() - auc_ship))
    ship = bool(a.min() >= auc_ship)
    print("  SHIP (worst seed matches or beats NC) -> %s" % ship)
    if not ship:
        print("  -> this is a LICENCE-FOR-ACCURACY TRADE, not a fix; "
              "reporting rather than shipping")

    rep = {"shipped_nc_auc": round(auc_ship, 4),
           "permissive_seeds": [round(x, 4) for x in aucs],
           "permissive_mean": round(float(a.mean()), 4),
           "permissive_min": round(float(a.min()), 4),
           "train_pos": int(ytr.sum()), "train_neg": int((1 - ytr).sum()),
           "eval_n": int(len(ye)), "eval_pos": int(ye.sum()), "ships": ship}
    if ship:
        pick = int(np.argsort(aucs)[len(aucs) // 2])
        conv = tf.lite.TFLiteConverter.from_keras_model(models[pick])
        conv.optimizations = [tf.lite.Optimize.DEFAULT]
        conv.target_spec.supported_types = [tf.float16]
        blob = conv.convert()
        open(os.path.join(HERE, "mg_gunshot_permissive_v1.tflite"),
             "wb").write(blob)
        pn = models[pick].predict(Xe, verbose=0).ravel()
        curve = []
        for t in (0.2, 0.3, 0.4, 0.5, 0.6, 0.7):
            pr, rc, _, _ = precision_recall_fscore_support(
                ye, (pn >= t).astype(int), average="binary", zero_division=0)
            curve.append({"t": t, "recall": round(float(rc), 3),
                          "precision": round(float(pr), 3)})
        for t in (0.5,):
            pr, rc, _, _ = precision_recall_fscore_support(
                ye, (ps >= t).astype(int), average="binary", zero_division=0)
            rep["shipped_at_0.5"] = {"recall": round(float(rc), 3),
                                     "precision": round(float(pr), 3)}
        rep["curve"] = curve
        rep["float16_kb"] = round(len(blob) / 1024, 1)
        rep["exported_seed"] = SEEDS[pick]
        print("  exported MEDIAN seed %d (%.4f), %s KB"
              % (SEEDS[pick], aucs[pick], rep["float16_kb"]))
        print("  curve:", curve)
    json.dump(rep, open(os.path.join(HERE, "gunshot_permissive_report.json"),
                        "w"), indent=2)
    print("report written")


if __name__ == "__main__":
    main()
