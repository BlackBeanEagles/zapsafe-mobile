# Day 312: CREMA-D low-intensity-anger "cold anger" proxy retrain + real access-request prep for IEMOCAP / MSP-IMPROV / MSP-Podcast

Context: Day 310 (`assets/models/DAY310_H_AGGRESSIVE_ACCESS_AND_PREP.md`, branch
`day310-h-aggressive-prep`) confirmed `h_aggressive_speech`'s positive ("aggressive")
class is 100% loud/shouted acted anger across every real data source used
(RAVDESS/CREMA-D/EmoDB/IEMOCAP/MELD/ShEMO), with the only concession to a calm register
being a synthetic DSP transform (`apply_calm_threat()`) applied to shouted clips at train
time -- not real human "cold anger" audio. Day 310 prepped real access-request details for
GEMEP/K-EmoCon/EAV, all still gated with no data yet. This session (1) mines a real,
immediately-usable proxy from data already on hand -- CREMA-D's own per-clip intensity
labels, never previously exploited by this project's `_cremad_samples()` loader -- and
retrains/evaluates it end-to-end on Kaggle, and (2) prepares real, browser-verified
access-request details for three more real academic-gated candidates: IEMOCAP,
MSP-IMPROV, MSP-Podcast.

## PART 1 -- CREMA-D low-intensity-anger mining (real retrain, no new access needed)

### Real dataset location and filename convention (verified)

Local mirror: `ml_datasets/vocal_stress/DS01_RAVDESS/Crema/` (7,442 `.wav` files) --
already the exact local cache for the Kaggle dataset `ejlok1/cremad`, already used by
`_cremad_samples()` in `kaggle_notebooks/day106_fusion_crosslang_push/day106_h_adversarial_core.py`
(existing h_aggressive_speech pipeline). Confirmed real filename convention via `find` over
the actual local files: `<ActorID>_<Sentence>_<Emotion>_<Intensity>.wav`, e.g.
`1001_IEO_ANG_LO.wav`. Intensity codes present: `LO`/`MD`/`HI` (three graded intensities,
recorded only for the `IEO` sentence and only for the four non-neutral emotions
ANG/DIS/FEA/HAP/SAD) and `XX` (unspecified/single-take, used for all other sentence codes
and for `NEU`, which CREMA-D never recorded at graded intensity at all).

### Real counts (verified by directly parsing the actual local files, not estimated)

```
ANG_HI = 91   ANG_MD = 91   ANG_LO = 91   ANG_XX = 998   (ANG total = 1271)
NEU (all XX, no graded intensity exists for neutral) = 1087
Unique actors contributing an ANG_LO clip = 91 (exactly one LO-intensity anger clip per actor)
```

`91` matches CREMA-D's known total actor count (91 professional actors) -- i.e. every
actor recorded exactly one low-intensity anger take, giving a real but genuinely small
positive-class pool of 91 clips. This is the exact count Day 310/311's honesty standard
requires reporting plainly: 91 is small for a from-scratch classifier, not a large corpus.

### Existing loader confirmed to ignore intensity entirely

`_cremad_samples()` (`day106_h_adversarial_core.py`, lines 162-182) buckets `ANG`/`DIS`/`FEA`
as positive and `HAP`/`NEU` as negative regardless of the `LO`/`MD`/`HI`/`XX` suffix -- every
retrain of `h_aggressive_speech` to date has trained on all-intensity anger, including the
991 clips (998 XX + 91 MD + 91 HI, i.e. everything except the 91 LO clips) of louder,
non-"cold" anger, with LO-intensity anger contributing to the positive class
indistinguishably from HI-intensity shouted anger.

### New script: `kaggle_notebooks/day312_h_cremad_intensity_push/day312_h_cremad_intensity.py`

Built as a clean, standalone variant (not a patch to the existing crosslang script, so the
existing production pipeline is untouched) that:

- **Positive class: ONLY real CREMA-D `ANG_LO` clips (91 total)** -- the "cold anger" proxy.
  No synthetic `apply_calm_threat()` transform is applied anywhere in this script; the
  entire point is a real recorded low-intensity delivery, not a DSP-modified shouted clip.
- **Negative class: real CREMA-D `NEU` clips** (1,087 total; CREMA-D has no graded-intensity
  neutral, so `XX` is the only real option -- not a compromise, the only choice that exists),
  subsampled with a fixed seed (42) to 273 clips (3x the positive count) for a less extreme
  class imbalance than the raw 91:1087.
- **Actor-disjoint train/val/test split** (62/11/18 actors, zero actor appears in more than
  one split) -- this project already established actor-disjoint splitting as the correct
  methodology for CREMA-D-scale actor pools (see `day286-pocket-muffled-actorsplit` branch
  history), which matters even more here given the small positive pool.
- Same 38-dim hand-engineered prosodic feature set as the shipped model (F0 mean/std,
  jitter, shimmer, RMS coefficient of variation, 13 MFCC mean + 13 MFCC std, RMS mean, ZCR
  mean, spectral centroid mean, spectral rolloff mean) for architectural continuity.
- A diagnostic-only probe (not the primary metric, explicitly labeled as such in the report
  JSON): after training on LO-intensity anger only, score the model against held-out
  MD/HI-intensity anger clips it never trained on, to see whether it generalizes toward
  louder anger too.

`kernel-metadata.json`: `dataset_sources: ["ejlok1/cremad"]`, `enable_gpu: false` (tiny
dataset, CPU-adequate), `code_file: day312_h_cremad_intensity.py`.

### Real Kaggle retrain -- pushed, monitored to actual completion

Kernel `hridyajain/zapsafe-day312-h-cremad-intensity` pushed via `kaggle kernels push`,
polled via `kaggle kernels status` every ~15-20s until status changed from `running` to
`complete` (real wall-clock kernel runtime: 381.8s / ~6.4 min per the report's
`elapsed_sec`, observed directly in the downloaded training log -- 40-epoch run with
early-stopping/LR-reduction callbacks active, real per-epoch metrics logged, e.g. epoch 1
`val_auc: 0.7262` climbing to convergence, no errors or crashes in the log). Output
artifacts pulled with `kaggle kernels output` into
`kaggle_notebooks/day312_h_cremad_intensity_push/final/`:
`h_cremad_intensity_cold_anger.tflite`, `h_cremad_intensity_norm.json`,
`h_cremad_intensity_report.json`, plus the full kernel log.

### Real result (from `h_cremad_intensity_report.json`, not rounded/cherry-picked)

```
real_counts:      ANG_LO=91  ANG_MD=91  ANG_HI=91  NEU_total=1087  NEU_used=273
actor_split:      train=62 actors  val=11 actors  test=18 actors  (disjoint)
split_sizes:      train pos=62/neg=185 | val pos=11/neg=41 | test pos=18/neg=47
test_auc:         0.9799
test_accuracy:    0.9385  (65 held-out test samples)
confusion_matrix: [[46, 1], [3, 15]]   (rows=true[neg,pos], cols=pred[neg,pos])
precision/recall: neg 0.94/0.98, pos 0.94/0.83 (18-sample positive test class)
diagnostic (model trained on LO only, scored against held-out MD/HI anger vs test NEU):
  ANG_MD auc_vs_test_neu = 0.9706
  ANG_HI auc_vs_test_neu = 0.9986
```

**This is a real, non-degenerate result** -- actor-disjoint AUC of 0.98 and accuracy of
0.94 on a genuinely held-out 65-sample test set, trained from real audio with zero
synthetic augmentation on either class. Training log shows normal gradual convergence
(val_auc climbing from 0.73 at epoch 1 through the run), not a collapsed/degenerate fit.

**Necessary honesty about what this result does and does not show** (per this session's
explicit brief, not glossed over):

- **What it shows**: a model *can* reliably tell CREMA-D's low-intensity acted anger apart
  from CREMA-D's neutral speech acoustically. That is a real, useful signal -- it confirms
  low-intensity anger is not acoustically indistinguishable from calm/neutral speech, which
  is a prerequisite for this being any kind of usable proxy at all.
- **What it does not show**: that low-intensity CREMA-D anger *sounds threatening* in the
  GEMEP "cold anger" sense (controlled, menacing, quietly dangerous). CREMA-D actors were
  simply directed to "act ANG at low intensity" -- a generic intensity-dial instruction, not
  a "portray calm, controlled menace" instruction the way GEMEP's cold-anger category
  explicitly is. The high separability from neutral is at least partly explainable by
  CREMA-D's low-intensity anger still differing from neutral in ordinary ways (word content,
  articulation tension) that have nothing to do with sounding threatening -- the classifier
  distinguishing "acting-ANG-at-low-volume" from "acting-NEU" is a real result, but it is
  not the same claim as "this model has learned to recognize a controlled, threatening
  tone." The diagnostic MD/HI generalization numbers (0.97, 0.999) if anything suggest the
  model may still be picking up on features shared with louder anger (e.g. articulation
  patterns, energy contour shape) rather than something unique to the "quiet and
  controlled" delivery GEMEP's cold-anger label targets specifically.
- **Sample size caveat**: 91 positive clips total (18 in the held-out test set) is small.
  A single actor-split reshuffle would move the AUC meaningfully; this number should be read
  as "a real, promising, non-degenerate first result on a small real proxy dataset," not as
  a production-ready gate-passing number comparable to the 6,000+-sample crosslang runs
  elsewhere in this project.

**Bottom line for Part 1**: CREMA-D low-intensity anger is a real, immediately-available,
non-degenerate acoustic proxy that is measurably distinguishable from neutral speech --
worth folding into `h_aggressive_speech` training data as one additional real-audio
register alongside (not instead of) the existing shouted-anger data once GEMEP/K-EmoCon/EAV
access comes through. It is **not** confirmed to be a genuine substitute for real
"controlled/threatening" cold-anger audio -- that claim would require either human
perceptual validation (does a listener rate these clips as "controlled and threatening" vs.
just "quiet"?) or the actual GEMEP/EAV/K-EmoCon data for a real head-to-head comparison,
neither of which this session had access to. Reporting this as a real, useful, but
incomplete positive result, not a solved problem.

## PART 2 -- Real access-request details: IEMOCAP, MSP-IMPROV, MSP-Podcast

All three verified by loading the real pages directly in-browser this session (not
guessed, not from cached/training knowledge).

### 1. IEMOCAP -- USC SAIL lab, online form (fastest of the three)

Verified live at `https://sail.usc.edu/iemocap/` and
`https://sail.usc.edu/iemocap/release_form.php`.

**What it is**: Interactive Emotional Dyadic Motion Capture database -- ~12 hours of
acted, multimodal, multispeaker audiovisual data (video, speech, face motion capture, text
transcriptions). Dyadic sessions of actors performing improvisations/scripted scenarios
selected to elicit emotion. Categorical labels (anger, happiness, sadness, neutrality, etc.)
plus dimensional labels (valence, activation, dominance) from multiple annotators.

**Exact real access process** (a direct web form, no PDF/mail needed):
1. Fill out the form at `https://sail.usc.edu/iemocap/release_form.php`.
2. Required fields: First Name, Last Name, E-Mail Address (must be an **academic
   institute email address** -- explicitly stated), Affiliation (university/school name),
   Department/Group, Title (e.g. PhD, Professor), Address, optional Personal Website,
   agreement checkbox for the release license, and a CAPTCHA.
3. The page states manual verification takes **3-5 days**, and warns of delays from
   current high request volume; check spam folder for the reply.
4. Must cite in any publication: C. Busso, M. Bulut, C.C. Lee, A. Kazemzadeh, E. Mower,
   S. Kim, J.N. Chang, S. Lee, and S.S. Narayanan, "IEMOCAP: Interactive emotional dyadic
   motion capture database," *Journal of Language Resources and Evaluation*, vol. 42, no.
   4, pp. 335-359, December 2008.
5. Explicitly **not for commercial use** -- privacy restriction on the participants.

**Action for the project owner**: submit the form directly at the URL above using an
academic email address; login details are emailed only to that address once approved.

### 2. MSP-IMPROV -- UT Dallas MSP lab (Prof. Carlos Busso), signed-PDF + email

Verified live at `https://lab-msp.com/MSP/MSP-Improv.html` (note: the older
`ecs.utdallas.edu` MSP-lab URL now redirects to the general UTD engineering-school
homepage -- the lab has moved to its own domain, `lab-msp.com`).

**What it is**: acted audiovisual emotional database of spontaneous dyadic improvisations,
6 dyad sessions (12 actors, UTD Theatre/Drama students with acting experience), 20 target
sentences with emotion-eliciting scenarios (happy/sad/anger/neutral), 8,438 total speaking
turns (652 corresponding to the fixed target sentences). Reference: Busso et al.,
"MSP-IMPROV: An acted corpus of dyadic interactions to study emotion perception," *IEEE
Transactions on Affective Computing*, vol. 8, no. 1, pp. 119-130, Jan-Mar 2017.

**Exact real access process** (signed PDF, not an online form):
1. Download the release-form PDF: `https://lab-msp.com/MSP/publications/AcademicLicense-MSP-IMPROV.pdf`.
2. The form must be **signed by the director of the research group**.
3. Send the signed form to **Prof. Carlos Busso** (contact link on the lab page).
4. Copy the group leader/lab director on the email.
5. Add the group leader/lab director to the list at the end of the agreement (full name,
   signature, title).
6. Use your **institution email** to make contact.
7. (Not applicable here) A commercial license exists separately for US$8,000 for companies.

### 3. MSP-Podcast -- UT Dallas MSP lab, signed institutional data-transfer agreement

Verified live at `https://lab-msp.com/MSP/MSP-Podcast.html`.

**What it is**: the largest naturalistic speech-emotion corpus in the community --
Version 2.0 has 264,705 speaking turns / 409 hours, sourced from podcast recordings with
permissive licenses, perceptually annotated by crowdsourcing + student evaluators for both
categorical emotions (anger, happiness, sadness, disgust, surprise, fear, contempt,
neutral, other) and dimensional attributes (activation, dominance, valence). Real
speaker-independent Train/Dev/Test1/Test2/Test3 partitions already defined by the corpus
authors (Test1: 465 speakers/46,294 segments; Test2: 112 speakers/14,822 segments from 117
podcasts not in other splits; Test3: 3,200 segments/428 speakers, held-out labels scored
via a web interface; Dev: 704 speakers/34,399 segments; Train: 2,220+ speakers/169,190
segments). Reference: Busso et al., "The MSP-Podcast corpus," *IEEE Transactions on
Affective Computing*, early access 2026 (also ArXiv 2509.09791).

**Exact real access process** (free academic license, but requires institutional
signing authority -- the strictest of the three):
1. Download the release-form PDF:
   `https://lab-msp.com/MSP/publications/Busso-FDPDTUA-MSP-Podcast-v4.pdf`.
2. Free of cost under an Academic License, but **the form must be signed by someone with
   signing authority on behalf of the university** -- the page explicitly says this is
   "usually someone from the sponsored research office," not the requesting researcher
   themselves.
3. The license is described as a standard **FDP (Federal Demonstration Partnership) data
   transfer form** -- the page notes it "should be easy to obtain a signature" for
   institutions already familiar with FDP agreements.
4. Sign page 3 of the PDF specifically (per an example image shown on the page).
5. Send the signed form to **Prof. Carlos Busso**.
6. Each institution needs its own signed agreement; if a previous MSP-Podcast version was
   already licensed, only the challenge/update version needs a fresh request.

### Summary table (copy-paste ready)

| Dataset | Mechanism | Real URL(s) | Extra required info |
|---|---|---|---|
| IEMOCAP | Online web form | `sail.usc.edu/iemocap/release_form.php` | Academic email required; 3-5 day manual review; must cite Busso et al. 2008 |
| MSP-IMPROV | Signed PDF + email | Form: `lab-msp.com/MSP/publications/AcademicLicense-MSP-IMPROV.pdf` · Send to: Prof. Carlos Busso | Signed by research-group director; group leader cc'd + added to agreement list |
| MSP-Podcast | Signed institutional data-transfer PDF + email | Form: `lab-msp.com/MSP/publications/Busso-FDPDTUA-MSP-Podcast-v4.pdf` · Send to: Prof. Carlos Busso | Requires university sponsored-research-office signature (FDP form), not just the researcher |

None of these three could be submitted on the user's behalf this session (submitting
forms with personal/institutional details is the user's own action per this project's
standing rule) -- this checklist exists so the user can complete all three without
re-searching, same pattern as Day 310's GEMEP/K-EmoCon/EAV checklist.

## What was NOT done this session

- No fabricated/placeholder training data for IEMOCAP/MSP-IMPROV/MSP-Podcast -- all three
  remain access-gated, real, unobtained.
- No modification of the existing production `h_aggressive_speech` crosslang pipeline
  (`day106_h_crosslang_remain.py` and its dependencies are untouched) -- Day 312's retrain
  is a standalone experiment in its own push directory.
- No detector/wiring/tflite-integration/pubspec/backend changes -- out of scope per this
  session's constraints; `h_cremad_intensity_cold_anger.tflite` is a research artifact in
  `kaggle_notebooks/day312_h_cremad_intensity_push/final/`, not wired into the shipped app.
- No push of either git repo (`zapsafe_mobile` / `kaggle_notebooks`) -- local commits only,
  per this session's instructions.
