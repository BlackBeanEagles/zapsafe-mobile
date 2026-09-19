# Day 329 — the `s_crowd_panic` / `k_confinement` rebuild: one is redundant, one is impossible

Day 328 measured both models non-functional and disabled them. The next step
was to rebuild the training data properly. Doing the data work first — before
writing a training script — shows that **neither model should be rebuilt**,
for two different reasons.

## The shared blocker: neither model has real positive data

This is what the Day 328 writeup implied but did not state plainly. Both
models' *negatives* are real recorded motion. Their **positives are entirely
synthetic**:

| model | positive IMU | positive second input |
|---|---|---|
| `s_crowd_panic` | `synth_push_imu` — `np.zeros` + two sinusoids | real panic audio |
| `k_confinement` | `synth_pos_from_neg` — a negative window with acc scaled 2.5–4.5x + noise | `make_light(0.0)`, a hardcoded constant |

A model trained this way cannot learn crowd crush or confinement. It can only
learn *the transform that generated the positives*, and the Day 328 probes
showed it did not even do that — it learned which dataset each window came
from, because the synthetic positives lacked the temperature offset the real
negatives carried in channel 0.

Fixing the PAMAP2 column read is necessary (cols 21–23 for acc16g and 27–29
for gyro give real 6-axis in m/s² and rad/s, which **match** what
`sensors_plus` feeds — so that part of the contract would finally be right).
But it is not sufficient, because there is still nothing real on the positive
side. MobiAct, the one real fall source these scripts referenced, is not
present locally; only UCI-HAR, MotionSense, PAMAP2, WISDM, SisFall and UniMiB
are, and none of them contain crowd crush or vehicle-trunk confinement.

## `s_crowd_panic`: redundant — the shipped scream detector already does this, better

The audio half of `s_crowd_panic` *is* real on both sides, so an audio-only
rebuild was the obvious fallback. It should not be built, because
`scream_classifier_v3` already ships and already covers this audio.

Measured against the shipped `scream_classifier_v3.tflite` on real AudioSet:

| class set | AUC vs calm | mean score | fires ≥ 0.30 |
|---|---|---|---|
| Screaming / Yell / Children shouting / Battle cry | **0.8417** | 0.5328 | 34/50 |
| **Shout / Crowd** — never in scream v3's training set | **0.8230** | 0.5007 | 30/50 |
| calm (Speech / Silence / etc.) | — | 0.1306 | 8/60 |

The second row is the one that matters. `scream_v3`'s `AS_SCREAM` set is
`{Screaming, Yell, Children shouting, Battle cry}` — four of the six
`PANIC_MIDS`. Shout and Crowd are the two it has **never seen**, and it
scores **0.8230** on them. The gap to the classes it trained on is only
0.019, so this is genuine generalisation, not memorisation.

Compare to `s_crowd_panic`'s own number on realistic phone input: **0.6062**.

**The detector already shipping beats the dedicated one by 0.22 AUC at the
dedicated one's own task.** Rebuilding `s_crowd_panic` as an audio model
would produce a second, worse copy of a detector the app already runs on
every audio window. The capability is not lost by deleting it — it was never
being provided by `s_crowd_panic` in the first place.

Recommendation: **delete**, not rebuild. Left in place for now because
`DetectionEventType.crowdPanic` maps to a backend `EventType.CROWD_PANIC`
column value, so removal is a coordinated mobile + `zapsafe_backend/ml/
models.py` change rather than an asset deletion.

## `k_confinement`: blocked on data collection, not on modelling

Both of its inputs are unavailable as real data:

* **IMU positives** — synthetic, as above. No local dataset contains a person
  confined in a vehicle trunk or similar.
* **Light** — `DAY269_K_CONFINEMENT_SCOPING.md` already recorded that no real
  ambient-light dataset exists locally; searched again for this task
  (`*lux*`, `*ambient*`, `*brightness*`, `*illumin*`, `*photometr*` across
  `ml_datasets/`, `kaggle_datasets/`, `dsfolder/`, `D:`, `E:` and `F:`),
  still zero — the single filename hit is an AudioSet clip that happens to
  contain the letters, `84Ib7tlLuXk.wav`. Day 272's
  `decorrelate_light()` samples uniformly from plausible regimes; it is a
  principled fix to the *pairing*, but the values were never measured.

So a retrain would draw both the positive motion and the light values from
distributions someone invented. That is not a model that can be validated,
and Day 328's measurement — output pinned at ~0.019, never firing at any
light value — is the predictable result of shipping one anyway.

There is also still the unfixed ordering bug: `synth_pos_from_neg` is called
at line 796, *after* the three `decorrelate_light()` calls at 752/760/764, so
its 600 positives keep `make_light(0.0)` and re-introduce the exact confound
the Day 272 retrain existed to remove. Worth fixing only if the model is ever
revived, which requires the data above.

Recommendation: **keep disabled, and treat it as a data-collection item**
(real trunk/vehicle recordings with synchronized IMU + lux), not an ML item.
It should come off the model roadmap until that data exists.

## What this means for the roadmap

Two of the seven "shipped" detectors are now accounted for as *not coming
back* without new data collection. Combined with Day 328, the standing
position is:

| detector | status |
|---|---|
| `motion_fall_v2` | works — AUC 0.999 held-out-subject |
| `scream_classifier_v3` | works — AUC 0.839, and covers crowd-panic audio at 0.823 |
| `m5_vocal_stress_v2` | works — AUC 0.850 held-out-speaker |
| `mg_gunshot_retrain` | alive, real-data AUC 0.89 |
| `h_aggressive_speech_v1` | alive, norm applied |
| `s_crowd_panic` | **redundant — delete** |
| `k_confinement_decorrelated` | **blocked on data collection** |
| `i_vehicle_crash` | needs float16 re-export + one unit system |
| `m2_motion_b_retrain` | needs the same unit fix |
| `dcs_fusion_v1` | placeholder, correctly deferred to beta data |

The honest headline is unchanged from Day 328 and is now better supported:
**three solid detectors, two more alive but unvalidated on-device, and
nothing has yet run on a physical phone.**
