"""Day 362C - what is a small amount of REAL-WORLD audio actually worth?

THE QUESTION THIS ANSWERS
=========================
Day 361 showed glass and gunshot both fall off a cliff outside FSD50K:

    m_glass_breaking_v4   FSD50K 0.866 -> AudioSet 0.688
    mg_gunshot_v2         FSD50K 0.846 -> AudioSet 0.701

and that glass's entire +0.182 retrain gain was FSD50K-specific. The
standing recommendation off the back of that is "get MIVIA" -- 6,000 real
events at realistic SNRs, behind a request form only the user can submit.

That recommendation has never been *tested*. It rests on the assumption
that a modest amount of in-domain data would close a gap that a large
amount of out-of-domain data cannot. Worth checking before asking someone
to go get data.

There are 59 glass and 77 gunshot AudioSet positives on this disk. Small --
which is precisely the point. If even that much moves the needle, more is
clearly worth acquiring. If it does not, the gap is not about data volume
and MIVIA would not fix it either.

THE DESIGN
==========
5-fold cross-validation over AudioSet CLIPS (not windows -- a clip's
windows must never straddle the split):

    arm BASE   train on FSD50K dev only            test on held-out fold
    arm MIX    train on FSD50K dev + 4/5 AudioSet  test on held-out fold

Out-of-fold predictions are collected across all 5 folds, so both arms are
finally scored on **every** AudioSet clip -- the full 59/77 positives, not
a fifth of them. Same clips, same order, both arms, so the bootstrap can be
paired.

WEAK LABELS: AudioSet is clip-level, and a 10 s clip labelled "Gunshot" has
the gunshot in perhaps one 3 s window. Feeding every window of a positive
clip as a positive would train on mostly-negative audio labelled positive.
Instead, for each positive clip the single window the BASE model scores
highest is taken as the positive instance. That uses the clip's known
label to locate the event within a clip already known to contain one; it
does not use the held-out fold's labels, because BASE never sees AudioSet.
Negative clips contribute all their windows, which are all genuinely
negative.

Test-time scoring is max-over-windows either way, matching the shipped
rolling-buffer path.

PRE-REGISTERED, before running: this is a measurement, not a ship decision.
No asset is exported. The number of interest is the DELTA, and either sign
is informative:
    MIX >> BASE   a little real-world data is worth a lot -> go get MIVIA
    MIX ~= BASE   the gap is not about volume -> MIVIA would not fix it,
                  and the recommendation should be withdrawn
"""
from __future__ import annotations

import json
import os

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
PERM = r"D:\zapsafe\permissive"
K = 5
SEEDS = (42, 7)
B = 2000

TASKS = {
    "glass": {"cache": "glass_dev_mel.npz", "y": "yg", "size": 96},
    "gun": {"cache": "gunshot_dev_mel.npz", "y": "yk", "size": 128},
}


def net(shape, seed):
    """The architecture both shipped models use."""
    import tensorflow as tf
    tf.keras.backend.clear_session()
    tf.random.set_seed(seed)
    np.random.seed(seed)
    inp = tf.keras.Input(shape=shape)
    x = inp
    for f in (16, 32, 64):
        x = tf.keras.layers.Conv2D(f, 3, padding="same", activation="relu")(x)
        x = tf.keras.layers.MaxPooling2D(2)(x)
    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    x = tf.keras.layers.Dropout(0.3)(x)
    x = tf.keras.layers.Dense(64, activation="relu")(x)
    out = tf.keras.layers.Dense(1, activation="sigmoid")(x)
    return tf.keras.Model(inp, out)


def fit(X, y, seed, epochs=25, batch=32):
    import tensorflow as tf
    m = net(X.shape[1:], seed)
    n1, n0 = int(y.sum()), int((1 - y).sum())
    m.compile(optimizer=tf.keras.optimizers.Adam(1e-3),
              loss="binary_crossentropy",
              metrics=[tf.keras.metrics.AUC(name="auc")])
    m.fit(X, y, epochs=epochs, batch_size=batch, verbose=0,
          class_weight={0: len(y) / (2.0 * max(n0, 1)),
                        1: len(y) / (2.0 * max(n1, 1))})
    return m


def three_ch(a):
    return np.repeat(a.astype(np.float32)[..., None], 3, axis=-1)


def main():
    from sklearn.metrics import roc_auc_score

    d = np.load(os.path.join(HERE, "audioset_fixture.npz"), allow_pickle=True)
    report = {}

    for task, cfg in TASKS.items():
        # --- FSD50K dev training set, as the shipped models were trained
        c = np.load(os.path.join(PERM, cfg["cache"]), allow_pickle=True)
        Xf = three_ch(c["X"].astype(np.float32)) if c["X"].ndim == 3 \
            else c["X"].astype(np.float32)
        yf = np.asarray(c["y"]).astype(int)

        # --- AudioSet, per-clip windows
        ya = d[cfg["y"]].astype(int)
        nwin = d["nwin_%s" % task].astype(int)
        off = np.concatenate([[0], np.cumsum(nwin)])
        W = d["win_%s" % task]
        n = len(ya)
        print("\n=== %s | FSD50K train %s pos=%d | AudioSet %d clips pos=%d"
              % (task, Xf.shape, yf.sum(), n, ya.sum()))

        rng = np.random.RandomState(42)
        fold = rng.permutation(n) % K          # split by CLIP
        oof = {"BASE": np.zeros(n), "MIX": np.zeros(n)}

        for f in range(K):
            te = fold == f
            tr = ~te
            # BASE: FSD50K only
            base = [fit(Xf, yf, s) for s in SEEDS]

            def win_scores(models, clips):
                """One batched predict over every window of `clips`, then
                split back per clip. Per-clip predict() calls cost ~32k
                Keras invocations and dominate the runtime."""
                spans = [(off[k], off[k + 1]) for k in clips]
                flat = np.concatenate([W[a:b] for a, b in spans])
                p = np.mean([m.predict(three_ch(flat), verbose=0,
                                       batch_size=256).ravel()
                             for m in models], axis=0)
                out, c = [], 0
                for a, b in spans:
                    out.append(p[c:c + (b - a)])
                    c += b - a
                return out

            def score(models, idx):
                clips = np.where(idx)[0]
                return np.array([w.max()
                                 for w in win_scores(models, clips)])

            oof["BASE"][te] = score(base, te)

            # MIX: FSD50K + this fold's AudioSet training clips.
            # Positives contribute their single highest-BASE-scoring window;
            # negatives contribute all windows.
            tr_clips = np.where(tr)[0]
            tr_win = win_scores(base, tr_clips)
            addX, addy = [], []
            for j, k in enumerate(tr_clips):
                w = three_ch(W[off[k]:off[k + 1]])
                if ya[k] == 1:
                    # the single window BASE scores highest: locate the
                    # event inside a clip already known to contain one
                    addX.append(w[int(np.argmax(tr_win[j]))])
                    addy.append(1)
                else:
                    for i in range(len(w)):
                        addX.append(w[i])
                        addy.append(0)
            Xm = np.concatenate([Xf, np.stack(addX)])
            ym = np.concatenate([yf, np.asarray(addy, int)])
            mix = [fit(Xm, ym, s) for s in SEEDS]
            oof["MIX"][te] = score(mix, te)
            print("  fold %d: +%d AudioSet rows (%d pos) -> train %d"
                  % (f, len(addy), int(np.sum(addy)), len(ym)), flush=True)

        a_base = float(roc_auc_score(ya, oof["BASE"]))
        a_mix = float(roc_auc_score(ya, oof["MIX"]))
        rs = np.random.RandomState(7)
        idx = [rs.randint(0, n, n) for _ in range(B)]
        dv = []
        for i in idx:
            if ya[i].min() == ya[i].max():
                continue
            dv.append(roc_auc_score(ya[i], oof["MIX"][i])
                      - roc_auc_score(ya[i], oof["BASE"][i]))
        dv = np.asarray(dv)
        lo, hi = np.percentile(dv, [2.5, 97.5])
        print("  BASE (FSD50K only)        AudioSet OOF AUC %.4f" % a_base)
        print("  MIX  (+4/5 AudioSet)      AudioSet OOF AUC %.4f" % a_mix)
        print("  delta %+.4f  [%+.4f, %+.4f]  P(MIX<=BASE) = %.3f"
              % (dv.mean(), lo, hi, float((dv <= 0).mean())))
        report[task] = {"base": round(a_base, 4), "mix": round(a_mix, 4),
                        "delta": round(float(dv.mean()), 4),
                        "ci95": [round(float(lo), 4), round(float(hi), 4)],
                        "p_mix_not_better": round(float((dv <= 0).mean()), 4),
                        "audioset_positives": int(ya.sum()),
                        "fsd_train_rows": int(len(yf))}

    json.dump(report, open(os.path.join(HERE, "multicorpus_value.json"), "w"),
              indent=2)
    print("\nreport written")


if __name__ == "__main__":
    main()
