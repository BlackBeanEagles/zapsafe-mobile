"""
Day 260D -- real-data retest of m2_motion_b / m2_motion_adversarial, the one
model pair left unresolved across DAY260/260B/260C (Day 259 flagged them
"exactly constant", Day 260B confirmed single-input + confirmed they are
plain float32/unquantised -- NOT int8, which rules out the quantisation-
collapse story used for the rest of the "exactly constant" family -- but
never actually re-ran them against real data).

Real training script: kaggle_notebooks/day107_hardmine_int4_push/day107_hardmine_m2.py
(confirmed the source of both staged files -- see writeup for the byte-identical
proof and the report.json showing arch="b" was the run that produced both
"m2_motion_b.tflite" and, via day108's build_tflite_bundle.py copying the
same fixed-name output under two filenames, "m2_motion_adversarial.tflite").

This script reuses the training script's OWN normalize()/sliding_windows()/
load_pamap2()/load_uci_har()/load_motionsense() functions directly (imported,
not re-derived) against real local datasets, with cache_roots() monkeypatched
to point at this machine's real dataset paths instead of the Kaggle/Colab
paths the script defaults to. No synthetic data is used for any of the real-
data tests below (synth_deliberate_shake() -- the one synthetic component of
the real training recipe -- is deliberately NOT used here, since the task is
to test on real data).

Requires: tensorflow, pandas, numpy.
"""
import importlib.util
import pathlib
import sys

import numpy as np
import pandas as pd
import tensorflow as tf

np.random.seed(42)

# Performance note (not a behavior change): PAMAP2's .dat files are
# whitespace-separated with a CONSTANT single-space delimiter (verified
# directly -- pd.read_csv(sep=" ", engine="c") on subject101.dat produces
# the identical (376417, 54) shape as sep=r"\s+", engine="python"). The
# training script's sep=r"\s+" forces pandas onto the slow python-engine
# regex path (~14 files x 1.6 GB total took >10 min and counting on this
# machine); sep=" ", engine="c" reads the same real files, same values,
# in ~1.6s/file. This patches pandas.read_csv process-wide, for this
# throwaway triage script only, to swap that one kwarg combination for an
# equivalent-but-faster one -- it does not change what data is read.
_real_read_csv = pd.read_csv


def _fast_read_csv(*args, **kwargs):
    if kwargs.get("sep") == r"\s+":
        kwargs["sep"] = " "
        kwargs["engine"] = "c"
    return _real_read_csv(*args, **kwargs)


pd.read_csv = _fast_read_csv

ROOT = pathlib.Path(r"C:\Users\hridy\Desktop\zapsafe")
TRAIN_SCRIPT = ROOT / "letsstartbuilding" / "kaggle_notebooks" / "day107_hardmine_int4_push" / "day107_hardmine_m2.py"
STAGE = pathlib.Path(
    r"C:\Users\hridy\Desktop\zapsafe\letsstartbuilding\kaggle_notebooks\day108_int4_m9_push"
    r"\day108_kaggle_output\saved\int4_m9\day108-int4-m9-kaggle-20260703-v5-production\tflite_staging"
)
UCIHAR_ROOT = ROOT / "ml_datasets" / "motion" / "DS11_UCI-HAR" / "UCI HAR Dataset"
PAMAP2_ROOT = ROOT / "ml_datasets" / "motion" / "DS14_PAMAP2"
MOTIONSENSE_ROOT = ROOT / "ml_datasets" / "motion" / "DS12_MotionSense"


def _import_from_path(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


def run_tflite_single_input(model_path, X):
    interp = tf.lite.Interpreter(model_path=str(model_path))
    interp.allocate_tensors()
    in_det = interp.get_input_details()[0]
    out_det = interp.get_output_details()[0]
    in_scale, in_zp = in_det["quantization"]
    out_scale, out_zp = out_det["quantization"]
    scores = []
    for x in X:
        xb = x[None, ...]
        if in_det["dtype"] in (np.int8, np.uint8):
            xb_q = (xb / in_scale + in_zp).round().astype(in_det["dtype"])
        else:
            xb_q = xb.astype(in_det["dtype"])
        interp.set_tensor(in_det["index"], xb_q)
        interp.invoke()
        out = interp.get_tensor(out_det["index"])
        if out_det["dtype"] in (np.int8, np.uint8):
            out = (out.astype(np.float32) - out_zp) * out_scale
        scores.append(float(out.ravel()[0]))
    return np.array(scores, dtype=np.float64)


def summarize(name, scores, labels=None):
    std = float(np.std(scores))
    print(f"\n--- {name} ---")
    print(f"n={len(scores)}  std={std:.6g}  min={scores.min():.6g}  max={scores.max():.6g}  mean={scores.mean():.6g}")
    if labels is not None:
        labels = np.array(labels)
        pos, neg = scores[labels == 1], scores[labels == 0]
        if len(pos) and len(neg):
            print(f"pos median={np.median(pos):.6g} (n={len(pos)})  neg median={np.median(neg):.6g} (n={len(neg)})")
            try:
                from sklearn.metrics import roc_auc_score
                print(f"AUC={roc_auc_score(labels, scores):.4f}")
            except Exception as e:
                print("AUC calc failed:", e)
    return std


def load_uci_har_windows(split, n=None, seed=42):
    sig_dir = UCIHAR_ROOT / split / "Inertial Signals"
    chans = ["body_acc_x", "body_acc_y", "body_acc_z", "body_gyro_x", "body_gyro_y", "body_gyro_z"]
    arrs = [np.loadtxt(sig_dir / f"{c}_{split}.txt", dtype=np.float32) for c in chans]
    stacked = np.stack(arrs, axis=-1)
    if n is not None:
        rng = np.random.RandomState(seed)
        stacked = stacked[rng.choice(stacked.shape[0], size=min(n, stacked.shape[0]), replace=False)]
    return stacked


# ---------------------------------------------------------------------------
# Step 0: import the REAL training script and point its cache_roots() at the
# real local dataset paths (it defaults to Kaggle/Colab paths that don't
# exist on this machine). This reuses normalize()/sliding_windows()/
# load_pamap2()/load_uci_har() verbatim -- not re-derived by guess.
# ---------------------------------------------------------------------------
mod = _import_from_path("day107_hardmine_m2", TRAIN_SCRIPT)

_REAL_CACHE = {
    "pamap2": [PAMAP2_ROOT],
    "uci_har": [UCIHAR_ROOT.parent],  # cache_roots does root.rglob("Inertial Signals")
    "motionsense": [MOTIONSENSE_ROOT],
}


def _patched_cache_roots(name):
    return [p for p in _REAL_CACHE.get(name, []) if p.is_dir()]


mod.cache_roots = _patched_cache_roots


def test_a_real_uci_har_as_trained():
    """
    Test A -- reproduce Day 259's own setup as closely as possible: real
    UCI-HAR test-split windows, run through the training script's OWN
    normalize() (clip to +-8g, /8), fed into the staged model exactly as
    the model expects. UCI-HAR is a REAL negative-only source for this
    model per its own m2_dataset_usage.json (uci_har: pos=0, neg=4000) --
    there is no real "positive" class from UCI-HAR for this model, so this
    test only checks: is the score constant across real, varied negative
    motion (walking/sitting/standing/laying/upstairs/downstairs)?
    """
    print("\n" + "=" * 70 + "\nTEST A: m2_motion_b on real UCI-HAR windows "
          "(training script's own normalize())\n" + "=" * 70)
    X_raw = load_uci_har_windows("test", n=150, seed=42)
    X = np.stack([mod.normalize(w) for w in X_raw])
    print(f"real UCI-HAR windows: {len(X)}  (raw per-window |acc| range: "
          f"min={np.abs(X_raw[..., :3]).min():.4f}g max={np.abs(X_raw[..., :3]).max():.4f}g -- "
          f"this is what normalize() divides by G_RANGE={mod.G_RANGE})")
    scores = run_tflite_single_input(STAGE / "m2_motion_b.tflite", X)
    summarize("m2_motion_b.tflite on real UCI-HAR (normalized per training)", scores)
    return scores


def test_a2_real_uci_har_raw_unnormalized():
    """
    Hypothesis: G_RANGE=8 normalization shrinks already-small UCI-HAR
    body_acc units (gravity already removed, typically well under 1g) down
    toward zero, saturating a downstream activation into a constant regime.
    Same real windows as Test A, but WITHOUT the clip/8 normalize() step
    (raw units fed directly) -- to see if scale alone changes the output
    distribution.
    """
    print("\n" + "=" * 70 + "\nTEST A2: m2_motion_b on real UCI-HAR windows, "
          "RAW units (no /G_RANGE normalize -- hypothesis check)\n" + "=" * 70)
    X_raw = load_uci_har_windows("test", n=150, seed=42)
    scores = run_tflite_single_input(STAGE / "m2_motion_b.tflite", X_raw.astype(np.float32))
    summarize("m2_motion_b.tflite on real UCI-HAR RAW (un-normalized)", scores)
    return scores


def test_b_real_pamap2_bug_for_bug():
    """
    Test B -- real PAMAP2 data run through the training script's OWN
    load_pamap2(), bug-for-bug: this uses FALL_IDS={12,13} (PAMAP2's
    official activity dictionary: 12=ascending stairs, 13=descending
    stairs -- NOT falls; PAMAP2 has no fall activity at all) as the
    "positive" class, and columns df.iloc[:,20:26] as the 6-channel IMU
    tensor -- which is [chest_temperature, chest_acc16_x/y/z,
    chest_acc6_x/y] per PAMAP2's real column layout, NOT [acc_x,y,z,
    gyro_x,y,z] the way UCI-HAR/model input semantics assume. This is the
    model's REAL positive class as actually trained -- reproduced exactly,
    not corrected.
    """
    print("\n" + "=" * 70 + "\nTEST B: m2_motion_b on real PAMAP2 data, "
          "bug-for-bug column slice exactly as day107_hardmine_m2.py trains it\n" + "=" * 70)
    pos, neg = mod.load_pamap2()
    print(f"real PAMAP2 windows via load_pamap2(): pos(act12/13 'stairs', trained as positive)={len(pos)} "
          f"neg(act in {{1,2,3,4,5,6,7,9,16,17}})={len(neg)}")
    n = min(len(pos), len(neg), 80)
    rng = np.random.RandomState(3)
    pos_s = [pos[i] for i in rng.choice(len(pos), n, replace=False)]
    neg_s = [neg[i] for i in rng.choice(len(neg), n, replace=False)]
    X = np.array(pos_s + neg_s, dtype=np.float32)
    y = [1] * n + [0] * n
    scores = run_tflite_single_input(STAGE / "m2_motion_b.tflite", X)
    summarize("m2_motion_b.tflite on real PAMAP2 (bug-for-bug, as trained)", scores, y)
    return scores, y, pos, neg


def _chest_temp_col_stats():
    """Directly verify PAMAP2 chest-temperature column (raw column 20) values."""
    print("\n" + "=" * 70 + "\nDirect check: PAMAP2 raw column 20 (chest temperature) "
          "value range across real files\n" + "=" * 70)
    vals = []
    files = sorted((PAMAP2_ROOT / "PAMAP2_Dataset" / "Protocol").glob("*.dat"))[:3]
    for f in files:
        df = pd.read_csv(f, sep=r"\s+", header=None, na_values="NaN", engine="python", nrows=20000)
        col20 = df.iloc[:, 20].dropna()
        vals.append(col20)
        print(f"  {f.name}: col20 min={col20.min():.3f} max={col20.max():.3f} mean={col20.mean():.3f}")
    all_vals = pd.concat(vals)
    print(f"combined: min={all_vals.min():.3f} max={all_vals.max():.3f} -- "
          f"G_RANGE=8.0, so clip(temp,-8,8)/8 = {np.clip(all_vals, -8, 8).unique()[:3]/8} "
          f"for EVERY sample regardless of real motion")


def test_c_corrected_columns():
    """
    Test C -- hypothesis: the PAMAP2 loader's column slice (20:26) is wrong
    -- it grabs [temp, acc16_x,y,z, acc6_x,y], not [acc_x,y,z,gyro_x,y,z].
    Rebuild the SAME real PAMAP2 windows/activity-ID split using the
    CORRECT chest acc6 (3-axis, +-6g range, matches the smaller of PAMAP2's
    two accelerometer ranges) + chest gyro (3-axis) columns -- df.iloc[:,
    24:30] -- instead of the buggy 20:26 slice, and see whether real
    variance/separation appears once the temperature channel and the
    missing-gyro problem are removed. This is a hypothesis test on the
    model's REAL weights (not a retrain) -- it answers "would correct
    preprocessing have produced a usable signal from this checkpoint", not
    "does a fixed pipeline exist to ship today".
    """
    print("\n" + "=" * 70 + "\nTEST C: m2_motion_b on real PAMAP2 data, CORRECTED "
          "columns (chest acc6[x,y,z]+gyro[x,y,z] = cols 24:30, hypothesis check)\n" + "=" * 70)
    FALL_IDS = {12, 13}
    NORM_IDS = {1, 2, 3, 4, 5, 6, 7, 9, 16, 17}
    pos, neg = [], []
    for root in [PAMAP2_ROOT]:
        for dat in root.rglob("*.dat"):
            try:
                df = pd.read_csv(dat, sep=r"\s+", header=None, na_values="NaN", engine="python", on_bad_lines="skip")
                if df.shape[1] < 30:
                    continue
                acts = df.iloc[:, 1].fillna(0).astype(int).values
                imu = df.iloc[:, 24:30].ffill().fillna(0.0).values.astype(np.float32)[::2]  # corrected slice
                acts2 = acts[::2]
                for act_id in set(acts2):
                    idx = np.where(acts2 == act_id)[0]
                    if len(idx) < mod.IMU_LEN:
                        continue
                    seg = imu[idx[0]: idx[-1] + 1]
                    for w in mod.sliding_windows(seg):
                        if act_id in FALL_IDS:
                            pos.append(w)
                        elif act_id in NORM_IDS:
                            neg.append(w)
            except Exception as exc:
                print("skip", dat, exc)
    print(f"real PAMAP2 windows with CORRECTED chest acc6+gyro slice: pos={len(pos)} neg={len(neg)}")
    n = min(len(pos), len(neg), 80)
    rng = np.random.RandomState(5)
    pos_s = [pos[i] for i in rng.choice(len(pos), n, replace=False)]
    neg_s = [neg[i] for i in rng.choice(len(neg), n, replace=False)]
    X = np.array(pos_s + neg_s, dtype=np.float32)
    y = [1] * n + [0] * n
    scores = run_tflite_single_input(STAGE / "m2_motion_b.tflite", X)
    summarize("m2_motion_b.tflite on real PAMAP2, CORRECTED columns (hypothesis check, same weights)", scores, y)
    return scores, y


def test_d_temp_channel_ablation(pos, neg):
    """
    Test D -- direct ablation confirming the temperature-channel-clip
    mechanism found in Test B / the direct column-20 check: take the SAME
    real, bug-for-bug PAMAP2 windows from Test B and forcibly replace
    channel 0 (the clipped, effectively-constant temperature channel) with
    real random noise in [-1, 1] (a stand-in "not always 1.0" signal) to
    see whether the model's output distribution changes -- isolating
    whether that one constant channel is driving the collapse (if there is
    one), independent of the other five (also-mismatched) channels.
    """
    print("\n" + "=" * 70 + "\nTEST D: ablation -- same real bug-for-bug PAMAP2 windows, "
          "channel 0 (temp, normally clipped to a constant) replaced with noise\n" + "=" * 70)
    rng = np.random.RandomState(7)
    n = min(len(pos), len(neg), 80)
    pos_s = [pos[i] for i in rng.choice(len(pos), n, replace=False)]
    neg_s = [neg[i] for i in rng.choice(len(neg), n, replace=False)]
    X = np.array(pos_s + neg_s, dtype=np.float32).copy()
    print(f"channel 0 (temp) real value before ablation: unique values = {np.unique(X[:, :, 0])[:5]} "
          f"(should all be the clipped constant, 1.0, if the hypothesis is right)")
    X[:, :, 0] = rng.uniform(-1, 1, size=X[:, :, 0].shape).astype(np.float32)
    y = [1] * n + [0] * n
    scores = run_tflite_single_input(STAGE / "m2_motion_b.tflite", X)
    summarize("m2_motion_b.tflite, real PAMAP2 windows w/ channel0 noise-ablated", scores, y)
    return scores


def confirm_byte_identical():
    a = (STAGE / "m2_motion_b.tflite").read_bytes()
    b = (STAGE / "m2_motion_adversarial.tflite").read_bytes()
    print(f"\nm2_motion_b.tflite size={len(a)}  m2_motion_adversarial.tflite size={len(b)}  "
          f"byte-identical={a == b}")


if __name__ == "__main__":
    confirm_byte_identical()
    _chest_temp_col_stats()
    test_a_real_uci_har_as_trained()
    test_a2_real_uci_har_raw_unnormalized()
    scores_b, y_b, pos, neg = test_b_real_pamap2_bug_for_bug()
    test_c_corrected_columns()
    test_d_temp_channel_ablation(pos, neg)
