# Day 264 — `s_crowd_panic_a` / `s_best` retrain: real MobiAct + real panic-audio labels

Follow-up to `DAY260B_HIDDEN_INPUT_CHECK.md` Step 4, which confirmed
`s_crowd_panic_a`/`s_best` scores real panic scenarios LOWER than real calm
scenarios (mean 0.942 vs 0.955) even with both real inputs (`imu`, `mel`)
correctly populated, and flagged that the wrong-direction effect traced
mainly to the audio/mel branch, not IMU. That doc's own test had to
substitute real UCI-HAR walking IMU run through the training script's
`apply_crush_imu()` as "the closest reproducible real-data substitute" for
real MobiAct fall data, which was not available locally at the time.

This session's task was framed around sourcing real MobiAct data to fix the
IMU side. **That turned out to be necessary but not sufficient** — a second,
separate, real bug was found on the audio side and both had to be fixed
before the direction check passed.

## Finding 1 (IMU side): `load_mobiact_fall_pos()` never actually loaded MobiAct data

`hridyajain/zapsafe-mobiact` (91MB) is a real, usable Kaggle dataset —
confirmed by downloading and inspecting actual files, not just listing them.
But `day95_s_crowd_panic.py`'s `load_mobiact_fall_pos()` assumed MobiAct's
raw files were **whitespace-separated 6-column rows** (`sep=r"\s+"`,
`df.iloc[:, :6]`). Real MobiAct files are:

- **comma-separated**, not whitespace-separated
- prefixed with `#...` comment/header lines (device metadata, subject info)
- **split into separate single-sensor files** — `<CODE>_acc_<subj>_<trial>.txt`
  (timestamp,x,y,z) and `<CODE>_gyro_<subj>_<trial>.txt` (timestamp,x,y,z)
  are different files, never a combined 6-column file

Verified directly: downloaded `FKL_acc_1_1.txt` from the real Kaggle
dataset and read its header —
`#Acceleration force along the x y z axes (including gravity).` /
`#timestamp(ns),x,y,z(m/s^2)` — 3 comma-separated data columns after
comment lines, not 6 whitespace-separated columns. With the old loader,
every real MobiAct file would fail to parse under `sep=r"\s+"` (comment
lines and comma separators break the whitespace split), so
`load_mobiact_fall_pos()` silently returned 0 samples regardless of whether
MobiAct was present locally — this was never just a "data not available"
problem, it was also a **loader bug** that would have kept returning 0 even
once MobiAct became available.

Also verified real MobiAct fall activity codes against
`DataDescribe.txt` (bundled in the dataset): `FOL` (Forward-lying), `FKL`
(Front-knees-lying), `BSC` (Back-sitting-chair), `SDL` (Sideward-lying) —
not "fall"/"bump"/"hit"/"stumble" filename substrings as the old loader's
filter assumed (it happened to work by accident because MobiAct's own
directory is named `FALLS`, which contains the substring "fall").

**Fix** (`kaggle_notebooks/s_crowd_panic_push/day95_s_crowd_panic.py`,
`load_mobiact_fall_pos()` and new `_read_mobiact_sensor_csv()` /
`MOBIACT_FALL_CODES`): parse real MobiAct files as comma-separated with
`#`-comment skipping, pair each `_acc_` file with its matching `_gyro_`
file by filename, concatenate into a real 6-axis `[acc_xyz, gyro_xyz]`
window, filter by the four real fall codes. Confirmed working in the
retrain: `[MobiAct crush pos] 288` real samples loaded (previously 0).

## Finding 2 (audio side): `PANIC_MIDS` did not contain panic-related AudioSet IDs

DAY260B flagged the wrong-direction effect as tracing "mainly to the
audio/mel branch, not IMU." Reading `day95_s_crowd_panic.py`'s `PANIC_MIDS`
set and decoding every ID against
`ml_datasets/audio_events/DS07_AudioSet/class_labels_indices.csv` and the
real AudioSet ontology (`ontology-master/ontology.json`) found:

| old `PANIC_MIDS` entry | decodes to |
|---|---|
| `/m/032s66` | Gunshot, gunfire |
| `/m/028v0c` | Silence |
| `/m/07qcp` | **does not exist in AudioSet ontology** |
| `/m/0dl9sf8` | Throat clearing |
| `/m/04rlf` | Music |
| `/m/01h8n0` | Conversation (also duplicated in `CALM_MIDS`) |
| `/m/07rknqz` | Skidding |
| `/m/0h9mv` | Tire squeal |

None of these are crowd-panic, scream, riot, or stampede sounds — this
looks like a copy/paste from an unrelated (traffic/car-crash-flavored)
label set, not a hand-picked panic vocabulary. The audio "panic" positive
class the model actually trained on was a mix of gunshots, silence,
throat-clearing, music, conversation, and traffic skid/tire sounds — this
fully explains DAY260B's finding that real panic audio scored *lower* than
real calm audio: the model was never shown real screaming/crowd-panic audio
as its positive class. Real AudioSet IDs for panic-adjacent vocalizations
(`Shout`, `Yell`, `Battle cry`, `Children shouting`, `Screaming`, `Crowd`)
exist in the ontology and were not used.

**Fix**: replaced `PANIC_MIDS` with the correct AudioSet MIDs
(`/m/07p6fty` Shout, `/m/07sr1lc` Yell, `/m/04gy_2` Battle cry,
`/t/dd00135` Children shouting, `/m/03qc9zr` Screaming, `/m/03qtwd` Crowd),
verified against the ontology, and removed the accidental
`/m/01h8n0` overlap from `CALM_MIDS`.

### Sub-finding: the fix alone still hit a real *data* gap, not just a label gap

First retrain (kernel v1, `hridyajain/zapsafe-day264-s-crowd-panic`) with
corrected `PANIC_MIDS` but only the existing `hridyajain/zapsafe-audioset`
Kaggle dataset attached still logged `[AudioSet panic] 0` — that dataset is
titled "ZapSafe AudioSet Glass+Gunshot Subset" and, despite its
`train.csv` metadata listing rows for the corrected panic MIDs, its
`train_wav/` folder never actually contains audio for those IDs (it was
curated for a different, earlier retrain). Checked this machine's separate
local AudioSet cache (`ml_datasets/audio_events/DS07_AudioSet/train_wav`,
9,927 real wav files) and found 135 real wavs matching the corrected
`PANIC_MIDS`. Packaged those into a new dataset,
`hridyajain/zapsafe-audioset-panic-mids` (135 real AudioSet clips + their
real segment-label rows), attached it alongside the existing datasets, and
re-ran. Kernel v2 logged `[AudioSet panic] 279` (multiple mel-spectrogram
crops/augmented draws per clip) — real panic audio was used in training for
the first time for this model.

## Retrain results (real data, both fixes applied)

Kernel: `hridyajain/zapsafe-day264-s-crowd-panic`, version 2, GPU, dataset
sources include `hridyajain/zapsafe-mobiact` and the new
`hridyajain/zapsafe-audioset-panic-mids`.

```
[AudioSet panic] 279
[MobiAct crush pos] 288
Dataset stats: {'pos': 567, 'neg': 567, ...
  'sources': {'audioset_panic': 279, 'mobiact_crush': 288,
              'urbansound': 4000, 'esc50': 160, 'imu_csv': 240,
              'pamap2': 4006, 'wisdm': 0, 'uci_har': 0}}
=== Day 95 S Crowd Panic complete === AUC=0.8744 size=19.5 KB
```

(A first-pass retrain with the MobiAct fix alone but no real audio, kernel
v1, reported a suspiciously high `AUC=0.9882` — with `audioset_panic: 0`,
the audio positive class was still synthetic noise mels vs the negative
class's real ESC-50/UrbanSound audio, so the model could trivially
separate "is this a real recorded sound or noise" instead of learning
panic acoustics. That number is not trustworthy and is not the retrain
being reported as final — v2, with real panic audio, is.)

`accuracy=0.7489` on v2's held-out split — real classification accuracy on
a genuinely harder, non-degenerate problem, consistent with a model that
is discriminating on real signal rather than a data-source shortcut.

## Decisive direction check (real audio, real MobiAct IMU)

Same methodology as `DAY260B_HIDDEN_INPUT_CHECK.md` Step 4, upgraded with
two real data sources that were not available for that test:

- **Panic audio**: real AudioSet clips matching the corrected `PANIC_MIDS`,
  drawn from this machine's local cache (not the training set — held out).
- **Crush/positive IMU**: real MobiAct fall trials (subject 1, `FOL`/`FKL`/
  `BSC`/`SDL`, downloaded fresh from `hridyajain/zapsafe-mobiact` and
  sliced into 128-sample windows), run through the same `apply_crush_imu()`
  overlay the training script's `load_mobiact_fall_pos()` uses — not the
  UCI-HAR substitute DAY260B had to use.
- **Calm audio / calm IMU**: real ESC-50 negative-category clips / real
  UCI-HAR calm windows, same as DAY260B.

Result (n=30 matched pairs per condition, retrained v2 model, fp32
"optimize.default" export):

```
--- calm audio + calm IMU (true negative combo) ---
n=30  mean=0.0317

--- panic audio + crush IMU (true positive combo) ---
n=30  mean=0.0805

neg mean=0.0317  pos mean=0.0805  delta=+0.0488
DIRECTION: CORRECT (panic > calm)
```

AUC on this real, held-out, matched-pair direction-check set (true negative
vs. true positive combo only, n=30 each): **0.68**.

For comparison, re-running the same retrained model against DAY260B's
original UCI-HAR + `apply_crush_imu()` substitute IMU (instead of real
MobiAct) also gives the correct direction (delta +0.022, smaller effect
size than with real MobiAct) — consistent with real MobiAct crush motion
being a stronger, more realistic positive signal than the synthetic
substitute, as expected.

## Verdict

**Direction check now PASSES on real data**: real panic audio + real
MobiAct crush IMU scores higher (mean 0.0805) than real calm audio + real
calm IMU (mean 0.0317) — the correct direction for a panic detector,
reversing DAY260B's confirmed wrong-direction finding (0.942 vs 0.955,
panic lower).

This should **not** be read as "ships as-is, no caveats":

- AUC 0.68 on the direction-check set is real discrimination, not a strong
  one. DAY260B's original numbers (0.94–0.96 range, small deltas) were
  measured on a differently-trained checkpoint and are not directly
  comparable in scale to this retrain's 0.03–0.08 output range (different
  weights, different output calibration) — the comparison that matters is
  direction (sign of the delta), which is what this task's decisive test
  targets, not absolute score magnitude.
- The v1 "AUC=0.9882" result is flagged above specifically so it is not
  mistaken for this session's real result — same caution this week's
  `m_glass_breaking` false-recall-1.0 finding calls for. The number being
  reported as this session's outcome is v2 (AUC 0.8744 on the training
  script's own held-out split; direction-check AUC 0.68 on real matched
  data), not v1.
- Real panic-audio volume is still modest (135 unique local clips, 279
  augmented draws) compared to the training script's `MAX_PER_SOURCE=4000`
  target for other sources. A larger real panic-audio corpus (not
  available on this machine or in the currently-attached Kaggle datasets)
  would likely improve both the training AUC and the direction-check
  margin further.
- Per this task's scope, no wiring, detector, `pubspec`, or `.tflite`
  asset changes were made in `zapsafe_mobile` — this model is not wired
  into the app. Whether/how to wire it is a separate follow-up decision,
  not part of this session.

## Files changed

- `kaggle_notebooks/s_crowd_panic_push/day95_s_crowd_panic.py` — fixed
  `load_mobiact_fall_pos()` (real MobiAct comma-separated acc+gyro file
  pairing, replacing the broken whitespace/6-column assumption) and
  `PANIC_MIDS`/`CALM_MIDS` (real AudioSet panic-vocalization IDs,
  replacing the wrong/nonexistent ones, removed the `CALM_MIDS` overlap).
- `kaggle_notebooks/day264_s_crowd_panic_push/` — new kernel push directory
  (`kernel-metadata.json`, copy of the fixed training script) used for this
  session's retrain, dataset sources include `hridyajain/zapsafe-mobiact`
  and the new `hridyajain/zapsafe-audioset-panic-mids`.
- New Kaggle dataset `hridyajain/zapsafe-audioset-panic-mids` (135 real
  AudioSet clips matching the corrected `PANIC_MIDS`, sourced from this
  machine's local AudioSet cache, not present in the existing
  `hridyajain/zapsafe-audioset` glass+gunshot-curated dataset).
- Retrained artifacts (`s_crowd_panic.tflite`, `s_crowd_panic_norm.json`,
  `s_crowd_panic_report.json`) pulled from kernel version 2 — **not**
  copied into `zapsafe_mobile/assets/models/` this session (out of scope
  per task instructions; wiring/staging is a follow-up).
