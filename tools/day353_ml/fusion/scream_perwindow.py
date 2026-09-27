"""Day 364B - correcting Day 363D: per-window, not max-over-video.

THE ERROR
=========
Day 363D reported that `scream_classifier_v5` has median **0.898** on
non-violent media audio and concluded it is saturated, defeating the DCS
two-modality rule.

That number is a **max over every 3 s window of the whole video**. XD-Violence
test videos have a median duration of 75 s, so at a 1.5 s hop that is a max
over ~50 draws, and the longest is 340 s -- 226 draws. The figure it was
compared against, AudioSet screams at 0.834, is a **single window**.

A maximum over 50 samples is far above the median of one sample for any
distribution. The two numbers were never comparable, and the conclusion
drawn from them -- that ambient audio scores HIGHER than real screams -- may
be entirely an artifact of that.

The DCS engine scores **one window at a time**. `infer()` takes a single
`AudioFeatures` frame. So the per-window distribution is the only one that
says anything about what the fusion actually sees.

WHAT THIS MEASURES
==================
Every 3 s window of non-violent XD-Violence audio, scored individually.
Then:

  * the per-window distribution, which is the honest ambient baseline;
  * what fraction of individual windows clear the levels that matter;
  * the max-over-N curve, to show how much of Day 363D's 0.898 was simply
    the maximum operator.

Nothing here rescues or condemns the detector on its own. It establishes
which number to use.
"""
from __future__ import annotations

import glob
import json
import os
import subprocess
import tempfile

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = (r"C:\Users\hridy\Desktop\zapsafe\letsstartbuilding"
          r"\zapsafe_mobile_main_reconcile\assets\models")
XD = r"D:\zapsafe\xdviolence\videos"
SR, DUR, N_MELS, FRAMES = 22050, 3, 128, 131
NEED = SR * DUR
N_VIDEOS = 100


def label_benign(name):
    import re
    tags = re.findall(r"label[_-]([A-Za-z0-9\-]+)", name)
    if not tags:
        return False
    parts = [p for p in re.split(r"[-_]", tags[-1].upper()) if p]
    import re as _re
    if any(_re.fullmatch(r"B\d+|G\d*", p) for p in parts):
        return False
    return any(_re.fullmatch(r"A\d*", p) for p in parts)


def audio_of(path, exe):
    with tempfile.TemporaryDirectory() as td:
        wav = os.path.join(td, "a.wav")
        r = subprocess.run([exe, "-nostdin", "-loglevel", "error", "-i", path,
                            "-ac", "1", "-ar", str(SR), "-vn", "-y", wav],
                           capture_output=True)
        if r.returncode != 0 or not os.path.exists(wav):
            return None
        import soundfile as sf
        try:
            y, _ = sf.read(wav, dtype="float32")
        except Exception:
            return None
    return y


def main():
    import tensorflow as tf
    import librosa
    import imageio_ffmpeg
    exe = imageio_ffmpeg.get_ffmpeg_exe()

    it = tf.lite.Interpreter(model_path=os.path.join(
        ASSETS, "scream_classifier_v5.tflite"))
    it.allocate_tensors()
    i0, o0 = it.get_input_details()[0], it.get_output_details()[0]
    shape = [int(v) for v in i0["shape"]]

    vids = [p for p in sorted(glob.glob(os.path.join(XD, "*.mp4")))
            if label_benign(os.path.basename(p))]
    rng = np.random.RandomState(42)
    vids = [vids[i] for i in rng.permutation(len(vids))[:N_VIDEOS]]
    print("non-violent videos: %d" % len(vids))

    per_window, per_video_max, nwin = [], [], []
    for n, p in enumerate(vids):
        y = audio_of(p, exe)
        if y is None or len(y) < SR:
            continue
        scores = []
        for st in range(0, max(1, len(y) - NEED + 1), NEED // 2):
            seg = y[st:st + NEED]
            seg = np.pad(seg, (0, NEED - len(seg))) if len(seg) < NEED else seg
            mel = librosa.feature.melspectrogram(y=seg, sr=SR, n_mels=N_MELS,
                                                 n_fft=2048, hop_length=512)
            db = librosa.power_to_db(mel, ref=np.max)
            rg = db.max() - db.min()
            db = (db - db.min()) / (rg if rg > 1e-8 else 1.0)
            if db.shape[1] < FRAMES:
                db = np.pad(db, ((0, 0), (0, FRAMES - db.shape[1])))
            m = db[:, :FRAMES].astype(np.float32)
            it.set_tensor(i0["index"], m.reshape(shape).astype(i0["dtype"]))
            it.invoke()
            v = it.get_tensor(o0["index"]).ravel()
            scores.append(float(v[-1] if v.size > 1 else v[0]))
        if not scores:
            continue
        per_window.extend(scores)
        per_video_max.append(max(scores))
        nwin.append(len(scores))
        if (n + 1) % 20 == 0:
            print("  %d/%d  windows so far %d" % (n + 1, len(vids),
                                                  len(per_window)),
                  flush=True)

    w = np.asarray(per_window)
    mx = np.asarray(per_video_max)
    print("\nwindows scored: %d across %d videos (median %d per video)"
          % (len(w), len(mx), int(np.median(nwin))))
    print("\n  PER-WINDOW (what the fusion actually sees)")
    for q in (10, 25, 50, 75, 90, 99):
        print("    p%-3d %.4f" % (q, np.percentile(w, q)))
    print("    mean %.4f" % w.mean())
    print("\n  MAX-OVER-VIDEO (what Day 363D reported)")
    print("    median %.4f   p90 %.4f" % (np.median(mx), np.percentile(mx, 90)))
    print("\n  fraction of INDIVIDUAL windows above:")
    for t in (0.3, 0.5, 0.7, 0.9):
        print("    > %.1f : %5.1f%%" % (t, 100 * (w > t).mean()))

    print("\n  how much of 0.898 was just the max operator?")
    for k in (1, 5, 10, 25, 50):
        sim = [np.max(rng.choice(w, size=k)) for _ in range(2000)]
        print("    max over %-3d random windows -> median %.4f" % (k,
                                                                   np.median(sim)))

    med_w = float(np.median(w))
    print("\n  DCS contribution at weight 0.5, per window:")
    print("    ambient per-window median %.4f -> %.4f of the 0.75 threshold"
          % (med_w, 0.5 * med_w))
    print("    + fall (0.30) = %.4f  %s"
          % (0.5 * med_w + 0.30,
             "ALERT" if 0.5 * med_w + 0.30 >= 0.75 else "no alert"))

    json.dump({"n_windows": int(len(w)), "n_videos": int(len(mx)),
               "per_window": {("p%d" % q): round(float(np.percentile(w, q)), 4)
                              for q in (10, 25, 50, 75, 90, 99)},
               "per_window_mean": round(float(w.mean()), 4),
               "max_over_video_median": round(float(np.median(mx)), 4),
               "frac_above": {str(t): round(float((w > t).mean()), 4)
                              for t in (0.3, 0.5, 0.7, 0.9)},
               "dcs_contribution_per_window": round(0.5 * med_w, 4),
               "fall_plus_ambient_per_window": round(0.5 * med_w + 0.30, 4),
               "corrects": ("DAY363D reported max-over-video (median 0.898) "
                            "and compared it to a single-window AudioSet "
                            "figure. The DCS engine scores one window at a "
                            "time, so the per-window distribution is the "
                            "correct ambient baseline.")},
              open(os.path.join(HERE, "scream_perwindow.json"), "w"), indent=2)
    print("\nreport written")


if __name__ == "__main__":
    main()
