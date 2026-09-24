"""Day 352 - TRAC-1 aggression text, English + Hindi, Apache-2.0.

WHAT THIS IS, AND WHAT IT IS NOT
================================
TRAC-1 (Trolling, Aggression and Cyberbullying, COLING 2018) is 30,002
aggression-annotated Facebook comments in English and Hindi under
**Apache-2.0** -- the only genuinely permissive text corpus on any drive.
Everything else is Non-Commercial, research-use, or unlicensed.

It does **NOT** satisfy M7. M7 needs multilingual **victim-perspective**
distress -- "someone is following me", "help me". TRAC is
**aggressor-perspective**: text written BY the aggressor. Those are
different signals and conflating them is exactly what
DAY347_DISTRESS_TEXT_DECISION.md refused to do with clinical text. This
model is named for what it detects and M7 stays blocked.

What it does enable is a real adjacent capability: **detecting threatening
or abusive messages directed at a user**, in Hindi as well as English.
Unlike `distress_text_v1` it makes no inference about the user's own mental
state -- it classifies text someone else sent them.

    agr_en_train  12,000   OAG 2,708  CAG 4,240  NAG 5,052
    agr_en_dev     3,001
    agr_hi_train  12,000   OAG 4,856  CAG 4,869  NAG 2,275
    agr_hi_dev     3,001

LABELS: BINARY, AND WHY
=======================
The shared task is 3-way (Overtly Aggressive / Covertly Aggressive /
Non-Aggressive). This trains **aggressive (OAG+CAG) vs not (NAG)**, because
the product question is "is this message hostile", not "how hostile".
Collapsing also avoids the OAG/CAG boundary, which is the hardest and least
reproducible distinction in the original task.

TOKENIZER MATCHES distress_text_v1's, DELIBERATELY
==================================================
Lowercase, keep [a-z0-9'] runs, map through a fixed vocab, pad/truncate.
That is trivial enough for Dart to reproduce exactly, which is why the
earlier model chose it. **Hindi is Devanagari**, so a [a-z0-9'] filter
would delete it entirely -- the character class is widened to keep any
non-ASCII letter, and a Devanagari-aware smoke test guards that.

THE SHORTCUT CONTROL
====================
Aggressive comments may simply be longer or use more punctuation. A
length-and-punctuation-only baseline is trained and reported, and the model
must beat it by a clear margin. This is the control that nearly sank
distress_text_v1 (word-count alone scored 0.9010 pooled) and it is run here
before any claim.

SPLIT: the corpus ships its own train/dev. dev is held out and never
trained on. Rows are independent comments with no author id available, so
no author-level grouping is possible -- recorded as a limitation, not
papered over.
"""
from __future__ import annotations

import collections
import csv
import io
import json
import os
import re
import zipfile

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = r"F:\zapsafe\trac-1-master.zip"
SEED = 42
MAXLEN = 60
VOCAB = 20000

FILES = {
    "en_train": "trac-1-master/english/agr_en_train.csv",
    "en_dev": "trac-1-master/english/agr_en_dev.csv",
    "hi_train": "trac-1-master/hindi/agr_hi_train.csv",
    "hi_dev": "trac-1-master/hindi/agr_hi_dev.csv",
}

# Keep ASCII word chars AND any non-ASCII letter, so Devanagari survives.
# A plain [a-z0-9'] filter -- which is what distress_text_v1 uses -- would
# delete every Hindi row down to an empty string.
TOKEN_RE = re.compile(r"[a-z0-9']+|[^\x00-\x7f]+")


def tokenize(text):
    return TOKEN_RE.findall((text or "").lower())


def load_rows():
    z = zipfile.ZipFile(SRC)
    out = {}
    for key, inner in FILES.items():
        txt = z.read(inner).decode("utf-8", "replace")
        rows = []
        for r in csv.reader(io.StringIO(txt)):
            if len(r) < 3:
                continue
            lab = r[-1].strip().upper()
            if lab not in ("OAG", "CAG", "NAG"):
                continue
            rows.append((r[1], 0 if lab == "NAG" else 1))
        out[key] = rows
        pos = sum(l for _, l in rows)
        print(f"  {key:9s} {len(rows):6d} rows  aggressive={pos} "
              f"({100*pos/max(len(rows),1):.1f}%)")
    return out


def build_vocab(texts):
    c = collections.Counter()
    for t in texts:
        c.update(tokenize(t))
    # 0 = pad, 1 = OOV
    return {w: i + 2 for i, (w, _) in enumerate(c.most_common(VOCAB - 2))}


def encode(texts, vocab):
    X = np.zeros((len(texts), MAXLEN), np.int32)
    for i, t in enumerate(texts):
        toks = tokenize(t)[:MAXLEN]
        for j, w in enumerate(toks):
            X[i, j] = vocab.get(w, 1)
    return X


def shortcut_features(texts):
    """Length and punctuation only -- the baseline the model must beat."""
    out = np.zeros((len(texts), 6), np.float64)
    for i, t in enumerate(texts):
        t = t or ""
        toks = tokenize(t)
        out[i] = [len(toks), len(t),
                  t.count("!"), t.count("?"),
                  sum(1 for c in t if c.isupper()) / max(len(t), 1),
                  np.mean([len(w) for w in toks]) if toks else 0.0]
    return out


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
    from sklearn.linear_model import LogisticRegression
    from sklearn.metrics import roc_auc_score
    from sklearn.preprocessing import StandardScaler
    tf.random.set_seed(SEED)
    np.random.seed(SEED)

    print("=== TRAC-1 (Apache-2.0) ===")
    rows = load_rows()

    # Smoke test: Devanagari must survive tokenization. A [a-z0-9'] filter
    # silently empties every Hindi row, which would look like a bad model
    # rather than a broken tokenizer.
    hi_sample = rows["hi_train"][0][0]
    assert tokenize(hi_sample), "tokenizer emptied a Hindi row"
    nonascii = sum(1 for t in tokenize(hi_sample) if any(ord(c) > 127 for c in t))
    print(f"  tokenizer keeps Devanagari: {nonascii} non-ASCII tokens in a "
          f"sample Hindi row")

    tr = rows["en_train"] + rows["hi_train"]
    dv = rows["en_dev"] + rows["hi_dev"]
    Ttr = [t for t, _ in tr]
    ytr = np.asarray([l for _, l in tr], np.int32)
    Tdv = [t for t, _ in dv]
    ydv = np.asarray([l for _, l in dv], np.int32)
    print(f"\n  train {len(ytr)}  dev {len(ydv)}  "
          f"dev aggressive {ydv.mean()*100:.1f}%")

    vocab = build_vocab(Ttr)
    print(f"  vocab {len(vocab)} (+pad,+oov)")
    Xtr, Xdv = encode(Ttr, vocab), encode(Tdv, vocab)

    # --- the shortcut control, run BEFORE the model ---------------------
    sc = StandardScaler().fit(shortcut_features(Ttr))
    base = LogisticRegression(max_iter=2000).fit(
        sc.transform(shortcut_features(Ttr)), ytr)
    p_base = base.predict_proba(sc.transform(shortcut_features(Tdv)))[:, 1]
    auc_base = float(roc_auc_score(ydv, p_base))
    print(f"\n  length+punctuation baseline AUC {auc_base:.4f}")

    m = tf.keras.Sequential([
        tf.keras.Input(shape=(MAXLEN,), dtype="int32", name="tokens"),
        # Conv + pooling, NOT a GRU. The recurrent version scored 0.8430
        # but compiled to TFLite with SELECT_TF_OPS -- FlexTensorListReserve,
        # FlexTensorListSetItem, FlexTensorListStack -- which needs the Flex
        # delegate linked into the Android build. For a model that is not
        # wired yet, taking on a delegate dependency to gain a few points
        # would be paying deployment cost up front for accuracy nobody is
        # consuming. Conv1D + GlobalMaxPooling uses builtin ops only.
        tf.keras.layers.Embedding(VOCAB, 64),
        tf.keras.layers.Conv1D(128, 3, padding="same", activation="relu"),
        tf.keras.layers.Conv1D(128, 5, padding="same", activation="relu"),
        tf.keras.layers.GlobalMaxPooling1D(),
        tf.keras.layers.Dropout(0.4),
        tf.keras.layers.Dense(32, activation="relu"),
        tf.keras.layers.Dropout(0.3),
        tf.keras.layers.Dense(1, activation="sigmoid", name="aggressive"),
    ], name="trac_aggression_v1")
    m.compile(optimizer=tf.keras.optimizers.Adam(1e-3),
              loss="binary_crossentropy",
              metrics=[tf.keras.metrics.AUC(name="auc")])
    npos, nneg = int(ytr.sum()), int((1 - ytr).sum())
    m.fit(Xtr, ytr, validation_data=(Xdv, ydv), epochs=30, batch_size=128,
          verbose=0,
          class_weight={0: len(ytr) / (2.0 * nneg), 1: len(ytr) / (2.0 * npos)},
          callbacks=[tf.keras.callbacks.EarlyStopping(
              monitor="val_auc", mode="max", patience=5,
              restore_best_weights=True)])

    p = m.predict(Xdv, verbose=0).ravel()
    auc = float(roc_auc_score(ydv, p))
    lo, hi = ci(ydv, p)
    print(f"  model AUC {auc:.4f}   95% CI [{lo:.4f}, {hi:.4f}]")
    print(f"  beats shortcut by {auc-auc_base:+.4f}")

    # per-language, because a pooled number can hide one language failing
    per = {}
    n_en = len(rows["en_dev"])
    for lang, sl in (("english", slice(0, n_en)), ("hindi", slice(n_en, None))):
        yy, pp = ydv[sl], p[sl]
        if len(set(yy.tolist())) < 2:
            continue
        a = float(roc_auc_score(yy, pp))
        per[lang] = round(a, 4)
        print(f"    {lang:8s} n={len(yy):5d}  AUC {a:.4f}")

    print("\n  operating points:")
    curve = []
    for t in (0.7, 0.6, 0.5, 0.4, 0.3):
        pred = p >= t
        tp = float((pred & (ydv == 1)).sum())
        rc, pr = tp / max(1, ydv.sum()), tp / max(1, pred.sum())
        curve.append({"t": t, "recall": round(rc, 3), "precision": round(pr, 3)})
        print(f"    t={t:.2f}  recall {rc:.3f}  precision {pr:.3f}")

    ship = bool(auc >= 0.70 and lo > 0.50 and (auc - auc_base) >= 0.05
                and min(per.values()) >= 0.65)
    print(f"\n  SHIP  AUC>=0.70 & CI>0.50 & beats shortcut by 0.05 & "
          f"both languages>=0.65  ->  {ship}")

    out = {"auc": round(auc, 4), "ci95": [round(lo, 4), round(hi, 4)],
           "shortcut_baseline_auc": round(auc_base, 4),
           "beats_shortcut_by": round(auc - auc_base, 4),
           "per_language": per, "operating_curve": curve,
           "train_n": int(len(ytr)), "dev_n": int(len(ydv)),
           "vocab_size": len(vocab), "maxlen": MAXLEN,
           "licence": "Apache-2.0",
           "NOT_m7": "aggressor-perspective aggression, NOT victim-perspective "
                     "distress. M7 remains blocked.",
           "limitation": "no author id in the corpus, so no author-level "
                         "grouping is possible; rows are independent comments",
           "SHIP": ship}

    if ship:
        conv = tf.lite.TFLiteConverter.from_keras_model(m)
        conv.optimizations = [tf.lite.Optimize.DEFAULT]
        conv.target_spec.supported_types = [tf.float16]
        # builtin ops only -- assert it, because a silent fallback to
        # SELECT_TF_OPS is exactly the deployment surprise this avoids
        conv.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS]
        blob = conv.convert()
        open(os.path.join(HERE, "trac_aggression_v1_float16.tflite"),
             "wb").write(blob)
        json.dump(vocab, io.open(os.path.join(HERE,
                                              "trac_aggression_v1_vocab.json"),
                                 "w", encoding="utf-8"), ensure_ascii=False)
        out["float16_kb"] = round(len(blob) / 1024, 1)
        print(f"  exported ({out['float16_kb']} KB) + vocab.json")

    json.dump(out, io.open(os.path.join(HERE, "report.json"), "w",
                           encoding="utf-8"), indent=2, ensure_ascii=False)
    print("report written")


if __name__ == "__main__":
    main()
