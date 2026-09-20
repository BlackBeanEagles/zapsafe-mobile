"""Extract FSD50K eval clips by scanning LOCAL FILE HEADERS.

Why not the central directory: this archive was produced by concatenating a
spanned zip (`.z01` + `.zip`). Both the end-of-central-directory disk fields
and every per-entry local-header offset are relative to the disk the data
sat on, so after concatenation the directory points to the wrong places.
Patching the EOCD made the archive *openable* (10,231 entries listed) but
entries still failed with "Bad magic number for file header".

The file data itself is contiguous and undamaged — only the bookkeeping is
wrong. So this ignores the directory and walks local file headers
(`PK\\x03\\x04`) from the start, which is self-describing: each header
carries its own filename, compression method and sizes.

Handles the one real complication: when a local header declares sizes of 0
with the data-descriptor flag set, the true sizes live *after* the data, so
those entries are skipped rather than guessed at. FSD50K stores its wavs
uncompressed or deflated with sizes present, so this loses nothing here and
is reported if it ever does.
"""
import csv
import collections
import io
import json
import os
import struct
import zipfile
import zlib

SRC = r"D:\zapsafe"
OUT = os.path.dirname(os.path.abspath(__file__))
JOINED = os.path.join(OUT, "_eval_joined.zip")
AUDIO = os.path.join(OUT, "audio")

WANT = {"Screaming", "Shout", "Yell", "Gunshot_and_gunfire", "Glass",
        "Crying_and_sobbing", "Siren", "Whispering"}
NEG = {"Laughter", "Speech", "Cough", "Sneeze", "Chatter", "Conversation",
       "Singing", "Male_speech_and_man_speaking",
       "Female_speech_and_woman_speaking"}


def wanted_labels():
    z = zipfile.ZipFile(os.path.join(SRC, "FSD50K.ground_truth.zip"))
    txt = z.read("FSD50K.ground_truth/eval.csv").decode("utf-8", "replace")
    out = {}
    for row in csv.DictReader(io.StringIO(txt)):
        labs = {x.strip() for x in row["labels"].split(",")}
        if labs & WANT or labs & NEG:
            out[f"{row['fname']}.wav"] = sorted(labs)
    return out


def main():
    os.makedirs(AUDIO, exist_ok=True)
    want = wanted_labels()
    print(f"target clips: {len(want)}")

    size = os.path.getsize(JOINED)
    got = skipped_desc = bad = 0
    manifest = []
    with open(JOINED, "rb") as f:
        pos = 0
        while pos < size - 30:
            f.seek(pos)
            head = f.read(30)
            if len(head) < 30 or head[:4] != b"PK\x03\x04":
                # resync to the next local header
                f.seek(pos)
                chunk = f.read(8 * 1024 * 1024)
                if not chunk:
                    break
                nxt = chunk.find(b"PK\x03\x04", 1)
                pos = pos + (nxt if nxt > 0 else len(chunk) - 3)
                continue
            (_, flags, method, _, _, _, csize, usize, nlen,
             elen) = struct.unpack("<HHHHHIIIHH", head[4:30])
            name = f.read(nlen).decode("utf-8", "replace")
            f.read(elen)
            data_at = pos + 30 + nlen + elen

            if flags & 0x08 and csize == 0:
                skipped_desc += 1
                pos = data_at + 1
                continue

            base = os.path.basename(name)
            if base in want and not os.path.exists(os.path.join(AUDIO, base)):
                f.seek(data_at)
                raw = f.read(csize)
                try:
                    out = (zlib.decompress(raw, -15) if method == 8 else raw)
                    with open(os.path.join(AUDIO, base), "wb") as w:
                        w.write(out)
                    got += 1
                except Exception:
                    bad += 1
            if base in want:
                manifest.append({"fname": base, "labels": want[base]})
            pos = data_at + csize
            if got and got % 250 == 0:
                print(f"  extracted {got} ...", flush=True)

    json.dump(manifest, open(os.path.join(OUT, "manifest.json"), "w"), indent=1)
    print(f"\nextracted {got}   decompress-failed {bad}   "
          f"skipped(data-descriptor) {skipped_desc}")

    c = collections.Counter()
    for m in manifest:
        for l in m["labels"]:
            if l in WANT or l in NEG:
                c[l] += 1
    print("\nclass counts in what was pulled:")
    for k, v in c.most_common(18):
        tag = "POS" if k in WANT else "neg"
        print(f"  [{tag}] {k:34s} {v}")


if __name__ == "__main__":
    main()
