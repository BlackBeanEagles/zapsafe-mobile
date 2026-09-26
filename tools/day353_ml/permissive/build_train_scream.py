"""Day 359 - permissive scream: the hardest of the three to beat.

`scream_classifier_v5` reads **0.828** on the gate, the strongest of the
three NC audio-event models, and it trains on five corpora
(VocalAffectBench MIT, FSD50K, AudioSet, ASVP-ESD, ESC-50). The NC comes
from ESC-50 (CC BY-NC 3.0) and FSD50K's BY-NC slice.

The permissive FSD50K subset has **218 Screaming positives**. That is an
order of magnitude less data than the shipped model saw, against a much
stronger baseline than glass's 0.684, so losing here is the expected
outcome. It is run anyway because "expected" is not "measured", and the
result decides whether the NC dependency is removable at all.

PREPROCESSING is copied from tools/day345_fsd50k/evaluate_scream.py, which
is how the shipped model is scored -- note it differs from the glass and
gunshot path in every respect:

    22.05 kHz (not 16 kHz), 3 s, 128 mels, n_fft 2048, hop 512
    power_to_db(ref=max) -> per-clip min-max -> PAD/TRUNCATE to 131 frames
    single channel [128, 131, 1] -- NOT np.resize, NOT 3-channel

Using the glass/gunshot preprocessing here would produce a confident wrong
number rather than an error, which is this project's recurring failure mode.

TRAIN: FSD50K dev, CC0/CC-BY only.
EVAL:  the gate's FSD50K eval fixture, disjoint, identical rows for both.

SHIP RULE: the permissive model must match or beat 0.828 on the shared
fixture. Anything less is a licence-for-accuracy trade on the project's
flagship detector and gets reported, not shipped.
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

SR, DURATION, N_MELS, N_FFT, HOP, FRAMES = 22050, 3, 128, 2048, 512, 131
NEED = SR * DURATION
WORKERS = 6
SEEDS = (42, 7, 123)
POS_LABEL = "Screaming"
SHIPPED = "scream_classifier_v5.tflite"


def mel_from(y, librosa):
    """Verbatim from tools/day345_fsd50k/evaluate_scream.py::mel_from."""
    if y.ndim > 1:
        y = y.mean(axis=1)
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


def _one(item):
    import librosa
    path, lab = item
    try:
        y, _ = librosa.load(path, sr=SR, mono=True)
        m = mel_from(y, librosa)
        return (m[..., None], lab) if m is not None else None
    except Exception:
        return None


def read_list(p):
    with io.open(p, encoding="utf-8") as fh:
        return [x.strip() for x in fh if x.strip()]


def build_train():
    cache = os.path.join(HERE, "scream_dev_mel.npz")
    if os.path.exists(cache):
        d = np.load(cache, allow_pickle=True)
        return d["X"].astype(np.float32), np.asarray(d["y"]).astype(int)
    pos = read_list(os.path.join(HERE, "scream_dev_pos.txt"))
    neg = read_list(os.path.join(HERE, "scream_dev_neg.txt"))
    rng = np.random.RandomState(42)
    neg = list(rng.permutation(neg)[:min(len(neg), 4 * len(pos))])
    items = ([(os.path.join(DEV_AUDIO, "%s.wav" % f), 1) for f in pos] +
             [(os.path.join(DEV_AUDIO, "%s.wav" % f), 0) for f in neg])
    items = [(p, l) for p, l in items
             if os.path.exists(p) and os.path.getsize(p) > 0]
    print("train clips: %d (%d pos)"
          % (len(items), sum(l for _, l in items)), flush=True)
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
            if (k + 1) % 300 == 0:
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
        mm = mel_from(w, librosa)
        if mm is None:
            continue
        X.append(mm[..., None])
        y.append(1 if POS_LABEL in m.get("labels", []) else 0)
    return np.stack(X), np.asarray(y, np.int64)


def net(seed):
    import tensorflow as tf
    tf.keras.backend.clear_session()
    tf.random.set_seed(seed)
    np.random.seed(seed)
    inp = tf.keras.Input(shape=(N_MELS, FRAMES, 1))
    x = inp
    for f in (16, 32, 64):
        x = tf.keras.layers.Conv2D(f, 3, padding="same", activation="relu")(x)
        x = tf.keras.layers.MaxPooling2D(2)(x)
    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    x = tf.keras.layers.Dropout(0.3)(x)
    x = tf.keras.layers.Dense(64, activation="relu")(x)
    out = tf.keras.layers.Dense(1, activation="sigmoid", name="scream")(x)
    return tf.keras.Model(inp, out, name="scream_permissive_v1")


def main():
    import tensorflow as tf
    from sklearn.metrics import roc_auc_score

    Xtr, ytr = build_train()
    print("loading eval fixture ...", flush=True)
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
    aucs = []
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
        print("  permissive seed %-5d AUC %.4f" % (s, a), flush=True)

    a = np.array(aucs)
    print("\n  permissive mean %.4f  min %.4f  max %.4f"
          % (a.mean(), a.min(), a.max()))
    print("  shipped (NC)    %.4f" % auc_ship)
    print("  delta mean %+.4f   worst seed %+.4f"
          % (a.mean() - auc_ship, a.min() - auc_ship))
    ship = bool(a.min() >= auc_ship)
    print("  SHIP -> %s" % ship)
    if not ship:
        print("  -> LICENCE-FOR-ACCURACY TRADE on the flagship detector; "
              "reporting, not shipping. 218 permissive positives cannot "
              "replace five corpora.")
    json.dump({"shipped_nc_auc": round(auc_ship, 4),
               "permissive_seeds": [round(x, 4) for x in aucs],
               "permissive_mean": round(float(a.mean()), 4),
               "permissive_min": round(float(a.min()), 4),
               "train_pos": int(ytr.sum()), "train_neg": int((1 - ytr).sum()),
               "eval_n": int(len(ye)), "eval_pos": int(ye.sum()),
               "ships": ship},
              open(os.path.join(HERE, "scream_permissive_report.json"), "w"),
              indent=2)
    print("report written")


if __name__ == "__main__":
    main()
