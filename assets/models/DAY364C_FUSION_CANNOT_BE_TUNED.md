# Day 364C — the fusion weights cannot be fixed by choosing better weights

Day 363B measured the DCS fusion weights as inverted against reliability
(shipped 0.5/0.3/0.2, reliability-implied 0.274/0.384/0.342) and stopped
short of changing them, because a naive swap re-breaks Day 326. The open
item was "re-weight and re-derive the threshold together, choosing the prior
explicitly."

That was done. **There is no such configuration.**

## Reliability weighting is the wrong objective, and actively harmful

Reliability says how much a detector's score *discriminates*. A safety gate
needs the decision boundary placed so specific operating scenarios land on
the right side. Those are different objectives, and optimising the first
damages the second in a way that is easy to miss:

Swapping to reliability weights raises motion 0.30 → 0.384. Paired with the
lower threshold it needs, motion alone then covers **64%** of the threshold
instead of 40%. The scream level required for "sustained fall + ambient TV
audio" to fire drops from **0.900 to 0.788** — and ambient media audio
exceeds 0.788 far more often than 0.900.

Measured on 60 ambient and 60 violent XD-Violence videos, per-window, under
the real `requiredConsecutiveWindows = 3` rule:

```
                                        A       B       C       D
shipped      0.50/0.30/0.20 @0.75     0.000   0.283   0.600   0.000
reliability  0.274/0.384/0.342 @0.60  0.000   0.650   0.833   0.000

A  ambient audio, no motion            must NOT alert
B  ambient audio + SUSTAINED fall      must NOT alert   <- the dangerous one
C  violent audio + sustained fall      should alert
D  violent scene, no fall              should alert
```

Reliability weighting more than doubles the false-alert rate, 0.283 → 0.650.

## The search came back empty

Constraints fixed before searching: `A == 0`, `B <= 0.02`, no single
modality at 1.0 may alert, and `scream+motion` must still alert (the Day 326
reachability property).

**0 of 17,152 configurations with `A == 0` satisfy them.**

The trade-off surface, best achievable detection for each false-alarm budget:

```
  B <=    best C    config (w_s/w_m/w_sc @ T)    scream+motion alerts?
  0.00    0.067     0.42/0.44/0.14 @0.95              no
  0.02    0.083     0.24/0.60/0.16 @0.95              no
  0.05    0.200     0.38/0.40/0.22 @0.86              no
  0.10    0.367     0.40/0.46/0.14 @0.87              no
  0.20    0.617     0.16/0.38/0.46 @0.64              no
  0.28    0.700     0.14/0.34/0.52 @0.57              no
```

Two things stand out.

**Every Pareto-optimal configuration abandons the two-modality property.**
To do better you must give up the thing the fusion exists for.

**The shipped config is not on the frontier** — at its own false-alarm rate
(B = 0.283) the best achievable detection is 0.700 against its 0.600. So
about +0.10 detection is available at no extra false-alarm cost, but only by
dropping the reachability guarantee and shifting weight heavily onto scene
(0.52), which is the input most often stale.

**`D` is 0.000 everywhere.** A violent scene alone never alerts in any
configuration where `A == 0`, because the no-single-modality constraint
forces every weight below the threshold. The scene detector — the *best* of
the three, AUC 0.725 off-corpus against scream's 0.641 — cannot raise an
alert by itself by construction.

## The adaptive baseline, which should have worked, does not

If the problem is that scream sits high on all media audio, the natural fix
is to score it *relative to its own recent ambient* — "is this screamier than
the last 30 s" rather than "is this above an absolute level".

```
window-level AUC, ambient vs violent audio
  raw scream        0.6062
  adaptive (minus trailing median)   0.5083     <- chance
```

It destroys the signal rather than isolating it. In violent clips the scream
is *sustained*, so the trailing median rises with it and the differencing
subtracts exactly what it was meant to detect. Configurations satisfying
both constraints do then exist (379 of them) — at detection rates around
**0.067**, which is not a detector.

## The actual binding constraint

None of this is a weighting problem. It is that `scream_classifier_v5`
separates ambient media audio from violent audio at **window-level AUC
0.606**. Any linear rule that lets audio+motion fire will fire on TV+fall,
because to this detector they look much alike.

## Decision

**Nothing changed.** Re-weighting cannot deliver the goal, and the
alternatives all trade away either the reachability property or detection.

What is now known that was not:

* the reliability-weight swap is not merely risky, it **doubles** the
  false-alert rate;
* the shipped config is off the Pareto frontier by ~0.10 detection, and
  closing that gap costs the two-modality guarantee;
* the scene detector cannot alert alone under the current constraint set,
  despite being the strongest input;
* an adaptive scream baseline does not work, and why;
* the binding constraint is the scream detector's 0.606 separation, not the
  weights.

## What would actually move this

Day 362C measured it: **~60 real-world clips beat 320 in-corpus ones by
0.105 AUC.** Raising scream's ambient-vs-incident separation is the only
change that opens the feasible region. Tuning is exhausted.

A second, cheaper option if the goal is only to stop the false alerts:
remove scream from the gate and require **scene + motion**. That is a
product decision with a real cost — it makes the app deaf to audio-only
incidents — and it is not taken here.

## Caveats

`C` and `D` use XD-Violence violent clips as the incident proxy. Movie
violence is not this app's SOS case; it is the only co-occurring multimodal
data that exists. `B` — ambient media audio plus a sustained fall — is the
most trustworthy number here, because it is measured on the negative class
and does not depend on the incident labels being the right construct.

Reproduce: `work/fusion/fusion_solve.py`, reports in `fusion_solve.json`
and `fusion_pareto.json`; window sequences cached in
`fusion_sequences.npz`.
