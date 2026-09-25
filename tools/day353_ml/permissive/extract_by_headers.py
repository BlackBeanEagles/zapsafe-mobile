"""Day 359 - pull FSD50K clips out of a spanned zip by scanning local headers.

WHY THIS EXISTS
===============
FSD50K.dev_audio ships as a spanned archive (.z01-.z05 + .zip, 17.1 GB). The
extracted copy on disk is **69.9% zero-byte files** -- 28,618 of 40,966 --
so the original extraction silently failed and every downstream count has
been running on ~30% of the corpus. That is why the permissive glass build
yielded 254 positives where the metadata promised 872.

Concatenating the parts gives a 17.1 GB file that Python still refuses:

    BadZipFile: zipfiles that span multiple disks are not supported

because the End-of-Central-Directory record keeps its disk-number fields.
The central directory is unusable, but **local file headers are
self-describing**: each carries its own signature, compression method,
sizes and filename immediately before the data. Scanning for those bypasses
the central directory completely.

WHAT IT DOES
============
Streams the joined file once, finds every PK\\x03\\x04 header, and writes out
only the filenames requested. Everything else is skipped by seeking past its
compressed size, so the pass costs one sequential read rather than a full
extraction.

CORRECTNESS GUARDS, because a header scan can go wrong quietly:
  * the CRC32 in the header is checked against the decompressed bytes, and a
    mismatch is counted and reported rather than written;
  * entries with the data-descriptor flag (bit 3) have zero sizes in the
    header and cannot be located this way -- they are counted and skipped,
    not guessed at;
  * files that already exist NON-EMPTY on disk are left alone, so a rerun
    resumes instead of redoing 17 GB.
"""
from __future__ import annotations

import io
import os
import struct
import sys
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
JOINED = r"D:\zapsafe\fsd50k_dev_joined.zip"
DEST = r"C:\Users\hridy\Desktop\zapsafe\ml_datasets\audio_events\DS08_FSD50K\FSD50K.dev_audio"
SIG = b"PK\x03\x04"
CHUNK = 8 << 20


def wanted_names():
    """Every clip any of the three permissive models needs."""
    names = set()
    for model in ("glass", "scream", "gunshot"):
        for kind in ("pos", "neg"):
            p = os.path.join(HERE, "%s_dev_%s.txt" % (model, kind))
            if not os.path.exists(p):
                continue
            with io.open(p, encoding="utf-8") as fh:
                for line in fh:
                    x = line.strip()
                    if x:
                        names.add("FSD50K.dev_audio/%s.wav" % x)
    return names


def main():
    want = wanted_names()
    print("clips wanted: %d" % len(want), flush=True)
    if not want:
        print("no clip lists found -- run build_permissive_sets.py first")
        return
    os.makedirs(DEST, exist_ok=True)

    have = set()
    for n in want:
        p = os.path.join(DEST, os.path.basename(n))
        if os.path.exists(p) and os.path.getsize(p) > 0:
            have.add(n)
    print("already present and non-empty: %d" % len(have), flush=True)
    todo = want - have
    if not todo:
        print("nothing to do")
        return
    print("to extract: %d" % len(todo), flush=True)

    size = os.path.getsize(JOINED)
    f = open(JOINED, "rb")
    written = skipped_dd = crc_bad = seen = 0
    pos = 0
    while pos < size:
        f.seek(pos)
        head = f.read(30)
        if len(head) < 30 or head[:4] != SIG:
            # not at a header: hunt forward for the next signature
            f.seek(pos)
            buf = f.read(CHUNK)
            if not buf:
                break
            i = buf.find(SIG, 1 if buf[:4] == SIG else 0)
            pos = pos + i if i >= 0 else pos + max(len(buf) - 3, 1)
            continue
        (_, _, flags, method, _, _, crc, csize, usize, nlen,
         elen) = struct.unpack("<IHHHHHIIIHH", head[:30])
        name = f.read(nlen).decode("utf-8", "replace")
        f.read(elen)
        data_at = pos + 30 + nlen + elen
        seen += 1
        if flags & 0x8:
            # sizes live in a trailing data descriptor; not locatable here
            skipped_dd += 1
            pos = data_at + 1
            continue
        if name in todo:
            f.seek(data_at)
            raw = f.read(csize)
            try:
                out = (zlib.decompress(raw, -15) if method == 8 else raw)
            except Exception:
                crc_bad += 1
                pos = data_at + csize
                continue
            if crc and (zlib.crc32(out) & 0xFFFFFFFF) != crc:
                crc_bad += 1
                pos = data_at + csize
                continue
            with open(os.path.join(DEST, os.path.basename(name)), "wb") as o:
                o.write(out)
            written += 1
            if written % 250 == 0:
                print("  written %d/%d  (scanned %d entries)"
                      % (written, len(todo), seen), flush=True)
        pos = data_at + csize
    f.close()
    print("\nentries scanned      %d" % seen)
    print("written              %d of %d" % (written, len(todo)))
    print("skipped (descriptor) %d" % skipped_dd)
    print("CRC/decompress fail  %d" % crc_bad)
    if written == 0:
        print("NOTHING WRITTEN -- the header scan found no requested names; "
              "check the path prefix inside the archive before rerunning")


if __name__ == "__main__":
    main()
