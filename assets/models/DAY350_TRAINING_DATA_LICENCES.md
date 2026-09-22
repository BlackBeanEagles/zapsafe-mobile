# Day 350 — training-data licences: two shipped models rest on NC data

This is not a model-quality finding and it may matter more than one. It
surfaced while auditing loose directories the Day 348 archive scan had
missed, and it affects models shipped **today**.

**I am not qualified to give a legal opinion. What follows is what the
dataset cards on disk actually say, and which models depend on them.**

## 1. The finding

Every dataset card found across all drives, grouped by licence:

```
NON-COMMERCIAL
  D:\zapsafe\ESD_Dataset      cc-by-nc-4.0
  D:\zapsafe\spoofing         cc-by-nc-4.0
  D:\zapsafe\expresso         cc-by-nc-4.0
  D:\zapsafe\nemo             cc-by-nc-sa-4.0
  E:\datasets\datsets         cc-by-nc-4.0
  E:\datasets\zap             cc-by-nc-4.0
  (+ TUT Rare Sound Events, established Non-Commercial on Day 298)

PERMISSIVE
  E:\datasets\vocal           MIT          <- VocalAffectBench, scream v5
  E:\datasets\whispered       cc0-1.0
  E:\datasets\ai4ser          cc-by-4.0
  E:\datasets\huma            cc-by-4.0
  E:\datasets\{d1,data,eighty,emotion}   mit / apache-2.0
```

**`ESD_Dataset` is `cc-by-nc-4.0`, and it is the acted half of both vocal
stress models** — including the two shipped hours ago on Day 350:

```
m4_vocal_stress_v2_38   ESD English 3,400  +  MELD train 8,106
m5_vocal_stress_v2_38   ESD Mandarin 3,400 +  EmotionTalk 14,000
```

## 2. The natural-speech halves are not clean either

* **MELD** — its datacard on disk states no licence and describes the corpus
  as "designed for **research** on emotion recognition". Upstream MELD is
  distributed for research use, and its audio is extracted from *Friends*
  episodes, i.e. **copyrighted broadcast content**. That is a separate issue
  from a licence string.
* **EmotionTalk** — `D:\zapsafe\EmotionTalk` contains only `Audio.tar`. No
  card, no licence file, nothing on disk states terms either way.

So for m4 and m5, *both* halves of the training data carry a question.

## 3. Which shipped models are affected

| model | training data | licence status |
|---|---|---|
| `m4_vocal_stress_v2_38` | ESD + MELD | **NC + research-use** |
| `m5_vocal_stress_v2_38` | ESD + EmotionTalk | **NC + unknown** |
| `h_aggressive` v2b (unshipped) | MELD + CREMA/TESS/RAVDESS/SAVEE | research-use |
| `scream_classifier_v5` | VocalAffectBench (**MIT**) + AudioSet + ASVP-ESD + ESC-50 + FSD50K | mostly permissive; AudioSet/FSD50K are per-clip CC |
| `m_glass_breaking_v3`, `mg_gunshot_retrain` | UrbanSound8K / Freesound-derived | per-clip CC, needs a check |
| `m3_violence_temporal` | RWF-2000 | research-use agreement |
| `motion_fall_v2` | UniMiB-SHAR | research-use |

Two things follow. First, **the NC exposure is specific and small** — it is
ESD, and it is the acted half of two models. Second, **research-use
licensing is systemic across this project**, which is a much larger
conversation than today's work.

## 4. Why this was not caught earlier

The Day 348 scan read dataset cards only for archives, and `ESD_Dataset`,
`spoofing`, `expresso` and `nemo` are **loose directories** — it never
opened them. Day 298 caught TUT's NC licence only because that check was
run deliberately for one dataset.

There has never been a licence gate. `tools/verify_shipped_models.py` checks
whether a model *works*; nothing checks whether its training data permits
the use.

## 5. What could be done, in order of cost

1. **Verify upstream terms.** The cards on disk are HuggingFace mirrors, not
   necessarily the original terms. ESD's upstream (Zhou et al., NUS) has its
   own release conditions; they may be more or less permissive than the
   mirror's card. This is a reading task, not an engineering one.
2. **If ESD is genuinely NC and that is a problem:** m4/m5 can be retrained
   without it. The ablation already shows what the acted half buys — and
   `E:\datasets\ai4ser` (cc-by-4.0, 3,508 files) and `E:\datasets\huma`
   (cc-by-4.0) are unexamined permissive emotional-speech candidates.
3. **Add a licence field to the model reports** so a training run records
   what it was trained on and under what terms. Cheap, and it makes this
   auditable instead of archaeological.

## 6. Status

Nothing was reverted. m4/m5 v2 remain shipped, because the honest position
is "this needs a decision", not "this is known to be a violation" — and
both models are behind `vocalStressPipelineProvider`, which has no consumers
in `lib/`, so neither currently runs.

**This is flagged for a decision, not resolved.**
