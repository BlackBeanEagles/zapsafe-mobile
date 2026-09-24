# Day 353 — m4/m5 drop ESD, and the acted benchmark was measuring backwards

Day 352 closed the ESD licence question with: *"ESD buys nothing on natural
speech and everything on acted — dropping it trades a legal risk for a
capability loss."* That framing was wrong twice over, and both errors were
mine.

## 1. The first error: a delta between two different sets

Day 352 reported "no-ESD m4 natural **0.6458** vs shipped **0.6235**,
+0.0223". Those numbers came from **different evaluation sets** — 0.6458 on
held-out speakers of MELD *train*, 0.6235 on MELD test+dev. That is not a
delta. It was also unpaired, so it carried no CI on the difference, which is
the decision rule this project uses everywhere else.

## 2. The second error: trusting the acted benchmark

The below-chance acted number (m4 read **0.318**) should have been the
signal, and I filed it as a curiosity. An AUC of 0.318 is not a weak model.
It is an **inverted** one — flip the sign and it reads 0.682.

`work/m4_m5_v4_signflip/diagnose.py` measures, per feature, which direction
means "stressed" in each corpus, and correlates the two:

```
m4  English   r = -0.07   CI [-0.33, +0.21]   unrelated
m5  Mandarin  r = -0.56   CI [-0.76, -0.29]   OPPOSED
```

For m5, all eight of the features ESD leans on hardest point **the other
way** on spontaneous speech. A linear probe — no capacity to memorise —
trained on acted reads **0.4004** on natural.

So the acted bar was not a conservative check. It was rewarding models for
learning a relationship that is false in the domain the app runs in.

Both label sets are nominally identical (`angry, sad` positive;
`neutral, happy` negative) and both sides use the same `yin_lite` 512/256
extractor, so this is not a label bug or a feature-space mismatch — both
were checked first. Acted sadness is *performed*, and a performance of
sadness sits on the opposite side of the energy axis from the real thing.

## 3. The measurement that decided it

`ab_esd.py` — two arms identical except for the presence of ESD rows, same
seed, same split, same architecture, scored on **identical rows**, with the
bootstrap taken on the paired difference using the same resample indices for
both arms:

```
m4  natural      -0.0054   CI [-0.0257, +0.0155]
m4  independent  -0.0163   CI [-0.0329, +0.0008]   MELD test+dev
m5  natural      -0.0044   CI [-0.0138, +0.0053]   at 38 dims, as ships
```

Every point estimate is negative and no CI excludes zero in ESD's favour. On
the one genuinely independent set, ESD *costs* 0.016 with an upper bound
that barely reaches zero.

Day 352 also ran m5's arm at **28 dims** while the shipped m5 is `_38`. Re-run
in the dimension that actually ships, the answer is unchanged.

Dropping ESD is therefore not a trade. It removes an NC corpus at no
measurable cost to the domain a phone hears.

## 4. What shipped

```
                     natural held-out      independent        acted
m4 v3  MELD only     0.6475 [.6176,.6764]  0.6410 [.6182,.6634]  0.4069
   v2  + ESD                                       0.6235         0.7738
m5 v3  EmotionTalk   0.7884 [.7724,.8042]      n/a                0.4913
   v2  + ESD              0.7810                                  0.7873
```

`m4_vocal_stress_v3_38.tflite` and `m5_vocal_stress_v3_38.tflite`, 28.8 KB
each. **m4 improves on the only independent set there is** (0.6410 vs
0.6235), which is the whole argument in one number.

The acted scores collapse and that is stated, not buried. They are not a
regression in anything a user experiences; they are the measurement of a
corpus these models no longer serve, taken with an instrument now known to
point backwards.

m5 has no independent natural set — the 4,000-clip Day 349 cache is drawn
from the same EmotionTalk pool — so its figure is held-out-speaker only.

## 5. The gate now scores them on natural speech

Left pointed at ESD, this gate would have reported **both models broken on
the day they got better** (m4 0.4069, m5 0.4913 — both below chance). The
`[1,38]` routing now sends `m4_*` and `m5_*` to held-out natural rows
exported by `train_final.py`, so there is one definition of "held out"
rather than two that can drift.

**m4 is red, and it stays red.** It reads 0.648 against the gate's 0.70 bar.
That bar is not being lowered. The honest reading is that m4 was *always*
this weak on English natural speech — Day 349 measured 0.4813 and Day 350
0.6235 — and its green gate was an artifact of scoring it on a corpus
anti-correlated with deployment. It ships as a fusion contributor at
threshold 0.50, not as an alert trigger, and the gate calling that out on
every run is the gate working.

## 6. Licence position, honestly

The NC exposure is gone from both models. What replaces it is not clean:

- **m4** now rests solely on **MELD** — no stated licence, audio cut from
  copyrighted broadcast.
- **m5** now rests solely on **EmotionTalk** — **CC BY-NC-SA 4.0**.

> **Corrected later the same day.** This section first said EmotionTalk had
> "no card or licence file on disk at all" and that a known NC term had been
> traded for an unstated one. Wrong. The licence badge is in the dataset's
> own source repo (`EmotionTalk-main.zip` → `README.md`); the extracted
> `D:\zapsafe\EmotionTalk` folder holds only `Audio.tar` and `.cache`,
> which is why the first pass found nothing — the licence was one directory
> away, in the code repo rather than the data drop.
>
> So ESD was not traded for an unknown. **It was traded for another
> Non-Commercial corpus**, and m5 is still NC. That is a smaller mistake
> than the one I described, but in the less favourable direction: the
> licence problem was not made murkier, it simply was not solved.
>
> Also worth correcting: EmotionTalk is "19 actors in dyadic conversation".
> Calling it *natural speech* throughout this document is too strong — it is
> **conversational** rather than read-aloud, which is a real difference from
> ESD and is what the measurements reflect, but the speakers are performing.
> The direction-inversion result stands, because it was measured rather than
> assumed; the label on the corpus does not.

What Day 353 settled is only that keeping ESD cannot be justified on
capability grounds, because there are none. The NC exposure is unchanged.

Also removed: the 8 real ESD-derived feature rows committed in
`test/fixtures/m4_en_38_golden.json`. No test read them —
`day336_compose38_test.dart` reads `feature_order` and nothing else — so
this costs no coverage. They were the only ESD-derived data inside the repo;
the gate reads ESD from `D:\` at runtime and commits nothing.

## 7. Status

| | |
|---|---|
| m4 | `m4_vocal_stress_v3_38.tflite`, 28.8 KB, **ESD-free**, natural 0.6475 / independent 0.6410 |
| m5 | `m5_vocal_stress_v3_38.tflite`, 28.8 KB, **ESD-free**, natural 0.7884 |
| gate | m5 ok; **m4 WEAK at 0.648 and deliberately left red** |
| licence | **still NC** — EmotionTalk is CC BY-NC-SA 4.0; MELD unstated. Open. |

859 tests pass.

Reproduce: `work/m4_m5_v4_signflip/{diagnose,ab_esd}.py` for the decision,
`work/m4_m5_v5_noesd/train_final.py` for the artifacts.

**Not run on physical hardware.**
