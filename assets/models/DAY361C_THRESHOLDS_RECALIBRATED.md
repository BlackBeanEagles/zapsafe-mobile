# Day 361C — both audio thresholds recalibrated across two corpora

Day 361 measured glass and gunshot on AudioSet and found both shipped
thresholds miscalibrated, in opposite directions. It stopped short of
changing them because alerting behaviour is a product decision. That
decision came back: **apply both.**

```
                  was     now
glass            0.22    0.30
gunshot          0.70    0.45
```

## How the numbers were chosen

Not by optimising on AudioSet. That would repeat the original mistake in a
new corpus — and 59 AudioSet glass positives have no better claim than the
FSD50K split that produced 0.22.

One grid was swept on **both** corpora and scored by the **worse** of the
two Youden J values. The rule was fixed before looking at results,
specifically so a strong in-domain number could not average out an
out-of-domain failure. Both winners beat the shipped value on *each*
corpus, not on the mean.

## gunshot: 0.70 → 0.45

```
                  FSD50K            AudioSet
recall         0.612 -> 0.709    0.208 -> 0.532
precision      0.421 -> 0.288    0.167 -> 0.156
fires on        5.4% -> 11.2%     5.3% -> 14.6%
Youden J      +0.558 -> +0.597  +0.155 -> +0.387
```

At 0.70 this detector answered "no" to **four out of five real gunshots**.
`gunshot_detector.dart` already contains the argument against its own
predecessor: *"a signal that is on two-thirds of the time carries almost no
information into DCS fusion."* The inverse is equally true, and 0.70 was on
the wrong side of it.

**This roughly doubles the false-positive rate**, and that is the cost being
accepted. It is acceptable because this is a **fusion contributor weighted
against other signals**, not a direct SOS trigger. Recorded in the class
doc: if the detector is ever promoted to a trigger, re-derive the threshold
for that use rather than inheriting 0.45.

## glass: 0.22 → 0.30

```
                  FSD50K            AudioSet
recall         0.918 -> 0.873    0.847 -> 0.746
precision      0.219 -> 0.257    0.051 -> 0.057
fires on       44.7% -> 34.5%    59.8% -> 47.2%
Youden J      +0.470 -> +0.528  +0.249 -> +0.273
```

This one **deliberately gives up recall on a safety detector**, which is
normally the wrong direction — and this exact model has an entry in its own
class doc about under-firing being how it failed before (the 0.8754 that was
chosen on 13 positives and withdrawn).

It is right here because at 0.22 the detector fired on **60% of all
real-world audio**. That is not a detector, it is a constant, and a constant
contributes nothing to fusion regardless of its recall.

The case for 0.22 was that the score distribution is strongly bimodal, so
the extra recall was nearly free. **That bimodality is an FSD50K property.**
Off-corpus the positive and negative medians sit 0.244 apart with heavy
overlap. It is the same finding as the AUC collapse, expressed as a
threshold.

Note 0.30 is still not a *good* operating point — precision 0.057 on
AudioSet. Glass remains a weak signal. This makes it less bad, honestly
measured; it does not fix it.

## What was NOT done

* **No model was retrained or re-exported.** Both `.tflite` files are
  byte-identical to what Day 359 shipped. Only two constants changed.
* **The AUCs are unchanged** — 0.688 and 0.701 off-corpus. A threshold moves
  the operating point along a curve; it does not improve the curve.
* **`m_glass_breaking_v4`'s licence-driven retrain is still not vindicated.**
  Day 361 showed its +0.182 gain was FSD50K-specific. It ships because it is
  no worse, 3.5x smaller, and NC-free — not because it is more accurate.

## Test coverage

`test/glass_break_detector_test.dart` pins 0.30 and records all three
candidate values with why each was rejected, so the next person to touch
this sees the history rather than an unexplained constant. A second test
asserts glass and gunshot thresholds are **not** equal — both are mel-image
detectors that share `np.resize` wrap semantics and both had their
thresholds re-derived from the same sweep on the same day, which makes a
copy-paste between them a live risk.

886 tests pass; analyze unchanged.
