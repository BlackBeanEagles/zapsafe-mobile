# Day 361 — cross-corpus validation of glass and gunshot

Vendored copies of the scripts that measured `m_glass_breaking_v4` and
`mg_gunshot_v2` on **AudioSet**, a corpus neither model has ever seen, after
both were shipped on FSD50K-only numbers.

Findings, in full: `assets/models/DAY361_CROSS_CORPUS_GLASS_AND_GUNSHOT.md`.

| script | what it does |
|---|---|
| `build_fixture.py` | selects 1,598 AudioSet clips (59 glass / 77 gunshot positives, 62 hard negatives) and builds per-task mel banks |
| `eval_xcorpus.py` | shipped vs retired model, paired bootstrap on shared resamples |
| `operating_point.py` | recall/precision/FPR at the threshold read from the Dart source |
| `aggregation_control.py` | single vs mean vs max window, to separate model weakness from aggregation |
| `threshold_both_corpora.py` | same grid on FSD50K and AudioSet, scored by the worse of the two Youden J values |

Each writes the matching `.json`, committed alongside.

## Two traps these scripts now guard against

**Per-task preprocessing.** Glass is **2.0 s / 96 mels**, gunshot is
**3.0 s / 128 mels** — from `train_glass_permissive.py` and
`build_train_gunshot.py`. An early version fed glass 3.0 s and produced a
confident, damning, wrong result (FPR 0.975). Eval now asserts the mel count
against the interpreter's declared input shape; the duration comes from a
per-task spec.

**Silent row loss.** An early run dropped 1,122 of 1,598 clips because
worker processes hit `MemoryError` and `except Exception` swallowed it,
leaving a plausible-looking 476-clip fixture. Workers now return a reason
string instead of `None`, and the build aborts above a 5% drop rate.

Root cause of the second: **C: was 100% full, so the Windows pagefile could
not grow.** Big jobs on this machine die with `MemoryError` while RAM looks
free. Keep headroom on C: before running anything here.

## Reproducing

Needs `DS07_AudioSet/train_wav` (9,927 wavs) plus the segment CSVs, and the
gate's FSD50K eval fixture at `work/fsd50k_eval`. Run `build_fixture.py`
first; the rest read its `.npz`. Roughly 20 min at `WORKERS = 2`.
