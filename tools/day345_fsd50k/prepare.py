"""Join FSD50K's spanned eval archive and pull only the clips ZapSafe needs.

WHY THIS MATTERS
================
`scream_classifier_v3` is evaluated on **45** real held-out positives, giving
a ~±0.05 confidence interval. That is why scream v4 came back *unmeasurable*
rather than bad (delta +0.0156, CI [-0.0287, +0.0617]). The eval set, not the
model, is the blocker.

FSD50K's eval split is independent of AudioSet, properly held out, and
contains:

    Screaming 123 · Shout 177 · Yell 60   -> 360 scream-family positives
    Gunshot_and_gunfire 134               -> first real eval set for mg_gunshot
    Glass 259                             -> first real eval set for glass

SPANNED ARCHIVE
===============
The audio ships as `FSD50K.eval_audio.z01` + `.zip`. Python's `zipfile`
refuses spanned archives outright ("zipfiles that span multiple disks are not
supported"), so the parts are concatenated in order first — the final `.zip`
part carries the central directory, so the join is a plain byte append.

This is **not** the same situation as the `videos.zip` abandoned earlier in
this project: that one was an incomplete download whose tail was not an
End-Of-Central-Directory record. Here every part is present.

Only the needed clips are extracted, and the ~5.9 GB joined file is deleted
afterwards — C: has ~12 GB free, and the dev split (17.5 GB) is deliberately
not attempted.
"""
import collections
import csv
import io
import json
import os
import shutil
import zipfile

SRC = r"D:\zapsafe"
OUT = r"C:\Users\hridy\Desktop\zapsafe\work\fsd50k_eval"
JOINED = os.path.join(OUT, "_eval_joined.zip")
AUDIO = os.path.join(OUT, "audio")

WANT = {"Screaming", "Shout", "Yell", "Gunshot_and_gunfire", "Glass",
        "Crying_and_sobbing", "Siren", "Whispering"}
# Same-domain hard negatives: human vocalisations that are NOT distress.
# A scream detector's real failure is firing on a laugh or a shouted
# conversation, so these matter more than arbitrary background noise.
NEG = {"Laughter", "Speech", "Cough", "Sneeze", "Chatter", "Conversation",
       "Singing", "Male_speech_and_man_speaking",
       "Female_speech_and_woman_speaking"}


def labels_for_eval():
    z = zipfile.ZipFile(os.path.join(SRC, "FSD50K.ground_truth.zip"))
    txt = z.read("FSD50K.ground_truth/eval.csv").decode("utf-8", "replace")
    out = {}
    for row in csv.DictReader(io.StringIO(txt)):
        labs = {x.strip() for x in row["labels"].split(",")}
        if labs & WANT or labs & NEG:
            out[row["fname"]] = labs
    return out


def join_parts():
    if os.path.exists(JOINED):
        print(f"  joined archive present ({os.path.getsize(JOINED)/1e9:.1f} GB)")
        return
    parts = [os.path.join(SRC, "FSD50K.eval_audio.z01"),
             os.path.join(SRC, "FSD50K.eval_audio.zip")]
    total = sum(os.path.getsize(p) for p in parts)
    print(f"  joining {len(parts)} parts -> {total/1e9:.1f} GB", flush=True)
    with open(JOINED, "wb") as w:
        for p in parts:
            print(f"    + {os.path.basename(p)}", flush=True)
            with open(p, "rb") as r:
                shutil.copyfileobj(r, w, 8 * 1024 * 1024)


def main():
    os.makedirs(AUDIO, exist_ok=True)
    want = labels_for_eval()
    print(f"eval clips matching wanted/negative classes: {len(want)}")
    join_parts()

    z = zipfile.ZipFile(JOINED)
    names = {os.path.basename(n): n for n in z.namelist()
             if n.lower().endswith(".wav")}
    print(f"  wavs in archive: {len(names)}")

    got = missing = 0
    manifest = []
    for fname, labs in want.items():
        key = f"{fname}.wav"
        if key not in names:
            missing += 1
            continue
        dst = os.path.join(AUDIO, key)
        if not os.path.exists(dst):
            with z.open(names[key]) as r, open(dst, "wb") as w:
                shutil.copyfileobj(r, w)
        manifest.append({"fname": key, "labels": sorted(labs)})
        got += 1
    z.close()

    json.dump(manifest, open(os.path.join(OUT, "manifest.json"), "w"), indent=1)
    print(f"  extracted {got}  missing {missing}")
    os.remove(JOINED)
    print("  removed joined archive to reclaim space")

    c = collections.Counter()
    for m in manifest:
        for l in m["labels"]:
            if l in WANT or l in NEG:
                c[l] += 1
    print("\n  class counts:")
    for k, v in c.most_common(16):
        print(f"    {k:34s} {v}")


if __name__ == "__main__":
    main()
