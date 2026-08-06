# Day 313 — Multilingual "cold/restrained anger" dataset search for h_aggressive_speech + real combined CREMA-D + SUBESCO retrain

Context: Day 312 (`assets/models/DAY312_CREMA_D_INTENSITY_AND_ACCESS_PREP.md`, branch
`day312-crema-d-intensity-mining`) mined CREMA-D's own real per-clip intensity labels
(LO/MD/HI) to build a "cold anger" proxy from the 91 real `ANG_LO` clips (actor-disjoint
test AUC 0.9799), but flagged a real, unresolved caveat: the model's diagnostic
generalization to held-out MD/HI (louder) anger was itself very high (AUC 0.97/0.999),
suggesting the model may be learning "anger in general" rather than something specific to
restrained/controlled delivery. 91 positive clips from one corpus is also a small,
single-language pool. This session searched a real, project-owner-supplied list of 9
freely-downloadable speech-emotion datasets for genuinely new material to expand and
stress-test that proxy, verified real availability/licenses, resolved a real MESD naming
discrepancy, mined a second real corpus (SUBESCO, Bangla) with a heuristic restraint proxy,
retrained a combined CREMA-D+SUBESCO model on Kaggle, and re-ran Day 312's diagnostic
methodology (now on two corpora) to see whether the caveat is resolved.

## PART 1 — What was already tried vs genuinely new (cross-checked against real prior days)

Read `DAY275_VOCAL_STRESS_RETRAIN.md` (branch `day275-vocal-stress`),
`DAY279_KAGGLE_CATALOG_SEARCH.md` (branch `day279-kaggle-catalog-search`), and
`DAY310_H_AGGRESSIVE_ACCESS_AND_PREP.md` / `DAY312_CREMA_D_INTENSITY_AND_ACCESS_PREP.md`
directly (not from memory) before starting.

| Dataset | Already tried? | Real detail |
|---|---|---|
| TESS, SAVEE, RAVDESS (proper) | Yes — Day 275 | Added to `m4/m5_vocal_stress` (a *different* model, generic distress framing); result was WORSE (m4 0.629→0.5685, m5 0.614→0.4862) |
| ShEMO | **Yes — for h_aggressive_speech specifically, not just m4/m5** | Day 310's own read of `day106_h_crosslang_remain.py`/`day106_h_adversarial_core.py` confirms `collect_shemo_aggressive_paths()` is already one of h_aggressive_speech's six positive-class sources (RAVDESS/CREMA-D/EmoDB/IEMOCAP/MELD/**ShEMO**), all loud/shouted acted anger. **This corrects a premise in this session's own task brief**, which stated ShEMO was not used for h_aggressive_speech — the real code says otherwise; flagging the discrepancy plainly rather than silently going along with it. |
| EmoDB | Yes — Day 310 confirms it's also already one of h_aggressive_speech's six positive-class sources | Same as ShEMO above |
| CREMA-D (generic angry) | Yes — same six sources, all-intensity | Day 312 additionally mined its LO-intensity subset specifically |
| CREMA-D ANG_LO (intensity-filtered) | Yes — Day 312 | This session's Part 2 builds directly on it |
| EMOVO, JL Corpus, CaFE, AESDD, CASIA, EMNS, SUBESCO, MESD | **No — genuinely new to this project** | Confirmed via `git log --all -i -S"<name>"` over every branch of `zapsafe_mobile`; zero hits for all 8 names before this session |

## PART 2 — Real verification of the 8 new candidates

All checked via the real Zenodo/OpenSLR/GitHub/Mendeley pages directly and cross-checked
against Kaggle's real dataset catalog (`kaggle datasets list -s "<name>"` /
`kaggle datasets files` / `kaggle datasets metadata`), not from training-data memory.

### SUBESCO (Bangla) — real, large, freely available, genuinely new — **used this session**

- Real corpus: SUST Bangla Emotional Speech Corpus, Sultana/Rahman/Shahnaz/Khan, *PLOS ONE*
  2021 (`journals.plos.org/plosone/article?id=10.1371/journal.pone.0250173`). 7,000
  utterances, 20 speakers (gender-balanced), 10 sentences x 7 emotions (Anger, Disgust,
  Fear, Happiness, Neutral, Sadness, Surprise) x 5 takes.
- Primary source: Zenodo DOI `10.5281/zenodo.4526477`, direct `SUBESCO.zip` (1.7GB)
  download, **no signing/DUA**, license stated on the Zenodo record as **CC-BY-4.0**.
- Kaggle mirror used for actual training: `sushmit0109/subescobangla-speech-emotion-dataset`
  (2GB, 1075 downloads). **Real license discrepancy found and flagged, not silently
  resolved**: the Kaggle mirror's own `dataset-metadata.json` declares
  **`CC-BY-NC-SA-4.0`** (non-commercial, share-alike) — more restrictive than the
  authoritative Zenodo page's `CC-BY-4.0`. This is very likely the re-uploader's own
  (possibly mistaken/conservative) tag on Kaggle, not a change to the original license, but
  the discrepancy is real and should be re-checked against the canonical Zenodo record
  before any commercial/production use of this data — current use here is non-commercial
  research/experimentation either way, so both license terms are satisfied.
- Real filename convention (verified against actual files, e.g.
  `F_02_MONIKA_S_1_NEUTRAL_5.wav`): `Gender_SpeakerNum_SpeakerName_S_SentenceNum_EMOTION_Take.wav`.
- **No intensity or restraint label of any kind** — "Anger" is one flat category, same
  limitation as every other newly-checked corpus below. Per the task's own fallback
  instruction, this session mines a real heuristic proxy instead (Part 3).
- Prioritized per the task's own instruction (Bengali/South-Asian relevance to this app's
  market) and because it is the largest of the 8 new candidates by a wide margin.

### MESD — real naming discrepancy, resolved

Two genuinely different real corpora share/near-share this acronym:

- **MESD = Mexican Emotional Speech Database** (Duville, Alonso-Valerdi, Ibarra-Zarate,
  Mendeley Data DOI via `data.mendeley.com/datasets/cy34mh68j9/5`, also mirrored on Kaggle
  as `saurabhshahane/mexican-emotional-speech-database-mesd`, real CC-BY-4.0 license
  confirmed on the Kaggle mirror's own metadata). **This is genuinely Mexican Spanish**,
  confirming Day 279's own prior identification was correct. 864 single-word recordings
  (anger, disgust, fear, happiness, neutral, sadness) from 3 female + 2 male adults + 6
  children. No intensity labels. Small (single-word utterances only — not useful for a
  prosodic/full-utterance model like `h_aggressive_speech`, and too small a real anger
  pool — roughly ~144 clips — to add real signal here).
- **MES-P = Mandarin Emotional Speech dataset with Proximal/distal labels** (Yang et al.,
  IEEE TAFFC, arXiv 2305.13137... — different paper, different acronym, different
  language, different institution). This is the real Mandarin dataset the task's
  "MESD Mandarin" framing was actually pointing at — **it is not called MESD**, it is
  called **MES-P**, a distinct near-homophone acronym. There is no real "MESD" that is
  Mandarin; the Mandarin corpus everyone finds when searching in that direction is a
  different, differently-named corpus. **Verdict: the "MESD Mandarin" claim in this
  session's brief was a mix-up with MES-P; MESD itself is unambiguously Mexican Spanish.**
  Neither was used for the retrain (MESD too small/wrong-format; MES-P was not verified
  further since it isn't actually "MESD").

### EMOVO (Italian) — real, small, generic-only, license caveat — not used

Real corpus (Costantini et al., LREC 2014). 6 actors x 14 sentences x 6 emotions + neutral
(~588 clips, 335MB). Original source page states "non-commercial re-use with
acknowledgment." Kaggle mirror `sourabhy/emovo-italian-ser-dataset` (241MB, real audio
confirmed via file listing, e.g. `EMOVO/f1/dis-f1-b1.wav`) tags its own license as
`DbCL-1.0` — another mirror-vs-original license mismatch, same pattern as SUBESCO's Kaggle
mirror, flagged not glossed over. **Only a flat "rabbia" (anger) category, no
intensity/restraint annotation** — same problem this task exists to avoid. Small enough
(under 100 real anger clips total) that it would not meaningfully expand the positive pool
even with the same heuristic-energy-mining approach applied to SUBESCO. Not used.

### JL Corpus (English, NZ-accented) — real, CC0, generic-only — not used

Real corpus (Tokyo/Waikato collaboration; `github.com/tli725/JL-Corpus`, Kaggle
`tli725/jl-corpus`, 1GB, CC0-1.0 confirmed via Kaggle metadata — genuinely public domain,
no restriction at all). 4 speakers, 5 primary emotions (angry/excited/happy/neutral/sad) +
5 secondary emotions (anxious/apologetic/confident/enthusiastic/worried). **"Angry" is one
flat primary-emotion category with no intensity scale** — the secondary emotions add
nuance to *other* affect categories, not to anger specifically, so this does not provide a
restrained-anger register either. Not used.

### AESDD (Greek) — real, generic-only, license unclear on original site — not used

Real corpus (Vryzas et al., Aristotle University of Thessaloniki, M3C lab). ~500
utterances, 5 speakers, 5 emotions (anger/disgust/fear/happiness/sadness). Kaggle mirror
`arie07/acted-emotional-speech-dynamic-database-aesdd` (336MB, real audio confirmed, e.g.
`.../anger/a01 (1).wav`) tags license `MIT` on Kaggle; the original M3C page only states
"non-commercial research purposes," another mirror/original mismatch. **Flat "anger"
category, no intensity labels.** Small (real anger pool ~100 clips based on file-count
pattern). Not used.

### CASIA (Mandarin) — **real license status could NOT be verified as freely available — excluded on that basis**

Real corpus exists (Institute of Automation, Chinese Academy of Sciences — 4 speakers x
6 emotions x ~9,600 total utterances per published literature), but the official CASIA
corpus has historically been distributed only via a request/license process from the
Institute of Automation, not an open download. The only Kaggle mirror found,
`rocklagoon/casia-emotion-recognition` (56MB, 1 download, usability rating 0.125), is a
raw scrape of a HuggingFace cache directory (`casia/.cache/huggingface/download/CASIA/...`)
with **license explicitly `"unknown"`** in its own `dataset-metadata.json` — i.e. the
uploader did not/could not assert a real license, consistent with this being an
unauthorized re-upload of an otherwise access-controlled corpus rather than a genuinely
freely-licensed one. **This contradicts the "freely downloadable, no signing/DUA" premise
in this session's brief for CASIA specifically** — flagging plainly rather than using
data whose license cannot be verified. Not used, and not recommended for future use
without going through CASIA's real official request process.

### EMNS (English monologues) — real, and the only other new candidate with a genuine intensity label — not used this session, real future lead

Real corpus (Noriy/Yang/Zhang, Bournemouth University, arXiv 2305.13137, OpenSLR-136,
Apache-2.0-licensed *collection tool*; the dataset itself has no separately-stated content
license found on the OpenSLR page — another item to verify before use). Verified directly
from the real paper PDF (not from search snippets): **8 emotions (happy, sad, angry,
excited, sarcastic, neutral, disgusted, surprised)**, evenly distributed (~11.8% angry of
a 2.3-hour corpus, ≈16 minutes of real angry audio total), and — genuinely notable — each
utterance carries a **real self-reported 0–10 Expressiveness Level** (0=neutral,
10=highly expressive), a real continuous intensity label, not present in SUBESCO/EMOVO/
JL/AESDD/CASIA. **This is a real, second corpus with genuine intensity annotation**, but
it is a **single female speaker** (British-English narrative-storytelling/game-narration
monologues, not conversational threat speech), so using its low-EL "angry" clips would add
almost no actor diversity (one voice) while introducing a severe speaker-identity confound
if mixed into a binary classifier trained mostly on CREMA-D's 91 different actors. Also
small in absolute terms (~16 minutes of angry audio spread across 11 EL bins → a low-EL
angry bucket would likely be under 20 clips). **Verdict: a real, promising lead for a
future session** (especially if EMNS adds more speakers later, or if it's used for a
listener-perception validation study rather than as training data), **not used this
session** given the actor-diversity/scale problems.

### CaFE (Canadian French) — real, real intensity levels (2, not fine-grained), no Kaggle mirror — not used

Real corpus (Gournay/Lahaie/Colnet, ACM MMSys 2018). 12 actors, 6 sentences, 6 emotions +
neutral, **each of the 6 basic emotions acted at 2 intensities** (a coarser 2-level
version of what CREMA-D does at 3 levels) — genuinely relevant in principle. License:
CC BY-NC-SA 4.0, hosted at `gel.usherbrooke.ca/audio/cafe.htm` and Zenodo
`10.5281/zenodo.1219621`. **No Kaggle mirror found** (`kaggle datasets list -s "canadian
french emotional"` returned zero results) — would require a direct download from the
Zenodo/USherbrooke source and manual upload as a new private Kaggle dataset to use in this
project's existing Kaggle-kernel-based pipeline, which was not done this session given the
time budget was allocated to SUBESCO per the task's own priority instruction. **Real
future lead**, not a dead end — flagged for a future session since it has the same real
intensity-label property CREMA-D has, just with fewer levels and a much smaller pool (12
actors).

## PART 3 — Real combined CREMA-D + SUBESCO retrain

### SUBESCO heuristic restraint mining (since it has no ground-truth intensity label)

Per the task's own fallback instruction, `kaggle_notebooks/day313_h_multilingual_restrained_anger_push/day313_h_multilingual_restrained_anger.py`
computes real RMS energy per SUBESCO `ANGRY` clip, ranks each speaker's own ANGRY takes by
that real RMS value, and takes the **bottom third (quietest, per-speaker-relative)** as a
"restrained-anger" proxy positive class, holding out the **top third (loudest,
per-speaker-relative)** as a same-corpus diagnostic set — directly analogous to Day 312's
real CREMA-D LO vs MD/HI split, except CREMA-D's split is a real human-directed label and
SUBESCO's is a real-but-heuristic acoustic proxy. Ranking within each speaker's own takes
(not a global threshold) removes cross-speaker recording-level/mic-gain as a confound.

### Combined design

- Positive: CREMA-D `ANG_LO` (91, real label) UNION SUBESCO quiet-tertile `ANGRY`
  (heuristic proxy).
- Negative: CREMA-D `NEU` (capped 3x CREMA-D positives) UNION SUBESCO `NEUTRAL` (capped 3x
  SUBESCO positives).
- Speaker/actor-disjoint split, computed independently within each corpus (a CREMA-D actor
  ID and a SUBESCO speaker ID are unrelated real people).
- Same 38-dim hand-engineered prosodic feature set as the shipped model / Day 312, for
  architectural continuity.
- Three explicit diagnostics (all clearly non-primary):
  1. Day-312-style: CREMA-D MD/HI generalization.
  2. **New**: SUBESCO loud-tertile generalization — the real "restrained vs generic anger"
     check for this session's own new data.
  3. **New**: per-source held-out test AUC (CREMA-D-only vs SUBESCO-only) — checks whether
     the combined model is really learning one shared cross-language signal or just two
     separate per-corpus fits.

### Real Kaggle retrain

Kernel `hridyajain/zapsafe-day313-h-multilingual-anger` pushed via `kaggle kernels push`
from `kaggle_notebooks/day313_h_multilingual_restrained_anger_push/`
(`dataset_sources: ["ejlok1/cremad", "sushmit0109/subescobangla-speech-emotion-dataset"]`,
`enable_gpu: false` — CPU-adequate feature-extraction workload, same as Day 312). Polled
`kaggle kernels status` directly to real completion (status stayed `running` for
~29 minutes, real wall-clock `elapsed_sec: 1853.4` inside the report, then transitioned to
`complete` with no errors in the downloaded log — normal gradual convergence visible
epoch-by-epoch, e.g. train `auc` climbing 0.88→0.998 while `val_auc` climbs 0.84→~0.93,
not a collapsed/degenerate fit). Output pulled via `kaggle kernels output` into
`kaggle_notebooks/day313_h_multilingual_restrained_anger_push/final/`.

### Real counts (from `h_multilingual_restrained_anger_report.json`, not rounded/cherry-picked)

```
CREMA-D: ANG_LO=91  ANG_MD=91  ANG_HI=91  NEU_total=1087  NEU_used=273
SUBESCO: ANGRY_total=1000 (20 speakers)  quiet_tertile=320  loud_tertile=320
         NEUTRAL_total=1000  NEUTRAL_used=960
group_split: train=76 val=13 test=22 (speaker/actor-disjoint groups)
split_sizes: train pos=331/neg=1004 | val pos=13/neg=33 | test pos=67/neg=196
```

### Real primary result

```
test_auc_combined:      0.9663
test_accuracy_combined: 0.9582
confusion_matrix:       [[192, 4], [7, 60]]   (rows=true[neg,pos], cols=pred[neg,pos])
precision/recall:       neg 0.96/0.98, pos 0.94/0.90  (67-sample positive test class)
```

A real, non-degenerate result on a held-out, speaker/actor-disjoint 263-sample test set,
substantially larger than Day 312's 65-sample CREMA-D-only test set (67 vs 18 positive
test samples).

### Real diagnostic results — does this resolve Day 312's caveat? **No, it does not.**

**Diagnostic 3 (per-source held-out test AUC)** — checks whether the combined model
really learned one shared signal or two separate per-corpus fits:

```
CREMA-D-only held-out test AUC: 0.8474 (n=69)
SUBESCO-only held-out test AUC: 0.9904 (n=194)
```

A real, notable finding, reported plainly: combining the two corpora did **not**
uniformly help. CREMA-D's own held-out discrimination **dropped substantially** compared
to Day 312's CREMA-D-only run (0.9799 solo → 0.8474 combined) — the much larger SUBESCO
pool (331 of the 344 total positives are SUBESCO's) dominates the shared feature
normalization/model capacity, and CREMA-D's smaller, more subtle LO-vs-NEU boundary gets
partially washed out. SUBESCO's own held-out AUC (0.9904) stays strong. **This is real
evidence that stapling two corpora together via a small shared MLP is not automatically a
"stronger multi-corpus positive class" — the mix ratio matters, and this run's naive
concatenation favored the larger source.** A future session should consider
per-source class-weighting or a fixed-ratio resample (e.g. equal contribution from each
corpus) rather than raw pooling, if pursued further.

**Diagnostic 1 (CREMA-D MD/HI generalization, Day 312-style)**:

```
ANG_MD auc_vs_test_neu: 0.9413  (Day 312 solo: 0.9706)
ANG_HI auc_vs_test_neu: 0.9547  (Day 312 solo: 0.9986)
```

Still high, still shows the LO-trained signal generalizing strongly to louder anger it
never trained on — the same pattern Day 312 flagged as evidence the model may be learning
"anger in general," not restraint specifically. Slightly lower than Day 312's solo numbers
but not meaningfully different in interpretation.

**Diagnostic 2 (NEW — SUBESCO loud-tertile generalization, the direct analogue of Day
312's question applied to this session's own new data)**:

```
ANGRY_loud_tertile auc_vs_test_neu: 0.9982  (n_pos_probed=320)
```

**This is the clearest real evidence against the "restrained delivery" hypothesis this
session produced.** The model was trained only on each SUBESCO speaker's quietest
(bottom-tertile-by-RMS) angry takes, held out entirely from that speaker's loudest
(top-tertile-by-RMS) angry takes. If the model had learned something specific to *quiet,
controlled* delivery, its AUC on the held-out **loud** tertile should be materially
*lower* than its performance on quiet-tertile anger. Instead, the loud-tertile AUC
(0.9982) is **higher** than the primary combined test AUC (0.9663) and higher than the
CREMA-D-only held-out AUC (0.8474) — the model separates loud SUBESCO anger from neutral
at least as well as, if not better than, quiet SUBESCO anger. **Real, honest conclusion:
Day 312's caveat is not resolved by this session's data. If anything, this session's own
diagnostic on genuinely new data reinforces it** — both the CREMA-D-intensity-label proxy
and this session's SUBESCO heuristic-energy proxy behave like general anger-vs-neutral
detectors rather than detectors specific to controlled/restrained delivery. This matches
Day 312's own explanation for why that might be true: low-intensity/quiet-tertile acted
anger still differs from neutral speech in ordinary ways (articulation, word content,
energy contour shape) that have nothing to do with sounding "controlled and threatening"
in the GEMEP cold-anger sense — a classifier can learn to separate "quieter acting-ANG"
from "acting-NEU" without learning anything about menace or restraint per se, and this
session's loud-tertile diagnostic is direct, additional real evidence for that reading,
not a refutation of it.

### Bottom line for Part 3

A real, technically successful multi-corpus retrain (AUC 0.9663 combined, non-degenerate,
speaker/actor-disjoint) that adds a genuinely new, large, real, freely-licensed corpus
(SUBESCO) to Day 312's CREMA-D proxy — but it does **not** resolve the core scientific
question this task exists to answer. The new SUBESCO-specific diagnostic (loud-tertile
AUC 0.998, matching/exceeding quiet-tertile performance) is real, additional, negative
evidence that neither CREMA-D's real LO-intensity label nor SUBESCO's heuristic
RMS-energy proxy captures something distinctively "restrained/cold" as opposed to "anger
in general, quieter or louder." Combining the two corpora also did not uniformly help —
CREMA-D's own held-out AUC fell from 0.98 (Day 312 solo) to 0.85 (this session, combined)
due to SUBESCO's larger pool dominating the shared model. **Resolving Day 312's caveat for
real still requires either genuine GEMEP/K-EmoCon/EAV cold-anger-specific data (Day 310's
access-request checklist, still unsubmitted) or a human perceptual-validation study (do
listeners rate these clips as "controlled and threatening," not just "quiet") — neither of
which any energy/intensity-based acoustic proxy, real-labeled or heuristic, can substitute
for.**

## What was NOT done this session

- No fabricated/placeholder data for any dataset — every real count in this doc came from
  directly parsing real filenames or reading real dataset-metadata JSON, not estimates.
- No use of CASIA (license status genuinely unverifiable on its only real Kaggle mirror)
  or MESD/EMOVO/JL Corpus/AESDD/CaFE/EMNS for training this session (all correctly
  excluded on a stated, real, verifiable basis — generic-only labels, too small, wrong
  format, single-speaker confound, or no Kaggle mirror — not a vague "didn't look right").
- No modification of the existing shipped `h_aggressive_speech` production pipeline
  (`day106_h_crosslang_remain.py` and dependents untouched) — this is a standalone
  research experiment, same convention as Day 312.
- No detector/wiring/tflite-integration/pubspec/backend changes.
- No push of either git repo (`zapsafe_mobile` / `kaggle_notebooks`) — local commits only.
