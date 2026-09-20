# Day 345 — the scream eval-set blocker is gone, and it changes two numbers

`scream_classifier_v3` was evaluated on **45** real held-out positives, a
~±0.05 confidence interval. That is why Day 339 could only call scream v4
"indistinguishable" (delta +0.0156, CI [-0.0287, +0.0617]) — the eval set,
not the model, was the blocker. Every scream conclusion in this project
rested on those 45 clips.

## The unblock

FSD50K's **eval** split is independent of AudioSet (Freesound-sourced,
different annotation pipeline) and properly held out. It was sitting
unopened on `D:` the whole time; filename searches never found it because
the relevant content is inside spanned archives.

```
POSITIVES   Screaming 123 · Shout 177 · Yell 60    = 360 scream-family
            Gunshot_and_gunfire 134                (first real eval for mg_gunshot)
            Glass 267                              (first real eval for glass)
NEGATIVES   Speech 785 · Male-speech 467 · Chatter 387 · Laughter 253
            Female-speech 247 · Singing 194 · Cough 106 · Sneeze 61 ...
```

The negatives matter as much as the positives: a scream detector's real
failure is firing on a laugh or a shouted conversation, not on silence.

### Getting the audio out — three separate obstacles

1. **Spanned archive.** `FSD50K.eval_audio.z01` + `.zip`. Python's `zipfile`
   refuses outright: *"zipfiles that span multiple disks are not supported"*.
   Concatenating the parts is necessary but not sufficient.
2. **Disk fields.** After joining, the EOCD, Zip64 EOCD and Zip64 locator
   still declare a multi-disk set. Patching those three records in place
   made the archive open (10,231 entries listed).
3. **Per-disk offsets.** Entries still failed with *"Bad magic number for
   file header"* — in a spanned zip each central-directory offset is
   relative to the disk its data sits on, so everything after part 1 points
   to the wrong place. Rather than rewrite the directory, the extractor
   **ignores it and walks local file headers** (`PK\x03\x04`), which are
   self-describing. **2,226 clips extracted, zero failures.**

This is *not* the `videos.zip` situation abandoned earlier in this project:
that one was an incomplete download whose tail was not an End-Of-Central-
Directory record at all. Here every part was present.

The 6.3 GB joined file is deleted after extraction; only the 1.9 GB of
needed clips is kept.

## Result 1 — v4 is not "indistinguishable", it is worse

```
              45 positives (Day 339)        1,764 clips / 287 pos (now)
v3                      0.8390                        0.7675
v4                      0.8546                        0.7522
delta                  +0.0156                       -0.0153
95% CI        [-0.0287, +0.0617]            [-0.0306, -0.0012]
P(v4 > v3)               0.739                         0.017
CI width                0.0904                        0.0295
```

The interval now **excludes zero on the negative side**. Day 339's decision
not to ship v4 was correct; the reason is now stronger than "cannot tell" —
SpecAugment plus doubled hard negatives made it measurably *worse*.

## Result 2 — v3's real number is 0.7675, not 0.839

The 0.839 on record comes from the gate's 135-clip AudioSet fixture. Against
an independent set with 1,477 same-domain hard negatives it is **0.7675**.

Operating points on the new set (the app ships `t=0.20`):

| t | recall | precision |
|---|---|---|
| 0.40 | 0.627 | 0.402 |
| 0.30 | 0.666 | 0.343 |
| **0.20** | **0.711** | **0.304** |
| 0.15 | 0.739 | 0.283 |
| 0.10 | 0.770 | 0.252 |

Precision is much lower than the 0.614 measured on the small fixture. That
is expected and is the point: this negative pool is *speech, chatter,
laughter and singing*, not silence, and the positive base rate is 16% rather
than 33%. **This is the number to plan against.**

The Day 342 threshold move (0.30 → 0.20) still looks right — it buys recall
0.666 → 0.711 for precision 0.343 → 0.304 — but both sides of that trade are
worse than the small fixture suggested.

## What this does not yet do

The gate still uses the 135-clip AudioSet fixture, so `scream_classifier_v3`
will keep reporting 0.839 there. Swapping the gate fixture to FSD50K is the
obvious follow-up and is deliberately not bundled into this change: it moves
a number every other document references, and deserves its own commit.

**`mg_gunshot_retrain` and glass-break now have real eval sets for the first
time** (134 and 267 held-out positives). Neither has ever been measured on
independent data — `mg_gunshot`'s recorded 0.89 comes from a 24-clip
liveness-style probe with no labels at all.

Reproduce: `tools/day345_fsd50k/`.
