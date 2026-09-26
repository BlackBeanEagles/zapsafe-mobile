# Day 361 — glass and gunshot, measured on a corpus they have never seen

Day 359 and 359B shipped two models and reported both numbers from FSD50K:

```
m_glass_breaking_v4   0.684 -> 0.866     trained FSD50K dev, eval FSD50K eval
mg_gunshot_v2         0.729 -> 0.846     trained FSD50K dev, eval FSD50K eval
```

Train and eval are disjoint *splits of one corpus*. Six speech corpora were
rejected this week for exactly that reason — corpus-ID AUC ran 0.98–1.00,
meaning a pooled model partitions by corpus rather than learning the
construct. Nothing had tested whether these two audio models survive a
corpus change, and both ship as SOS contributors.

AudioSet was already on this disk (9,927 clips) and neither model has ever
seen it. 1,598 clips selected: 59 glass positives, 77 gunshot positives,
62 hard negatives (Explosion, Fireworks — the loud broadband transients a
detector most plausibly confuses), 1,400 random negatives.

**Nothing was retrained. This measures what already ships.**

## 1. The headline result

```
                              FSD50K eval   AudioSet   drop
m_glass_breaking_v3 (retired)    0.684       0.680    -0.004
m_glass_breaking_v4 (SHIPPED)    0.866       0.688    -0.178
mg_gunshot_retrain  (retired)    0.729       0.649    -0.080
mg_gunshot_v2       (SHIPPED)    0.846       0.701    -0.145
```

**Glass: the retrain's gain is entirely FSD50K-specific.** v3→v4 measured
**+0.182** on FSD50K and **+0.007** on AudioSet, paired-bootstrap CI
[−0.069, +0.087], P(new ≤ old) = **0.436**. Look at v3's row: 0.684
in-domain, 0.680 out-of-domain — v3 generalised honestly. v4 bought 0.18
in-domain and nothing outside it. That is the signature of fitting the
corpus, not the construct.

**Gunshot: the gain partially transfers.** +0.117 on FSD50K → **+0.050** on
AudioSet, CI [−0.037, +0.132], P(new ≤ old) = 0.128. Direction holds, not
significant at 77 positives.

Both shipped models are real detectors out of domain — 0.69 and 0.70 are
well clear of chance — but **the model cards' 0.866 and 0.846 do not
describe behaviour outside FSD50K.**

## 2. The thresholds are miscalibrated, in opposite directions

AUC is a ranking measure and says nothing about whether the constant baked
into the Dart detector fires. That distinction has cost this project twice
already (scream's card says 0.95 recall and it fires on ~6% of real screams;
h_aggressive v5 kept v4's threshold and recall collapsed 0.664 → 0.057).

At the thresholds that ship today, on AudioSet:

```
glass  @0.22   recall 0.847   precision 0.054   fires on 56.6% of non-events
gun    @0.70   recall 0.208   precision 0.167   fires on  5.3% of non-events
```

Glass fires on **more than half of all real-world audio**. Gunshot catches
**1 in 5** real gunshots — the scream failure again.

### Not an artifact of the rolling buffer

The shipped Dart path scores max-over-sliding-windows, which gives several
chances to cross the threshold and inflates false positives on its own. So
it was separated out:

```
glass              AUC     recall   FPR        gun               AUC     recall   FPR
single           0.6126    0.492   0.333       single          0.6049   0.078   0.018
mean             0.6539    0.610   0.383       mean            0.6444   0.039   0.001
max (SHIPPED)    0.6877    0.847   0.566       max (SHIPPED)   0.7006   0.208   0.053
```

**The aggregation is load-bearing and correct** — max is the best of the
three for both models on AUC. The weakness is in the models, not the buffer.

## 3. A threshold that holds on both corpora

The obvious move — retune to AudioSet's optimum — would repeat the original
mistake in a new corpus. Day 359's glass threshold was already chosen once
on 13 positives and withdrawn. So the same grid was swept on **both**
corpora and scored by the **worse** of the two Youden J values, fixed before
looking: a threshold has to hold up on each, and averaging would let a
strong in-domain number hide an out-of-domain failure.

```
glass                FSD50K J    AudioSet J
  0.22  SHIPPED       +0.470       +0.249
  0.30  best          +0.528       +0.273

gun                  FSD50K J    AudioSet J
  0.70  SHIPPED       +0.558       +0.155
  0.45  best          +0.597       +0.387
```

**Both recommendations are better on both corpora than what ships.** The
gunshot case is stark: 0.70 → 0.45 raises recall from 0.612 → 0.709 on
FSD50K and **0.208 → 0.532** on AudioSet.

It is not free. At 0.45 gunshot's FSD50K precision falls 0.421 → 0.288 and
its false-positive rate roughly doubles (0.054 → 0.112). That is the right
trade for a **DCS fusion contributor**, which is what this detector is —
`gunshot_detector.dart` itself argues a signal that carries little
information is the failure mode to avoid — but it is a product decision and
it is recorded here rather than applied silently.

**Neither threshold was changed.** The evidence is here; the call is not
mine to make unasked.

## 4. Two bugs found on the way, both of the usual kind

1. **Six worker processes OOMed** and `except Exception` turned that into a
   silent 70% row drop — a 476-clip fixture with 14 glass positives that
   looked entirely plausible. Root cause: **C: is 100% full, so the pagefile
   cannot grow.** The builder now returns a reason instead of `None` and
   aborts above a 5% drop rate.

2. **Glass was fed 3.0 s of audio; it is a 2.0 s model.** The first run
   produced a confident, damning, wrong glass result (FPR 0.975) that was
   nearly written up. `GlassBreakDetector`'s own class doc warns about
   exactly this — *"gunshot's 3 s window would feed the model 50% more audio
   than it has ever seen and produce a confident wrong answer."* Preprocessing
   now comes from a per-task spec (glass 2.0 s/96 mels, gun 3.0 s/128 mels)
   and eval asserts the mel count against the interpreter's declared shape.

The corrected run is what section 1 reports. The wrong glass run had said
v4 beat v3 by +0.057; with the right window that collapses to +0.007. **The
"both gains replicate" reading was an artifact and is withdrawn.**

## 5. What this changes

| | before | after |
|---|---|---|
| glass v4 | "0.866, +0.18 over v3" | 0.688 out of domain; **the gain is FSD50K-specific** |
| gunshot v2 | "0.846, +0.12 over v1" | 0.701 out of domain; gain partially transfers |
| glass threshold | 0.22, chosen on FSD50K | fires on 57% of real audio; 0.30 better on both corpora |
| gun threshold | 0.70, chosen on FSD50K | catches 1 in 5 real gunshots; 0.45 better on both corpora |
| rolling buffer | untested | **validated** — max beats single and mean for both |

Nothing shipped from this. Two models keep their licences and their code;
what changed is that their real-world numbers are now known and written
down instead of implied by an in-domain split.

## 6. Caveats, stated rather than buried

* **59 and 77 positives.** The CIs are wide and printed for that reason. The
  direction is the finding, not the third decimal.
* **AudioSet is weakly labelled 10 s YouTube audio.** Its `Glass` class
  includes clinking and tinkling, not only breaking, which will depress
  measured glass recall. The 57% false-positive rate is computed on
  negatives and is unaffected by that.
* **The negative pool is random YouTube audio** — music, speech, machinery.
  Harsher than a phone in a quiet room, far closer to deployment than
  FSD50K's isolated clean clips.

Reproduce: `work/audioset_xcorpus/{build_fixture,eval_xcorpus,operating_point,aggregation_control,threshold_both_corpora}.py`
with reports in the matching `.json` files.
