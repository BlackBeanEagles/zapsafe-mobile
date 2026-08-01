# Day 281 — evaluating `s_crowd_panic_b/c/d` sibling checkpoints against real data

Follow-up to `DAY264_S_CROWD_PANIC_MOBIACT.md` (fixed the MobiAct IMU loader and
the wrong AudioSet `PANIC_MIDS`, retrained `s_crowd_panic_a`/`s_best` to real
AUC 0.8744, direction check passes) and `DAY265_CROWD_PANIC_WIRING.md` (wired
`s_crowd_panic_a` into the app as the `crowd_panic` event type). This session
evaluates the three sibling checkpoints that were never individually assessed
this week: `s_crowd_panic_b.tflite`, `s_crowd_panic_c.tflite`,
`s_crowd_panic_d.tflite` (staged at
`kaggle_notebooks/day108_int4_m9_push/day108_kaggle_output/saved/int4_m9/day108-int4-m9-kaggle-20260703-v5-production/tflite_staging/`).

## 1. What `a`/`b`/`c`/`d` actually are

Found the real sweep leaderboard:
`kaggle_notebooks/day102_sweep_push/day102_sweep_kaggle_output/saved/sweep/s/s_sweep_leaderboard.json`
(`build_id: day102-sweep-kaggle-20260625-v5-s-recovery`). The letters are
**architecture-capacity variants from a single Day 102 sweep**, defined in
`kaggle_notebooks/day102_sweep_push/day102_sweep_common.py::build_dual_model()`:

| arch | name | mel branch | IMU branch | fusion dense | int8 / f32 size |
|---|---|---|---|---|---|
| a | `small_dual` | Conv2D(16)→pool→Conv2D(32)→GAP | Conv1D(32)→GAP | Dense(64) | 19.7 / 44.1 KB |
| b | `medium_dual` | Conv2D(32)→pool→Conv2D(64)→GAP | Conv1D(48)→Conv1D(96)→GAP | Dense(96) | 60.4 / 200.5 KB |
| c | `large_dual` | Conv2D(64)→pool→Conv2D(128)→GlobalMax | Conv1D(64)→Conv1D(128)→GlobalMax | Dense(128) | 146.0 / 530.2 KB |
| d | `deep_dual` | Conv2D(32)→pool→Conv2D(64)→GAP | Conv1D(32)→LSTM(64) | Dense(96) | 445.7 / 598.8 KB |

Real, distinct architectures (increasing conv width/depth a→c, plus d swaps
the IMU branch for an LSTM instead of more conv/pool) — not random noise, as
the task suspected might need checking.

**Confirmed real tensor shapes for all four independently** via
`interpreter.get_input_details()`/`get_output_details()` (not assumed to
match `a`'s signature): all four staged `.tflite` files have the identical
two-input signature `serving_default_imu:0 [1,128,6] float32` /
`serving_default_mel:0 [1,64,64,1] float32` → `[1,1] float32` output. Same
input contract, different internal capacity — consistent with a pure
architecture-capacity sweep on one fixed I/O spec.

**Important distinction the task context didn't state explicitly**: the
staged `s_crowd_panic_a.tflite` in `tflite_staging/` (20,200 bytes) is **not**
the same file as the wired, Day264-retrained `s_crowd_panic_a`/`s_best`
(19,936 bytes, md5 `4d67fc0d020d91ed0c994b764a448fef`, per
`DAY265_CROWD_PANIC_WIRING.md`). The staged `a` is the original Day102
sweep-winner checkpoint (`test_auc=1.0` in the leaderboard); the wired `a` is
a *separate, later* retrain of the same architecture using Day264's fixed
loaders. Confirmed by file size and by reading the sweep leaderboard's own
`data_stats` (below) — the sweep checkpoint predates both Day264 fixes.

**All four sweep checkpoints (a/b/c/d) were trained on the same, pre-fix
dataset** — leaderboard `data_stats` for every arch shows
`"audioset_panic": 0, "mobiact_crush": 0, "synth_push": 400"` — i.e. none of
them, including the sweep's own `a`, ever saw real panic audio or real
MobiAct crush IMU during training; the positive class was synthetic noise
mel + synthetic push-IMU. This is the same root cause `DAY264` diagnosed and
fixed for the model that got wired — the sweep predates that fix entirely.

Also confirmed (`day102_sweep_common.py::run_dual_sweep`) that the sweep
training loop applies **no mel/imu normalization at all** — raw
`power_to_db` mel values and raw IMU units go straight into the model, no
`(x - mean)/std` step, unlike the Day264-fixed `day95_s_crowd_panic.py`
export path. None of `b_norm.json`/`c_norm.json`/`d_norm.json` contain
mean/std constants (only `arch`/`data_stats`), consistent with this. Real
raw (unnormalized) features were used for this session's evaluation to match
what each checkpoint actually saw in training.

## 2. Real-data evaluation methodology

Same direction-check methodology as `DAY264`'s decisive test:

- **Panic audio**: real AudioSet clips matching the corrected `PANIC_MIDS`
  (Shout, Yell, Battle cry, Children shouting, Screaming, Crowd), drawn from
  this machine's local `ml_datasets/audio_events/DS07_AudioSet/train_wav`
  cache (9,927 real wavs) via `train.csv` label matching — n=30.
- **Crush/positive IMU**: real MobiAct fall trials (`FOL`/`FKL`/`BSC`/`SDL`),
  extracted for real from `kaggle_datasets/zapsafe-mobiact/mobiact.zip` (630
  real acc/gyro files), paired acc+gyro by filename, run through
  `apply_crush_imu()` — n=30. (Subject-1-only, as Day264's own decisive test
  used, yields just 12 real acc/gyro pairs; widened to all subjects — still
  real MobiAct fall-code data — to reach n=30 for a stable estimate.)
- **Calm audio**: real ESC-50 clips (`air_conditioner`, `engine`, `car_horn`,
  `footsteps`, `street_music`, `siren` categories, `s.ESC_NEG`), from
  `ml_datasets/audio_events/DS21_ESC-50/audio/audio` — n=30.
- **Calm IMU**: real UCI-HAR train-split windows (walking/standing), from
  `ml_datasets/motion/DS11_UCI-HAR` — n=30.
- Preprocessing reused directly from the fixed
  `kaggle_notebooks/s_crowd_panic_push/day95_s_crowd_panic.py`
  (`audio_to_mel`, `apply_crush_imu`, `pad_imu`, `_read_mobiact_sensor_csv`,
  `PANIC_MIDS`, `ESC_NEG`) via import, not reimplemented, so feature
  extraction exactly matches what fixed `a`.
- Ran each of the four staged `.tflite` interpreters directly via
  `interpreter.set_tensor`/`invoke()` on the real matched pairs (n=30 pos,
  n=30 neg), no synthetic substitutes.

Script: `finals/backend/scratchpad/day281_eval.py` (scratch, not committed to
this repo).

## 3. Real results (n=30 matched pairs, staged sweep-era weights)

```
=== s_crowd_panic_a (staging, sweep-era weights — NOT the wired s_best) ===
  pos_mean=0.8914  neg_mean=0.9539  delta=-0.0625
  direction: WRONG (panic <= calm)
  direction-check AUC: 0.2733

=== s_crowd_panic_b (medium_dual) ===
  pos_mean=0.9238  neg_mean=0.9220  delta=+0.0019
  direction: CORRECT (panic > calm), but a near-zero margin
  direction-check AUC: 0.6356

=== s_crowd_panic_c (large_dual) ===
  pos_mean=0.9782  neg_mean=0.9982  delta=-0.0200
  direction: WRONG (panic <= calm)
  direction-check AUC: 0.6317

=== s_crowd_panic_d (deep_dual, IMU-LSTM) ===
  pos_mean=0.9761  neg_mean=0.9963  delta=-0.0202
  direction: WRONG (panic <= calm)
  direction-check AUC: 0.3589
```

The staged sweep-era `a` checkpoint itself **fails** the direction check
(delta -0.0625, AUC 0.27) on this real data — consistent with, and a useful
independent confirmation of, `DAY260B`'s original wrong-direction finding
that Day264 had to fix. This is expected: the sweep-era `a` predates both
Day264 fixes, same as b/c/d.

Note on AUC vs. mean-delta for `c`: AUC 0.63 despite a negative mean delta —
the two metrics disagree because AUC measures full-distribution separability
while the mean delta is a single-point summary; here the score distributions
overlap with mixed ordering, so a moderately-real (but wrong-signed) AUC and
a negative mean delta can coexist. The direction check (does panic score
higher than calm, on average) is the criterion the task specifies as
decisive, and by that criterion `c` fails.

## 4. Verdict

**All three of b/c/d are worse than, or at best comparable-and-weaker than,
the currently-shipped Day264-retrained `a`.** None should replace it:

- `b` passes the direction check but with a razor-thin margin (delta
  +0.0019, ~30x smaller than shipped `a`'s real delta of +0.0488 from
  `DAY264`) — not a meaningfully working detector.
- `c` and `d` fail the direction check outright (panic scores lower than
  calm on average).
- All three share the same root defect the shipped `a` needed fixing for:
  none of them were ever trained on real panic audio or real MobiAct crush
  IMU (`audioset_panic: 0, mobiact_crush: 0` for all four sweep arches) —
  they only ever saw synthetic placeholder positives. Bigger/deeper
  architecture (b→c→d) did not compensate for that; if anything, the largest
  (`c`) and deepest/LSTM (`d`) variants show *worse* direction-check
  behavior than the smallest (`b`), consistent with more capacity better
  memorizing the synthetic positive class's spurious cues rather than
  generalizing to real panic signal.
- This is the **expected, valid outcome** flagged in this task's own
  framing (§4): a sweep checkpoint that was not individually
  fixed/retrained this week performing worse than the one that was.

**No wiring, detector, `pubspec`, `.tflite` asset, or backend changes were
made.** Per task scope, if any variant were retrained on real data and found
to beat shipped `a`, that would be a follow-up retrain-and-swap decision, not
part of this session — and in any case none of b/c/d cleared that bar as-is.

## Files referenced (read-only this session)

- `kaggle_notebooks/day102_sweep_push/day102_sweep_kaggle_output/saved/sweep/s/s_sweep_leaderboard.json`
- `kaggle_notebooks/day102_sweep_push/day102_sweep_common.py`
- `kaggle_notebooks/day102_sweep_push/day102_s_sweep.py`
- `kaggle_notebooks/s_crowd_panic_push/day95_s_crowd_panic.py` (fixed version, reused for preprocessing)
- `kaggle_notebooks/day108_int4_m9_push/day108_kaggle_output/saved/int4_m9/day108-int4-m9-kaggle-20260703-v5-production/tflite_staging/s_crowd_panic_{a,b,c,d}.tflite` (+ `_f32` siblings, not separately evaluated — int8 staging files are representative of the same weights)
