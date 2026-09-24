# `tools/day353_ml` — the scripts behind Days 352–353 and 391

## Why this directory exists

Twenty-one documents under `assets/models/` end with a line like
*"Reproduce: `work/m4_m5_v4_signflip/diagnose.py`"*. That path is
`C:\Users\hridy\Desktop\zapsafe\work\…`, which is **outside this repository
and is not a git repository itself**. Every reproduction instruction in
those docs pointed at files that existed on exactly one machine, with no
history and no backup.

Days 352–353 changed shipped assets on the strength of these scripts —
m4 and m5 were retrained, ESD was dropped, LEGOv2 was rejected, and
h_aggressive's gate fixture was built. A decision that changes a shipped
model should not be reproducible only from an un-versioned folder.

So the scripts that produced those decisions are vendored here, next to the
`tools/day260_ml_triage`, `tools/day328_dual_input_probe`,
`tools/day334_m3_burst` and `tools/day344_cross_dataset` directories that
already follow this convention.

## What is and is not here

**Here:** the `.py` scripts and their `report.json` outputs — 207 KB of text.

**Not here:** the `.npz` feature caches, `.tflite` artifacts and dataset
archives. Those run to gigabytes and several carry Non-Commercial licences.
The scripts rebuild them from the drives.

**These are copies, not the originals.** They still contain absolute paths
(`C:\Users\hridy\Desktop\zapsafe\work`, `D:\zapsafe`, `E:\datasets`,
`F:\zapsafe`) and will not run unchanged on another machine or without the
datasets attached. They are vendored for **provenance and review**, not as
a portable pipeline. The live copies remain under `work/` and are what
actually ran.

## Map

| path | what it decided |
|---|---|
| `m4_m5_v4_signflip/diagnose.py` | Per-feature direction agreement. Found ESD is **anti-correlated** with conversational speech (m5 r = −0.56, m4 r = −0.07). The reason the acted benchmark was retired. |
| `m4_m5_v4_signflip/ab_esd.py` | The paired A/B that authorised dropping ESD. Also caught that Day 352's "+0.0223" compared two *different* eval sets. |
| `m4_m5_v5_noesd/train_final.py` | Built the shipped `m4_vocal_stress_v3_38` and `m5_vocal_stress_v3_38`. |
| `m4_m5_v3_noesd/train_noesd.py` | Superseded. Kept because it is the run whose 0.318 I misread as a curiosity rather than as an inverted model. |
| `lego_natural/featurise_lego.py` | LEGOv2 (CMU Let's Go) in both 38-dim spaces. |
| `lego_natural/diagnose_lego.py` | Screening: direction agreement **+0.70**, but corpus-ID AUC 1.0000. |
| `lego_natural/ab_lego.py` | Four configurations; one cleared its CI (+0.0410). |
| `lego_natural/confirm_seeds.py` | **The script that stopped a mistake.** The hit did not replicate (mean +0.0029, 2/4 seeds). LEGOv2 rejected. |
| `trac_aggression/train_trac.py` | TRAC-1, 0.8312 in-corpus, Apache-2.0. |
| `trac_aggression/crosscorpus_indo.py` | **0.7081** on 58,477 unseen rows — the number the Day 391 UI quotes. |
| `trac_aggression/make_golden_trac.py` | The fixture pinning Dart's tokenizer to the trained one. |
| `h_aggressive_v4/*` | Day 352's frame-size isolation and its golden fixture. |
| `m4_m5_v2/*` | Day 350 featurisation, including the EmotionTalk speaker recovery. |
| `m7_distress_text/train_distress_text.py` | Built but **deliberately unshipped** — see `DAY347_DISTRESS_TEXT_DECISION.md`. Vendored so the shelving decision stays reviewable. |

## The one worth reading first

`confirm_seeds.py`. `ab_lego.py` produced a clean-looking +0.0410 with a CI
excluding zero, and it was noise — one win across four tests plus a lucky
initialisation. Re-running the winning configuration at fresh seeds is the
cheapest step in this whole directory and the only one that prevented a
corpus being adopted on nothing.
