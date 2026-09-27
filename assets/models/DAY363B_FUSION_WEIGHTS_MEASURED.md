# Day 363B — the DCS fusion weights are inverted. Do not just swap them.

`dcs_inference_engine.dart` fuses three detector scores with weights written
on Day 31 and never derived from anything:

```
fused = 0.5*scream + 0.3*motion + 0.2*scene      alert threshold 0.75
```

This measures what each input is actually worth, through each model's real
`.tflite` path on real labelled data.

## What each input is worth

Calibrated as a log-likelihood ratio — `LLR(s) = log[P(s|danger)/P(s|safe)]`
— fitted by logistic regression on measured scores against real labels. The
**LLR span** is how many nats of evidence a detector's score range actually
carries, which is the thing a fusion weight should be proportional to.

```
input      AUC      LLR span   implied w   shipped w
scream   0.8600      3.658       0.274        0.50
motion   0.9986      5.127       0.384        0.30
scene    0.9085      4.569       0.342        0.20
```

**The ordering is exactly inverted.** The most reliable input (motion, AUC
0.9986) is weighted lowest of the pair that matters; the least reliable
(scream) is weighted highest.

Calibration is monotone, so no single detector's AUC changes. The point is
to make the three scores *addable* — at present a 0.9 from motion and a 0.9
from scream are treated as equal evidence, and they are not.

### A hypothesis I had to withdraw mid-way

I expected scream to be badly over-weighted because its card is known to
overstate it. Measured on AudioSet, out of domain, `scream_classifier_v5`
reads **AUC 0.8600** — *higher* than its 0.828 gate figure, and its shipped
0.50 against an implied 0.528 looked almost right.

That comparison was against glass and gunshot, which are **not** the
fusion's inputs. Against the three real inputs, scream is indeed the weakest
— but weakest of three good rankers, not bad.

The "fires on ~6% of real screams" finding is about **recall at the shipped
threshold**, not ranking. A detector can rank well and still have a badly
placed threshold. Conflating the two was the error.

## Why swapping the weights would be a bug, not a fix

Which combinations can reach the 0.75 alert threshold, with every firing
detector at ~1.0:

```
combination            shipped        implied
scream                 0.500  --      0.274  --
motion                 0.300  --      0.384  --
scene                  0.200  --      0.342  --
scream+motion          0.800 ALERT    0.658  --
scream+scene           0.700  --      0.616  --
motion+scene           0.500  --      0.726  --
all three              1.000 ALERT    1.000 ALERT
```

Under the shipped weights, **scream+motion reaches the threshold** — the
"two independent modalities agree" property the engine's own doc describes
as the point of the fusion.

Under reliability-implied weights, **only all three together can alert.**
And scene is the one input that is usually absent: an M3 burst runs on
demand and is only counted for 30 s (`kSceneMaxAgeMs`).

So a naive weight swap would make DCS escalation nearly unreachable — which
is **exactly the Day 326 bug** (`DAY326_DCS_FUSION_NEVER_FUSED.md`), where
the fused score was capped at 0.50 against a 0.75 threshold and
`onDCSThresholdExceeded` could never fire.

The arbitrary Day 31 weights accidentally encode a sensible safety
property. The reliability-correct weights destroy it. **Both facts are
true, and that is why this is not a one-line change.**

## What a real LLR fusion says

Summing calibrated LLRs and converting to a probability, at an assumed 1%
danger base rate:

```
nothing firing    P(danger) = 0.0000
scream only                   0.0010
motion only                   0.0035
scream + motion               0.0949
motion + scene                0.1977
all three                     0.8797
```

This is the honest reading of the current detectors: **two modalities
agreeing does not justify high confidence**, because none of the three is
strong enough on its own. Only all three together clears 0.5.

It also exposes the hidden variable. That table moves a lot with the assumed
prior, and the prior — what fraction of monitored time is a real incident —
is a **product decision nobody has made**. At 1% the fusion is very
conservative; at 10% two modalities would look quite different.

## Decision

**Nothing changed.** Not the weights, not the threshold.

Changing either alters when the app raises an SOS, the reachability
analysis above shows the obvious fix breaks a safety property, and the
principled alternative needs a prior that has not been chosen. Shipping a
silent change to SOS escalation on my own judgement of an unmeasured prior
is not a call I should make.

What is now available that was not before:

* the **measured** evidence weight of all three inputs, out of domain;
* the calibration constants for a real LLR fusion (`a`, `b` per input);
* a reachability table for any candidate weighting;
* the specific trap that the obvious fix walks into.

## The recommendation, for a decision

Re-weight **and** re-derive the threshold together, choosing the prior
explicitly and stating which combinations should alert. A defensible target:
keep `scream+motion` alerting (it is the common real case, since scene is
usually stale) while making `all three` clearly stronger than it is today.
That is a threshold-and-prior choice, not a weight choice.

Until then the shipped behaviour stands, and it is now documented as
*accidentally reasonable* rather than *correct*.

## Caveat

Per-detector calibration is fitted on real labelled data per modality —
scream on AudioSet (123 pos / 900 neg), motion on the gate's UniMiB fixture
(80/160), scene on the gate's RWF fixture (215/400). The **fused** model is
not validated end to end, because that needs co-occurring multi-modal
incident data, which is precisely what M9 has always lacked. Conditional
independence between detectors is assumed and is wrong in detail — a violent
scene and a scream co-occur. It is the standard first-order approximation
and it is stated, not hidden.

Reproduce: `work/fusion/{calibrate_fusion,calibrate_motion_scene}.py`,
reports in the matching `.json`.
