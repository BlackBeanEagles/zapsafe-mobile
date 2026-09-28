# Day 364D — scream dropped from the DCS gate. Two inputs, and it costs nothing.

> **Scenario B is reinterpreted by DAY365.** `motion_fall_v2` was measured
> off-corpus and holds (AUC 0.9905 vs 0.999 on its own corpus, per-window
> false-positive rate on ordinary activities **0.07%**). Scenario B —
> "ambient audio + a *sustained* fall" — is therefore a **conditional**, not
> a measured false-alarm frequency: when motion sustains high, a fall almost
> certainly happened, so those escalations are largely correct. The
> comparisons here are matched-rate and unaffected, but read B as "how often
> this config escalates when motion asserts", not "how often it is wrong".
> See `DAY365_MOTION_FALL_SURVIVES_OFF_CORPUS.md`.

Day 364C searched every weighting of the three-input fusion and found no
configuration that keeps the gate usable while scream is in it. The binding
constraint was the detector, not the weights: `scream_classifier_v5`
separates ambient media audio from violent audio at window-level AUC
**0.606**, so any linear rule that lets audio+motion fire also fires on
television plus a fall.

The decision taken was to remove scream from the gate. This implements it.

## The configuration

```
                    was                 now
weights    0.50 / 0.30 / 0.20    0.00 / 0.52 / 0.48   (scream / motion / scene)
alert threshold      0.75                0.66
auto-SOS             0.85                0.90
```

Weights and thresholds were chosen **together**, against measured scenarios,
not picked. On 60 ambient and 60 violent XD-Violence videos, per window,
under `requiredConsecutiveWindows = 3`:

```
                                    ambient   ambient    violent
                                     alone    + fall     + fall
three-input 0.5/0.3/0.2 @0.75        0.000     0.283      0.600
two-input   0.0/0.52/0.48 @0.66      0.000     0.267      0.617
```

**Better on both axes.** Fewer false alerts and more detection, with scream
removed. It was contributing noise to the gate, not evidence.

At matched false-alarm rate the comparison is +0.017 detection, i.e. a wash —
the honest summary is that dropping scream **costs nothing measurable**, not
that it improves things.

### Why the thresholds moved in opposite directions

`alertThreshold` went **down** (0.75 → 0.66) and `autoSosThreshold` went
**up** (0.85 → 0.90). That is not inconsistent: the scale changed. With
scream gone the fused score concentrates into two inputs, so 0.90 now means
"motion and scene both near-maximal" where 0.85 on the old scale bought a
looser combination.

A 0.14 margin separates the largest single weight (0.52) from the alert
threshold, so **no single modality can alert alone**. The search also offered
0.58/0.42 @0.59 with a 0.01 margin; it was rejected for being a knife edge.

### auto-SOS is the weakest part of this

It bypasses the three-window vote and fires SOS automatically, so it was
chosen on false-bypass rate:

```
t       ambient+fall bypasses    violent+fall bypasses
0.85         10.0%                    20.0%
0.90          3.3%                     6.7%
0.95          1.7%                     1.7%    <- discrimination gone
```

**~2:1 at best.** 0.90 is the least bad point on that curve, not a good one.
Raising it further buys nothing. A control that skips confirmation deserves
better than 2:1, and that is a real limitation of the current detectors, not
of the threshold.

## The trap this nearly walked into

Removing scream from the fusion would have broken the camera.

`ViolenceBurstCoordinator` triggered on the **fused** score, and its 0.45
threshold was derived from `audioWeight 0.5 × a confident scream 0.9`. With
`audioWeight = 0`, a scream moves the fused score not at all — so the camera
would never investigate a scream.

That is a new reachability trap of exactly the **Day 326** shape: the gate now
needs `motion + scene`, scene comes from a burst, and bursts came from audio.
Audio evidence still has to be able to *start* an investigation even though
it no longer votes on escalation.

So the coordinator now reads the **raw scream probability** from the audio
slot, with the fused score passed separately to suppress bursts once the app
is already escalating. Trigger threshold **0.45 → 0.90**, chosen from the
measured per-window distribution:

```
t       ambient windows   violent windows   ratio
0.80        8.1%              21.7%         2.68x
0.90        3.2%              12.5%         3.97x
0.95        1.2%               8.1%         6.88x
```

0.80 would fire roughly every 18 s of ordinary television.

**This is the right use of a weak signal.** A burst costs battery, not a
false alarm to the user, so a detector too unreliable to escalate on can
still be good enough to say "point the camera" — and the far stronger m3
detector then decides. Scream loses its vote and keeps its job as a scout.

(The coordinator is not yet wired into the live path — `shouldTrigger` has no
caller in `lib/` outside its own file — so this was a design correction
rather than a live bug. It would have become one the moment it was wired.)

## The accepted cost

**The app is now deaf to audio-only incidents at the gate.** An incident with
a scream but no fall and no camera burst will not escalate on audio alone.

That was already nearly true: on the old weights audio alone had a ceiling of
0.50 against a 0.75 threshold, so it could never escalate by itself either.
What changes is that a scream can no longer *contribute* to a combination.
It can still start a burst, and the burst can still carry a real threat over
the line through the scene slot.

`ScreamDetectorV2` is untouched. It still runs, still reports, and its score
is still surfaced. It was removed from escalation, not from the app.

## Tests

`dcs_fusion_reachability_test.dart` was rewritten. The Day 326 and Day 335
arithmetic is preserved but pinned against **explicit historical constants**
rather than the live ones, so it keeps documenting two real bugs instead of
silently ceasing to mean anything. New assertions cover: no single modality
reaching the gate, the 0.14 margin, `motion + scene` remaining reachable,
auto-SOS needing both inputs, and scream contributing exactly zero.

`dcs_engine_test.dart` had a test asserting a scream *raises* the fused
score. It now asserts the opposite, with the reason, plus that the scream
detector still distinguishes its inputs in the audio slot — the vote is gone,
the detector is not.

890 tests pass; analyze at 57 issues, 0 errors.

## Caveats

The scenario data is XD-Violence: movie, CCTV and web video. "Violent" there
is not this app's SOS case, so the detection column is a proxy. The
false-alert column is the trustworthy one — it is measured on the negative
class and does not depend on the incident labels being the right construct.

Scenario B is "ambient audio + a **sustained** fall". If `motion_fall_v2` is
correct, a fall did happen and alerting is arguably right; B is only a false
alarm if the motion detector is wrong. Its real-world false-positive rate has
never been measured — the gate scores it 0.999 on UniMiB, the corpus it
trained on, and it is the last detector never tested off-corpus. That
measurement would change how this table should be read.

Reproduce: `work/fusion/fusion_solve.py` and the chosen configuration in
`fusion_chosen.json`.
