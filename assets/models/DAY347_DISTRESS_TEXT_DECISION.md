# Day 347 — `distress_text_v1`: shelved, and why that is not a technical call

`work/m7_distress_text/distress_text_v1_float16.tflite` is a good model that
has been sitting unshipped. This records the decision not to ship it, so it
is a decision rather than an omission someone rediscovers later.

## The model is genuinely good

```
held-out AUC                 0.9628
length-controlled AUC        0.9370
word-count-only baseline     0.9010 pooled  ->  0.61/0.63/0.62/0.59/0.56 within quintiles
rows 49,368   test 9,873   vocab 19,998   float16 2,513 KB
```

It survives the control that should have sunk it. A pooled word-count
baseline of 0.9010 looks damning, but that is driven by between-bin base
rates (median 12 words for Normal, 88 for distress). **Within** length
quintiles the model holds 0.9503 / 0.9560 / 0.9448 / 0.9195 / 0.9128 while
length-only collapses to 0.6086 / 0.6279 / 0.6163 / 0.5895 / 0.5568. The
confound is worth 0.026, not 0.90. The lexical signal is real.

The tokenizer was deliberately built to be reproducible in Dart (lowercase,
`[a-z0-9']` runs, fixed vocab, pad/truncate to 120), so wiring it would be
straightforward. This is not a "too hard" decision.

## Why it is not shipped

**1. It is a different product from every other detector here.**
Every other model answers *"is a dangerous event happening right now?"* from
a sensor — audio, IMU, camera. This one infers **clinical mental-health
state** from a user's private typed text. Its positive classes are Anxiety,
Depression and **Suicidal**. That is a health inference, and it carries a
different ethical and regulatory posture than "a window broke". It should
not be slipped in behind a threshold constant because the AUC was good.

**2. There is no consumer, and no designed surface.**
The app has 72 files containing a `TextField` and **zero** references to
this model or any text-distress feature. Shipping it would add 2.5 MB to
every bundle for nothing to call — the same dead weight
`scream_classifier_v3.tflite` was removed for on Day 346B. A model that
scores what a user types needs a surface they consented to, not an
opportunistic hook into an existing field.

**3. Its eval has a limitation that matters more for a clinical claim.**
The split is random over deduped rows. The training script records why —
this data has no `speaker_id` or session field to group on, so no
speaker-held-out split is possible — and flags it rather than papering over
it. That is honest, but a random split over forum posts by an unknown number
of repeat authors is a weaker footing than 0.9628 suggests, and weaker
footing matters more when the output is "this person may be suicidal".

**4. It has never been tested cross-corpus, in a week that keeps punishing
that.** Both numbers come from the same two mental-health CSVs. Day 346
measured `m3_violence_temporal` at 0.9126 in-corpus and **0.4821** on an
independent one; scream v3 went 0.839 -> 0.7675. Nothing about
`distress_text_v1` has been exposed to that test.

**5. It does not satisfy M7 and must not be logged as if it does.**
M7 (`m7_nlp_context_enhanced`) needs a **multilingual, victim-perspective**
corpus — "someone is following me", "help me". This is English self-reported
clinical state. The training script names itself differently for exactly
this reason. Clinical distress and "I am in immediate physical danger" are
different signals and conflating them would be the most consequential
mislabel in the project.

## What would change this

Not a better number. A **product decision plus a surface**:

* an explicit, opt-in feature the user knows is reading their text;
* a defined response that is appropriate to a mental-health signal, which is
  almost certainly *not* the SOS escalation path the other detectors feed;
* a cross-corpus measurement on text the model has never seen;
* and a considered position on false positives and false negatives on the
  Suicidal class specifically.

Until those exist, the model stays in `work/m7_distress_text/`, complete and
reproducible, and **M7 remains blocked** rather than quietly marked done.

## Status

| | |
|---|---|
| model | `work/m7_distress_text/distress_text_v1_float16.tflite` |
| quality | good — 0.9628, 0.9370 length-controlled |
| shipped | **no, deliberately** |
| satisfies M7 | **no** |
| blocker | product surface + consent + cross-corpus eval, not model quality |
