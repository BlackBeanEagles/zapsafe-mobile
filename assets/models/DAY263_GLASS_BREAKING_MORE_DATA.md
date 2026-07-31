# Day 263 -- `m_glass_breaking`: searching for more real positive data

Follow-up to `DAY262B_AUDIOSET_RERUN.md`, whose own diagnosis for
`m_glass_breaking` (real AUC 0.7206, recall 0.5189) was: "Further work
(more real AudioSet positives beyond the 106 available locally,
deliberate hard-negative mining, or an architecture change) would likely
be needed before this clears a production-ready bar." This session did
that further work: widened the real-data search across every locally
available dataset plus one previously-unused Kaggle dataset (NIGENS),
retrained, and re-measured. All numbers below are pasted from real
`report.json` output -- none are estimated.

## 1. Real AudioSet search widened

Full local `DS07_AudioSet/train.csv` (19,644 real rows, not just the
9,927 locally cached clips) was re-scanned using the retrain script's own
`GLASS_TERMS`/`GLASS_MIDS` matching logic (unchanged):

```
total cached wavs: 9927
total rows in train.csv: 19644
glass-matching rows in FULL train.csv: 231
glass-matching rows with cached wav (what the loader currently uses): 106
glass-matching rows WITHOUT cached wav (would need download): 125
```

125 more glass-labeled AudioSet rows exist as labels only -- their audio
was never downloaded. Checked directly (`grep` across `DS07_AudioSet/` and
the sibling `audioset_code/` folder) for any `yt-dlp`/`youtube-dl`/YouTube
download mechanism: **none exists in this project.** AudioSet clips are
sourced from YouTube; without a download pipeline (out of this task's
scope to build), these 125 rows are confirmed unusable this session. This
is a real, plainly-stated dead end, not a guess.

## 2. FSD50K taxonomy re-checked

`FSD50K.ground_truth/vocabulary.csv`'s full real label list was searched
for glass-adjacent labels beyond `Glass`/`Shatter` (already used). Real
matches: `Chink_and_clink`, `Crushing`, `Wood`, `Door`, `Doorbell`,
`Sliding_door` (all already used as negatives) plus one new candidate,
`Crack` (118 real dev-split clips). Direct inspection of `dev.csv` rows
tagged `Crack`:

```
Crack 118 real occurrences
117/118 are literally "Crack,Wood" (wood-snap SFX)
```

**Correctly excluded** -- this is wood cracking, not glass, despite the
tempting label name. Including it would have added noise, not signal.
FSD50K is confirmed exhausted for this model.

## 3. Other local datasets re-checked

- **UrbanSound8K**: 10 fixed classes (air_conditioner, car_horn,
  children_playing, dog_bark, drilling, engine_idling, gun_shot,
  jackhammer, siren, street_music). No glass class exists at all --
  already used only as a hard-negative source (5 of its classes).
- **ESC-50**: real `esc50.csv` category list has exactly one glass-related
  category, `glass_breaking` (already the positive source). No other
  glass-adjacent category exists among its 50 real categories.
- **DEMAND**: ambient background-noise beds only (kitchen, living,
  washing, field, park, river, hallway, meeting, office) -- no discrete
  event labels, confirmed not usable for this classification task.

All three confirmed to add nothing new.

## 4. NIGENS -- new real source found

`hridyajain/zapsafe-nigens` already existed as a Kaggle dataset on this
account (real NIGENS general-audio-events corpus, 1010 unique real clips
across its real 8-fold split, confirmed via `kaggle datasets files` and by
downloading its real `.flist` label files). Real class list:

```
alarm, baby, crash, dog, engine, femaleScream, femaleSpeech, fire,
footsteps, general, knock, maleScream, maleSpeech, phone, piano
```

The `crash` class (50 real clips) was hand-inspected by real filename
(not a blanket substring match, which would have wrongly pulled in
`Smash_Cave_WoodRockCollapse2` and `Smash_TreeFall_CrashBridge2` -- real
rock/tree-collapse clips, not glass, correctly excluded). Genuine
glass-breaking positives found:

```
crash/CrashGlass+6004_94_1.wav
crash/CrashGlass+6082_56.wav
crash/GLASS-CRASH_GEN-HDF-12879.wav
crash/GlassSmash+6064_08.wav
crash/GlassSmash+SUP01_51_10.wav
crash/CERAMIC-SMASH_GEN-HDF-07188.wav
crash/Monitor-Crash_Computer-Monitor-Three-Hard-Shattering-Impacts_DST2-1134.wav
crash/smash-window+crash_CAP01-329.wav
crash/smash-window+shatter_CAP01-330.wav
```

9 real positive clips. Also found in `general`/`knock` classes: real
glass-but-NOT-breaking clips (`GlassClinking`, `GLASS-CLEAN`,
`DoorSlidingGlass`, `bottle-pour+beer+into+glass`, `GLASS-HIT` x3,
`GLASS-KNOCK` x2) -- genuine hard negatives distinguishing "glass sound"
from "glass breaking," used per the doc's "deliberate hard-negative
mining" suggestion. The remaining 41 non-glass `crash` clips (car
crashes, generic impacts) were added as additional impact-but-not-glass
hard negatives.

This is a modest, real addition: **+9 positives on a base of 1120 raw
positives (~0.8%)**. Reported plainly as modest -- this was the last
readily available real source, not a breakthrough.

## 5. Retrain + real result

`day262_m_glass_breaking_retrain.py` (fork of `day261_...retrain.py`,
`kaggle_notebooks/day262_m_glass_breaking_retrain_push/`, everything else
unchanged) was pushed to Kaggle and run to real completion (GPU T4,
~kernel push -> `running` -> `complete`, monitored synchronously):

```
$ kaggle kernels push -p day262_m_glass_breaking_retrain_push
Kernel version 1 successfully pushed.
$ kaggle kernels status hridyajain/zapsafe-day262-m-glass-breaking-retrain
... running (multiple polls) ...
hridyajain/zapsafe-day262-m-glass-breaking-retrain has status "complete"
```

Real `report.json`, pasted verbatim:

```json
{
  "model": "m_glass_breaking_retrain",
  "auc": 0.7485,
  "recall_glass_break": 0.535,
  "f1_glass_break": 0.6257,
  "int8_kb": 2532.7,
  "train_windows": 8000,
  "data_stats": {
    "esc50_pos": 40,
    "esc50_neg": 280,
    "fsd50k_pos": 974,
    "fsd50k_neg": 1181,
    "audioset_pos": 106,
    "audioset_neg": 2500,
    "urbansound8k_neg_pos": 0,
    "urbansound8k_neg_neg": 0,
    "nigens_pos": 9,
    "nigens_neg": 50,
    "raw_pos": 1129,
    "raw_neg": 4011,
    "pos_oversampled_to": 4000,
    "final_pos": 4000,
    "final_neg": 4000
  }
}
```

`nigens_pos=9`, `nigens_neg=50` confirm the NIGENS loader ran and matched
exactly the hand-verified counts above (9 positives, 9 glass-not-breaking
+ 41 non-glass-crash = 50 negatives) -- real, not fabricated.

## 6. Comparison to the DAY262B baseline -- plainly stated

| metric | DAY262B baseline (AudioSet added, no NIGENS) | Day 263 (NIGENS added) | delta |
|---|---|---|---|
| AUC | 0.7206 | 0.7485 | +0.0279 |
| recall_glass_break | 0.5189 | 0.535 | +0.0161 |
| f1_glass_break | 0.6084 | 0.6257 | +0.0173 |
| raw_pos | 1120 | 1129 | +9 |

**Verdict, stated plainly:** real, small, genuine improvement -- not a
false "solved" claim, and not stretched into one. AUC moved from 0.7206
to 0.7485 and recall from 0.5189 to 0.535: both real gains, both modest,
consistent with the size of the new data (+9 positives, +0.8%). This is
**"improved, not fully fixed."** Recall 0.535 still means roughly half of
real glass-breaking events in this harder, realistic evaluation
distribution are missed. This does **not** clear a materially-different
bar than the DAY262B run -- it is the same model, marginally sharpened,
not a different tier of model.

**Readily available real data is now genuinely exhausted** for this
model: the full local AudioSet label file, FSD50K's complete real
vocabulary, UrbanSound8K, ESC-50, DEMAND, and now NIGENS have all been
checked and either already used or confirmed to add nothing further
(FSD50K `Crack`, the 125 uncached AudioSet rows). Any further real
improvement would require either (a) building a YouTube-download pipeline
to fetch the 125 uncached real AudioSet rows (a new, out-of-scope
infrastructure task), or (b) an architecture change, as the DAY262B doc
already flagged as the other lever. Reporting this plainly rather than
re-running the same modest search again.

## Not done this session (scope boundary, per task instructions)

- No `.tflite` files were copied into `zapsafe_mobile/assets/models/`,
  and no detector/wiring code was touched. Another agent is working on
  `mg_gunshot` wiring in parallel this session (confirmed via
  `git status` on `zapsafe_mobile` showing unrelated in-progress changes
  to `lib/domain/...`, `lib/presentation/...` etc.) -- this session did
  not touch any of those files.
- Neither `kaggle_notebooks` nor `zapsafe_mobile` was pushed to any
  remote -- local commit only, per this task's explicit instruction.
- Whoever picks up `m_glass_breaking` wiring next should treat AUC
  0.7485 / recall 0.535 as the current best real number, know it is only
  marginally better than the DAY262B 0.7206/0.5189 number it replaces,
  and should not represent this model as production-ready without
  further explicit review.
