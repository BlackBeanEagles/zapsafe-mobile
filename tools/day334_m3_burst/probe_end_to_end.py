"""Day 334 - verify the SHIPPED two-stage M3 chain on real held-out clips.

flutter test cannot execute a TFLite model, so this is the only place the
encoder->head chain is actually run. It also measures the input-scaling
hazard directly: feeding /255-scaled pixels (the convention the OTHER
MobileNetV3 model in this app uses) instead of raw [0,255].

Frame sampling is byte-identical to train_m3_temporal.sample_frames,
INCLUDING the short-clip pad that repeats the last frame. An earlier version
of this probe skipped clips shorter than 16 frames instead, and took the
first 22 paths alphabetically -- that scored AUC 0.7025 and looked like a
broken chain. With training-matched sampling and a random sample it is
0.9176. The bug was in the probe.
"""
import glob, os, random, numpy as np, cv2, tensorflow as tf
from sklearn.metrics import roc_auc_score

random.seed(0)
REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
A = os.path.join(REPO, "assets", "models")
VIO = r"D:\zapsafe\violene"
FRAMES, SIZE = 16, 224

enc = tf.lite.Interpreter(model_path=os.path.join(A, "mobilenetv3small_encoder_float16.tflite"))
tem = tf.lite.Interpreter(model_path=os.path.join(A, "m3_violence_temporal_float16.tflite"))
enc.allocate_tensors(); tem.allocate_tensors()
ei, eo = enc.get_input_details()[0], enc.get_output_details()[0]
ti, to = tem.get_input_details()[0], tem.get_output_details()[0]


def sample_frames(path):
    try:
        cap = cv2.VideoCapture(path)
        total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT)) or 0
        if total <= 0:
            cap.release(); return None
        want = set(np.linspace(0, total - 1, FRAMES).astype(int).tolist())
        out, i = [], 0
        while True:
            ok, fr = cap.read()
            if not ok: break
            if i in want: out.append(cv2.resize(fr, (SIZE, SIZE))[:, :, ::-1])
            i += 1
        cap.release()
        if not out: return None
        while len(out) < FRAMES: out.append(out[-1])   # the pad that matters
        return np.stack(out[:FRAMES]).astype(np.uint8)
    except Exception:
        return None


def score(frames, scaled=False):
    seq = np.zeros((FRAMES, 576), np.float32)
    f32 = frames.astype(np.float32)
    for i in range(FRAMES):
        x = f32[i] / 255.0 if scaled else f32[i]
        enc.set_tensor(ei["index"], x[None]); enc.invoke()
        seq[i] = np.ravel(enc.get_tensor(eo["index"]))
    tem.set_tensor(ti["index"], seq[None]); tem.invoke()
    return float(np.ravel(tem.get_tensor(to["index"]))[0])


def clips(name):
    return [p for p in glob.glob(os.path.join(VIO, "val", name, "**", "*.avi"),
                                 recursive=True) if not p.endswith("_processed.avi")]


def main(k=70):
    F, N = clips("Fight"), clips("NonFight")
    random.shuffle(F); random.shuffle(N)
    cF = [a for a in (sample_frames(p) for p in F[:k]) if a is not None]
    cN = [a for a in (sample_frames(p) for p in N[:k]) if a is not None]
    print(f"decoded Fight={len(cF)} NonFight={len(cN)}")
    for tag, sc in (("raw [0,255]  <- correct, what Dart does", False),
                    ("/255 scaled  <- the other model's convention", True)):
        sp = [score(a, sc) for a in cF]
        sn = [score(a, sc) for a in cN]
        allv = sp + sn
        print(f"\n  {tag}")
        print(f"    AUC={roc_auc_score([1]*len(sp)+[0]*len(sn), sp+sn):.4f} "
              f"sep={np.mean(sp)-np.mean(sn):+.4f} span={max(allv)-min(allv):.4f}")
        print(f"    fires>=0.5: {sum(1 for v in sp if v>=0.5)}/{len(sp)} fight, "
              f"{sum(1 for v in sn if v>=0.5)}/{len(sn)} nonfight")


if __name__ == "__main__":
    main()
