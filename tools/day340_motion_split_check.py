"""Is motion_fall_v2's 0.999 a real number or a lucky subject split?

m5's shipped 0.7988 turned out to be the best of six held-out speaker
triples (mean 0.6314, sd 0.1100). motion_fall_v2 was reported from ONE
subject split by the same method and has never been checked. Its 0.941
separation makes split-luck unlikely, but unlikely is not checked.

Reproduces train_motion.py's architecture and preprocessing exactly, varying
only which 7 of 30 subjects are held out.
"""
import os, numpy as np, scipy.io as sio
ROOT = r"C:\Users\hridy\Desktop\zapsafe"
B = os.path.join(ROOT, r"ml_datasets\motion\DS_UniMiB\UniMiB-SHAR\data")
WINDOW, CHANNELS, HELD_OUT = 100, 3, 7

def load_mat(name):
    d = sio.loadmat(os.path.join(B, name))
    return d[[k for k in d if not k.startswith("__")][0]]

def main():
    import tensorflow as tf
    from sklearn.metrics import roc_auc_score
    from sklearn.model_selection import train_test_split
    X, Y = load_mat("two_classes_data.mat"), load_mat("two_classes_labels.mat")
    n = X.shape[0]
    w = np.stack([X[:, :151], X[:, 151:302], X[:, 302:453]], axis=-1)
    mid = w.shape[1] // 2
    w = w[:, mid - WINDOW // 2: mid + WINDOW // 2, :].astype(np.float32)
    y = (Y[:, 0] == 2).astype(np.float32)
    subj = Y[:, 1]
    print(f"windows {w.shape}  falls {int(y.sum())}  subjects {len(np.unique(subj))}")

    def auc_for(seed):
        rng = np.random.default_rng(seed)
        subs = np.unique(subj).copy(); rng.shuffle(subs)
        test_subs = set(subs[:HELD_OUT].tolist())
        te = np.array([s in test_subs for s in subj])
        Xtr_all, ytr_all, Xte, yte = w[~te], y[~te], w[te], y[te]
        if yte.sum() < 5 or (1 - yte).sum() < 5:
            return None, sorted(test_subs)
        Xtr, Xva, ytr, yva = train_test_split(Xtr_all, ytr_all, test_size=0.15,
                                              random_state=42, stratify=ytr_all)
        mean = Xtr.reshape(-1, CHANNELS).mean(axis=0)
        std = Xtr.reshape(-1, CHANNELS).std(axis=0) + 1e-8
        nz = lambda a: ((a - mean) / std).astype(np.float32)
        Xtr, Xva, Xte_n = nz(Xtr), nz(Xva), nz(Xte)
        tf.keras.utils.set_random_seed(42)
        inp = tf.keras.Input(shape=(WINDOW, CHANNELS))
        x = inp
        for f in (32, 64, 128):
            x = tf.keras.layers.Conv1D(f, 5, padding="same", activation="relu")(x)
            x = tf.keras.layers.BatchNormalization()(x)
            x = tf.keras.layers.MaxPooling1D(2)(x)
        x = tf.keras.layers.GlobalAveragePooling1D()(x)
        x = tf.keras.layers.Dropout(0.3)(x)
        x = tf.keras.layers.Dense(64, activation="relu")(x)
        out = tf.keras.layers.Dense(1, activation="sigmoid")(x)
        m = tf.keras.Model(inp, out)
        m.compile(optimizer=tf.keras.optimizers.Adam(1e-3), loss="binary_crossentropy",
                  metrics=[tf.keras.metrics.AUC(name="auc")])
        npos, nneg = int(ytr.sum()), int((1 - ytr).sum())
        cw = {0: len(ytr) / (2.0 * max(nneg, 1)), 1: len(ytr) / (2.0 * max(npos, 1))}
        m.fit(Xtr, ytr, validation_data=(Xva, yva), epochs=60, batch_size=64,
              class_weight=cw, verbose=0,
              callbacks=[tf.keras.callbacks.EarlyStopping(monitor="val_auc", mode="max",
                         patience=10, restore_best_weights=True)])
        p = m.predict(Xte_n, verbose=0).ravel()
        return float(roc_auc_score(yte, p)), sorted(test_subs)

    res = []
    for seed in (42, 1, 2, 3, 4, 5):
        a, subs = auc_for(seed)
        if a is None:
            print(f"  seed {seed}: degenerate split, skipped"); continue
        res.append(a)
        mark = "  <- the split motion_fall_v2 shipped from" if seed == 42 else ""
        print(f"  seed {seed}  held-out {subs}  AUC={a:.4f}{mark}", flush=True)
    print(f"\n  mean {np.mean(res):.4f}  sd {np.std(res):.4f}  "
          f"min {min(res):.4f}  max {max(res):.4f}")
    print(f"  for contrast, m5 vocal stress was mean 0.6314 sd 0.1100 min 0.5060")

if __name__ == "__main__":
    main()
