"""Day 350 - recover EmotionTalk's real speaker_id per featurised row.

THE LEAK THIS FIXES
===================
`featurise_natural.py` stored the conversation-group prefix (`G00001`) as
the grouping key, and `train_v2.py` held out whole groups. That is not a
speaker-disjoint split: EmotionTalk's json carries a `speaker_id` and
speakers recur across groups --

    G00001 -> speakers 01, 02      G00003 -> speakers 02, 13
    G00002 -> speakers 07, 08      G00006 -> speakers 07, 12

so holding out G00003 while training on G00001 leaves speaker 02 on both
sides. m5 v2b's natural-speech AUC of 0.7969 is inflated by that, and it
was higher than m4's 0.6454 on natural English, which is what prompted the
check.

WHY NO RE-FEATURISATION IS NEEDED
=================================
`collect_etalk()` walks the tar in order and takes the first 14,000
labelled clips; `run_pool` maps over them in order and drops only rows
whose featurisation returned None. The run reported exactly
`(14000, 38)` for 14,000 collected clips, so **nothing was dropped and row
order is the collection order**. Replaying the collection's key sequence --
a json-only pass, no audio decoded -- therefore aligns 1:1 with the cached
feature rows.

The alignment is asserted rather than assumed: the recovered label sequence
must equal the cached `y` exactly. If it does not, the mapping is wrong and
this refuses to write anything.
"""
from __future__ import annotations

import collections
import json
import os
import tarfile

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ETALK = r"D:\zapsafe\EmotionTalk\Audio.tar"
LIMIT = 14000
POS = {"angry", "anger", "sad", "sadness"}
NEG = {"neutral", "happy", "happiness", "joy"}


def main():
    # pass 1: labels + speaker_id, keyed by clip name (json only)
    meta = {}
    with tarfile.open(ETALK, "r:") as t:
        for m in t:
            if not m.isfile() or not m.name.endswith(".json"):
                continue
            try:
                d = json.loads(t.extractfile(m).read()
                               .decode("utf-8", "replace"))
            except Exception:
                continue
            votes = [str(v.get("emotion", "")).lower()
                     for v in (d.get("data") or {}).values()]
            votes = [v for v in votes if v]
            if not votes:
                continue
            c = collections.Counter(votes).most_common()
            if len(c) > 1 and c[0][1] == c[1][1]:
                continue
            lab = 1 if c[0][0] in POS else (0 if c[0][0] in NEG else None)
            if lab is None:
                continue
            meta[os.path.basename(m.name)[:-5]] = (
                lab, str(d.get("speaker_id", "unk")))
    print(f"majority-labelled clips: {len(meta)}")

    # pass 2: replay the wav order exactly as collect_etalk() did
    keys = []
    with tarfile.open(ETALK, "r:") as t:
        for m in t:
            if not m.isfile() or not m.name.endswith(".wav"):
                continue
            if len(keys) >= LIMIT:
                break
            k = os.path.basename(m.name)[:-4]
            if k in meta:
                keys.append(k)
    print(f"replayed order: {len(keys)} keys")

    d = np.load(os.path.join(HERE, "feat_etalk.npz"), allow_pickle=True)
    y_cached = d["y"]
    assert len(keys) == len(y_cached), \
        f"order mismatch: {len(keys)} keys vs {len(y_cached)} cached rows"
    y_replay = np.asarray([meta[k][0] for k in keys], np.int32)
    assert np.array_equal(y_replay, y_cached), \
        "label sequence differs -- the row mapping is NOT valid, refusing"
    print("label sequence matches cached y exactly -> mapping is valid")

    spk = np.asarray(["etspk_" + meta[k][1] for k in keys])
    grp = np.asarray(["etgrp_" + k.split("_")[0] for k in keys])
    np.savez_compressed(os.path.join(HERE, "feat_etalk.npz"),
                        X=d["X"], y=y_cached, spk=spk, grp=grp)
    print(f"rewrote feat_etalk.npz with real speaker ids: "
          f"{len(set(spk.tolist()))} speakers, "
          f"{len(set(grp.tolist()))} groups")

    # how bad was the leak?
    g2s = collections.defaultdict(set)
    for g, s in zip(grp, spk):
        g2s[g].add(s)
    shared = collections.Counter()
    for g, ss in g2s.items():
        for s in ss:
            shared[s] += 1
    multi = [s for s, n in shared.items() if n > 1]
    print(f"speakers spanning >1 group: {len(multi)} of {len(shared)} "
          f"-> group-level holdout was NOT speaker-disjoint")


if __name__ == "__main__":
    main()
