# Day 365 — motion_fall_v2 off-corpus: it holds. And that corrects Day 364.

`motion_fall_v2` was the last detector never measured on a second corpus. Its
gate figure — **AUC 0.999** — is held-out UniMiB-SHAR, the corpus it trained
on, and every other detector measured this week lost 0.11–0.18 crossing
corpora:

```
m3_violence   0.908 -> 0.725   (-0.183)
glass         0.815 -> 0.688   (-0.127)
gunshot       0.810 -> 0.701   (-0.109)
```

Two things made it urgent rather than tidy: Day 364D dropped scream from the
DCS gate, so motion is now one of only **two** inputs carrying 0.52 of a 0.66
threshold; and Day 364's "false alert" scenario is *"ambient audio + a
sustained fall"*, which is only a false-alarm rate **if this model
false-fires**.

## It holds

MobiFall v2.0 (Apache-2.0), 24 subjects, 630 accelerometer trials,
288 falls / 342 ADLs, phone-collected:

```
AUC per trial (max over windows) : 0.9905
AUC per window                   : 0.7492
gate figure on UniMiB-SHAR       : 0.999
off-corpus drop                  : -0.0085
```

**−0.0085.** An order of magnitude smaller than any other detector's drop.
This is the first model in the project that survives a corpus change intact.

At the shipped threshold (`MotionDetectorV2.kDefaultThreshold = 0.5`),
per trial:

```
recall 0.944   precision 0.982   FPR on ADLs 0.015
```

And per activity — the breakdown that matters:

```
FALL BSC  n=72  median 0.999   fires  93.1%
FALL FKL  n=72  median 1.000   fires  93.1%
FALL FOL  n=75  median 1.000   fires  96.0%
FALL SDL  n=69  median 1.000   fires  95.7%

adl  JOG  n=27  median 0.006   fires   3.7%
adl  JUM  n=27  median 0.005   fires   3.7%
adl  WAL  n= 9  median 0.003   fires   0.0%
adl  STU  n=54  median 0.013   fires   0.0%
adl  CSO  n=54  median 0.016   fires   0.0%
adl  SCH  n=54  median 0.023   fires   0.0%
adl  CSI  n=54  median 0.030   fires   5.6%
adl  STN  n=54  median 0.048   fires   0.0%
adl  STD  n= 9  median 0.150   fires   0.0%
```

**Jogging and jumping — the hard negatives for any fall detector — score 0.006
and 0.005.** No threshold tuning needed. 0.5 is a good operating point on a
corpus it has never seen.

**Per-window false-positive rate on ordinary activities: 0.07%.** That is the
number the DCS gate actually sees, one window at a time.

## This corrects Day 364's framing

Day 364C and 364D measured a scenario labelled *"ambient media audio +
sustained fall"* at 0.283 (shipped) and 0.267 (new), and treated it as a
**false-alert rate**. I flagged at the time that it is only a false alarm if
`motion_fall_v2` is wrong, and that its real-world FPR had never been
measured.

It is now measured, and it is **0.07% per window**. So when motion sustains
high, a fall almost certainly happened — and those "false alerts" were
largely **correct escalations on real falls**.

Concretely:

* The DCS gate's real-world false-alarm behaviour is **better** than the
  Day 364 tables implied. Scenario B is a conditional — "if a fall is
  detected *and* there is television audio" — not a measured false-alarm
  frequency. With motion's FPR at 0.07% per window, the joint probability of
  that firing spuriously is very small.
* **Dropping scream from the gate remains correct**, because that was decided
  on a matched-rate comparison (+0.017 detection) and holds regardless of how
  B is interpreted. But the *motivation* I gave for it — "stop the false
  alerts" — was partly misframed. The defensible reason is that scream
  contributed no usable evidence (window-level separation AUC 0.606), not
  that it was generating alarms.
* The auto-SOS concern stands. Its ~2:1 discrimination came from the scene
  input's weakness, which this does not touch.

## Why the per-window AUC is much lower, and why that is fine

Per trial 0.9905, per window 0.7492. Most windows of a 10 s fall trial contain
no fall, so the per-window label is noisy by construction. The
max-over-windows aggregation is doing legitimate work here — this is the
opposite of the Day 363D error, where max-over-windows was used to
characterise an *ambient baseline* and inflated it. Which question is being
asked decides which aggregation is right; both are reported.

## The corpus choice was the risky part

`DS13_SisFall` was already on disk and was **rejected**. It is not raw
SisFall but a preprocessed derivative: 1024×6 windows at ~±0.2 scale, six
unlabelled channels, no stated normalisation, no indication whether gravity
was removed. Feeding it would have reproduced `i_vehicle_crash` exactly —
trained in g, fed m/s², 8× out of distribution, AUC 0.5000, nothing thrown.

MobiFall was chosen because its Readme states the contract outright:

> `timestamp(ns),x,y,z(m/s^2)` — "Acceleration force along the x y z axes
> (including gravity)."

matching `motion_fall_v2_norm.json`'s `"m/s^2 including gravity (Android
TYPE_ACCELEROMETER)"`. And it was **verified, not just read**: median
|acc| across all 630 trials is **9.73 m/s²**, i.e. gravity.

It is also phone-collected (Galaxy S3, trouser pocket), where UniMiB-SHAR is
a research harness — so this is closer to deployment, not merely different.

Resampling 90 Hz → 50 Hz is linear interpolation. Not `np.resize`, which
tiles, and not decimation, which aliases; both have caused real bugs here.

## Status

**Nothing changed.** No threshold moved, because 0.5 is already right on both
corpora — the first time this week that has been true.

| | |
|---|---|
| detectors tested off-corpus | **4 of 4** — complete |
| motion_fall_v2 | **validated**, −0.0085, threshold unchanged |
| Day 364 scenario B | reinterpreted: mostly correct escalation, not false alarm |

Reproduce: `work/fall_xcorpus/eval_motion_fall.py`, report in
`motion_fall_xcorpus.json`.
