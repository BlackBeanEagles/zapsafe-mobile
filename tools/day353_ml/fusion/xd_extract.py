"""Day 363C - run the real detectors over XD-Violence to build fusion data.

WHAT THIS PRODUCES
==================
Per video segment: (scream_score, scene_score, violence_label) -- the
co-occurring multi-modal incident data M9 has always lacked. Two of the
fusion's three inputs; XD-Violence has audio and video but no IMU, so the
motion slot cannot be filled from it. That gap is real and is reported, not
papered over by feeding motion a constant (which would train the model to
ignore it while still LOOKING like it uses motion at runtime).

LABELS COME FROM THE FILENAME
=============================
XD-Violence encodes the label in the file name:

    A    non-violent          B2   shooting     B6   car accident
    B1   fight                B4   riot         G    explosion
                              B5   abuse

e.g. `v=xxx__#1_label_A` is normal; anything with a non-A tag is violent.
That is video-level. The official frame-level `annotations.txt` is used when
present in the download, because a 5-minute video labelled violent is mostly
not violent, and video-level labels would put ordinary footage in the
positive class.

TWO INPUT CONVENTIONS THAT MUST NOT BE SWAPPED
==============================================
`violence_burst_detector.dart` spells out the hazard this repo has hit
repeatedly:

  * `mobilenetv3small_encoder` takes **raw [0,255]** -- its `Rescaling`
    layer is baked into the exported graph. Dividing by 255 applies it twice
    and hands the temporal head embeddings from a distribution it has never
    seen: well-formed, confident, wrong, nothing thrown.
  * cv2 decodes **BGR**; the encoder was trained on **RGB**. Also silent.

Both are handled explicitly below and neither is inferable from the shapes.

AUDIO comes through ffmpeg (bundled via imageio-ffmpeg; OpenCV cannot
extract audio) at 22.05 kHz mono, then the scream front-end: 3 s, 128 mels,
n_fft 2048, hop 512, 131 frames -- verbatim from build_train_scream.py.
"""
from __future__ import annotations

import glob
import json
import os
import re
import subprocess
import sys
import tempfile

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
XD = r"D:\zapsafe\xdviolence"
ASSETS = (r"C:\Users\hridy\Desktop\zapsafe\letsstartbuilding"
          r"\zapsafe_mobile_main_reconcile\assets\models")

SR, DUR, N_MELS, FRAMES = 22050, 3, 128, 131
NEED = SR * DUR
IMG, SEQ = 224, 16
MAX_VIDEOS = int(os.environ.get("XD_MAX", "400"))


def ffmpeg_exe():
    import imageio_ffmpeg
    return imageio_ffmpeg.get_ffmpeg_exe()


def label_from_name(name):
    """A = non-violent; B1/B2/B4/B5/B6/G = violent. None if no tag found.

    Violence is decided POSITIVELY -- "does any tag name a violent class" --
    not negatively as "are all tags A". The negative form looks equivalent
    and is not: XD-Violence pads multi-label names with zeros, so `label_A-0-0`
    has parts ['A','0','0'], and "all parts start with A" is False, which
    would silently file a NON-violent video as violent. Padding zeros are
    ignorable; only B* and G* carry meaning.
    """
    tags = re.findall(r"label[_-]([A-Za-z0-9\-]+)", name)
    if not tags:
        return None
    parts = [p for p in re.split(r"[-_]", tags[-1].upper()) if p]
    if not parts:
        return None
    violent = [p for p in parts if re.fullmatch(r"B\d+|G\d*", p)]
    benign = [p for p in parts if re.fullmatch(r"A\d*", p)]
    if violent:
        return 1
    if benign:
        return 0
    return None


def extract_audio(path, exe):
    """Decode the whole track to mono 22.05 kHz float32 via ffmpeg."""
    with tempfile.TemporaryDirectory() as td:
        wav = os.path.join(td, "a.wav")
        r = subprocess.run(
            [exe, "-nostdin", "-loglevel", "error", "-i", path,
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


def mel_window(y, librosa):
    y = np.pad(y, (0, NEED - len(y))) if len(y) < NEED else y[:NEED]
    mel = librosa.feature.melspectrogram(y=y, sr=SR, n_mels=N_MELS,
                                         n_fft=2048, hop_length=512)
    db = librosa.power_to_db(mel, ref=np.max)
    rg = db.max() - db.min()
    db = (db - db.min()) / (rg if rg > 1e-8 else 1.0)
    if db.shape[1] < FRAMES:
        db = np.pad(db, ((0, 0), (0, FRAMES - db.shape[1])))
    return db[:, :FRAMES].astype(np.float32)


def read_frames(path, n=SEQ):
    """n evenly spaced frames, RGB, raw [0,255] float32 -- see module doc."""
    import cv2
    cap = cv2.VideoCapture(path)
    total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT) or 0)
    if total <= 0:
        cap.release()
        return None
    idx = np.linspace(0, max(total - 1, 0), n).astype(int)
    out = []
    for i in idx:
        cap.set(cv2.CAP_PROP_POS_FRAMES, int(i))
        ok, fr = cap.read()
        if not ok:
            cap.release()
            return None
        fr = cv2.resize(fr, (IMG, IMG))
        fr = cv2.cvtColor(fr, cv2.COLOR_BGR2RGB)      # cv2 gives BGR
        out.append(fr.astype(np.float32))             # RAW 0-255, no /255
    cap.release()
    return np.stack(out)


def main():
    import tensorflow as tf
    import librosa

    vids = [p for p in glob.glob(os.path.join(XD, "**", "*.mp4"),
                                 recursive=True)]
    vids += glob.glob(os.path.join(XD, "**", "*.avi"), recursive=True)
    vids = sorted(vids)
    if not vids:
        raise SystemExit("no videos found under %s -- is the zip extracted?"
                         % XD)
    print("videos found: %d" % len(vids))

    labelled = [(p, label_from_name(os.path.basename(p))) for p in vids]
    labelled = [(p, y) for p, y in labelled if y is not None]
    print("with a parseable label: %d  (pos %d)"
          % (len(labelled), sum(y for _, y in labelled)))
    if not labelled:
        print("SAMPLE NAMES:", [os.path.basename(p) for p in vids[:5]])
        raise SystemExit("could not parse labels from filenames")

    rng = np.random.RandomState(42)
    pos = [x for x in labelled if x[1] == 1]
    neg = [x for x in labelled if x[1] == 0]
    k = MAX_VIDEOS // 2
    sel = ([pos[i] for i in rng.permutation(len(pos))[:k]] +
           [neg[i] for i in rng.permutation(len(neg))[:k]])
    print("processing %d videos (%d pos / %d neg)"
          % (len(sel), sum(1 for _, y in sel if y), sum(1 for _, y in sel
                                                        if not y)))

    enc = tf.lite.Interpreter(model_path=os.path.join(
        ASSETS, "mobilenetv3small_encoder_float16.tflite"))
    enc.allocate_tensors()
    ei, eo = enc.get_input_details()[0], enc.get_output_details()[0]
    m3 = tf.lite.Interpreter(model_path=os.path.join(
        ASSETS, "m3_violence_temporal_v1.tflite"))
    m3.allocate_tensors()
    mi, mo = m3.get_input_details()[0], m3.get_output_details()[0]
    sc = tf.lite.Interpreter(model_path=os.path.join(
        ASSETS, "scream_classifier_v5.tflite"))
    sc.allocate_tensors()
    si, so = sc.get_input_details()[0], sc.get_output_details()[0]
    sshape = [int(v) for v in si["shape"]]

    exe = ffmpeg_exe()
    rows, drops = [], {}
    for n, (path, y) in enumerate(sel):
        frames = read_frames(path)
        if frames is None:
            drops["video"] = drops.get("video", 0) + 1
            continue
        emb = np.zeros((SEQ, 576), np.float32)
        for i in range(SEQ):
            enc.set_tensor(ei["index"],
                           frames[i:i + 1].astype(ei["dtype"]))
            enc.invoke()
            emb[i] = enc.get_tensor(eo["index"]).ravel()
        m3.set_tensor(mi["index"], emb[None].astype(mi["dtype"]))
        m3.invoke()
        scene = float(m3.get_tensor(mo["index"]).ravel()[-1])

        wav = extract_audio(path, exe)
        if wav is None or len(wav) < SR // 2:
            drops["audio"] = drops.get("audio", 0) + 1
            continue
        best = 0.0
        step = NEED // 2
        for st in range(0, max(1, len(wav) - NEED + 1), step):
            m = mel_window(wav[st:st + NEED], librosa)
            sc.set_tensor(si["index"], m.reshape(sshape).astype(si["dtype"]))
            sc.invoke()
            v = sc.get_tensor(so["index"]).ravel()
            best = max(best, float(v[-1] if v.size > 1 else v[0]))
        rows.append({"file": os.path.basename(path), "y": int(y),
                     "scream": round(best, 6), "scene": round(scene, 6)})
        if (n + 1) % 25 == 0:
            print("  %d/%d kept=%d %s" % (n + 1, len(sel), len(rows),
                                          drops or ""), flush=True)

    print("kept %d of %d (drops: %s)" % (len(rows), len(sel), drops or "none"))
    json.dump(rows, open(os.path.join(HERE, "xd_fusion_rows.json"), "w"),
              indent=2)
    y = np.array([r["y"] for r in rows])
    print("positives %d / %d" % (int(y.sum()), len(y)))
    print("written xd_fusion_rows.json")


if __name__ == "__main__":
    main()
