"""M1 scream v3 — VocalAffectBench screams + same-domain hard negatives.

v2 (Day 322) reached real AUC 0.759 but had no usable operating point: 91%
recall cost 35% precision. Diagnosis was data, not architecture -- only 101
real screams existed, and the negatives were speech/ambient, so nothing
taught the model to reject the sounds actually confusable with a scream.

VocalAffectBench (E:/datasets/vocal) fixes both halves:

  Scream            714 clips   <- 7x the AudioSet scream count
  Crying           2020         distress, same family
  Pant / Moan        89         distress-adjacent

and, far more importantly, ~23,000 NON-SPEECH hard negatives from the same
recording domain:

  Laughter 4797 · Cough 4248 · Sneeze 3813 · Throat Clearing 3549
  Sigh 3546 · Sniff 3504 · Yawn 311

A cough and a scream are both sharp non-speech vocalisations. v2 never saw
that distinction, which is why its precision collapsed as soon as recall
rose. These are the negatives that teach it.

Held-out eval is unchanged from v2 -- the same real AudioSet screams -- so
the number is directly comparable to v1 0.616 and v2 0.759.

.tar.gz is streamed sequentially (random access would re-decompress from the
start each time); one worker per archive parallelises across them. Nothing is
extracted to disk: every drive here is under 4 GB free.
"""
from __future__ import annotations

import csv
import io
import json
import os
import random
import tarfile
import time
from concurrent.futures import ProcessPoolExecutor

import numpy as np

EPOCHS = 45   # v4b: val_auc was already 0.9363 at epoch 13 of the killed run
SEED = 42
random.seed(SEED)
np.random.seed(SEED)

ROOT = r"C:\Users\hridy\Desktop\zapsafe"
VAB = r"E:\datasets\vocal\data"
ASVP_ZIP = r"D:\zapsafe\ASVP_ESD.zip"
AS_DIR = os.path.join(ROOT, r"ml_datasets\audio_events\DS07_AudioSet")
ESC = os.path.join(ROOT, r"ml_datasets\audio_events\DS21_ESC-50")
OUT = os.path.join(ROOT, "work", "scream_v4")
CKPT = os.path.join(OUT, "ckpt.weights.h5")

SR, DURATION, N_MELS, N_FFT, HOP, FRAMES = 22050, 3, 128, 2048, 512, 131
NEED = SR * DURATION

# (archive, label, cap).  Caps keep the negative pool from swamping training.
# v4: negative caps roughly doubled. v3 capped these to stop the negative
# pool swamping training, but with class_weight already correcting the
# imbalance the cap was throwing away the most useful data in the set --
# these are SAME-DOMAIN hard negatives (human non-scream vocalisations), not
# filler. A scream detector's real failure mode is firing on a laugh or a
# cough, so more of them is exactly what the decision boundary needs.
VAB_SPEC = [("Scream", 1, 714), ("Crying", 1, 700), ("Pant", 1, 44), ("Moan", 1, 45),
            ("Laughter", 0, 1800), ("Cough", 0, 1800), ("Sneeze", 0, 1400),
            ("Throat Clearing", 0, 1200), ("Sigh", 0, 1200), ("Sniff", 0, 1200),
            ("Yawn", 0, 311)]

AS_SCREAM = {"/m/03qc9zr", "/m/07sr1lc", "/t/dd00135", "/m/04gy_2"}
AS_NEG = {"/m/09x0r", "/m/01j3sz", "/m/053hz1", "/m/028ght"}
ASVP_POS = {"06", "11"}          # fearful, pain (non-speech only)
ASVP_NEG = {"02", "03", "10"}    # neutral, happy, pleasure
ESC_NEG = {"car_horn", "engine", "siren", "rain", "wind", "clapping",
           "keyboard_typing", "vacuum_cleaner", "footsteps"}


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
    return db[:, :FRAMES].astype(np.float16)


def do_tar(spec):
    """Stream one .tar.gz start-to-finish; random access would re-decompress."""
    import soundfile as sf
    name, label, cap = spec
    path = os.path.join(VAB, name + ".tar.gz")
    rows = []
    if not os.path.exists(path):
        return name, rows
    try:
        with tarfile.open(path, "r|gz") as t:          # streaming mode
            for m in t:
                if len(rows) >= cap:
                    break
                if not m.isfile() or not m.name.lower().endswith((".wav", ".flac", ".mp3", ".ogg")):
                    continue
                f = t.extractfile(m)
                if f is None:
                    continue
                try:
                    y, sr = sf.read(io.BytesIO(f.read()), dtype="float32")
                    mel = mel_from(y, sr)
                    if mel is not None:
                        rows.append((mel, label))
                except Exception:
                    continue
    except Exception:
        pass
    return name, rows


_zipf = None


def do_file(item):
    """(source, path, label) -> (mel, label) or None. Runs in a pool worker."""
    global _zipf
    import zipfile
    import soundfile as sf
    src, path, label = item
    try:
        if src == "zip":
            if _zipf is None:
                _zipf = zipfile.ZipFile(ASVP_ZIP)
            y, sr = sf.read(io.BytesIO(_zipf.read(path)), dtype="float32")
        else:
            y, sr = sf.read(path, dtype="float32")
        mel = mel_from(y, sr)
        return None if mel is None else (mel, label)
    except Exception:
        return None


def collect_asvp():
    import zipfile
    z = zipfile.ZipFile(ASVP_ZIP)
    pos, neg = [], []
    for n in z.namelist():
        if not n.lower().endswith(".wav"):
            continue
        p = os.path.basename(n).split(".")[0].split("-")
        if len(p) < 3 or p[1] != "02":
            continue
        if p[2] in ASVP_POS:
            pos.append(n)
        elif p[2] in ASVP_NEG:
            neg.append(n)
    return pos, neg


def collect_audioset():
    wd = os.path.join(AS_DIR, "train_wav")
    if not os.path.isdir(wd):
        return [], []
    present = {os.path.splitext(f)[0]: os.path.join(wd, f) for f in os.listdir(wd)}
    scream, neg, seen = [], [], set()
    for name in ("train.csv", "balanced_train_segments.csv",
                 "unbalanced_train_segments.csv"):
        p = os.path.join(AS_DIR, name)
        if not os.path.exists(p):
            continue
        for line in open(p, encoding="utf-8", errors="replace"):
            if line.startswith("#"):
                continue
            parts = line.split(",")
            yt = parts[0].strip().strip('"')
            if yt in seen or yt not in present:
                continue
            lab = {x.strip().strip('"') for x in ",".join(parts[3:]).split(",")}
            if lab & AS_SCREAM:
                scream.append(present[yt]); seen.add(yt)
            elif lab & AS_NEG:
                neg.append(present[yt]); seen.add(yt)
    return scream, neg


def collect_esc():
    cp = os.path.join(ESC, "esc50.csv")
    if not os.path.exists(cp):
        return []
    idx = {}
    for dp, _, fs in os.walk(ESC):
        for f in fs:
            if f.lower().endswith(".wav"):
                idx[f] = os.path.join(dp, f)
    return [idx[r["filename"]] for r in csv.DictReader(open(cp, newline="", encoding="utf-8"))
            if r["category"] in ESC_NEG and r["filename"] in idx]



def spec_augment(batch, rng):
    """SpecAugment (Park et al. 2019) + gain jitter, applied per batch.

    v3 trained with NO augmentation at all, which is the single largest
    omission for a mel-based audio classifier this small. Real screams vary
    in distance, room and recording gain far more than the training set does,
    and masking teaches the model not to depend on any one frequency band or
    instant -- both of which a phone mic will degrade unpredictably.

    Masks are applied to a COPY, and only to the training split; the held-out
    real-AudioSet evaluation never sees augmented data.
    """
    out = batch.copy()
    n, mels, frames, _ = out.shape
    for i in range(n):
        # gain jitter in the normalised [0,1] mel domain
        out[i] = np.clip(out[i] * rng.uniform(0.85, 1.15), 0.0, 1.0)
        # two frequency masks
        for _ in range(2):
            f = rng.randint(0, 16)
            f0 = rng.randint(0, max(1, mels - f))
            out[i, f0:f0 + f, :, 0] = 0.0
        # two time masks
        for _ in range(2):
            t = rng.randint(0, 20)
            t0 = rng.randint(0, max(1, frames - t))
            out[i, :, t0:t0 + t, 0] = 0.0
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    cache = os.path.join(OUT, "features.npz")

    if os.path.exists(cache):
        d = np.load(cache)
        X, y, Xe, ye = d["X"], d["y"], d["Xe"], d["ye"]
    else:
        print("=== streaming VocalAffectBench archives (parallel, 1 worker per tar) ===")
        t0 = time.time()
        vab_rows = []
        with ProcessPoolExecutor(max_workers=4) as ex:
            for name, rows in ex.map(do_tar, VAB_SPEC):
                lab = dict((s[0], s[1]) for s in VAB_SPEC)[name]
                print(f"  {name:18s} {len(rows):5d} clips (label {lab})", flush=True)
                vab_rows.extend(rows)
        print(f"  VocalAffectBench total {len(vab_rows)} in {time.time()-t0:.0f}s")

        a_pos, a_neg = collect_asvp()
        s_scream, s_neg = collect_audioset()
        e_neg = collect_esc()
        random.shuffle(s_scream); random.shuffle(s_neg)

        # Identical held-out protocol to v2 so numbers stay comparable.
        n_ev = max(25, len(s_scream) // 3)
        ev_pos, tr_scream = s_scream[:n_ev], s_scream[n_ev:]
        ev_neg, tr_neg = s_neg[:n_ev * 3], s_neg[n_ev * 3:]
        print(f"held-out REAL eval: {len(ev_pos)} AudioSet screams vs {len(ev_neg)} negs")

        items = ([("zip", p, 1) for p in a_pos] +
                 [("fs", p, 1) for p in tr_scream] +
                 [("zip", p, 0) for p in a_neg[:1200]] +
                 [("fs", p, 0) for p in tr_neg[:1200]] +
                 [("fs", p, 0) for p in e_neg])
        ev_items = [("fs", p, 1) for p in ev_pos] + [("fs", p, 0) for p in ev_neg]

        print(f"=== featurising {len(items)} other + {len(ev_items)} eval ===")
        other, B = [], 300
        for s in range(0, len(items), B):
            chunk = items[s:s + B]
            try:
                with ProcessPoolExecutor(max_workers=4) as ex:
                    for r in ex.map(do_file, chunk, chunksize=4):
                        if r is not None:
                            other.append(r)
            except Exception:
                for it in chunk:
                    r = do_file(it)
                    if r is not None:
                        other.append(r)
            print(f"    {len(other)} ({s+len(chunk)}/{len(items)})", flush=True)

        ev = []
        for it in ev_items:
            r = do_file(it)
            if r is not None:
                ev.append(r)

        rows = vab_rows + other
        random.shuffle(rows)
        X = np.stack([r[0] for r in rows]); y = np.array([r[1] for r in rows], dtype=np.int32)
        Xe = np.stack([r[0] for r in ev]); ye = np.array([r[1] for r in ev], dtype=np.int32)
        np.savez_compressed(cache, X=X, y=y, Xe=Xe, ye=ye)

    print(f"\ntrain {len(y)} (pos={int(y.sum())} neg={int((1-y).sum())})")
    print(f"held-out real {len(ye)} (pos={int(ye.sum())} neg={int((1-ye).sum())})")

    import tensorflow as tf
    from sklearn.metrics import roc_auc_score, precision_recall_curve
    from sklearn.model_selection import train_test_split
    tf.random.set_seed(SEED)

    Xf = X.astype(np.float32)[..., None]
    Xef = Xe.astype(np.float32)[..., None]
    Xtr, Xva, ytr, yva = train_test_split(Xf, y, test_size=0.2,
                                          random_state=SEED, stratify=y)
    npos, nneg = int(ytr.sum()), int((1 - ytr).sum())
    cw = {0: len(ytr) / (2.0 * max(nneg, 1)), 1: len(ytr) / (2.0 * max(npos, 1))}

    inp = tf.keras.Input(shape=(N_MELS, FRAMES, 1), name="mel")
    x = inp
    for f in (32, 64, 128):
        x = tf.keras.layers.Conv2D(f, 3, padding="same", activation="relu")(x)
        x = tf.keras.layers.BatchNormalization()(x)
        x = tf.keras.layers.MaxPooling2D(2)(x)
    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    x = tf.keras.layers.Dropout(0.4)(x)
    x = tf.keras.layers.Dense(64, activation="relu")(x)
    x = tf.keras.layers.Dropout(0.3)(x)
    out = tf.keras.layers.Dense(1, activation="sigmoid", name="scream")(x)
    model = tf.keras.Model(inp, out, name="m1_scream_v4")
    model.compile(optimizer=tf.keras.optimizers.Adam(1e-4),
                  loss="binary_crossentropy",
                  metrics=["accuracy", tf.keras.metrics.AUC(name="auc")])

    class AugmentedSequence(tf.keras.utils.Sequence):
        """Feeds freshly-augmented batches each epoch."""

        def __init__(self, X, y, batch_size=32, seed=0):
            self.X, self.y, self.bs = X, y, batch_size
            self.rng = np.random.RandomState(seed)
            self.idx = np.arange(len(X))

        def __len__(self):
            return int(np.ceil(len(self.X) / self.bs))

        def __getitem__(self, i):
            sl = self.idx[i * self.bs:(i + 1) * self.bs]
            return spec_augment(self.X[sl], self.rng), self.y[sl]

        def on_epoch_end(self):
            self.rng.shuffle(self.idx)

    # v4: augmented generator instead of raw arrays. Validation stays
    # un-augmented so val_auc measures the real thing.
    train_seq = AugmentedSequence(Xtr, ytr, batch_size=32, seed=SEED)

    # v4b: resume from the best checkpoint if one survives from a killed run.
    initial_epoch = 0
    if os.path.exists(CKPT):
        try:
            model.load_weights(CKPT)
            initial_epoch = int(open(CKPT + ".epoch").read().strip())
            print(f"  resumed from {CKPT} at epoch {initial_epoch}", flush=True)
        except Exception as exc:
            print(f"  checkpoint present but unusable ({exc}); starting fresh",
                  flush=True)

    class _EpochStamp(tf.keras.callbacks.Callback):
        """Records which epoch the checkpoint belongs to, so a resume does
        not silently restart the schedule from 0."""

        def on_epoch_end(self, epoch, logs=None):
            open(CKPT + ".epoch", "w").write(str(epoch + 1))

    model.fit(train_seq, validation_data=(Xva, yva), epochs=EPOCHS,
              initial_epoch=initial_epoch,
              class_weight=cw,
              callbacks=[tf.keras.callbacks.ModelCheckpoint(
                             CKPT, monitor="val_auc", mode="max",
                             save_best_only=True, save_weights_only=True),
                         _EpochStamp(),
                         tf.keras.callbacks.EarlyStopping(monitor="val_auc", mode="max",
                                                          patience=15, restore_best_weights=True),
                         tf.keras.callbacks.ReduceLROnPlateau(monitor="val_auc", mode="max",
                                                              factor=0.5, patience=7)],
              verbose=2)

    vp = model.predict(Xva, verbose=0).ravel()
    pr, rc, th = precision_recall_curve(yva, vp)
    f1 = 2 * pr * rc / (pr + rc + 1e-9)
    t = float(th[int(np.argmax(f1[:-1]))]) if len(th) else 0.5

    pe = model.predict(Xef, verbose=0).ravel()
    real_auc = float(roc_auc_score(ye, pe))

    print("\n" + "=" * 66)
    print(f"  REAL held-out AUC  {real_auc:.4f}   (v1 0.616 -> v2 0.759 -> v3 0.8234 -> v4 ?)")
    print(f"{'thresh':>8}{'recall':>9}{'precis':>9}{'alerts':>8}")
    curve = []
    for tt in (0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2, 0.1):
        tp = int(((pe >= tt) & (ye == 1)).sum()); fp = int(((pe >= tt) & (ye == 0)).sum())
        r = tp / max(1, int(ye.sum())); p = tp / max(1, tp + fp)
        curve.append({"t": tt, "recall": round(r, 3), "precision": round(p, 3)})
        print(f"{tt:8.2f}{r:9.3f}{p:9.3f}{tp+fp:8d}")
    print("=" * 66)

    conv = tf.lite.TFLiteConverter.from_keras_model(model)
    conv.optimizations = [tf.lite.Optimize.DEFAULT]
    conv.target_spec.supported_types = [tf.float16]
    fp16 = conv.convert()
    open(os.path.join(OUT, "m1_scream_v3_float16.tflite"), "wb").write(fp16)

    json.dump({"model": "m1_scream_v4",
               "headline_real_auc": round(real_auc, 4),
               "headline_note": "held-out real AudioSet screams, same protocol as v1/v2",
               "v1_real_auc": 0.616, "v2_real_auc": 0.7591,
               "beats_v2": bool(real_auc > 0.7591),
               "operating_curve": curve,
               "chosen_threshold_from_val": round(t, 4),
               "val_auc": round(float(roc_auc_score(yva, vp)), 4),
               "train_pos": int(y.sum()), "train_neg": int((1 - y).sum()),
               "eval_real_pos": int(ye.sum()), "eval_real_neg": int((1 - ye).sum()),
               "float16_kb": round(len(fp16) / 1024, 1),
               "key_change": "added 714 VocalAffectBench screams and ~4500 "
                             "same-domain non-speech hard negatives "
                             "(laughter/cough/sneeze/sigh/sniff/throat/yawn)",
               "input_contract": {"sr": SR, "duration": DURATION, "n_mels": N_MELS,
                                  "frames": FRAMES, "shape": [1, N_MELS, FRAMES, 1]}},
              open(os.path.join(OUT, "m1_scream_v3_report.json"), "w"), indent=2)
    print("report written")


if __name__ == "__main__":
    main()
