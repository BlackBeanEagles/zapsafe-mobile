"""Day 353 - TRAC-1 cross-corpus: does 0.8312 survive a different corpus?

WHY THIS TEST EXISTS
====================
TRAC-1's report carries two caveats: the corpus has no author id, so rows by
the same author can straddle the split, and the model has never been scored
on text from anywhere else. This week has repeatedly punished exactly that
gap -- m3_violence 0.9126 in-corpus vs 0.4821 on an independent one, scream
v3 0.839 -> 0.7675, and every vocal-stress model at chance the moment the
recording situation changed.

THE INDEPENDENT CORPUS
======================
Indo-HateSpeech: 77,926 Instagram comments, Hindi (both Devanagari and
romanised) and English, labelled HS0 / HS1 / HSN. Same language pair as
TRAC-1, different platform, different collection, different annotators.

WHAT IT DOES AND DOES NOT MEASURE
=================================
TRAC-1's labels are OAG / CAG / NAG -- overtly aggressive, covertly
aggressive, non-aggressive -- collapsed to binary. Indo-HateSpeech's are
hate speech vs not. **These are related constructs, not the same one.**
Hate speech is roughly a subset of aggression that targets a protected
attribute; plenty of TRAC aggression is a personal insult with no group
target, and would be HS0 here.

So a drop on this set has two possible causes and this test alone cannot
separate them: the model failing to transfer, or the two label definitions
genuinely differing. That is a real limit and it is why the length baseline
below matters -- it is computed on THESE labels, so it says how much of this
particular set is learnable from a trivial cue, and the model has to beat
that bar on the same terms.

HSN rows are dropped: the category is undocumented in the sheet and
assigning it to either class would be inventing a label.

PRE-REGISTERED READING, fixed before running:
    >= 0.75   transfers; the in-corpus number was not corpus-specific
    0.60-0.75 partial; the constructs overlap but the model is corpus-bound
    <= 0.60   does not transfer, and TRAC-1 should not be described as an
              aggression detector without naming the corpus it belongs to
"""
from __future__ import annotations

import collections
import io
import json
import os
import re
import zipfile

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
XLSX_ZIP = r"D:\zapsafe\Indo-HateSpeech.zip"
INNER = "Indo-HateSpeech/Indo-HateSpeech_Dataset.xlsx"

# identical to train_trac.py -- the Devanagari branch is load-bearing, a
# plain [a-z0-9']+ deletes every Hindi token silently
TOKEN_RE = re.compile(r"[a-z0-9']+|[^\x00-\x7f]+")
MAXLEN = 60


def tokenize(t):
    return TOKEN_RE.findall((t or "").lower())


def read_xlsx():
    """Read the sheet without openpyxl -- an xlsx is a zip of XML."""
    z = zipfile.ZipFile(XLSX_ZIP)
    inner = zipfile.ZipFile(io.BytesIO(z.read(INNER)))
    ss = re.findall(r"<t[^>]*>(.*?)</t>",
                    inner.read("xl/sharedStrings.xml").decode("utf-8",
                                                              "replace"),
                    re.S)
    sheet = inner.read("xl/worksheets/sheet1.xml").decode("utf-8", "replace")
    rows = re.findall(r"<row[^>]*>(.*?)</row>", sheet, re.S)

    def cells(body):
        out = {}
        for m in re.finditer(r'<c[^>]*r="([A-Z]+)\d+"([^>]*)>(.*?)</c>',
                             body, re.S):
            col, attrs, inner_ = m.group(1), m.group(2), m.group(3)
            v = re.search(r"<v>(.*?)</v>", inner_, re.S)
            if not v:
                continue
            val = v.group(1)
            if 't="s"' in attrs:
                val = ss[int(val)]
            out[col] = val
        return out

    texts, labels, raw = [], [], collections.Counter()
    for body in rows[1:]:
        c = cells(body)
        t = c.get("F", "")
        lab = (c.get("I", "") or "").strip().strip("'").upper()
        raw[lab] += 1
        if lab not in ("HS0", "HS1"):
            continue
        if not t or len(tokenize(t)) < 2:
            continue
        texts.append(t)
        labels.append(1 if lab == "HS1" else 0)
    return texts, np.array(labels), raw


def encode(texts, vocab):
    X = np.zeros((len(texts), MAXLEN), np.int32)
    oov = 0
    tot = 0
    for i, t in enumerate(texts):
        toks = tokenize(t)[:MAXLEN]
        for j, w in enumerate(toks):
            idx = vocab.get(w, 1)
            X[i, j] = idx
            oov += (idx == 1)
            tot += 1
    return X, (oov / max(tot, 1))


def boot(y, p, n=4000):
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

    texts, y, raw = read_xlsx()
    print("label counts in sheet:", dict(raw.most_common(6)))
    print("usable rows %d  hate=%d (%.1f%%)"
          % (len(y), int(y.sum()), y.mean() * 100))

    vocab = json.load(io.open(os.path.join(
        HERE, "trac_aggression_v1_vocab.json"), encoding="utf-8"))
    X, oov = encode(texts, vocab)
    print("OOV token rate against TRAC's vocab: %.1f%%" % (oov * 100))
    if oov > 0.5:
        print("  NOTE: over half the tokens are unknown to the model. A low "
              "AUC below would partly measure vocabulary coverage, not "
              "aggression.")

    it = tf.lite.Interpreter(model_path=os.path.join(
        HERE, "trac_aggression_v1_float16.tflite"))
    it.allocate_tensors()
    inp, out = it.get_input_details()[0], it.get_output_details()[0]
    it.resize_tensor_input(inp["index"], [1, MAXLEN])
    it.allocate_tensors()
    p = np.zeros(len(X), np.float64)
    for i in range(len(X)):
        it.set_tensor(inp["index"], X[i:i + 1].astype(inp["dtype"]))
        it.invoke()
        p[i] = float(it.get_tensor(out["index"]).ravel()[0])
        if (i + 1) % 5000 == 0:
            print("  scored %d/%d" % (i + 1, len(X)), flush=True)

    auc = float(roc_auc_score(y, p))
    lo, hi = boot(y, p)

    # the trivial-cue control, computed on THESE labels
    ln = np.array([len(tokenize(t)) for t in texts], np.float64)
    base = float(roc_auc_score(y, ln))
    base = max(base, 1.0 - base)

    print("\n" + "=" * 66)
    print("  TRAC-1 on Indo-HateSpeech : %.4f  CI [%.4f, %.4f]"
          % (auc, lo, hi))
    print("  length-only baseline      : %.4f" % base)
    print("  in-corpus (TRAC dev)      : 0.8312")

    if auc >= 0.75:
        v = "TRANSFERS - the in-corpus number was not corpus-specific"
    elif auc >= 0.60:
        v = ("PARTIAL - constructs overlap but the model is corpus-bound; "
             "do not quote 0.8312 as general aggression detection")
    else:
        v = ("DOES NOT TRANSFER - TRAC-1 is a TRAC-corpus detector and must "
             "be described as one")
    print("  -> %s" % v)
    if auc <= base + 0.05:
        print("  AND it does not clear the length baseline on this set, "
              "which is the stronger finding of the two")

    json.dump({"auc": round(auc, 4), "ci95": [round(lo, 4), round(hi, 4)],
               "length_baseline": round(base, 4), "in_corpus": 0.8312,
               "n": int(len(y)), "pos": int(y.sum()),
               "oov_rate": round(oov, 4), "verdict": v,
               "construct_caveat": "hate speech labels vs aggression labels "
                                   "-- related, not identical"},
              open(os.path.join(HERE, "crosscorpus_report.json"), "w"),
              indent=2)
    print("report written")


if __name__ == "__main__":
    main()
