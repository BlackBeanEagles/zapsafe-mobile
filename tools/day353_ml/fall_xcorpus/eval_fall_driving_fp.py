"""Does motion_fall_v2 fire on hard driving manoeuvres? (Day 368)

Day 365 measured its false-positive rate on everyday activities (MobiFall
ADL: 0.07% of windows). It never saw a moving car. Harsh braking produces
large decelerations that a fall detector could mistake for an impact, so
this scores every window of real in-car IMU logs.

Data: dinupadevinda/byd-atto-bmi160-imu-driving-events (CC BY 4.0), BMI160
flat in a BYD Atto, ~20 Hz, m/s^2 including gravity (verified: acc_z ~9.97
at rest). 10 sessions: harsh_braking and lane_change.

Preprocessing matches the app exactly: linear resample to 50 Hz, 100-sample
windows, hop 25, per-channel (x - mean) / std from motion_fall_v2_norm.json.

Orientation caveat: the board lay flat, so gravity is on z. A phone in a
trouser pocket carries gravity mostly on y. Both are scored:
  as_logged   x, y, z as recorded
  pocket_like gravity rotated onto y (x, z, y -> x, y, z)
"""
import json
import os

import numpy as np
import pandas as pd
import tensorflow as tf

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
MODEL = os.path.join(ROOT, "assets", "models", "motion_fall_v2.tflite")
NORM = os.path.join(ROOT, "assets", "models", "motion_fall_v2_norm.json")
DATA = os.environ.get(
    "BYD_CSV",
    r"D:\zapsafe\datasets\byd_atto_bmi160\byd-atto-imu-driving-events"
    r"\data\processed\imu_samples_clean.csv")
WIN, HOP, RATE, THRESH = 100, 25, 50.0, 0.5


def main():
    nz = json.load(open(NORM, encoding="utf-8"))
    mu, sd = np.array(nz["mean"]), np.array(nz["std"])
    it = tf.lite.Interpreter(model_path=MODEL)
    it.allocate_tensors()
    i0, o0 = it.get_input_details()[0], it.get_output_details()[0]

    df = pd.read_csv(DATA)
    out = {"source": "byd-atto-bmi160 (CC BY 4.0)", "threshold": THRESH,
           "orientations": {}}
    for orient in ("as_logged", "pocket_like"):
        rows, allw = [], []
        for sess, g in df.groupby("session_id"):
            t = g["t_seconds"].to_numpy()
            xyz = g[["acc_x", "acc_y", "acc_z"]].to_numpy(dtype=float)
            if orient == "pocket_like":
                xyz = xyz[:, [0, 2, 1]]
            tt = np.arange(t[0], t[-1], 1.0 / RATE)
            r = np.stack([np.interp(tt, t, xyz[:, c]) for c in range(3)], 1)
            scores = []
            for st in range(0, len(r) - WIN + 1, HOP):
                w = ((r[st:st + WIN] - mu) / sd).astype(np.float32)
                it.set_tensor(i0["index"], w.reshape(i0["shape"]))
                it.invoke()
                scores.append(float(it.get_tensor(o0["index"]).ravel()[-1]))
            s = np.array(scores)
            allw.extend(scores)
            peak_g = float(np.max(np.linalg.norm(xyz, axis=1)) / 9.81)
            rows.append({"session": sess, "event": g["event_type"].iloc[0],
                         "windows": len(s), "max": float(s.max()),
                         "fired": int((s >= THRESH).sum()),
                         "peak_g": round(peak_g, 2)})
        a = np.array(allw)
        out["orientations"][orient] = {
            "windows": int(len(a)),
            "fired": int((a >= THRESH).sum()),
            "fp_rate": float((a >= THRESH).mean()),
            "max": float(a.max()), "median": float(np.median(a)),
            "sessions": rows,
        }
        print(f"\n{orient}: {len(a)} windows, fired {(a >= THRESH).sum()} "
              f"({(a >= THRESH).mean():.2%}), max {a.max():.3f}, "
              f"median {np.median(a):.4f}")
        for r_ in rows:
            print(f"  {r_['session']:<34} {r_['event']:<14} win={r_['windows']:4} "
                  f"max={r_['max']:.3f} fired={r_['fired']:3} peak={r_['peak_g']}g")
    json.dump(out, open(os.path.join(HERE, "fall_driving_fp.json"), "w"),
              indent=2)


if __name__ == "__main__":
    main()
