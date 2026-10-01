# Day 368 — motion_fall_v2 does not fire on hard driving

Day 365 measured `motion_fall_v2`'s false-positive rate on everyday activities
(MobiFall ADL: 0.07% of windows) but never in a moving car. Harsh braking is
the obvious way a fall detector could misfire on someone who is perfectly
safe, so this checks it on real in-vehicle data.

## Data

`dinupadevinda/byd-atto-bmi160-imu-driving-events` on Kaggle, **CC BY 4.0**
(licence read from the dataset metadata, not assumed). It is a BMI160 board
lying flat in a BYD Atto on urban roads in Sri Lanka, logged at about 20 Hz,
with 10 sessions labelled `harsh_braking` or `lane_change`.

Units were **verified**, not just read from the card (which says "appears to
be m/s²"): `acc_z` reads 9.97 at rest, i.e. gravity, which matches
`motion_fall_v2_norm.json`'s "m/s² including gravity".

Attribution required by the licence: see the dataset's `CITATION.cff`.
Downloaded to `D:\zapsafe\datasets\byd_atto_bmi160\`.

## Method

Same preprocessing as the app: linear resample to 50 Hz, 100-sample windows,
hop 25, per-channel normalisation from `motion_fall_v2_norm.json`, firing
threshold 0.5.

The board lay flat, so gravity sits on z. A phone in a trouser pocket carries
gravity mostly on y. Both orientations were scored.

## Result

```
               windows  fired   max     median
as_logged        6183     2    1.000    0.0011
pocket_like      6183     2    0.766    0.0983

harsh_braking sessions (3):  max 0.002 as logged, 0.173 pocket-like. Never fired.
```

**Both firings are logger start-up artefacts.** In each case the window
contains the first two samples of a session, which read 4.2 g and then drop
straight to 1.03 g. That is the logger settling, not a jolt. The rest of the
dataset never exceeds 1.43 g.

**With those excluded: 0 of about 6,180 windows fired.**

## What this does and does not show

- It shows that real harsh braking and lane changes do not trigger
  `motion_fall_v2`, in either orientation.
- It is one car, one sensor, and one board-on-a-surface mount. A phone
  sliding off a seat during braking was not measured. That is a drop, which
  is a different hazard and the rule-based `FallDetector`'s known weakness.
- It says nothing about crash detection: the data has no crashes.

## Reminder that outranks all of this

As of Day 367, `motion_fall_v2`'s output is not read by anything in the
shipped app. The DCS stream only ticks on voiced audio, and audio capture is
started only from debug screens. This result matters once detection is
switched on.

Reproduce: `tools/day353_ml/fall_xcorpus/eval_fall_driving_fp.py`, which
writes `fall_driving_fp.json` next to it.
