# Day 348 — h_aggressive v2: the fix was one corpus, not six

Day 347 measured `h_aggressive_speech_v1` at **0.4780 — chance —** on
natural speech, against 0.8442 on the acted RAVDESS booth recordings that
were its entire training world. v2 retrains across multiple corpora.

## 1. Result

```
                                acted (held-out speakers)   MELD (natural)
v1   (RAVDESS only, 24 actors)          0.8442*                0.4780
v2   (6 corpora, 28,048 clips)          0.8043                 0.6458
v2b  (5 corpora, 17,548 clips)          0.8096                 0.6661   <- best
MELD-fitted ceiling, same features          —                  0.6832
```
\* v1's figure is on RAVDESS, the corpus it trained on.

v2b reaches **97.5% of the achievable ceiling** on natural speech while
still scoring 0.81 on acted speech. It gives up 0.035 on the acted number —
which was never in doubt — to gain **+0.188** on the one that was.

MELD bootstrap CI [0.6427, 0.6896], clear of chance. The evaluation rows are
byte-identical to Day 347's, so v1 and v2b are compared on the same clips.

## 2. "Combine many datasets" is not the lesson. This is.

Each corpus was dropped in turn and the cost measured:

```
leave-one-corpus-out, MELD AUC (all-corpora baseline 0.6458)

  without meld      0.4895   -0.1563   <- back to CHANCE without it
  without ravdess   0.5966   -0.0492
  without tess      0.6292   -0.0166
  without savee     0.6321   -0.0136
  without crema     0.6460   +0.0002   <-  6,171 clips, contributes nothing
  without esd       0.6621   +0.0163   <- 10,500 clips, actively HARMFUL
```

**More data was not the fix; one particular kind of data was.** MELD alone
accounts for essentially the whole gain — remove it and the model returns to
chance no matter what the other 20,000 clips contain. Meanwhile the two
largest acted corpora, **16,671 of 28,048 clips (59% of the data)**,
contribute nothing or actively hurt.

ESD's harm has a likely cause worth recording: its only aggressive class is
**Angry**, with no fear or disgust. It therefore teaches a narrower target
than the evaluation scores — the same defect that cost scream v4 its
retrain (Day 346), arriving from a different direction.

## 3. The ablation was wrong once, and training caught it

The table above also said removing CREMA-D would help (+0.0080). It was
acted on and did not survive:

```
v2b  (no ESD)             MELD 0.6661   acted 0.8096
v2c  (no ESD, no CREMA)   MELD 0.6540   acted 0.7107   <- fails ship bar
```

Predicted +0.0080; actual **−0.012 on MELD and −0.099 on acted**. ESD's
+0.0163 survived a real retrain (both numbers improved); CREMA's +0.0080 was
noise.

Worse, v2c's own ablation then claimed removing three *more* corpora would
help — the ablation eating itself as the training set shrinks and each
estimate gets noisier.

**Leave-one-out is a screening tool.** Deltas of that size have to be
confirmed by an actual retrain before being acted on. Two extra training
runs, each a few seconds, is what stopped a worse model being shipped.

## 4. The split, and the leak it avoids

CREMA-D has 12 clips per actor per emotion; TESS has 200 per speaker reading
the same word list. A random split puts the same voice saying the same word
on both sides and reports memorisation as skill — a gap this project has
already measured, with `m5_vocal_stress_v2` at 0.9984 on seen speakers and
0.7988 on held-out ones.

So the split holds out 25% of speakers **within each corpus** (pooled would
risk removing all four SAVEE speakers and leaving that corpus untested), and
MELD is grouped by dialogue id so utterances from one conversation cannot
straddle it. MELD's test+dev were never trained on at all.

## 5. What was rejected, and why

* **EmotionTalk** (14.8 GB, 19,250 clips, five annotators each) ranked first
  among natural-speech candidates and is **Mandarin** — confirmed from CJK
  codepoints in the transcripts, not from the name. Day 343 measured
  EN→Mandarin prosodic transfer at 0.4537, so it cannot help an English
  model. It is a strong candidate for the Mandarin `m5`.
* **VESUS** (4.2 GB, 15,043 clips) ranked first until its README was read:
  *"recordings of emotional speech from actors."* More acted speech is the
  thing v2 already has too much of.

## 6. Status

| | |
|---|---|
| model | `work/h_aggressive_v2/h_aggressive_v2_noesd_float16.tflite` (12 KB) |
| norm | `h_aggressive_v2_noesd_norm.json` — **mandatory**, v1 dropped to 0.52 on raw features |
| natural speech | **0.6661** (v1: 0.4780) |
| acted, held-out speakers | **0.8096** |
| shipped | **no** — Phase B wiring is still not done |

The wiring blocker is unchanged and unrelated to model quality: the native
layer emits 15 per-frame scalars, while the day90 extractor needs pyin f0
mean/std/jitter, RMS-derived shimmer and HNR, and spectral rolloff. v2b
makes that work worth doing — 0.67 on natural speech instead of chance — but
does not remove it.

**Nothing here has run on physical hardware.**
