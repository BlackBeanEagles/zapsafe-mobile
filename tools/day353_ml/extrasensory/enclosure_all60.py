"""Day 362 - was ExtraSensory really too thin, or was the BUILD too thin?

WHAT DAY 360 CONCLUDED
======================
k_confinement's honest replacement (phone-concealment) was refused because:

    participants in the built dataset        16
    participants with BOTH classes            5
    LOPO median 0.7741  worst fold 0.5723  identity-alone 0.6087

and the reading was "the approach is sound and the dataset is too thin".
That conclusion rested on 5 participants. ExtraSensory has **60**.

WHY ONLY 16 GOT IN
==================
`build_enclosure.py` needs per-window RAW accelerometer and gyro files from
`ExtraSensory.raw_measurements.*.zip`. Those archives are no longer on this
disk, and when they were, the raw coverage is what capped the build at 16
participants -- not the labels. So "too thin" was a statement about the raw
measurement archives, not about ExtraSensory.

The **per-UUID feature archive covers all 60 users** and is still here
(225 MB). It carries precomputed statistics over the same sensors:

    raw_acc            26 features
    proc_gyro          26
    lf_measurements     8   (includes light)
    watch_acceleration 46   EXCLUDED - needs a watch, cut from project scope
    location           11   EXCLUDED - privacy, and not what this detects
    audio_naive        26   EXCLUDED - separate pipeline
    raw_magnet         31   EXCLUDED - not in the phone sensor set used

Only what a phone can compute from `sensors_plus` is used: accelerometer,
gyroscope and light. 53-ish columns.

WHAT A PASS HERE WOULD AND WOULD NOT MEAN
=========================================
This is a DIFFERENT input representation from the shipped slot, which takes
raw IMU [128,6] + light [32,1]. So a pass does **not** mean a drop-in asset.
It means the concept is proven on 60 participants instead of 5, and building
the Dart-side feature extractor becomes worth the work. Settling the science
first is deliberate: the extractor is the expensive half.

SHIP RULE, unchanged from Day 357/360 so the numbers stay comparable:
    LOPO median >= 0.75, worst fold >= 0.65, AND identity-alone <= 0.60
Reported as a distribution over every both-class participant, not a mean.
The identity control is the one that killed this before and is re-run here.
"""
from __future__ import annotations

import csv
import gzip
import io
import json
import math
import os
import zipfile

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
FEAT_ZIP = os.path.join(HERE, "ExtraSensory.per_uuid_features_labels.zip")
POS = ("label:PHONE_IN_POCKET", "label:PHONE_IN_BAG")
# Only sensors the phone actually has in this app's pipeline.
KEEP_PREFIX = ("raw_acc:", "proc_gyro:", "lf_measurements:")
SEED = 42


def load():
    cache = os.path.join(HERE, "enclosure_all60.npz")
    if os.path.exists(cache):
        d = np.load(cache, allow_pickle=True)
        return d["X"], d["y"].astype(int), d["uuid"]

    z = zipfile.ZipFile(FEAT_ZIP)
    names = sorted(z.namelist())
    cols = None
    X, y, uu = [], [], []
    for n in names:
        uuid = os.path.basename(n).split(".")[0]
        raw = gzip.decompress(z.read(n)).decode("utf-8", "replace")
        rdr = csv.DictReader(io.StringIO(raw))
        if cols is None:
            cols = [c for c in rdr.fieldnames
                    if any(c.startswith(p) for p in KEEP_PREFIX)]
            print("using %d feature columns" % len(cols))
        for r in rdr:
            lab = 1 if any(r.get(k, "") == "1" for k in POS) else 0
            if lab == 0 and not all(r.get(k, "") == "0" for k in POS):
                # a missing annotation is not a negative
                continue
            # ExtraSensory features are SPARSELY populated -- a sensor that
            # was off for that minute leaves its whole block blank. A first
            # version required every column to be present and kept ZERO of
            # ~300,000 rows. NaNs are preserved instead: HistGradientBoosting
            # handles them natively, and the linear control imputes with the
            # TRAINING fold's median so no test-fold information leaks.
            v = []
            for c in cols:
                try:
                    f = float(r.get(c, ""))
                except (TypeError, ValueError):
                    f = math.nan
                v.append(f)
            # A row with no accelerometer at all carries nothing this model
            # is about, so that one block is required.
            acc = [v[i] for i, c in enumerate(cols)
                   if c.startswith("raw_acc:")]
            if not acc or all(math.isnan(f) for f in acc):
                continue
            X.append(v)
            y.append(lab)
            uu.append(uuid)
    X = np.asarray(X, np.float32)
    y = np.asarray(y, np.int64)
    uu = np.asarray(uu)
    np.savez_compressed(cache, X=X, y=y, uuid=uu, cols=np.asarray(cols))
    print("built %s pos=%d uuids=%d" % (X.shape, y.sum(), len(set(uu))))
    return X, y, uu


def main():
    from sklearn.linear_model import LogisticRegression
    from sklearn.ensemble import HistGradientBoostingClassifier
    from sklearn.metrics import roc_auc_score

    X, y, uu = load()
    allu = np.unique(uu)
    print("\nrows %d  positives %d (%.1f%%)  participants %d"
          % (len(y), y.sum(), 100 * y.mean(), len(allu)))

    both = [u for u in allu if 0 < float(y[uu == u].mean()) < 1]
    print("participants with BOTH classes: %d of %d  (was 5 of 16)"
          % (len(both), len(allu)))
    m = np.array([u in set(both) for u in uu])
    X, y, uu = X[m], y[m], uu[m]
    print("restricted: %d rows, %d positives (%.1f%%)"
          % (len(y), y.sum(), 100 * y.mean()))

    # THE CONTROL that killed this before: can identity alone predict it?
    rate = np.array([y[uu == u].mean() for u in uu])
    id_auc = float(roc_auc_score(y, rate))
    print("\nidentity-alone AUC: %.4f   (16-participant build: 0.6087, "
          "all-16 unrestricted: 0.8804)" % id_auc)
    if id_auc > 0.60:
        print("  -> identity still predicts the label; a model can score by "
              "recognising the person, and the folds below mean less")

    rows = []
    for held in both:
        te = uu == held
        tr = ~te
        if len(set(y[te].tolist())) < 2:
            continue
        # Statistics come from the TRAINING fold only; using all rows would
        # leak the held-out participant into the standardisation.
        mu = np.nanmean(X[tr], axis=0)
        sd = np.nanstd(X[tr], axis=0) + 1e-8
        mu = np.nan_to_num(mu)
        Ztr, Zte = (X[tr] - mu) / sd, (X[te] - mu) / sd

        # GBT sees the NaNs and routes them itself.
        clf = HistGradientBoostingClassifier(
            max_iter=200, learning_rate=0.1, max_depth=6,
            random_state=SEED)
        clf.fit(Ztr, y[tr])
        auc = float(roc_auc_score(y[te], clf.predict_proba(Zte)[:, 1]))

        # Linear control: if a logistic regression matches the GBT, the
        # extra capacity is not buying anything and the result is simpler
        # than it looks. Imputes with the TRAINING median, post-standardised.
        med = np.nanmedian(Ztr, axis=0)
        med = np.nan_to_num(med)
        Itr = np.where(np.isnan(Ztr), med, Ztr)
        Ite = np.where(np.isnan(Zte), med, Zte)
        lr = LogisticRegression(max_iter=2000, class_weight="balanced")
        lr.fit(Itr, y[tr])
        lin = float(roc_auc_score(y[te], lr.predict_proba(Ite)[:, 1]))

        rows.append({"user": held[:8], "n": int(te.sum()),
                     "pos_rate": round(float(y[te].mean()), 3),
                     "auc": round(auc, 4), "linear": round(lin, 4)})
        print("  %-9s n=%-6d pos=%.2f  GBT %.4f   linear %.4f"
              % (held[:8], int(te.sum()), float(y[te].mean()), auc, lin),
              flush=True)

    a = np.array([r["auc"] for r in rows])
    print("\nfolds %d  median %.4f  mean %.4f  min %.4f  max %.4f"
          % (len(a), np.median(a), a.mean(), a.min(), a.max()))
    print("  below 0.65: %d of %d" % (int((a < 0.65).sum()), len(a)))
    ship = bool(np.median(a) >= 0.75 and a.min() >= 0.65 and id_auc <= 0.60)
    print("  SHIP (median>=0.75, worst>=0.65, identity<=0.60) -> %s" % ship)
    if not ship:
        why = []
        if np.median(a) < 0.75:
            why.append("median %.3f < 0.75" % np.median(a))
        if a.min() < 0.65:
            why.append("worst fold %.3f < 0.65" % a.min())
        if id_auc > 0.60:
            why.append("identity %.3f > 0.60" % id_auc)
        print("  -> NOT SHIPPED: %s" % "; ".join(why))

    json.dump({"participants_total": int(len(allu)),
               "participants_both_classes": len(both),
               "rows": int(len(y)), "positives": int(y.sum()),
               "identity_auc": round(id_auc, 4),
               "folds": rows,
               "median": round(float(np.median(a)), 4),
               "mean": round(float(a.mean()), 4),
               "min": round(float(a.min()), 4),
               "n_below_065": int((a < 0.65).sum()),
               "ships": ship,
               "note": ("feature-vector input, NOT the shipped slot's raw "
                        "IMU [128,6]+light[32,1]; a pass proves the concept "
                        "on 60 participants, not a drop-in asset")},
              open(os.path.join(HERE, "enclosure_all60_report.json"), "w"),
              indent=2)
    print("report written")


if __name__ == "__main__":
    main()
