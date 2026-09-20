"""Day 343 — extract M8 blink-liveness features from Zalo + the attack-diverse set.

Feature contract is UNCHANGED from Day 292/302: SEQ_LEN=24, FEAT_DIM=12, the
same MediaPipe FaceLandmarker EAR landmark indices. Only the data changes.

WHY A SECOND DATASET
====================
Zalo (1,168 videos, 598 live / 570 spoof) is replay/print-focused. The
`D:\\zapsafe\\spoofing` set adds **84 attack videos** whose types Zalo is
least likely to contain:

    Cutout 15 · Textile-3D 23 · Silicone 11 · Latex 10
    Replay-mobile 10 · Wrapped-3D 10 · Replay-display 5

All 84 are spoof — the set's `Selfies/` and `Replay_display_attacks/Real/`
folders hold JPEGs, not video, so there are no live clips to add. That is a
single-class addition and it is deliberate: a liveness model's real failure
mode is an **attack type it has never seen**, not class imbalance, and the
mild skew it introduces (654 spoof / 598 live) is what class_weight is for.

TWO LOCAL DEVIATIONS FROM THE KAGGLE SCRIPT, BOTH NECESSARY
===========================================================
1. `_ensure_mediapipe_deps()` is NOT called. On Kaggle it pip-installs
   mediapipe at runtime; here that reinstall pulls numpy 2.x and breaks
   TensorFlow 2.17 with `SystemError: initialization of
   _pywrap_checkpoint_reader raised unreported exception` — which happened
   once already while setting this up. The venv is pinned at numpy 1.26.4,
   mediapipe 1.0.1, cv2 5.0.0, all verified working together.
2. The landmarker model goes to a Windows path, not `/tmp`.

Features cache to `feats.npz`, so a killed run resumes instead of redoing
~1,250 videos of MediaPipe.
"""
from __future__ import annotations

import os
import pathlib
import sys
import urllib.request

import numpy as np

SEQ_LEN, FEAT_DIM = 24, 12
MAX_FRAMES = 60

ROOT = pathlib.Path(r"C:\Users\hridy\Desktop\zapsafe")
ZALO = ROOT / "ml_datasets" / "liveness_zalo" / "train" / "train"
SPOOF_EXTRA = pathlib.Path(r"D:\zapsafe\spoofing")
OUT = ROOT / "work" / "m8_combined"
CACHE = OUT / "feats.npz"

_MODEL = str(OUT / "face_landmarker.task")
_URL = ("https://storage.googleapis.com/mediapipe-models/face_landmarker/"
        "face_landmarker/float16/1/face_landmarker.task")

LEFT_EYE_EAR_IDX = (362, 385, 387, 263, 373, 380)
RIGHT_EYE_EAR_IDX = (33, 160, 158, 133, 153, 144)
MOUTH_IDX = (61, 291, 13, 14)
NOSE_TIP_IDX, LEFT_BROW_IDX, RIGHT_BROW_IDX = 1, 105, 334
LEFT_CHEEK_IDX, RIGHT_CHEEK_IDX = 234, 454
FACE_LEFT_IDX, FACE_RIGHT_IDX = 234, 454

_landmarker = None


def _get_landmarker():
    global _landmarker
    if _landmarker is None:
        from mediapipe.tasks import python as mp_python
        from mediapipe.tasks.python import vision as mp_vision
        os.makedirs(OUT, exist_ok=True)
        if not os.path.exists(_MODEL):
            print("  downloading face_landmarker.task ...", flush=True)
            urllib.request.urlretrieve(_URL, _MODEL)
        opts = mp_vision.FaceLandmarkerOptions(
            base_options=mp_python.BaseOptions(model_asset_path=_MODEL),
            output_face_blendshapes=False,
            output_facial_transformation_matrixes=False,
            num_faces=1,
            running_mode=mp_vision.RunningMode.IMAGE,
        )
        _landmarker = mp_vision.FaceLandmarker.create_from_options(opts)
    return _landmarker


def _dist(a, b):
    return float(np.hypot(a.x - b.x, a.y - b.y))


def _ear(lm, idx):
    p1, p2, p3, p4, p5, p6 = (lm[i] for i in idx)
    horiz = _dist(p1, p4)
    if horiz < 1e-6:
        return 0.0
    return float((_dist(p2, p6) + _dist(p3, p5)) / (2.0 * horiz))


def frame_to_features(rgb):
    import mediapipe as mp
    res = _get_landmarker().detect(
        mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb))
    if not res.face_landmarks:
        return None
    lm = res.face_landmarks[0]
    ear_l, ear_r = _ear(lm, LEFT_EYE_EAR_IDX), _ear(lm, RIGHT_EYE_EAR_IDX)
    lc, rc, ul, ll = (lm[i] for i in MOUTH_IDX)
    mouth_w, mouth_h = _dist(lc, rc), _dist(ul, ll)
    return np.array([
        ear_l, ear_r, (ear_l + ear_r) / 2.0,
        float(mouth_h / (mouth_w + 1e-6)),
        float(lm[NOSE_TIP_IDX].y),
        float((lm[LEFT_BROW_IDX].y + lm[RIGHT_BROW_IDX].y) / 2.0),
        float(abs(lm[LEFT_CHEEK_IDX].y - lm[RIGHT_CHEEK_IDX].y)),
        float(rgb.mean()) / 255.0,
        float(lm[LEFT_EYE_EAR_IDX[0]].z), float(lm[RIGHT_EYE_EAR_IDX[0]].z),
        float(abs(lm[FACE_RIGHT_IDX].x - lm[FACE_LEFT_IDX].x)),
        float(abs(ear_l - ear_r)),
    ], dtype=np.float32)


def read_frames(path):
    import cv2
    cap = cv2.VideoCapture(str(path))
    frames = []
    try:
        total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT) or 0)
        step = max(1, total // MAX_FRAMES) if total > MAX_FRAMES else 1
        i = 0
        while True:
            ok, bgr = cap.read()
            if not ok:
                break
            if i % step == 0:
                frames.append(cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB))
            i += 1
            if len(frames) >= MAX_FRAMES:
                break
    finally:
        cap.release()
    return frames


def video_sequence(path):
    """-> [SEQ_LEN, FEAT_DIM] or None if no face was found in any frame."""
    feats = [f for f in (frame_to_features(fr) for fr in read_frames(path))
             if f is not None]
    if not feats:
        return None
    arr = np.stack(feats)
    if len(arr) >= SEQ_LEN:
        idx = np.linspace(0, len(arr) - 1, SEQ_LEN).astype(int)
        return arr[idx]
    pad = np.repeat(arr[-1:], SEQ_LEN - len(arr), axis=0)
    return np.concatenate([arr, pad], axis=0)


def collect():
    import csv
    items = []
    with open(ZALO / "label.csv", newline="", encoding="utf-8") as f:
        for r in csv.DictReader(f):
            p = ZALO / "videos" / r["fname"]
            if p.exists():
                items.append((p, int(r["liveness_score"]), "zalo"))
    extra = [p for p in SPOOF_EXTRA.rglob("*")
             if p.suffix.lower() in (".mp4", ".mov") and ".cache" not in str(p)]
    items += [(p, 0, "spoof_extra") for p in extra]
    return items


def main():
    os.makedirs(OUT, exist_ok=True)
    if CACHE.exists():
        print(f"cache present at {CACHE}; delete it to re-extract")
        return
    items = collect()
    nz = sum(1 for _, _, s in items if s == "zalo")
    print(f"videos: {len(items)}  (zalo {nz}, spoof_extra {len(items)-nz})")
    print(f"labels: live {sum(1 for _,l,_ in items if l==1)}  "
          f"spoof {sum(1 for _,l,_ in items if l==0)}")

    X, y, src, failed = [], [], [], 0
    for i, (p, lab, s) in enumerate(items):
        try:
            seq = video_sequence(p)
        except Exception as exc:
            seq, exc_msg = None, str(exc)[:60]
            if failed < 3:
                print(f"  ! {p.name}: {exc_msg}", flush=True)
        if seq is None:
            failed += 1
            continue
        X.append(seq); y.append(lab); src.append(s)
        if (i + 1) % 100 == 0:
            print(f"  {i+1}/{len(items)}  kept {len(X)}  failed {failed}",
                  flush=True)
    X = np.stack(X).astype(np.float32)
    y = np.asarray(y, dtype=np.float32)
    src = np.asarray(src)
    np.savez_compressed(CACHE, X=X, y=y, src=src)
    print(f"\nwrote {CACHE}  X={X.shape}  live={int(y.sum())} "
          f"spoof={int((1-y).sum())}  failed={failed}")
    for s in ("zalo", "spoof_extra"):
        m = src == s
        print(f"  {s}: {int(m.sum())} kept, live {int(y[m].sum())}, "
              f"spoof {int((1-y[m]).sum())}")


if __name__ == "__main__":
    main()
