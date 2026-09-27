# Day 364B — m3_violence off-corpus: the largest gap in the project, and a threshold that labelled 6% of real violence

`m3_violence_temporal_v1` reads **AUC 0.908** on the gate and is marked
**ok**. That fixture is held-out **RWF-2000** — the corpus it trained on.

Running it over XD-Violence during the fusion work gave 0.725. That was
found as a side effect and never measured deliberately. This measures it.

## It is a fair cross-corpus test

RWF-2000 and XD-Violence both carry **violence** labels, so the construct
matches and only the domain changes — RWF is real-world fight footage,
XD-Violence is movies, CCTV and web video. The glass/gunshot AudioSet checks
had to worry about weak labels meaning something slightly different; this one
does not.

## The drop is real and significant

```
RWF-2000   (IN-corpus, the gate's own fixture)  n=400 pos=215  0.9085 [0.878, 0.936]
XD-Violence (OUT of corpus)                     n=400 pos=200  0.7247 [0.674, 0.775]

drop 0.1838        confidence intervals do NOT overlap
```

**−0.184** — larger than glass (−0.127), gunshot (−0.109) or anything else
measured this week, and the only one where the intervals are cleanly
separated.

## The operating point had collapsed

```
             RWF-2000 (in-corpus)        XD-Violence (out)
  t        recall  prec   FPR     J    recall  prec   FPR     J
  0.80      0.507  0.924  0.049 +0.458  0.060  0.600  0.040 +0.020   <- SHIPPED
  0.25      0.921  0.805  0.259 +0.661  0.730  0.719  0.285 +0.445
```

**At the shipped 0.80 this detector labelled 6% of real off-corpus
violence.** Youden J of +0.020 is a hair above useless. It is the
`scream_classifier` pattern for the third time this week: a card that reads
well in-domain, and a detector that almost never fires in the world.

## 0.80 → 0.25, APPLIED

Chosen by sweeping one grid on **both** corpora and taking the best
**worst-case** Youden J — the rule fixed before looking that produced the
Day 361C glass and gunshot recalibrations.

0.25 wins on both corpora, and notably **it beats 0.80 on RWF itself**
(+0.661 vs +0.458) — the corpus 0.80 was chosen on. That is not a
contradiction: Day 337 picked 0.80 deliberately to buy *precision*, not to
maximise separation, and on an in-corpus curve that looked nearly free.

The cost is real and is not hidden: RWF false-positive rate **0.049 → 0.259**
and precision 0.924 → 0.805. On XD-Violence precision actually *improves*
(0.600 → 0.719).

### Why this one could be applied when the fusion weights could not

Day 363B measured the DCS fusion weights as inverted and **did not change
them**, because they alter when the app raises an SOS. This is different:

> "Note this threshold does **not** gate the DCS contribution — the fusion
> reads the raw `violence` probability… What this controls is the reported
> label, and therefore what gets submitted."

Verified rather than taken on trust: `classScores` is built
**unconditionally** with `{'violence': violence, 'no_violence': 1 - violence}`
on every inference, and `_dangerScore` reads `classScores['violence']`
directly. So the fused DCS score is **byte-identical** either side of this
change.

What moves is the reported label and what is submitted as evidence — which
is exactly where a 6%-recall detector was doing damage.

## Where this leaves the model

The threshold is fixed; **the model is not**. A −0.184 corpus gap means
`m3_violence` is substantially weaker in the world than its gate number
says, and no threshold repairs that. The gate will keep reporting 0.908
because it scores on RWF; that number should be read as in-domain only.

Day 362C measured what would help: ~60 real-world clips beat 320 in-corpus
ones by 0.105 AUC for gunshot. The same logic applies here — a modest set of
real-world violence footage would be worth far more per clip than more
RWF-like data.

## Caveat

Both corpora are curated video, not phone-camera footage. The Day 337 note
that this is "still not calibrated on real *device* footage" remains true,
and 0.25 is a better number measured on two datasets, not a number measured
on the thing the app actually sees.

Reproduce: `work/fusion/m3_crosscorpus.py`, report in `m3_crosscorpus.json`.
