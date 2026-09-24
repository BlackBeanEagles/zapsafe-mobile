# Day 354 — a corpus acquired and rejected, and a shelved model confirmed dead

Two datasets were downloaded today to attack the two remaining open
questions. Both questions now have answers, and neither answer is the one
that was hoped for. That is the useful outcome.

## 1. CMU-MOSEI — acquired, measured, rejected

m4 (0.648) and h_aggressive (0.641) are weak for one reason: their only
natural English is MELD, ~6–8k rows of scripted TV dialogue. Day 353 showed
adding *acted* English is unsafe. So the search was for spontaneous English.

**CMU-MOSEI** is YouTube monologues from 1,000+ speakers, human-annotated
for six Ekman emotions. Downloaded the `cairocode/cmu_mosei_wav_2` mirror —
the subset shipping **actual audio**, since the official CMU release
distributes COVAREP features which are useless against a `yin_lite`
extractor. 4,977 clips survived, 1,409 speakers, median 5.28 s.

The screening test refused it before any training:

```
                          direction agreement        corpus-ID   linear transfer
h_aggressive space   r = +0.07  [-0.27, +0.37]        0.9810      0.43 / 0.47
m4 space             r = -0.61  [-0.78, -0.36]        0.9799      0.41 / 0.47
```

The paired A/B confirmed it, both arms scored on identical untouched MELD
rows:

```
h_aggressive   -0.0092   CI [-0.0314, +0.0130]
m4             -0.0122   CI [-0.0287, +0.0045]
```

**Rejected.** No seed-replication was needed — there was no positive hit to
replicate. That is the second natural-English corpus found, measured and
rejected in two days (LEGOv2 was the first).

## 2. The finding that actually matters: m4's label class is incoherent

MOSEI opposed MELD at **r = −0.61** in m4's space but was merely *unrelated*
at +0.07 in h_aggressive's. The only difference between those two label
sets is that m4 includes `sad` and h_aggressive does not. So the positive
class was decomposed:

```
MOSEI anger vs MELD   r = +0.061  CI [-0.257, +0.370]   20/38 agree
MOSEI sad   vs MELD   r = -0.669  CI [-0.794, -0.512]    7/38 agree
```

**The entire opposition is `sad`.**

m4 pools anger and sad into one "stressed" class. Angry speech is loud, fast
and high-pitched; sad speech is quiet, slow and low-pitched. Pooling them
asks a single direction in feature space to mean both, and which one wins
then depends on the anger/sadness mix a corpus happens to contain. MELD is
sitcom drama, so its pooled direction is effectively the anger direction —
and MOSEI's vlog sadness points the other way.

**This reframes m4's 0.648.** It has been treated all week as a data-volume
problem. It is at least partly a *construct* problem, and no quantity of
additional data fixes a label definition that contradicts itself across
corpora.

What this does **not** do is authorise changing m4's definition. Dropping
`sad` would narrow it to anger detection, and for a personal-safety app a
distressed user's sadness may be exactly the signal worth keeping. That is a
product decision, and it is recorded here as a recommendation rather than
made unilaterally.

Testing it properly needs MELD test+dev re-featurised with per-emotion
labels — the cached eval fixture carries only the pooled `y`, so anger-only
cannot be scored against it today.

## 3. `distress_text_v1` — the measurable blocker is now resolved, badly

Day 347 shelved it for four product reasons plus one measurement: it had
never been scored cross-corpus. Day 353B confirmed no local corpus could do
that. Two were downloaded to try.

**Attempt 1 — Dreaddit: ABORTED by its own guard.**

```
training texts 49,368 | Dreaddit 3,549 | exact overlap 1,351 (38.07%)
```

The training corpus already contains 38% of Dreaddit. The script aborts
above 1% rather than reporting a number that would be a third memorisation.
This also tells us something about the training data itself: those
"mental_health" CSVs are an aggregate of public research datasets, not an
independent scrape.

**Attempt 2 — a 19,775-tweet corpus, 0.01% overlap, genuinely independent:**

```
distress_text_v1 on Twitter   0.5268   CI [0.5187, 0.5352]
length-only baseline          0.5194
in-corpus (its own split)     0.9628
```

**0.9628 → 0.527, and it fails to clear a trivial length baseline.**

Caveats stated plainly: the constructs differ (clinical status vs depression
labels), and tweets are short while the model trained on long Reddit posts
where Day 347 measured median 12 words for Normal against 88 for distress.
Some of the collapse is that length cue vanishing. But a model that reads
unseen text at 0.527 and cannot beat word-count is not a model with a
deployment problem — it is a corpus artefact.

**The shelving decision is now permanent rather than pending.** Day 347's
caution was right, and its fourth reason — "never tested cross-corpus, in a
week that keeps punishing that" — turned out to be the decisive one.

### A bug worth recording

The first Twitter run returned exactly 0.5000 with CI [0.5000, 0.5000] and
**100% OOV**. The vocab file is a *wrapper* — `{"vocab": {...}, ...}` — and
passing the outer dict makes every lookup miss. Right shape, plausible-looking
output, dead constant, no exception: this project's signature failure. The
OOV-rate print is what caught it, and it stays in the script for that reason.

## 4. Disk: 164 GB of Golos deleted

D: had 1.6 GB free. `golos_opus.tar`, `crowd.tar`, `train_crowd{0,1,2,4,7,8}.tar`,
`train_farfield.tar` and `features.tar` are the **Golos Russian ASR corpus** —
downloaded believing "crowd" meant crowd-panic audio, as
`DAY344_CROSS_DATASET_AND_M8.md` already recorded. Confirmed again before
deleting: the archives share file hashes and the opus tree is
`golos_opus/train/crowd/`. Zero references in any script, gate entry or doc.

D: is now at **267 GB free**, every needed corpus verified intact. ESD was
kept deliberately — 6 GB, and it is the raw evidence behind Day 353.

## 5. Status

| | |
|---|---|
| CMU-MOSEI | downloaded, measured, **rejected** for both models |
| m4 | still 0.648; its *label construct* is now the prime suspect, not data |
| h_aggressive | still 0.641 |
| `distress_text_v1` | **does not transfer** (0.527); shelving now permanent |
| training corpus | contains 38% of Dreaddit — it is an aggregate, not a scrape |
| disk | 164 GB reclaimed |

No shipped asset changed today. 881 tests pass; analyze at 57.

Reproduce: `work/mosei_natural/{featurise_mosei,diagnose_mosei,ab_mosei,
decompose_labels}.py`, `work/m7_distress_text/crosscorpus_dreaddit.py`.
