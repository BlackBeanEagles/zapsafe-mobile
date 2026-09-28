"""Day 364C - choose the fusion weights AND threshold together, from real data.

WHY "USE THE RELIABILITY WEIGHTS" IS WRONG
=========================================
Day 363B measured each input's evidence weight and found the shipped
0.5/0.3/0.2 inverted against it (implied 0.274/0.384/0.342). The obvious fix
is to swap them. It makes the app WORSE, in two distinct ways:

  1. Reachability. With reliability weights, scream+motion sums to 0.658 and
     no longer clears 0.75, so only all-three can alert -- and scene is
     usually stale (kSceneMaxAgeMs = 30 s). That is the Day 326 bug, where
     the fused score could not reach the threshold at all.

  2. Worse false positives, which is less obvious. Reliability weighting
     raises motion 0.30 -> 0.384; pairing that with a lower threshold makes
     motion cover 64% of the threshold instead of 40%. The scream level
     needed for "sustained fall + ambient TV audio" to fire drops from
     0.900 to 0.788, and ambient audio exceeds 0.788 far more often than
     0.900.

Reliability tells you how much a detector's score DISCRIMINATES. A safety
gate needs the decision boundary placed so that specific operating
scenarios land on the right side. Those are different objectives, and
optimising the first silently damages the second.

WHAT THIS DOES INSTEAD
======================
Solves for (w_scream, w_motion, w_scene, threshold) against scenarios built
from measured per-window scores, under the real `requiredConsecutiveWindows
= 3` rule:

    A  ambient audio, no motion, ambient scene      must NOT alert
    B  ambient audio + SUSTAINED fall               must NOT alert  <- the
                                                       dangerous one
    C  violent-clip audio + sustained fall          SHOULD alert
    D  violent-clip audio + violent scene, no fall  SHOULD alert

Alert rates are computed over real overlapping window sequences, not by
assuming detectors sit at 1.0 and not by cubing a per-window probability --
windows share half their audio at a 1.5 s hop, so they are correlated.

Scenario C/D use XD-Violence violent clips as the incident proxy. That is
imperfect -- movie violence is not this app's SOS case -- and is stated
rather than hidden. It is the only co-occurring multimodal incident data
available.

CONSTRAINTS, fixed before searching:
    P(alert | A) == 0
    P(alert | B) <= 0.02        per video, over ambient media audio
    maximise P(alert | C) + P(alert | D)
    no single modality at 1.0 may alert      (w_i < T for every i)
    scream+motion at 1.0 MUST alert          (preserves the Day 326 fix)
"""
from __future__ import annotations

import glob
import itertools
import json
import os
import re
import subprocess
import tempfile

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = (r"C:\Users\hridy\Desktop\zapsafe\letsstartbuilding"
          r"\zapsafe_mobile_main_reconcile\assets\models")
XD = r"D:\zapsafe\xdviolence\videos"
SR, NEED, FR = 22050, 22050 * 3, 131
N_PER_CLASS = 60
CONSEC = 3
SEQ_CACHE = os.path.join(HERE, "fusion_sequences.npz")


def violent(name):
    t = re.findall(r"label[_-]([A-Za-z0-9\-]+)", name)
    if not t:
        return None
    p = [x for x in re.split(r"[-_]", t[-1].upper()) if x]
    if any(re.fullmatch(r"B\d+|G\d*", x) for x in p):
        return True
    if any(re.fullmatch(r"A\d*", x) for x in p):
        return False
    return None


def build_sequences():
    """Per-window scream score sequences + one scene score, per video."""
    if os.path.exists(SEQ_CACHE):
        d = np.load(SEQ_CACHE, allow_pickle=True)
        return (list(d["amb_seq"]), list(d["vio_seq"]),
                d["amb_scene"], d["vio_scene"])

    import tensorflow as tf
    import librosa
    import imageio_ffmpeg
    import soundfile as sf
    import cv2
    exe = imageio_ffmpeg.get_ffmpeg_exe()

    sc = tf.lite.Interpreter(model_path=os.path.join(
        ASSETS, "scream_classifier_v5.tflite"))
    sc.allocate_tensors()
    si, so = sc.get_input_details()[0], sc.get_output_details()[0]
    sshape = [int(v) for v in si["shape"]]
    enc = tf.lite.Interpreter(model_path=os.path.join(
        ASSETS, "mobilenetv3small_encoder_float16.tflite"))
    enc.allocate_tensors()
    ei, eo = enc.get_input_details()[0], enc.get_output_details()[0]
    m3 = tf.lite.Interpreter(model_path=os.path.join(
        ASSETS, "m3_violence_temporal_v1.tflite"))
    m3.allocate_tensors()
    mi, mo = m3.get_input_details()[0], m3.get_output_details()[0]

    vids = sorted(glob.glob(os.path.join(XD, "*.mp4")))
    tagged = [(p, violent(os.path.basename(p))) for p in vids]
    amb = [p for p, v in tagged if v is False]
    vio = [p for p, v in tagged if v is True]
    rng = np.random.RandomState(7)
    amb = [amb[i] for i in rng.permutation(len(amb))[:N_PER_CLASS]]
    vio = [vio[i] for i in rng.permutation(len(vio))[:N_PER_CLASS]]

    def one(path):
        with tempfile.TemporaryDirectory() as td:
            w = os.path.join(td, "a.wav")
            if subprocess.run([exe, "-nostdin", "-loglevel", "error",
                               "-i", path, "-ac", "1", "-ar", str(SR),
                               "-vn", "-y", w],
                              capture_output=True).returncode != 0:
                return None, None
            try:
                y, _ = sf.read(w, dtype="float32")
            except Exception:
                return None, None
        seq = []
        for st in range(0, max(1, len(y) - NEED + 1), NEED // 2):
            seg = y[st:st + NEED]
            seg = np.pad(seg, (0, NEED - len(seg))) if len(seg) < NEED else seg
            mel = librosa.feature.melspectrogram(y=seg, sr=SR, n_mels=128,
                                                 n_fft=2048, hop_length=512)
            db = librosa.power_to_db(mel, ref=np.max)
            rg = db.max() - db.min()
            db = (db - db.min()) / (rg if rg > 1e-8 else 1.0)
            if db.shape[1] < FR:
                db = np.pad(db, ((0, 0), (0, FR - db.shape[1])))
            x = db[:, :FR].astype(np.float32)
            sc.set_tensor(si["index"], x.reshape(sshape).astype(si["dtype"]))
            sc.invoke()
            v = sc.get_tensor(so["index"]).ravel()
            seq.append(float(v[-1] if v.size > 1 else v[0]))
        # one scene score for the video: 16 frames, RAW 0-255 RGB
        cap = cv2.VideoCapture(path)
        tot = int(cap.get(cv2.CAP_PROP_FRAME_COUNT) or 0)
        if tot <= 0:
            cap.release()
            return (np.array(seq) if seq else None), None
        emb = np.zeros((16, 576), np.float32)
        for j, fi in enumerate(np.linspace(0, tot - 1, 16).astype(int)):
            cap.set(cv2.CAP_PROP_POS_FRAMES, int(fi))
            ok, fr = cap.read()
            if not ok:
                cap.release()
                return (np.array(seq) if seq else None), None
            fr = cv2.cvtColor(cv2.resize(fr, (224, 224)), cv2.COLOR_BGR2RGB)
            enc.set_tensor(ei["index"],
                           fr.astype(np.float32)[None].astype(ei["dtype"]))
            enc.invoke()
            emb[j] = enc.get_tensor(eo["index"]).ravel()
        cap.release()
        m3.set_tensor(mi["index"], emb[None].astype(mi["dtype"]))
        m3.invoke()
        scene = float(m3.get_tensor(mo["index"]).ravel()[-1])
        return (np.array(seq) if seq else None), scene

    out = {}
    for tag, paths in (("amb", amb), ("vio", vio)):
        seqs, scenes = [], []
        for n, p in enumerate(paths):
            s, v = one(p)
            if s is None or len(s) < CONSEC or v is None:
                continue
            seqs.append(s)
            scenes.append(v)
            if (n + 1) % 20 == 0:
                print("  %s %d/%d" % (tag, n + 1, len(paths)), flush=True)
        out[tag + "_seq"] = np.array(seqs, dtype=object)
        out[tag + "_scene"] = np.asarray(scenes)
        print("  %s: %d videos" % (tag, len(seqs)))
    np.savez_compressed(SEQ_CACHE, **out)
    return (list(out["amb_seq"]), list(out["vio_seq"]),
            out["amb_scene"], out["vio_scene"])


def alert_rate(seqs, scenes, ws, wm, wsc, T, motion, use_scene):
    """Fraction of videos with >= CONSEC consecutive windows over T."""
    hits = 0
    for s, sv in zip(seqs, scenes):
        f = ws * s + wm * motion + (wsc * sv if use_scene else 0.0)
        c = f >= T
        run = 0
        hit = False
        for x in c:
            run = run + 1 if x else 0
            if run >= CONSEC:
                hit = True
                break
        hits += int(hit)
    return hits / max(len(seqs), 1)


def main():
    amb_seq, vio_seq, amb_scene, vio_scene = build_sequences()
    print("\nambient videos %d | violent videos %d"
          % (len(amb_seq), len(vio_seq)))

    def scen(ws, wm, wsc, T):
        return {
            "A_ambient_only": alert_rate(amb_seq, amb_scene, ws, wm, wsc, T,
                                         0.0, True),
            "B_ambient_plus_fall": alert_rate(amb_seq, amb_scene, ws, wm, wsc,
                                              T, 1.0, True),
            "C_violent_plus_fall": alert_rate(vio_seq, vio_scene, ws, wm, wsc,
                                              T, 1.0, True),
            "D_violent_scene_only": alert_rate(vio_seq, vio_scene, ws, wm,
                                               wsc, T, 0.0, True),
        }

    print("\n=== the two candidate configs already on the table")
    for lbl, (ws, wm, wsc, T) in (
            ("shipped      0.50/0.30/0.20 @0.75", (0.5, 0.3, 0.2, 0.75)),
            ("reliability  0.274/0.384/0.342 @0.60",
             (0.274, 0.384, 0.342, 0.60))):
        r = scen(ws, wm, wsc, T)
        print("  %-38s A %.3f  B %.3f  C %.3f  D %.3f"
              % (lbl, r["A_ambient_only"], r["B_ambient_plus_fall"],
                 r["C_violent_plus_fall"], r["D_violent_scene_only"]))

    print("\n=== search: A==0, B<=0.02, singles<T, scream+motion>=T")
    grid = [round(x, 2) for x in np.arange(0.10, 0.61, 0.02)]
    best = None
    rows = []
    for ws in grid:
        for wm in grid:
            for wsc in grid:
                tot = ws + wm + wsc
                if abs(tot - 1.0) > 1e-6:
                    continue
                for T in [round(t, 2) for t in np.arange(0.40, 0.91, 0.01)]:
                    if max(ws, wm, wsc) >= T:        # no single may alert
                        continue
                    if ws + wm < T:                  # Day 326 property
                        continue
                    r = scen(ws, wm, wsc, T)
                    if r["A_ambient_only"] > 0:
                        continue
                    if r["B_ambient_plus_fall"] > 0.02:
                        continue
                    score = r["C_violent_plus_fall"] + r["D_violent_scene_only"]
                    rows.append({"w": [ws, wm, wsc], "T": T, **r,
                                 "score": round(score, 4)})
                    if best is None or score > best["score"]:
                        best = rows[-1]

    print("  feasible configurations: %d" % len(rows))
    if not best:
        print("  -> NO configuration satisfies the constraints. The "
              "detectors cannot support this gate; report, do not ship.")
    else:
        rows.sort(key=lambda r: -r["score"])
        print("  %-26s %6s %6s %6s %6s" % ("top configs (w | T)", "A", "B",
                                           "C", "D"))
        for r in rows[:8]:
            print("  %-26s %6.3f %6.3f %6.3f %6.3f"
                  % ("%.2f/%.2f/%.2f @%.2f" % (r["w"][0], r["w"][1],
                                               r["w"][2], r["T"]),
                     r["A_ambient_only"], r["B_ambient_plus_fall"],
                     r["C_violent_plus_fall"], r["D_violent_scene_only"]))
        print("\n  BEST: w=%.2f/%.2f/%.2f  T=%.2f"
              % (best["w"][0], best["w"][1], best["w"][2], best["T"]))
    json.dump({"best": best, "n_feasible": len(rows),
               "top": rows[:20] if rows else [],
               "constraints": {"A": "==0", "B": "<=0.02",
                               "singles": "< T", "scream+motion": ">= T"},
               "caveat": ("C/D use XD-Violence violent clips as the incident "
                          "proxy; movie violence is not this app's SOS case. "
                          "Only co-occurring multimodal data available.")},
              open(os.path.join(HERE, "fusion_solve.json"), "w"), indent=2)
    print("report written")


if __name__ == "__main__":
    main()
