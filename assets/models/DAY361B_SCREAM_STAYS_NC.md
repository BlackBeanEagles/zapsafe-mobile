# Day 361B — scream's NC flag does not come off for free. Answered, not cleared.

Day 360 reopened this with a specific argument, and it was a good one:

> Day 359C trained a permissive scream **from scratch** on 218 CC0/CC-BY
> FSD50K positives and it lost (0.82–0.86 vs 0.9057). That comparison threw
> away every other source — including VocalAffectBench, which is **MIT** and
> supplies most of the positives. **ESC-50 is 360 negative clips — 2.4% of
> the data and none of the positives.** The right question is whether
> removing those costs anything.

The A/B died three times to this machine's memory ceiling before it finished.
It has now run to completion, both arms, three seeds each.

## The result

```
A: with ESC-50    n=14,749    mean 0.7823   (0.7788 – 0.7844)
B: NC-free        n=14,389    mean 0.7628   (0.7587 – 0.7693)

B − A  =  −0.0195
```

Ship rule, fixed before running: **non-regression, ≥ −0.005**. It fails, and
not marginally — by roughly 4x the tolerance.

The seed ranges **do not overlap**. Arm A's worst seed (0.7788) beats arm
B's best (0.7693). This is not noise.

## So the framing was right and the answer is no

Day 360's reasoning held up — the question really was "do those 360
negatives cost anything", not "can 218 positives replace five corpora", and
asking it properly was worth doing. The answer just came back the other way.

**360 negative clips, 2.4% of the rows and none of the positives, are worth
0.0195 AUC.** The plausible reason is that ESC-50 is curated, balanced
environmental sound — 50 distinct classes, clean recordings. That is
negative *diversity* the other sources don't supply: FSD50K negatives are
Freesound uploads, ASVP-ESD is vocal, VocalAffectBench is vocal. A small set
of clean, varied non-vocal negatives is exactly what teaches a scream
detector what is *not* a scream.

## Two things this does NOT establish

**1. "B: NC-free" is not NC-free.** The label in the script is optimistic.
Dropping ESC-50 removes the *named* NC corpus, but FSD50K is per-clip
licensed and roughly 15% of its clips are CC BY-NC. Those rows sit inside
`fsd_dev_neg` / `fsd_dev_pos`, and the cached feature array stores a source
tag but no filenames, so removing them needs a re-extraction. Even the
winning arm would still carry NC data.

**2. The −0.0195 is measured on a proxy, not on the shipped model.** Both
arms use a simplified recipe that reads ~0.78, against the shipped
`scream_classifier_v5` at 0.9057. The A/B is internally valid — same recipe,
same eval fixture, same seeds, only the data differs — so the *delta* is
sound. But it is a delta on a weaker model, and a stronger recipe might
absorb the loss differently.

## Decision

**scream_classifier_v5 stays as it is, and stays NC-flagged.** Going NC-free
here would be a licence-for-accuracy trade of about 0.02 AUC on a detector
that is already the weakest thing in the project — the one whose card claims
0.95 recall and which fires on ~6% of real AudioSet screams. Spending
accuracy it cannot spare, to remove one of two NC corpora, while a second NC
exposure (the FSD50K slice) remains either way, is not a trade worth making.

**NC models: 2** (`m5_vocal_stress_v3`, `scream_classifier_v5`) — unchanged,
down from 5 on Day 359 morning. That number is now final for both remaining
entries unless new data appears:

* `m5_vocal_stress_v3` — EmotionTalk is CC BY-NC-SA 4.0 and is the only
  Mandarin stress corpus obtained. Day 353 established that prosodic stress
  does not transfer EN→Mandarin, so it cannot be replaced by m4's data.
* `scream_classifier_v5` — this note.

## What would change the answer

Permissively-licensed **negative** diversity, not positives. Roughly 360
clean, varied, non-vocal environmental clips under CC0 / CC BY / MIT would
substitute for ESC-50's contribution directly. That is a much smaller and
more findable ask than "a permissive scream corpus", and it is the concrete
next step if this is revisited.

Reproduce: `work/permissive/scream_drop_esc50.py`, report in
`scream_ncfree.json`.
