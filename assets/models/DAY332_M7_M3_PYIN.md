# Day 332 — M7 (renamed and built), M3 encoder exported, and the pyin decision split in two

Three items worked. One reached a shippable model under a corrected name, one
got its missing half built, and one turned out to be two decisions rather
than one.

## 1. M7 is still blocked. Something useful was built instead, under a different name.

`m7_nlp_context_enhanced`'s spec is a labeled **multilingual**,
**victim-perspective** distress corpus — "someone is following me", "help
me". Day 311 rejected six hate-speech candidates for being
perpetrator-threat rather than victim-distress, and that reading is right.

Swept every attached drive for text, **including the ~955 GB recently
added**: `.csv`/`.tsv`/`.jsonl`/`.txt` over 200 KB across `D:`, `E:`,
`dsfolder/`, `ml_datasets/`, `kaggle_datasets/`. The only text corpora
anywhere are the three mental-health CSVs on `D:`. Everything else in the
955 GB is audio or video. **The new datasets do not unblock M7**, and that is
worth stating because it was the reason to re-check.

So the mental-health data was used to build a different model, deliberately
named so it cannot be mistaken for M7:

**`distress_text_v1`** — English, Normal vs distress (Anxiety / Depression /
Suicidal), 49,368 rows after removing 1,234 exact duplicates *before* the
split.

```
HELD-OUT AUC              0.9628
word-count-only baseline  0.9010   <- built on purpose, and it nearly sank this
separation +0.7210   span 1.0000   (clears the Day 330 collapse floors)
recall 0.962 @ precision 0.914 at t=0.5
fraction scored >=0.5:  suicidal 0.967 | depression 0.967 | anxiety 0.939 | normal 0.156
```

The baseline is the point. A pooled AUC of 0.9010 from **counting words**
makes 0.9628 look like a length detector: median length is 12 words for
Normal and 88 for distress.

It is not, and the stratified analysis is what shows it. Within length
quintiles:

| words | n | model AUC | length-only AUC | base rate |
|---|---|---|---|---|
| 1–11 | 2052 | **0.9503** | 0.6086 | 0.123 |
| 11–29 | 2088 | **0.9560** | 0.6279 | 0.337 |
| 29–70 | 2035 | **0.9448** | 0.6163 | 0.821 |
| 70–132 | 2007 | **0.9195** | 0.5895 | 0.904 |
| 132–5643 | 1984 | **0.9128** | 0.5568 | 0.973 |

Length-only collapses to ~0.6 within every bin while the model holds
0.91–0.96. The n-weighted within-bin model AUC is **0.9370**. The pooled
0.9010 baseline was driven by between-bin base rates, not by the model
leaning on length, so **the confound is worth 0.026 and the lexical signal is
real.**

**Scope limit, stated not buried:** this is clinical *state* from
self-reported text, not "I am in immediate physical danger", and it is
English only. It does not satisfy M7. It is also a random split over deduped
rows — this data has no speaker or session grouping to hold out, unlike ESD,
and that limitation is recorded in the report rather than papered over.

Artifacts: `work/m7_distress_text/` — float16 tflite, vocab JSON, report. Not
copied into `assets/models/`; wiring it is a product decision about whether
the app should classify the user's own typed text at all.

## 2. M3's missing half: the frame encoder

`m3_violence_temporal` (AUC 0.9124) could not be wired because its input is
`[1, 16, 576]` — a sequence of 16 **MobileNetV3Small embeddings**, not
pixels. The app ships no such encoder, so the model had nothing to consume.

Exported it: `work/m3_violence/encoder/mobilenetv3small_encoder_float16.tflite`,
**1.85 MB**, `[1,224,224,3] float32 -> [1,576] float32`. Parity against the
Keras source on identical input: **corr 0.999984**, max abs diff 0.039 (float16
on embedding magnitudes, not a structural difference).

**The contract detail that would otherwise have been a silent bug:**
MobileNetV3Small carries its own `Rescaling(scale=1/127.5, offset=-1.0)` as
layer 1, and `tf.keras.applications.mobilenet_v3.preprocess_input` is a
verified **pass-through** (checked this session: input `[0,255]` comes back
`[0,255]`, `np.allclose` true). So the Dart side must feed **raw `[0,255]`
float pixels**. Normalising them first — the reflex, and what every other
audio model in this app does — would silently halve the input range and
produce embeddings the temporal head has never seen.

Still required to finish the wiring, and not done here: a camera burst
capture of 16 frames, resize to 224, and a two-stage inference. That is real
Dart work against a plugin surface, and it should not be rushed in beside two
other items.

## 3. The pyin decision is actually two decisions

Day 331 measured the app-computable 28-feature vocal-stress set at 0.7176 in
English against 0.8985 for the full 38, and framed implementing `pyin` in
Dart as the way to recover 0.181.

Reading `feats38` shows the 10 missing features are not one group:

| indices | feature | Dart cost |
|---|---|---|
| `[0-4]` | voiced_frac, f0_mean, f0_std, f0_range, jitter | **pyin — large, high risk** |
| `[5]` | shimmer — `mean(abs(diff(rms)))` | trivial |
| `[6]` | hnr — autocorrelation peak ratio | trivial |
| `[33,34,35]` | rms mean / std / max | trivial |

Ablation, 3 seeds each, held-out speakers (a *different* held-out set from
Day 331's training script, so compare within this table only):

| feature set | English | Mandarin |
|---|---|---|
| 28 — app today | 0.6949 ± 0.027 | 0.5221 ± 0.004 |
| 33 — **+ the five cheap ones** | **0.7469** ± 0.017 | 0.5585 ± 0.013 |
| 33p — + pyin only | 0.8052 ± 0.016 | 0.5448 ± 0.008 |
| 38 — everything | 0.8445 ± 0.014 | 0.5895 ± 0.021 |

**The five cheap features are worth +0.052. pyin is worth +0.110.** They
overlap slightly (0.052 + 0.110 = 0.162 against a combined 0.150).

That reframes it:

* **Do now:** implement RMS framing, shimmer and autocorrelation HNR in
  `VocalStressFeatures`, moving 28 → 33. Roughly a hundred lines against DSP
  the class already has the scaffolding for, no new algorithms, and it
  recovers a third of the gap.
* **Decide separately:** `pyin` for the remaining +0.110. Day 325 called it
  "a large, high-risk job" and that judgement stands — it needs a difference
  function, cumulative mean normalisation, thresholding, parabolic
  interpolation and a Viterbi pass, each a place for a silent parity bug of
  exactly the kind this project keeps finding. +0.110 is a real number, but it
  should be bought deliberately, not folded into a cheaper task.

Mandarin confirms the Day 331 finding from the other side: every variant sits
between 0.52 and 0.59 on this harder split, and pyin is worth *less* than the
cheap features there (0.5448 vs 0.5585). The language dependence is not an
artifact of one split.

## Status

Nothing in this commit changes app behaviour. What it changes is that two
items which read as "blocked" and "just wire it" are now costed:

* M7 multilingual victim-distress — **blocked, confirmed against the 955 GB**
* `distress_text_v1` — **built, 0.9370 length-controlled**, wiring is a
  product call
* M3 — **encoder exported and parity-checked**; remaining work is camera
  burst capture
* vocal stress — **33-feature step is cheap and worth doing**; pyin is a
  separate +0.110 decision
