"""Day 354 - distress_text_v1's cross-corpus test, finally possible.

WHAT WAS BLOCKING THIS
======================
Day 347 listed five reasons `distress_text_v1` (0.9628) stays shelved. Four
are product decisions. The fifth was a MEASUREMENT: it had never been scored
on text from anywhere else, in a project where that test has repeatedly been
the difference between a real model and a corpus-shaped one.

Day 353B confirmed it could not be done with data on disk --
`mental_health_feature_engineered.csv` is 100.0% the same 48,928 texts as
the training source, extra columns and nothing more.

Dreaddit (Turcan & McKeown, EMNLP 2019 workshop) is an independent corpus:
3,553 Reddit posts labelled for stress by crowdworkers, collected for a
different paper from a different subreddit pool (abuse, anxiety, financial,
PTSD, social relationships).

THE CONSTRUCT CAVEAT, WHICH IS REAL
===================================
distress_text_v1 predicts Anxiety/Depression/Suicidal vs Normal.
Dreaddit labels *is this post expressing stress*. Those overlap heavily but
are not the same thing: a post can be stressed without being clinical, and
a flat depressive post can read as unstressed.

So a drop here has two possible causes and this test cannot separate them.
That is exactly the caveat TRAC-1 carried against Indo-HateSpeech, and it is
stated for the same reason. The length baseline below is computed on
DREADDIT's labels, so it says how much of *this* set is trivially
learnable, and the model must beat that on the same terms.

OVERLAP IS CHECKED FIRST. Both corpora are Reddit-derived. If Dreaddit
posts appear in the training data this measures memorisation, not transfer,
and the run aborts rather than reporting a flattering number.

PRE-REGISTERED READING, fixed before running:
    >= 0.80   transfers well; 0.9628 was not corpus-specific
    0.65-0.80 partial; real signal, but 0.9628 must never be quoted alone
    <= 0.65   does not transfer; the model is a corpus artefact and the
              shelving decision becomes permanent rather than pending
"""
from __future__ import annotations

import hashlib
import io
import json
import os
import re

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
import sys
# Day 354: Dreaddit ABORTED at 38.07% exact overlap -- the training corpus
# already contains it. Kept as the default so that result stays
# reproducible; pass "twitter" for the non-Reddit corpus, which is the
# only source with a real chance of being independent.
WHICH = sys.argv[1] if len(sys.argv) > 1 else "dreaddit"
DREADDIT = os.path.join(HERE, WHICH)
TEXT_COL = {"dreaddit": "text", "twitter": "post_text"}[WHICH]
SRC = [r"D:\zapsafe\mental_heath_unbanlanced.csv",
       r"D:\zapsafe\mental_health_combined_test.csv"]

_TOK = re.compile(r"[a-z0-9']+")
MAXLEN = 120


def norm_text(s):
    return " ".join(_TOK.findall((s or "").lower()))


def h(t):
    return hashlib.md5(t.encode()).hexdigest()


def load_dreaddit():
    import pyarrow.parquet as pq
    texts, y = [], []
    for f in sorted(os.listdir(DREADDIT)):
        if not f.endswith(".parquet"):
            continue
        for d in pq.read_table(os.path.join(DREADDIT, f)).to_pylist():
            t = norm_text(d.get(TEXT_COL))
            lab = d.get("label")
            if len(t.split()) < 3 or lab is None:
                continue
            texts.append(t)
            y.append(int(lab))
    return texts, np.array(y)


def training_hashes():
    import csv
    seen = set()
    for p in SRC:
        if not os.path.exists(p):
            print("  MISSING %s" % p)
            continue
        with io.open(p, encoding="utf-8", errors="replace", newline="") as f:
            for r in csv.DictReader(f):
                t = norm_text(r.get("text"))
                if len(t) >= 3:
                    seen.add(h(t))
    return seen


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

    texts, y = load_dreaddit()
    print("%s usable rows %d  positive=%d (%.1f%%)"
          % (WHICH, len(y), int(y.sum()), y.mean() * 100))

    print("\nchecking overlap with the training corpus...")
    tr = training_hashes()
    dup = sum(1 for t in texts if h(t) in tr)
    print("  training texts %d | eval texts %d | exact overlap %d (%.2f%%)"
          % (len(tr), len(texts), dup, 100.0 * dup / max(len(texts), 1)))
    if dup > 0.01 * len(texts):
        print("  ABORT: more than 1% overlap -- this would measure "
              "memorisation, not transfer.")
        return

    raw = json.load(io.open(os.path.join(
        HERE, "distress_text_v1_vocab.json"), encoding="utf-8"))
    # The file is a WRAPPER: {"vocab": {...}, ...}, not the mapping itself.
    # Passing the outer dict makes every lookup miss, which reads as 100%
    # OOV and a dead-constant 0.5000 AUC -- right shape, wrong answer, no
    # exception. The OOV print below is what caught it; keep it.
    vocab = raw["vocab"] if isinstance(raw, dict) and "vocab" in raw else raw
    assert isinstance(vocab, dict) and len(vocab) > 1000,         "vocab did not resolve to a word->id mapping (%d entries)" % len(vocab)
    X = np.zeros((len(texts), MAXLEN), np.int32)
    oov = tot = 0
    for i, t in enumerate(texts):
        ids = [vocab.get(w, 1) for w in t.split()[:MAXLEN]]
        X[i, :len(ids)] = ids
        oov += sum(1 for v in ids if v == 1)
        tot += len(ids)
    print("  OOV token rate against the model's vocab: %.1f%%"
          % (100.0 * oov / max(tot, 1)))

    it = tf.lite.Interpreter(model_path=os.path.join(
        HERE, "distress_text_v1_float16.tflite"))
    it.allocate_tensors()
    inp, out = it.get_input_details()[0], it.get_output_details()[0]
    it.resize_tensor_input(inp["index"], [1, MAXLEN])
    it.allocate_tensors()
    p = np.zeros(len(X), np.float64)
    for i in range(len(X)):
        it.set_tensor(inp["index"], X[i:i + 1].astype(inp["dtype"]))
        it.invoke()
        p[i] = float(it.get_tensor(out["index"]).ravel()[0])
        if (i + 1) % 1000 == 0:
            print("  scored %d/%d" % (i + 1, len(X)), flush=True)

    auc = float(roc_auc_score(y, p))
    lo, hi = boot(y, p)
    ln = np.array([len(t.split()) for t in texts], np.float64)
    base = float(roc_auc_score(y, ln))
    base = max(base, 1.0 - base)

    print("\n" + "=" * 68)
    print("  distress_text_v1 on %s : %.4f  CI [%.4f, %.4f]"
          % (WHICH, auc, lo, hi))
    print("  length-only baseline         : %.4f" % base)
    print("  in-corpus (its own test split): 0.9628")

    if auc >= 0.80:
        v = "TRANSFERS - 0.9628 was not corpus-specific"
    elif auc >= 0.65:
        v = ("PARTIAL - real signal, but 0.9628 must never be quoted alone; "
             "this is the number that describes it on unseen text")
    else:
        v = ("DOES NOT TRANSFER - a corpus artefact; the shelving decision "
             "becomes permanent rather than pending")
    print("  -> %s" % v)
    if auc <= base + 0.05:
        print("  AND it fails to clear the length baseline on this set, "
              "which is the stronger finding")

    json.dump({"auc": round(auc, 4), "ci95": [round(lo, 4), round(hi, 4)],
               "length_baseline": round(base, 4), "in_corpus": 0.9628,
               "n": int(len(y)), "pos": int(y.sum()),
               "exact_overlap_with_training": int(dup),
               "oov_rate": round(oov / max(tot, 1), 4), "verdict": v,
               "construct_caveat": "clinical status labels vs stress labels "
                                   "-- overlapping, not identical"},
              open(os.path.join(HERE, "crosscorpus_%s_report.json" % WHICH),
                   "w"), indent=2)
    print("report written")


if __name__ == "__main__":
    main()
