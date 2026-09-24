"""Distress-text classifier (English) — the honest subset of what M7 wanted.

SCOPE, STATED UP FRONT
======================
This is **not** `m7_nlp_context_enhanced`. That model's spec is a labeled
**multilingual** corpus for **victim-perspective** distress ("someone is
following me", "help me"). Swept every attached drive including the ~955 GB
recently added: the only text corpora present anywhere are the three
mental-health CSVs on D:. Everything else is audio or video. So the
multilingual victim-distress spec stays blocked, and this model is given a
different name so it cannot be mistaken for satisfying it.

What this IS: an English classifier over self-reported mental-health text,
Normal vs distress (Anxiety / Depression / Suicidal). That is a genuinely
useful signal for a safety app operating on a user's own typed text, and it
is honestly labelled real data — but it is clinical *state*, not "I am in
immediate physical danger", and the two should not be conflated.

DESIGN NOTES
============
Tokenizer is deliberately trivial so Dart can reproduce it exactly:
lowercase, strip to [a-z0-9'] runs, map through a fixed vocab, pad/truncate
to MAXLEN. No stemming, no subwords, no language-specific rules. The vocab
ships as JSON beside the model.

Leakage discipline, given this project's history:
  * exact-duplicate texts are removed BEFORE the split, and the dedup is on
    normalised text so "Hello!" and "hello" cannot straddle it
  * the split is a plain random one over deduped rows, which is legitimate
    here because rows are independent posts with no speaker/session grouping
    available -- there is no `speaker_id` analogue in this data to hold out,
    and that limitation is recorded rather than papered over
  * a text-length-only baseline is trained and reported, because "distress
    posts are longer" is exactly the kind of shortcut that would otherwise
    read as model skill
"""
from __future__ import annotations

import csv
import json
import os
import re
import sys

import numpy as np

SEED = 42
np.random.seed(SEED)

ROOT = r"C:\Users\hridy\Desktop\zapsafe"
OUT = os.path.join(ROOT, "work", "m7_distress_text")
SRC = [r"D:\zapsafe\mental_heath_unbanlanced.csv",
       r"D:\zapsafe\mental_health_combined_test.csv"]

VOCAB_SIZE = 20000
MAXLEN = 120
EMBED = 64
DISTRESS = {"anxiety", "depression", "suicidal"}
NORMAL = {"normal"}

_TOK = re.compile(r"[a-z0-9']+")


def norm_text(s: str) -> str:
    return " ".join(_TOK.findall((s or "").lower()))


def load():
    rows, seen = [], set()
    dupes = 0
    for path in SRC:
        if not os.path.exists(path):
            print(f"  MISSING {path}")
            continue
        with open(path, encoding="utf-8", errors="replace", newline="") as f:
            for r in csv.DictReader(f):
                status = (r.get("status") or "").strip().lower()
                if status in DISTRESS:
                    lab = 1
                elif status in NORMAL:
                    lab = 0
                else:
                    continue
                t = norm_text(r.get("text"))
                if len(t) < 3:
                    continue
                if t in seen:            # dedup BEFORE the split
                    dupes += 1
                    continue
                seen.add(t)
                rows.append((t, lab, status))
        print(f"  {os.path.basename(path)}: running total {len(rows)}")
    print(f"  dropped {dupes} exact duplicate texts before splitting")
    return rows


def main():
    os.makedirs(OUT, exist_ok=True)
    import tensorflow as tf
    from sklearn.metrics import roc_auc_score

    rows = load()
    if len(rows) < 1000:
        sys.exit("not enough labelled rows")
    texts = [r[0] for r in rows]
    y = np.array([r[1] for r in rows], dtype=np.float32)
    status = [r[2] for r in rows]
    print(f"\nrows={len(rows)}  distress={int(y.sum())}  normal={int((1-y).sum())}")

    idx = np.random.permutation(len(rows))
    n_te = int(len(rows) * 0.2)
    te_i, tr_i = idx[:n_te], idx[n_te:]
    te = np.zeros(len(rows), bool)
    te[te_i] = True

    # vocab from TRAIN ONLY -- building it over everything would leak test
    # vocabulary into the model's input space.
    from collections import Counter
    cnt = Counter()
    for i in tr_i:
        cnt.update(texts[i].split())
    vocab = {w: i + 2 for i, (w, _) in enumerate(cnt.most_common(VOCAB_SIZE - 2))}
    print(f"vocab={len(vocab)} (from {len(tr_i)} train rows only)")

    def encode(t):
        ids = [vocab.get(w, 1) for w in t.split()[:MAXLEN]]
        return ids + [0] * (MAXLEN - len(ids))

    X = np.array([encode(t) for t in texts], dtype=np.int32)

    # --- shortcut baseline: length alone -------------------------------
    lens = np.array([len(t.split()) for t in texts], dtype=np.float32)
    len_auc = roc_auc_score(y[te], lens[te])
    print(f"\nSHORTCUT BASELINE  word-count-only AUC = {len_auc:.4f}"
          "   <- the model must beat this to mean anything")

    model = tf.keras.Sequential([
        tf.keras.layers.Input(shape=(MAXLEN,), dtype="int32", name="tokens"),
        tf.keras.layers.Embedding(VOCAB_SIZE, EMBED, mask_zero=True),
        tf.keras.layers.GlobalAveragePooling1D(),
        tf.keras.layers.Dense(64, activation="relu"),
        tf.keras.layers.Dropout(0.3),
        tf.keras.layers.Dense(1, activation="sigmoid"),
    ], name="distress_text")
    model.compile(optimizer=tf.keras.optimizers.Adam(1e-3),
                  loss="binary_crossentropy", metrics=["accuracy"])
    model.fit(X[tr_i], y[tr_i], validation_split=0.1, epochs=12, batch_size=128,
              verbose=2,
              callbacks=[tf.keras.callbacks.EarlyStopping(
                  monitor="val_loss", patience=3, restore_best_weights=True)])

    p = model.predict(X, verbose=0).ravel()
    auc = roc_auc_score(y[te], p[te])
    pos, neg = p[te][y[te] == 1], p[te][y[te] == 0]
    sep = float(pos.mean() - neg.mean())
    span = float(p[te].max() - p[te].min())

    print("\n" + "=" * 66)
    print(f"  HELD-OUT AUC              {auc:.4f}")
    print(f"  vs word-count baseline    {len_auc:.4f}  (delta {auc - len_auc:+.4f})")
    print(f"  separation                {sep:+.4f}   span {span:.4f}")
    curve = []
    for t in (0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2):
        pred = p[te] >= t
        tp = float((pred & (y[te] == 1)).sum())
        rec = tp / max(1.0, float((y[te] == 1).sum()))
        pre = tp / max(1.0, float(pred.sum()))
        curve.append({"t": t, "recall": round(rec, 3), "precision": round(pre, 3)})
        print(f"    {t:.2f}   recall {rec:.3f}   precision {pre:.3f}")

    # per-status recall at 0.5 -- Suicidal is the one that matters most
    per_status = {}
    st = np.array(status)
    for s in sorted(set(status)):
        m = te & (st == s)
        if m.sum():
            per_status[s] = round(float((p[m] >= 0.5).mean()), 3)
    print(f"  fraction scored >=0.5 by original label: {per_status}")
    print("=" * 66)

    conv = tf.lite.TFLiteConverter.from_keras_model(model)
    conv.optimizations = [tf.lite.Optimize.DEFAULT]
    conv.target_spec.supported_types = [tf.float16]
    tfl = conv.convert()
    mp = os.path.join(OUT, "distress_text_v1_float16.tflite")
    open(mp, "wb").write(tfl)

    json.dump({"vocab": vocab, "maxlen": MAXLEN, "oov_id": 1, "pad_id": 0,
               "lowercase": True, "token_regex": "[a-z0-9']+"},
              open(os.path.join(OUT, "distress_text_v1_vocab.json"), "w"), indent=0)
    json.dump({"model": "distress_text_v1",
               "NOT_m7": "does NOT satisfy m7_nlp_context_enhanced, which needs a "
                         "MULTILINGUAL VICTIM-PERSPECTIVE distress corpus. This is "
                         "English clinical-state text. No multilingual distress "
                         "corpus exists on any attached drive including the ~955GB.",
               "heldout_auc": round(float(auc), 4),
               "word_count_baseline_auc": round(float(len_auc), 4),
               "beats_shortcut_by": round(float(auc - len_auc), 4),
               "separation": round(sep, 4), "span": round(span, 4),
               "operating_curve": curve,
               "fraction_over_0.5_by_label": per_status,
               "rows": len(rows), "test_n": int(te.sum()),
               "split": "random over deduped rows; NO speaker/session grouping "
                        "exists in this data to hold out - recorded as a limitation",
               "vocab_size": len(vocab), "maxlen": MAXLEN,
               "float16_kb": round(len(tfl) / 1024, 1)},
              open(os.path.join(OUT, "distress_text_v1_report.json"), "w"), indent=2)
    print("report written")


if __name__ == "__main__":
    main()
