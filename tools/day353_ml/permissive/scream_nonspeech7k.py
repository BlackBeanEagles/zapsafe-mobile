"""Day 368 - does Nonspeech7k improve the scream model?

THE DATA
========
Nonspeech7k (Zenodo 6967442, CC BY 4.0; byte-equivalent Kaggle mirror
raajanwankhade/nonpeech7k). 7 human non-speech classes, every clip an
original (no augmented copies). Train: 593 screaming, plus breath, cough,
laugh, sneeze, yawn, crying. Test: 70 screaming, ~450 others.

Clips come from Freesound, aigei.com and YouTube. The audio's licence
standing is the same as AudioSet's, which this project already trains on.

LEAKAGE, CHECKED BEFORE TRAINING
================================
FSD50K is also built from Freesound, and both the scream eval fixture (FSD50K
eval) and v5's training set (FSD50K dev) are FSD50K. Measured overlap by
Freesound sound id:

    Nonspeech7k train  vs FSD50K eval   76 ids (10 of them screams)
    Nonspeech7k test   vs FSD50K dev   151 ids (v5 trained on these)

Rules applied:
  * train additions drop any id in FSD50K eval OR FSD50K dev
  * the Nonspeech7k test set drops any id in FSD50K dev OR Nonspeech7k train
    (one recording cut into segments must not sit on both sides)

LABELS, CONSISTENT WITH v5
==========================
screaming -> positive. breath, cough, laugh, sneeze, yawn -> negative.
crying -> EXCLUDED, exactly as v5's arm D excluded it (the fixture does not
score crying either way).

THE COMPARISON
==============
Same recipe for both arms (Day 361E's "real recipe": 30 epochs, batch 32,
class-weighted), three seeds each:

  A  control    v5's training rows only
  N  treatment  v5's rows + filtered Nonspeech7k train

Scored on three sets: FSD50K eval (the fixture every scream model is judged
on), AudioSet held-out (132 clips), and filtered Nonspeech7k test (a corpus
none of the training sets came from).

SHIP RULE, FIXED BEFORE RUNNING
===============================
N ships only if its worst seed >= the shipped v5 tflite on FSD50K eval, AND
N's mean is not below shipped on either other set. A control arm that
cannot reproduce shipped is reported, not hidden.
"""
from __future__ import annotations

import json
import os
import sys
import time
from concurrent.futures import ProcessPoolExecutor

import numpy as np
import pandas as pd

HERE = os.path.dirname(os.path.abspath(__file__))
SV5 = r"C:\Users\hridy\Desktop\zapsafe\work\scream_v5"
FSD_EVAL_MAN = r"C:\Users\hridy\Desktop\zapsafe\work\fsd50k_eval\manifest.json"
ASSETS = (r"C:\Users\hridy\Desktop\zapsafe\letsstartbuilding"
          r"\zapsafe_mobile_main_reconcile\assets\models")
SHIPPED = "scream_classifier_v5.tflite"
NS = os.environ.get("NS7K", r"D:\zapsafe\datasets\nonspeech7k\kaggle_mirror")
CACHE = os.path.join(HERE, "nonspeech7k_features.npz")
OUT = os.path.join(HERE, "scream_nonspeech7k.json")
PROGRESS = os.path.join(HERE, "scream_nonspeech7k_progress.jsonl")

SR, DURATION, N_MELS, N_FFT, HOP, FRAMES = 22050, 3, 128, 2048, 512, 131
NEED = SR * DURATION
SEEDS = (42, 7, 123)
EPOCHS, BATCH = 30, 32
POS = {"screaming"}
NEG = {"breath", "cough", "laugh", "sneeze", "yawn", "yawm"}   # 'yawm' is the test csv's typo


def mel_from(y, sr):
    """Verbatim copy of work/scream_v5/train_scream_v5.py::mel_from.

    Any drift here makes every comparison below meaningless.
    """
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
    return db[:, :FRAMES].astype(np.float16)


def _one(item):
    path, label = item
    import soundfile as sf
    try:
        y, sr = sf.read(path, dtype="float32")
    except Exception as e:      # noqa: BLE001
        return ("read", str(e)[:60])
    m = mel_from(y, sr)
    if m is None:
        return ("silent", path)
    return (m, label)


def featurise(items, tag):
    X, y, drops = [], [], {}
    t0 = time.time()
    with ProcessPoolExecutor(max_workers=4) as ex:
        for k, r in enumerate(ex.map(_one, items, chunksize=16)):
            if isinstance(r[0], str):
                drops[r[0]] = drops.get(r[0], 0) + 1
                continue
            X.append(r[0])
            y.append(r[1])
            if (k + 1) % 1000 == 0:
                print(f"    {tag} {k+1}/{len(items)} {time.time()-t0:.0f}s", flush=True)
    lost = 1 - len(X) / max(len(items), 1)
    print(f"  {tag}: {len(X)}/{len(items)} kept, dropped {drops}", flush=True)
    if lost > 0.05:
        raise SystemExit(f"ABORT: {tag} lost {lost:.1%} of clips")
    return np.stack(X), np.array(y, np.int32)


def fsd_ids(path):
    return {str(m.get("fname", "")).split(".")[0] for m in json.load(open(path))}


def find_wav(name):
    for sub in ("train/train", "train", "test/test", "test"):
        p = os.path.join(NS, sub, name)
        if os.path.exists(p):
            return p
    return None


def build():
    if os.path.exists(CACHE):
        d = np.load(CACHE)
        return d["Xn"], d["yn"], d["Xt"], d["yt"], json.loads(str(d["info"]))

    ev_ids = fsd_ids(FSD_EVAL_MAN)
    dev_ids = fsd_ids(os.path.join(SV5, "dev_manifest.json"))
    cols = ["fn", "fid", "ms", "cid", "cls", "aid", "aug", "src"]
    tr = pd.read_csv(os.path.join(NS, "metadata_train.csv"))
    te = pd.read_csv(os.path.join(NS, "metadata_test.csv"))
    tr.columns, te.columns = cols, cols
    for df in (tr, te):
        df["fid"] = df["fid"].astype(str)
        df["cls"] = df["cls"].str.strip().str.lower()

    info = {}

    def pick(df, banned, tag):
        keep = df[df["cls"].isin(POS | NEG)]
        before = len(keep)
        keep = keep[~keep["fid"].isin(banned)]
        info[tag + "_dropped_overlap"] = int(before - len(keep))
        items = []
        for _, r in keep.iterrows():
            p = find_wav(r["fn"])
            if p:
                items.append((p, 1 if r["cls"] in POS else 0))
        info[tag + "_missing_files"] = int(len(keep) - len(items))
        return items

    tr_items = pick(tr, ev_ids | dev_ids, "train")
    te_items = pick(te, dev_ids | set(tr["fid"]), "test")
    print(f"Nonspeech7k train items {len(tr_items)} (pos {sum(l for _, l in tr_items)}), "
          f"test items {len(te_items)} (pos {sum(l for _, l in te_items)})")
    print("filter info:", info)
    Xn, yn = featurise(tr_items, "ns7k-train")
    Xt, yt = featurise(te_items, "ns7k-test")
    np.savez_compressed(CACHE, Xn=Xn, yn=yn, Xt=Xt, yt=yt, info=json.dumps(info))
    return Xn, yn, Xt, yt, info


def net(seed):
    """Layer for layer the Day 361E recipe network (build_train_scream.py::net)."""
    import tensorflow as tf
    tf.keras.backend.clear_session()
    tf.random.set_seed(seed)
    np.random.seed(seed)
    inp = tf.keras.Input(shape=(N_MELS, FRAMES))
    x = tf.keras.layers.Reshape((N_MELS, FRAMES, 1))(inp)
    for f in (16, 32, 64):
        x = tf.keras.layers.Conv2D(f, 3, padding="same", activation="relu")(x)
        x = tf.keras.layers.MaxPooling2D(2)(x)
    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    x = tf.keras.layers.Dropout(0.3)(x)
    x = tf.keras.layers.Dense(64, activation="relu")(x)
    out = tf.keras.layers.Dense(1, activation="sigmoid", name="scream")(x)
    m = tf.keras.Model(inp, out, name="scream_ns7k")
    m.compile(optimizer=tf.keras.optimizers.Adam(1e-3),
              loss="binary_crossentropy",
              metrics=[tf.keras.metrics.AUC(name="auc")])
    return m


def tflite_scores(path, X):
    import tensorflow as tf
    it = tf.lite.Interpreter(model_path=path)
    it.allocate_tensors()
    i0, o0 = it.get_input_details()[0], it.get_output_details()[0]
    shape = [int(v) for v in i0["shape"]]
    p = np.zeros(len(X))
    for k in range(len(X)):
        it.set_tensor(i0["index"], X[k:k + 1].astype(np.float32).reshape(shape))
        it.invoke()
        p[k] = float(it.get_tensor(o0["index"]).ravel()[0])
    return p


def main():
    from sklearn.metrics import roc_auc_score
    import tensorflow as tf

    d = np.load(os.path.join(SV5, "features_v5.npz"), allow_pickle=True)
    X, y = d["X"], d["y"].astype(int)
    sets = {"fsd50k_eval": (d["Xf"], d["yf"].astype(int)),
            "audioset_heldout": (d["Xa"], d["ya"].astype(int))}
    Xn, yn, Xt, yt, info = build()
    sets["nonspeech7k_test"] = (Xt, yt)

    shipped = {k: float(roc_auc_score(yy, tflite_scores(os.path.join(ASSETS, SHIPPED), XX)))
               for k, (XX, yy) in sets.items()}
    print("\nshipped v5 :", {k: round(v, 4) for k, v in shipped.items()}, flush=True)

    arms = {"A_control": (X, y),
            "N_plus_nonspeech7k": (np.concatenate([X, Xn]), np.concatenate([y, yn]))}
    res = {"shipped": shipped, "filter": info, "arms": {}}

    # Checkpointed and interleaved. The first attempt ran arm A's three seeds
    # and then arm N's, writing nothing until the end, and was killed after
    # ~2 h with no result at all. Now each (seed, arm) fit appends a line to
    # PROGRESS and saves its weights, a restart skips anything already done,
    # and the order is A,N per seed so a partial run is still a paired result.
    done = {}
    if os.path.exists(PROGRESS):
        for line in open(PROGRESS, encoding="utf-8"):
            r = json.loads(line)
            done[(r["arm"], r["seed"])] = r["auc"]
    for s in SEEDS:
        for name, (Xa_, ya_) in arms.items():
            if (name, s) in done:
                print(f"  {name} seed {s}: already done {done[(name, s)]}", flush=True)
                continue
            n1, n0 = int(ya_.sum()), int((1 - ya_).sum())
            t0 = time.time()
            print(f"\n=== {name} seed {s}: n={len(ya_)} pos={n1} neg={n0}", flush=True)
            m = net(s)
            m.fit(Xa_.astype(np.float32), ya_, epochs=EPOCHS, batch_size=BATCH,
                  verbose=2, class_weight={0: len(ya_) / (2.0 * n0),
                                           1: len(ya_) / (2.0 * n1)})
            auc = {k: round(float(roc_auc_score(
                       yy, m.predict(XX.astype(np.float32), verbose=0).ravel())), 4)
                   for k, (XX, yy) in sets.items()}
            m.save_weights(os.path.join(HERE, f"ns7k_{name}_seed{s}.weights.h5"))
            with open(PROGRESS, "a", encoding="utf-8") as fh:
                fh.write(json.dumps({"arm": name, "seed": s, "auc": auc,
                                     "minutes": round((time.time() - t0) / 60, 1)}) + "\n")
            done[(name, s)] = auc
            print(f"  {name} seed {s}: {auc}  ({(time.time()-t0)/60:.1f} min)", flush=True)

    best_model = None
    for name in arms:
        per = {k: [done[(name, s)][k] for s in SEEDS] for k in sets}
        res["arms"][name] = {k: {"seeds": vs, "mean": round(float(np.mean(vs)), 4),
                                 "min": round(float(np.min(vs)), 4)}
                             for k, vs in per.items()}
        if name.startswith("N"):
            models = []
            for s in SEEDS:
                m = net(s)
                m.load_weights(os.path.join(HERE, f"ns7k_{name}_seed{s}.weights.h5"))
                models.append(m)
            best_model = (models, per)

    N = res["arms"]["N_plus_nonspeech7k"]
    ships = (N["fsd50k_eval"]["min"] >= shipped["fsd50k_eval"]
             and N["audioset_heldout"]["mean"] >= shipped["audioset_heldout"]
             and N["nonspeech7k_test"]["mean"] >= shipped["nonspeech7k_test"])
    res["ship_rule"] = ("worst seed >= shipped on FSD50K eval AND mean >= shipped "
                        "on AudioSet held-out and Nonspeech7k test")
    res["ships"] = bool(ships)
    print("\nSHIP ->", ships)

    if ships:
        models, per = best_model
        a = np.array(per["fsd50k_eval"])
        pick = int(np.argsort(a)[len(a) // 2])          # median seed, not best
        conv = tf.lite.TFLiteConverter.from_keras_model(models[pick])
        conv.optimizations = [tf.lite.Optimize.DEFAULT]
        conv.target_spec.supported_types = [tf.float16]
        blob = conv.convert()
        path = os.path.join(HERE, "scream_classifier_v6_candidate.tflite")
        open(path, "wb").write(blob)
        res["exported"] = {"seed": SEEDS[pick], "kb": round(len(blob) / 1024, 1),
                           "path": path}
        # Re-score through the real tflite path: the number that would ship.
        res["exported"]["tflite_auc"] = {
            k: round(float(roc_auc_score(yy, tflite_scores(path, XX))), 4)
            for k, (XX, yy) in sets.items()}
        print("exported", res["exported"])

    json.dump(res, open(OUT, "w"), indent=2)
    print("report ->", OUT)


if __name__ == "__main__":
    sys.exit(main())
