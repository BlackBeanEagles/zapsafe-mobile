"""Day 357 - build the honest replacement for k_confinement.

WHAT THIS MODEL IS, AND WHAT IT IS NOT
======================================
It detects **the phone being concealed** -- in a pocket or a bag -- from
motion plus ambient light. It does NOT detect a user trapped in a confined
space, which is what the name `k_confinement` claims.

ExtraSensory's only true confined-space label is ELEVATOR, and with the
light channel present it has **71 examples**. That is not a training set.
`PHONE_IN_POCKET` (8,936 with light) and `PHONE_IN_BAG` (3,056) are, so the
model is trained and NAMED for what the data supports. Shipping this under
the old name was explicitly declined; the slot gets renamed.

WHY IT REPLACES A BROKEN ASSET
==============================
`k_confinement_decorrelated.tflite` is measured non-functional: trained on
a temperature-contaminated PAMAP2 slice, with kImuMean[0]=18.83 -- physically
impossible for a carried phone -- and it outputs ~0.019 on real input and
never fires. Anything that works at all is an improvement.

UNITS: the raw accelerometer here is (timestamp, x, y, z) with z ~ 9.8, i.e.
**m/s^2** -- the same units `sensors_plus` delivers on the phone. That is the
exact mismatch that broke the original (UCI-HAR in g, fed m/s^2, 8x out of
distribution). This one matches the pipeline by construction.

LIGHT: `lf_measurements:light` is one value per minute and is LOG-SCALED
(observed range -11.5 to 12.3). The model's light input is [1,32,1] and
Day 260B recorded it as "a broadcast scalar with one obvious
interpretation", so the single value is broadcast across 32 steps, matching
the original design rather than inventing a series that does not exist.

SPLIT: by UUID. The 60 participants are the natural speaker/device unit, and
a random split over minutes would put the same phone, pocket and gait on
both sides.
"""
from __future__ import annotations

import csv
import gzip
import io
import os
import sys
import zipfile

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
FEAT_ZIP = os.path.join(HERE, "ExtraSensory.per_uuid_features_labels.zip")
ACC_ZIP = os.path.join(HERE, "ExtraSensory.raw_measurements.raw_acc.zip")
GYR_ZIP = os.path.join(HERE, "ExtraSensory.raw_measurements.proc_gyro.zip")

WIN = 128            # the model's IMU timesteps
LIGHT_STEPS = 32     # the model's light input length
POS = ("label:PHONE_IN_POCKET", "label:PHONE_IN_BAG")
SEED = 42
MAX_PER_CLASS = 9000


def resample(a, n):
    """Linear-interpolate an (m,3) block to exactly n rows."""
    m = len(a)
    if m == n:
        return a
    src = np.linspace(0.0, 1.0, m)
    dst = np.linspace(0.0, 1.0, n)
    return np.stack([np.interp(dst, src, a[:, i]) for i in range(a.shape[1])],
                    axis=1)


def read_dat(z, name):
    try:
        raw = z.read(name).decode("utf-8", "replace").strip()
    except Exception:
        return None
    if not raw:
        return None
    rows = []
    for line in raw.split("\n"):
        p = line.split()
        if len(p) < 4:
            continue
        try:
            rows.append((float(p[1]), float(p[2]), float(p[3])))
        except ValueError:
            continue
    if len(rows) < 16:
        return None
    return np.asarray(rows, np.float64)


def main():
    import math
    print("reading labels + light ...", flush=True)
    zf = zipfile.ZipFile(FEAT_ZIP)
    rows = []
    for n in zf.namelist():
        uuid = os.path.basename(n).split(".")[0]
        raw = gzip.decompress(zf.read(n)).decode("utf-8", "replace")
        for r in csv.DictReader(io.StringIO(raw)):
            try:
                lv = float(r.get("lf_measurements:light", ""))
            except (TypeError, ValueError):
                continue
            if math.isnan(lv):
                continue
            lab = 1 if any(r.get(k, "") == "1" for k in POS) else 0
            # negatives must be genuinely NOT concealed: require an explicit
            # 0 on both, not merely a missing annotation
            if lab == 0:
                if not all(r.get(k, "") == "0" for k in POS):
                    continue
            ts = r.get("timestamp") or r.get("")
            if not ts:
                continue
            rows.append((uuid, ts.strip(), lv, lab))
    print("  rows with light and a usable label: %d" % len(rows))
    npos = sum(1 for r in rows if r[3] == 1)
    print("  positives %d  negatives %d" % (npos, len(rows) - npos))
    if npos < 500:
        print("  TOO FEW POSITIVES -- stopping rather than training on noise")
        return

    rng = np.random.RandomState(SEED)
    pos = [r for r in rows if r[3] == 1]
    neg = [r for r in rows if r[3] == 0]
    rng.shuffle(pos)
    rng.shuffle(neg)
    keep = pos[:MAX_PER_CLASS] + neg[:min(len(neg), MAX_PER_CLASS)]
    print("  sampled %d (%d pos)" % (len(keep), min(len(pos), MAX_PER_CLASS)))

    za = zipfile.ZipFile(ACC_ZIP)
    zg = zipfile.ZipFile(GYR_ZIP)
    acc_names = set(za.namelist())
    gyr_names = set(zg.namelist())

    X, L, y, u = [], [], [], []
    missing = short = 0
    for i, (uuid, ts, lv, lab) in enumerate(keep):
        an = "raw_acc/%s/%s.m_raw_acc.dat" % (uuid, ts)
        gn = "proc_gyro/%s/%s.m_proc_gyro.dat" % (uuid, ts)
        if an not in acc_names or gn not in gyr_names:
            missing += 1
            continue
        a = read_dat(za, an)
        g = read_dat(zg, gn)
        if a is None or g is None:
            short += 1
            continue
        imu = np.concatenate([resample(a, WIN), resample(g, WIN)], axis=1)
        X.append(imu.astype(np.float32))
        L.append(np.full((LIGHT_STEPS, 1), lv, np.float32))
        y.append(lab)
        u.append(uuid)
        if (i + 1) % 2000 == 0:
            print("  %d/%d kept=%d" % (i + 1, len(keep), len(y)), flush=True)

    X = np.stack(X)
    L = np.stack(L)
    y = np.asarray(y, np.int64)
    u = np.asarray(u)
    print("\nbuilt IMU %s  light %s  pos=%d  uuids=%d"
          % (X.shape, L.shape, int(y.sum()), len(set(u.tolist()))))
    print("  missing raw files %d | unreadable/short %d" % (missing, short))
    print("  acc z mean %.3f (expect ~9.8 for m/s^2)"
          % float(X[:, :, 2].mean()))
    np.savez_compressed(os.path.join(HERE, "enclosure_dataset.npz"),
                        X=X, L=L, y=y, uuid=u)
    print("written enclosure_dataset.npz")


if __name__ == "__main__":
    main()
