# Day 337 — vocal stress was never wired, plus the M3 burst trigger and threshold

## 1. The correction: m5 vocal stress has never run

`model_registry.dart` said, against the `m5_vocal_stress_v2` entry:

> `// WIRED and verified. VocalStressDetector loads it; ...`

**It was not wired.** `VocalStressDetector` existed, was gate-verified, and
had librosa-parity feature tests — but **nothing in `lib/` ever constructed
it**. No provider, no pipeline, no caller. The registry loaded the asset at
startup, validated it, and then nothing used it. The only reference to the
class outside its own file was that comment.

Every status table in this project — including ones written this week —
listed m5 as wired. It was shipped and verified, which is not the same
thing, and the comment asserting otherwise is precisely why nobody looked.

So "wire the new English model" turned out to mean **wiring vocal stress at
all, for the first time**.

## 2. Wired by locale, not by replacement

The obvious move was to swap `m5_vocal_stress_v2` (Mandarin, 28 features) for
`m4_vocal_stress_en_38` (English, 0.8321). That would have been wrong:
prosodic stress does not transfer across languages, measured at **0.4537**
English→Mandarin. Replacing one with the other halves coverage rather than
upgrading it.

`vocalStressDetectorProvider` chooses by device locale:

| locale | model | features | held-out AUC |
|---|---|---|---|
| `zh*`, `cmn*`, `yue*` | `m5_vocal_stress_v2` | 28 | 0.7988 |
| everything else | `m4_vocal_stress_en_38` | 38 | **0.8321** |

English is the unknown-locale fallback — both the stronger model and the
likelier match.

The detector now carries **two input contracts**, which is the risk this
introduces, so the loader enforces the pairing rather than trusting it:

* `tryLoad` accepts a norm file of 28 **or** 38 constants, and requires the
  model's own input tensor to match that width. A 38-feature model paired
  with 28 constants would standardise the wrong columns and produce
  confident nonsense with nothing thrown.
* `inferPcm` dispatches on the loaded width — `compose38()` or `extract()` —
  rather than assuming 28.

Still missing: a **pipeline**. The detector now loads and can infer, but
nothing feeds it a continuous PCM stream the way `ScreamAudioPipeline` does
for scream. That is the remaining step before vocal stress contributes
anything at runtime, and it is deliberately not bundled in with the wiring
fix.

## 3. The M3 burst trigger

`ViolenceBurstCoordinator` decides **when** a camera burst is justified.

A burst fires when the fused DCS danger sits in
`[0.45, alertThreshold)` — suspicious, but not yet alerting:

* **below** it, nothing has happened and pointing a camera is unjustified;
* **above** it the app is already escalating, and a capture that takes ~3 s
  to answer arrives too late to inform the decision.

**0.45 is exactly where an uncorroborated confident scream lands** —
`audioWeight 0.5 × 0.9` with motion and scene silent. That is the situation
that should go looking for corroboration, which is why the threshold sits
there rather than at a round number.

Bounded four ways:

* **90 s cooldown** — a sustained above-threshold stretch must not burst
  continuously. Suppressed attempts are *counted*, not silently dropped.
* **Single-flight** — captures take seconds; overlapping them would queue
  the camera.
* **OS camera permission** — `CameraFrameService.ensureInitialized` returns
  false without it, so a user who has not granted camera access never
  triggers a capture. That is the privacy gate and it belongs to the OS.
* **Staleness** — the engine independently discards any burst older than 30 s
  (Day 335), so even a handed-over stale result cannot inflate the score.

Dependencies are injected as **functions** rather than service objects, so
"when is pointing a camera at the user justified" is testable with no camera
and no native interpreter attached. That is not only a testing convenience:
the decision deserves verification independent of whether hardware happens to
be present.

## 4. M3 threshold: 0.5 → 0.80

Calibrated on all 670 held-out val clips:

| t | recall | precision | false-positive rate |
|---|---|---|---|
| 0.90 | 0.373 | 0.956 | 0.019 |
| **0.80** | **0.538** | **0.935** | **0.040** |
| 0.70 | 0.613 | 0.910 | 0.065 |
| 0.50 | 0.743 | 0.862 | **0.127** |

The sigmoid midpoint fired on **12.7%** of non-violent clips. At 0.80 that is
**4.0%** — a third as many — for recall 0.743 → 0.538.

Precision is the right purchase here. This is a **corroborating** signal,
captured only after something else raised suspicion, so a miss costs a
confirmation the app was not relying on; a false positive puts a "violence"
event in the user's feed and the backend. And escalation actually fires now
(Day 335), so a wrong label is no longer harmless.

Note the threshold does **not** gate the DCS contribution — the fusion reads
the raw `violence` probability deliberately, so a borderline burst
contributes proportionally rather than all-or-nothing. What this controls is
the reported label, and therefore what gets submitted.

## 5. A second correction: scream's threshold

Earlier in this session I said `scream_classifier_v3` "misses half of real
screams at the default threshold", from the gate's `rec@0.5 = 0.489`.

**The app ships 0.30, not 0.5.** The gate reports a fixed 0.5 that is not the
operating point. Measured on the same real AudioSet fixture:

```
 thresh   recall  precision
  0.50    0.489    0.759
  0.35    0.644    0.707
  0.30    0.689    0.660   <- shipped
  0.20    0.778    0.614
```

At the shipped threshold it is recall **0.689**, not 0.489. The detector is
meaningfully better than I described it.

## Status

| | |
|---|---|
| vocal stress | detector wired by locale; **pipeline still missing** |
| M3 burst | trigger built and bounded; coordinator not yet subscribed to the DCS stream |
| M3 threshold | calibrated 0.80 on 670 held-out clips |
| device | **nothing has run on physical hardware** — `adb devices` is empty |

841 tests pass, `flutter analyze` unchanged at 57 issues.
