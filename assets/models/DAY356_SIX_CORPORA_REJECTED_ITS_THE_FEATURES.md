# Day 356 — six corpora, ~150k clips, no gain. The ceiling is the features.

m4 (0.648) and h_aggressive (0.641) have been treated all week as starved of
natural English speech. Six corpora were acquired and tested against that
theory. Every one was rejected, and the pattern across them says the problem
is not the data.

## 1. The scoreboard

| corpus | clips | h_aggressive result |
|---|---|---|
| ESD | 3,400 | **actively harmful**, direction r = −0.56 |
| LEGOv2 (CMU Let's Go) | 4,243 | screened +0.0410, replicated **2/4** |
| CMU-MOSEI | 4,977 | −0.0092, negative outright |
| AudioSet (local) | 9,927 | only ~128 usable positives |
| EQ4You | 77,182 | screened +0.0183, replicated **2/4** |
| NaturalVoices | 31,998 | screened +0.0196, replicated **4/8** |

Roughly 150,000 clips of natural, non-acted English. Not one produced a
gain that survived replication.

## 2. My 4-seed protocol was not strong enough

EQ4You's tar4 subset replicated **4/4 positive** and this file's predecessor
called it *"CONFIRMED — the effect is real and small, so scaling the corpus
up is justified"*. On that basis 16 more tars were downloaded.

It was wrong. At full volume the same corpus replicated 2/4, and with four
seeds a true-zero effect produces 4/4 about 6% of the time — the tar4 result
was in that tail. NaturalVoices was therefore run at **eight** seeds, where
a fluke needs p = 1/256, and it came back 4/8.

Every "CONFIRMED" produced by the 4-seed protocol this week should be
re-read as *not established*. The only one that mattered was EQ4You's, and
it is retracted here.

## 3. What six rejections have in common

**corpus-ID AUC, measured on every single one:**

```
LEGOv2         1.0000        EQ4You         0.9994
CMU-MOSEI      0.9810        NaturalVoices  0.9978
```

A classifier separates *which corpus a clip came from* essentially
perfectly, in the same 38-dim space the detector uses. When corpus identity
is that available, a pooled model does not have to generalise — it can
partition, learn "if corpus A apply rule A, else rule B", and the added rows
contribute nothing to MELD.

That is not a property of any one corpus. It is a property of the
**representation**. The 38-dim vector — 5 pitch, shimmer, HNR, 26 MFCC
statistics, 3 RMS, ZCR, spectral centroid — encodes recording channel,
codec, room and microphone at least as strongly as it encodes affect.
Telephone 8 kHz, YouTube AAC, podcast broadcast chain and TV dialogue are
each trivially identifiable, and that is what the pooled model keys on.

Linear transfer measurements say the same thing. Across all six, a linear
probe trained on the new corpus scored **0.49–0.56** on MELD. Chance.

## 4. So the ceiling is not data

The honest conclusion, after acquiring 41 GB and testing six corpora:

**More natural speech will not move m4 or h_aggressive in this feature
space.** The next real gain requires a different representation — a learned
speech embedding (wav2vec2 / HuBERT / WavLM) in place of hand-crafted
prosodic statistics. Those are trained to be invariant to channel and
speaker, which is precisely the invariance the 38-dim vector lacks.

That is a substantial change: a new encoder in the app, a much larger
asset, and a new Dart feature path. It is not a "download more data" task
and should not be scheduled as one.

## 5. What was kept

Nothing was retrained and no shipped asset changed. m4 stays at 0.648 and
h_aggressive at 0.641, both red on the gate, both honest.

Kept on disk: the `.npz` features for all six corpora, so any future
representation work can be tested against the same rows without
re-downloading. Raw audio for CMU-MOSEI was deleted (rejected, and C: was at
1.4 GB); EQ4You's 8 tars and NaturalVoices' archive are retained.

Also corrected on the way: a fetch script whose `remote_size` matched the
`Access-Control-Expose-Headers` line — which merely *lists* `X-Linked-Size`
— and returned a header string where a number was expected, turning eleven
downloads into 15-byte stubs while reporting success.

## 6. Status

| | |
|---|---|
| corpora tested | 6, all rejected |
| m4 / h_aggressive | unchanged, 0.648 / 0.641 |
| seed protocol | raised 4 → 8; prior "CONFIRMED" results retracted |
| next real lever | learned speech embeddings, not more data |

Reproduce: `work/{lego_natural,mosei_natural,eq4you_natural,nv_natural}/`.
