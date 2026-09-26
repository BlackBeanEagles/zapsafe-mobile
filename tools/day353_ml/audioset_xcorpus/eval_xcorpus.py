"""Day 361 - run four shipped/retired models over AudioSet. Nothing trains.

    m_glass_breaking_v3   retired  207.0 KB   96 mels   FSD50K eval 0.684
    m_glass_breaking_v4   SHIPPED   59.6 KB   96 mels   FSD50K eval 0.866
    mg_gunshot_retrain    retired 4677.0 KB  128 mels   FSD50K eval 0.729
    mg_gunshot_v2         SHIPPED   59.7 KB  128 mels   FSD50K eval 0.846

Each goes through its real .tflite inference path, at its OWN mel size, on
rows neither has seen. The mel size is asserted against the interpreter's
declared input shape rather than assumed -- a first version fed every model
128 mels and TFLite raised "Got 128 but expected 96", which was luck. A
resize to 96 would have run clean and returned a plausible wrong number.

Paired bootstrap over CLIPS with shared indices, so old-vs-new is compared on
identical resamples -- the same correction Day 352 needed after comparing two
models on two different eval sets and reporting the difference as a gain.

With 59 glass and 77 gunshot positives the intervals are wide. That is the
point of printing them: the direction is the finding, not the third decimal.
"""
from __future__ import annotations

import json
import os

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = (r"C:\Users\hridy\Desktop\zapsafe\letsstartbuilding"
          r"\zapsafe_mobile_main_reconcile\assets\models")
B = 2000
SEED = 42

MODELS = {
    "glass": [("m_glass_breaking_v3 (retired)",
               os.path.join(HERE, "m_glass_breaking_v3.tflite"), 0.684),
              ("m_glass_breaking_v4 (SHIPPED)",
               os.path.join(ASSETS, "m_glass_breaking_v4.tflite"), 0.866)],
    "gun": [("mg_gunshot_retrain (retired)",
             os.path.join(HERE, "mg_gunshot_retrain.tflite"), 0.729),
            ("mg_gunshot_v2 (SHIPPED)",
             os.path.join(ASSETS, "mg_gunshot_v2.tflite"), 0.846)],
}


def run(path, banks):
    """Score every row, at whatever mel size this model declares.

    `banks` maps size -> (N, size, size) single-channel float16. The gate
    builds its input as np.stack([img] * 3), three identical copies, so the
    channel expansion here is lossless rather than an approximation.
    """
    import tensorflow as tf
    it = tf.lite.Interpreter(model_path=path)
    it.allocate_tensors()
    i0, o0 = it.get_input_details()[0], it.get_output_details()[0]
    _, h, w, c = [int(v) for v in i0["shape"]]
    if h != w or h not in banks:
        raise SystemExit("%s wants %dx%d; fixture has %s"
                         % (os.path.basename(path), h, w, sorted(banks)))
    if c != 3:
        raise SystemExit("%s wants %d channels, expected 3"
                         % (os.path.basename(path), c))
    X = banks[h]
    out = np.zeros(len(X))
    for k in range(len(X)):
        img = np.repeat(X[k].astype(np.float32)[..., None], 3, axis=-1)
        it.set_tensor(i0["index"], img[None].astype(i0["dtype"]))
        it.invoke()
        v = it.get_tensor(o0["index"]).ravel()
        out[k] = float(v[-1]) if v.size > 1 else float(v[0])
    return out, h


def boot_ci(y, p, idx):
    from sklearn.metrics import roc_auc_score
    vals = []
    for i in idx:
        yy = y[i]
        if yy.min() == yy.max():
            continue
        vals.append(roc_auc_score(yy, p[i]))
    v = np.asarray(vals)
    return float(np.percentile(v, 2.5)), float(np.percentile(v, 97.5)), v


def main():
    from sklearn.metrics import roc_auc_score
    d = np.load(os.path.join(HERE, "audioset_fixture.npz"), allow_pickle=True)
    ys = {"glass": d["yg"].astype(int), "gun": d["yk"].astype(int)}
    n = len(ys["glass"])
    print("fixture: %d clips | glass pos %d (%d mels, %.1fs) | "
          "gun pos %d (%d mels, %.1fs)"
          % (n, ys["glass"].sum(), int(d["mels_glass"]), float(d["dur_glass"]),
             ys["gun"].sum(), int(d["mels_gun"]), float(d["dur_gun"])))

    rng = np.random.RandomState(SEED)
    idx = [rng.randint(0, n, n) for _ in range(B)]   # SHARED resamples

    report = {}
    for task, entries in MODELS.items():
        y = ys[task]
        banks = {int(d["mels_%s" % task]): d["win_%s" % task]}
        firsts = {int(d["mels_%s" % task]): d["first_%s" % task]}
        nwin = d["nwin_%s" % task].astype(int)
        off = np.concatenate([[0], np.cumsum(nwin)])
        print("\n=== %s   (AudioSet base rate %.3f, %d positives, "
              "%d windows of %.1fs)"
              % (task, y.mean(), y.sum(), int(nwin.sum()),
                 float(d["dur_%s" % task])))
        curves = {}
        for name, path, fsd in entries:
            if not os.path.exists(path):
                print("  MISSING %s" % path)
                continue
            pw, size = run(path, banks)
            pmax = np.array([pw[off[k]:off[k + 1]].max() for k in range(n)])
            pf, _ = run(path, firsts)
            a_max = float(roc_auc_score(y, pmax))
            a_first = float(roc_auc_score(y, pf))
            lo, hi, bv = boot_ci(y, pmax, idx)
            curves[name] = bv
            report.setdefault(task, {})[name] = {
                "mels": size, "fsd50k_eval": fsd,
                "audioset_maxwin": round(a_max, 4),
                "audioset_first3s": round(a_first, 4),
                "ci95": [round(lo, 4), round(hi, 4)]}
            print("  %-32s %3d mels | FSD50K %.3f | AudioSet max-win %.4f "
                  "[%.3f-%.3f] | first-3s %.4f"
                  % (name, size, fsd, a_max, lo, hi, a_first), flush=True)
        ks = list(curves)
        if len(ks) == 2:
            dv = curves[ks[1]] - curves[ks[0]]
            lo, hi = np.percentile(dv, [2.5, 97.5])
            pw = float((dv <= 0).mean())
            print("  paired delta (new - old): %+.4f  [%+.4f, %+.4f]  "
                  "P(new<=old) = %.3f" % (dv.mean(), lo, hi, pw))
            report[task]["paired_delta"] = {
                "mean": round(float(dv.mean()), 4),
                "ci95": [round(float(lo), 4), round(float(hi), 4)],
                "p_new_not_better": round(pw, 4)}
    json.dump(report, open(os.path.join(HERE, "xcorpus_report.json"), "w"),
              indent=2)
    print("\nreport written")


if __name__ == "__main__":
    main()
