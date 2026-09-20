# Day 335 — M3 into the DCS scene slot, and the second break in the same path

The scene slot has contributed a constant **0** to the fused Danger
Confidence Score since the day a real model first landed in it. Day 326
found that; Day 327 fixed motion and left scene deliberately, because
`scene_analyzer_v1` is near-chance (0.594) and a noisy input is worse than an
absent one. `m3_violence_temporal` (AUC 0.9176 end-to-end, Day 334) is the
first thing worth putting there.

## What changed in the engine

`DCSInferenceEngine.infer()` takes a `sceneResultOverride`, mirroring the
motion override from Day 327. Two decisions inside it are worth stating.

**The danger key is now `'violence'`, not `'outdoor'`.**
`scene_analyzer_v1`'s labels are `indoor`/`outdoor`/`transit`, and **none of
them is a danger class** — being outdoors is not evidence of danger. Had that
slot ever loaded, a confident `outdoor` reading would have pushed the fused
score up for no reason at all. It stubbed to 0 in practice, so nothing
regresses by dropping it; M3's `violence` is the first real danger
probability this input has ever carried.

**A burst older than `kSceneMaxAgeMs` (30 s) is discarded, not decayed.**
The scene slot is unlike the other two: audio and motion produce a result
every window, while an M3 burst is 16 `takePicture()` calls plus 16 encoder
passes and runs rarely, on demand. Without a bound, one violence reading
would keep inflating the DCS score for as long as the app stayed up. The
check is on **absolute** time difference, so a burst dated far in the future
(clock skew) is rejected too, and it lives in the engine rather than at the
call site because a caller forgetting it would silently reintroduce the
problem in the path that drives SOS.

The fusion reads the raw `violence` **probability**, not the thresholded
label. M3 fires on 13% of NonFight clips at its 0.5 midpoint; reading the
label would make every one of those a full-weight danger signal, while
reading the probability scales the contribution.

## The second break, found while wiring this

`DCSScoreWatcher.observe()` — the thing that decides whether to escalate —
began:

```dart
final scream = score.fusion.classScores['scream'] ?? 0;
```

**The fusion has never produced a `'scream'` key.**
`DCSInferenceEngine.create()` builds that slot with
`classLabels: ['safe', 'danger']`, for both the stub and the real-model
branch, so `LinearStubInterpreter` emits exactly `safe` and `danger`. The
lookup resolved to null and was coerced to 0 on **every window**, which means
neither `alertThreshold` (0.75) nor `autoSosThreshold` (0.85) could ever be
crossed regardless of what the sensors saw.

So the escalation path had **two independent breaks**. Day 326/327 found the
fused score capped at 0.50 against a 0.75 threshold and fixed the wiring so
the score could rise. The code reading that score was still looking at a key
that does not exist, so escalation stayed dead — and nothing threw, because
`?? 0` is a perfectly well-formed default.

`day335_dcs_scene_slot_test.dart` pins it: a maximal-danger window leaves
`classScores['scream']` **null** while `classScores['danger']` exceeds 0.49.

### Why the tests did not catch it

`test/unit/dcs_score_watcher_test.dart` built its fixture by hand:

```dart
classScores: {'scream': screamProb, 'normal': 1 - screamProb, 'shout': 0},
```

That is a shape **only the test produced**. `month2_runner.dart`'s
`dcsWatcher()` integration probe did the same thing and reported PASS. A
fixture that invents its own contract will agree with any implementation that
shares the invention, which is how twelve passing tests and a green
integration probe coexisted with an escalation path that could not fire.

Both now build `{'safe': 1 - p, 'danger': p}`, matching what
`LinearStubInterpreter` actually emits, so they exercise the real path.

## What this does to escalation — stated plainly, because it is a real change

| | before | after |
|---|---|---|
| fused ceiling | 0.80 | **1.00** |
| alert (0.75) | reachable, 0.05 margin | reachable |
| auto-SOS (0.85) | **impossible** | **reachable** |
| watcher could fire at all | **no** | yes |

`0.85` single-window auto-SOS is now reachable for the first time. It still
requires near-saturation on **all three** modalities: two saturated with the
third silent gives `0.5 + 0.3 = 0.80`, still below 0.85. That property is
pinned by test.

The cost is also pinned. A spurious burst at 0.9 contributes `0.2 × 0.9 =
0.18` — far short of alerting on its own, but enough to tip a borderline
case: scream 0.9 + motion 0.9 was 0.72 and below threshold, and adding a
false 0.9 scene takes it to 0.90. Given M3's 13% false-fire rate on NonFight,
that is a real exposure, and it is the reason for both the staleness bound
and the decision to read probabilities rather than labels.

## Still not done

* **Nothing triggers a burst.** The detector loads and the slot accepts a
  result, but no caller captures one. What should prompt a burst — and
  whether a camera capture is acceptable at that moment — is a product
  decision.
* **Weights are still guessed.** `[0.5, 0.3, 0.2]` predates any measured
  number, and the ordering remains inverted against measured reliability:
  motion 0.999 carries 0.3 while scream 0.839 carries 0.5. M3 at 0.918 now
  sits in the smallest slot.
* **`dcs_fusion_v1` is still a placeholder**, correctly deferred to real beta
  incidents.
* **Nothing has run on a physical device.** Every number here is from held-out
  datasets and unit tests.

832 tests pass, `flutter analyze` unchanged at 57 issues, 0 errors.
