"""Day 359 - can the NC audio models be retrained on CC0/CC-BY only?

THE PROBLEM
===========
Five shipped models carry Non-Commercial training data:

    scream_classifier_v5   ESC-50 (CC BY-NC 3.0), FSD50K BY-NC subset
    m_glass_breaking_v3    UrbanSound8K (CC BY-NC 3.0)
    mg_gunshot_retrain     UrbanSound8K (CC BY-NC 3.0), AudioSet
    m5_vocal_stress_v3     EmotionTalk (CC BY-NC-SA 4.0)
    h_aggressive_v5        TESS (BY-NC), RAVDESS (BY-NC-SA)

The last two have no permissive replacement -- emotional speech corpora are
essentially all NC. The first three are AUDIO EVENT detectors, and FSD50K
carries a PER-CLIP licence:

    CC BY      20,017 (48.9%)
    CC0        14,959 (36.5%)   -> 85.4% permissive
    CC BY-NC    4,616 (11.3%)
    Sampling+   1,374 (3.4%)

and the permissive fraction holds for the classes that matter:

    Screaming 218/254  Shatter 387/414  Glass 872/974
    Gunshot   320/348  Shout   195/216  Yell  130/139

So a CC0+CC-BY-only retrain is arithmetically possible. Whether it is
possible WITHOUT LOSING ACCURACY is the question, and it is decided by an
A/B against the shipped models on the SAME eval fixtures the gate uses --
not by the subset being big enough.

WHAT THIS SCRIPT DOES
=====================
Builds the permissive-only clip lists and reports, per model, how much
training data survives against what the shipped model used. If a class drops
below a usable floor the script says so rather than producing a set that
cannot train.

IT DOES NOT TRAIN. The A/B comes next, and it only runs on classes that
survive here.

LICENCE NOTE: CC BY requires ATTRIBUTION, which CC0 does not. A CC-BY-only
model obliges the app to credit the contributors somewhere a user can reach.
That is a real product obligation, not a formality, and it is the price of
clearing the NC flag. It is cheaper than NC, which forbids the commercial
use outright.
"""
from __future__ import annotations

import csv
import io
import json
import os
import collections

HERE = os.path.dirname(os.path.abspath(__file__))
F = r"C:\Users\hridy\Desktop\zapsafe\ml_datasets\audio_events\DS08_FSD50K"

# what each model needs, in FSD50K vocabulary terms
MODELS = {
    "scream": {"pos": ["Screaming"], "neg": ["Speech", "Conversation",
                                             "Laughter", "Singing"]},
    "glass": {"pos": ["Shatter", "Glass"], "neg": ["Speech", "Door",
                                                   "Clatter", "Tap"]},
    "gunshot": {"pos": ["Gunshot_and_gunfire"], "neg": ["Speech",
                                                        "Fireworks",
                                                        "Hammer", "Door"]},
}
MIN_POS = 150          # below this a class cannot carry a detector


def licence_of(url):
    u = (url or "").lower()
    if "publicdomain" in u or "zero" in u or "/cc0" in u:
        return "CC0"
    if "by-nc" in u:
        return "CC BY-NC"
    if "by-sa" in u:
        return "CC BY-SA"
    if "creativecommons.org/licenses/by/" in u:
        return "CC BY"
    if "sampling+" in u:
        return "Sampling+"
    return "other"


def main():
    os.makedirs(HERE, exist_ok=True)
    out = {}
    for split, info_f, gt_f in (
            ("dev", "dev_clips_info_FSD50K.json", "dev.csv"),
            ("eval", "eval_clips_info_FSD50K.json", "eval.csv")):
        info = json.load(io.open(os.path.join(F, "FSD50K.metadata", info_f),
                                 encoding="utf-8"))
        lic = {k: licence_of(v.get("license")) for k, v in info.items()}
        perm = {k for k, v in lic.items() if v in ("CC0", "CC BY")}
        gt = {}
        for r in csv.DictReader(io.open(
                os.path.join(F, "FSD50K.ground_truth", gt_f),
                encoding="utf-8")):
            gt[r["fname"]] = set(r["labels"].split(","))
        print("\n=== %s: %d clips, %d permissive (%.1f%%)"
              % (split, len(info), len(perm), 100.0 * len(perm) / len(info)))

        for name, spec in MODELS.items():
            pos_all = [f for f, l in gt.items() if l & set(spec["pos"])]
            neg_all = [f for f, l in gt.items()
                       if (l & set(spec["neg"])) and not (l & set(spec["pos"]))]
            pos_p = [f for f in pos_all if f in perm]
            neg_p = [f for f in neg_all if f in perm]
            lost = len(pos_all) - len(pos_p)
            print("  %-8s pos %4d -> %4d permissive (lost %d, %.1f%%)   "
                  "neg %5d -> %5d"
                  % (name, len(pos_all), len(pos_p), lost,
                     100.0 * lost / max(len(pos_all), 1),
                     len(neg_all), len(neg_p)))
            key = "%s_%s" % (name, split)
            out[key] = {"pos_total": len(pos_all), "pos_permissive": len(pos_p),
                        "neg_total": len(neg_all), "neg_permissive": len(neg_p),
                        "usable": len(pos_p) >= MIN_POS}
            if len(pos_p) < MIN_POS:
                print("       -> BELOW the %d-positive floor; a permissive-"
                      "only %s cannot be trained from FSD50K alone"
                      % (MIN_POS, name))
            with io.open(os.path.join(HERE, "%s_pos.txt" % key), "w") as fh:
                fh.write("\n".join(sorted(pos_p)))
            with io.open(os.path.join(HERE, "%s_neg.txt" % key), "w") as fh:
                fh.write("\n".join(sorted(neg_p)))

        # licence mix, for the attribution obligation
        c = collections.Counter(lic[k] for k in perm)
        print("  permissive mix: %s" % dict(c))
        out["%s_mix" % split] = dict(c)

    json.dump(out, open(os.path.join(HERE, "permissive_report.json"), "w"),
              indent=2)
    print("\nwrote clip lists + permissive_report.json")
    usable = [k for k, v in out.items()
              if isinstance(v, dict) and v.get("usable")]
    print("usable (>=%d permissive positives): %s" % (MIN_POS, usable))


if __name__ == "__main__":
    main()
