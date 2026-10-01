"""Day 368D - thresholds for scream_classifier_v6, matched to v5's operating points.

A new model's scores sit on its own scale, so v5's numbers cannot be reused.
Each threshold is re-derived to reproduce the BEHAVIOUR v5's was chosen for,
not its value.

1. ScreamDetectorV2.kDefaultThreshold (v5: 0.20)
   Chosen on Day 346 for recall on FSD50K eval (287 real screams):
   v5 at 0.20 -> recall 0.843, precision 0.282. A missed scream is the
   expensive error, so v6's threshold is the HIGHEST t whose recall is still
   >= v5's recall at 0.20. Precision at that point is reported, not chosen.

2. ViolenceBurstCoordinator.kTriggerThreshold (v5: 0.90)
   Chosen on Day 364D by how often it fires on ordinary media audio
   (camera bursts cost battery): v5 at 0.90 fired on ~3.2% of ambient
   windows. v6's threshold is the one firing on the SAME fraction of ambient
   windows. Its rate on violent windows is reported.

   Measured on all labelled XD-Violence test videos, cut into 3 s windows at
   a 1.5 s hop, and both models score the SAME windows. That keeps the
   comparison exact without depending on Day 364D's 60/60 subset.
"""
import glob
import json
import os
import sys
from concurrent.futures import ProcessPoolExecutor

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import scream_nonspeech7k as ns          # noqa: E402  mel_from (verbatim v5), SV5, ASSETS

# v5 left assets/ when v6 replaced it (Day 368D); this is the byte-identical
# copy uploaded with the Kaggle dataset.
V5 = os.environ.get("SCREAM_V5", r"D:\zapsafe\kaggle_upload\scream-armd-ns7k\scream_classifier_v5.tflite")
V6 = os.path.join(HERE, "scream_classifier_v6_candidate.tflite")
XD = r"D:\zapsafe\xdviolence\videos"
XD_CACHE = r"D:\zapsafe\fusion\xd_windows_mel.npz"
OUT = os.path.join(HERE, "scream_v6_recalibration.json")
HOP_S = 1.5


def label(name):
    """Same positive-first rule as tools/day353_ml/fusion/xd_extract.py."""
    import re
    tags = re.findall(r"label[_-]([A-Za-z0-9\-]+)", name)
    if not tags:
        return None
    parts = [p for p in re.split(r"[-_]", tags[-1].upper()) if p]
    if any(re.fullmatch(r"B\d+|G\d*", p) for p in parts):
        return 1
    if any(re.fullmatch(r"A\d*", p) for p in parts):
        return 0
    return None


def windows_of(path):
    import subprocess
    import tempfile
    import imageio_ffmpeg
    import soundfile as sf
    with tempfile.TemporaryDirectory() as td:
        wav = os.path.join(td, "a.wav")
        r = subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), "-nostdin", "-loglevel", "error",
                            "-i", path, "-ac", "1", "-ar", str(ns.SR), "-vn", "-y", wav],
                           capture_output=True)
        if r.returncode != 0 or not os.path.exists(wav):
            return path, []
        y, sr = sf.read(wav, dtype="float32")
    hop, need = int(HOP_S * ns.SR), ns.NEED
    out = []
    for st in range(0, max(1, len(y) - need + 1), hop):
        m = ns.mel_from(y[st:st + need], ns.SR)
        if m is not None:
            out.append(m)
    return path, out


def xd_windows():
    if os.path.exists(XD_CACHE):
        d = np.load(XD_CACHE)
        return d["X"], d["y"], d["vid"]
    vids = [(p, label(os.path.basename(p))) for p in sorted(glob.glob(os.path.join(XD, "*.mp4")))]
    vids = [(p, l) for p, l in vids if l is not None]
    lab = dict(vids)
    print(f"XD-Violence videos labelled: {len(vids)} "
          f"(violent {sum(l for _, l in vids)})", flush=True)
    X, y, vid = [], [], []
    with ProcessPoolExecutor(max_workers=4) as ex:
        for k, (p, ws) in enumerate(ex.map(windows_of, [p for p, _ in vids], chunksize=4)):
            X.extend(ws)
            y.extend([lab[p]] * len(ws))
            vid.extend([k] * len(ws))
            if (k + 1) % 50 == 0:
                print(f"  {k+1}/{len(vids)} videos, {len(X)} windows", flush=True)
    X, y, vid = np.stack(X), np.array(y, np.int8), np.array(vid, np.int32)
    np.savez(XD_CACHE, X=X, y=y, vid=vid)
    return X, y, vid


def scores(path, X):
    """One window at a time, through the real tflite path.

    Batched resize_tensor_input does not work here: v5 has a fixed batch of
    1 and returned a single output for a whole batch (the length assert
    caught it). One-at-a-time is also how the app runs the model.
    """
    p = ns.tflite_scores(path, X)
    assert len(p) == len(X)
    return p


def pr_at(p, y, t):
    pred = p >= t
    tp = float((pred & (y == 1)).sum())
    return tp / max(1, (y == 1).sum()), tp / max(1, pred.sum())


def main():
    res = {}
    # ---- 1. detector threshold on FSD50K eval ----
    d = np.load(os.path.join(ns.SV5, "features_v5.npz"), allow_pickle=True)
    Xf, yf = d["Xf"], d["yf"].astype(int)
    p5, p6 = scores(V5, Xf), scores(V6, Xf)
    r5, pr5 = pr_at(p5, yf, 0.20)
    # Exact, not a grid: v6 is far more decisive than v5 (median score 0.002
    # vs 0.186), and the threshold that keeps v5's recall sits below 0.01,
    # under any coarse grid. Take the score of the positive at the rank that
    # still leaves recall >= r5.
    pos = np.sort(p6[yf == 1])
    k = int(np.floor((1.0 - r5) * len(pos)))
    t6 = float(pos[k])
    r6, pr6 = pr_at(p6, yf, t6)
    assert r6 >= r5, (r6, r5)
    table = {f"{t:g}": {"v5": [round(v, 3) for v in pr_at(p5, yf, t)],
                        "v6": [round(v, 3) for v in pr_at(p6, yf, t)]}
             for t in (0.001, 0.003, 0.01, 0.03, 0.10, 0.20, 0.30, 0.50, round(t6, 5))}
    res["detector"] = {"v5_threshold": 0.20, "v5_recall": round(r5, 3), "v5_precision": round(pr5, 3),
                       "v6_threshold": t6, "v6_recall": round(r6, 3), "v6_precision": round(pr6, 3),
                       "table_recall_precision": table}
    print("detector:", {k: v for k, v in res["detector"].items() if k != "table_recall_precision"},
          flush=True)

    # ---- 2. camera-burst trigger on XD-Violence media audio ----
    Xx, yx, vid = xd_windows()
    q5, q6 = scores(V5, Xx), scores(V6, Xx)
    amb, vio = yx == 0, yx == 1
    a5 = float((q5[amb] >= 0.90).mean())
    v5r = float((q5[vio] >= 0.90).mean())
    # v6 threshold firing on the same ambient fraction: the (1 - a5) quantile.
    b6 = float(np.quantile(q6[amb], 1.0 - a5))
    a6, v6r = float((q6[amb] >= b6).mean()), float((q6[vio] >= b6).mean())
    res["burst"] = {"windows": int(len(yx)), "ambient_windows": int(amb.sum()),
                    "violent_windows": int(vio.sum()), "videos": int(len(set(vid.tolist()))),
                    "v5_threshold": 0.90, "v5_ambient_rate": round(a5, 4),
                    "v5_violent_rate": round(v5r, 4),
                    "v5_ratio": round(v5r / a5, 2) if a5 else None,
                    "v6_threshold": round(b6, 4), "v6_ambient_rate": round(a6, 4),
                    "v6_violent_rate": round(v6r, 4),
                    "v6_ratio": round(v6r / a6, 2) if a6 else None}
    print("burst:", res["burst"], flush=True)
    json.dump(res, open(OUT, "w"), indent=2)
    print("->", OUT)


if __name__ == "__main__":
    main()
