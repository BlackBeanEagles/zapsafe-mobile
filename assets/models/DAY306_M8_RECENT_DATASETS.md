# Day 306 — recency-focused search for new (2024-2025) real blink-liveness video datasets

Follow-up to `DAY302_M8_ITERATION4.md` (current best: AUC 0.7518, real MediaPipe
extraction + temporal augmentation + Conv1D+BiLSTM+attention, on 1,160/1,168
usable real videos from the MIT-licensed `hlly34/liveness-detection-zalo-2022`
corpus) and six total prior real dataset-search rounds across Kaggle, Hugging
Face, Zenodo, OpenSLR, Mendeley, IEEE DataPort, OSF, PhysioNet, Internet
Archive, AcademicTorrents, DAGsHub, BBC, SoundBible (`DAY294`, `DAY296`-style,
`DAY299_NEW_PLATFORMS_SEARCH.md`, `DAY300_PHYSIONET_ARCHIVE_SEARCH.md` — note:
Day 299/300 were actually scoped to the 6 stuck audio/text models, not
blink-liveness; the blink-liveness-specific dataset search history is
`DAY292`/`DAY294`/`DAY302`).

This session's job: a **recency-only** angle — check whether new real
face-liveness video datasets were published/indexed in 2024-2025 that did not
exist (or weren't indexed) during the earlier searches, rather than
re-searching the same catalogs by relevance.

## 1. Kaggle — sorted/filtered for real liveness video candidates

Searched `face liveness detection video dataset 2024 2025`. The dominant
real candidates are the **TrainingDataPro / UniqueData** family of
data-marketplace listings (the same vendor, "Unique Data" on Kaggle,
mirrored 1:1 on Hugging Face under `TrainingDataPro/*` and `UniqueData/*`):
`web-camera-face-liveness-detection`, `asian-people-liveness-detection-video-dataset`,
`black-people-liveness-detection-video-dataset`, `hispanic-people-liveness-detection-video-dataset`,
`caucasian-people-liveness-detection-dataset`, `real-vs-fake-anti-spoofing-video-classification`,
`ibeta-level-1-liveness-detection-dataset-part-1`, `on-device-face-liveness-detection`.

Verified directly via the Kaggle API (`kaggle datasets metadata` /
`kaggle datasets files`, not just search-result text) for three of these,
covering both older and newer upload dates:

| dataset | creation date (real, from Kaggle API) | license (real, from Kaggle API) |
|---|---|---|
| `real-vs-fake-anti-spoofing-video-classification` | 2023-10-30 | **Attribution-NonCommercial-NoDerivatives 4.0 (CC BY-NC-ND 4.0)** |
| `asian-people-liveness-detection-video-dataset` | **2024-04-17** | **CC BY-NC-ND 4.0** |
| `ibeta-level-1-liveness-detection-dataset-part-1` | **2026-03-02** | **CC BY-NC-ND 4.0** |

So this vendor family does include genuinely new upload dates (2024 and even
2026), but every listing checked carries the identical **CC BY-NC-ND 4.0**
license — NonCommercial and NoDerivatives — which fails this project's
established open-license rule (NC/gated = not usable) regardless of upload
date. The dataset descriptions themselves confirm the pattern: each Kaggle
page states "This is just an example of the data. Leave a request [here] to
learn more," i.e. these are marketing teasers for a paid commercial dataset
at `unidata.pro`, not standalone open corpora. **Rejected on license, for
all dates checked — not a recency-driven finding, a structural one.**

## 2. Hugging Face — recently-updated liveness/anti-spoofing search

`UniqueData/*` and `TrainingDataPro/*` on Hugging Face are direct mirrors of
the same Kaggle vendor above (same organization, same content, same
`unidata.pro` marketing links) — same CC BY-NC-ND rejection applies, no
independent new candidate. No other real, video-content, non-mirrored
liveness/anti-spoofing dataset with a 2024-2025 creation date and an open
license (CC0/MIT/CC-BY/Apache) surfaced in this search.

## 3. Zalo AI Challenge — later-year liveness track check

Checked `challenge.zalo.ai` and general search for Zalo AI Challenge tracks
in 2023, 2024, and 2025. **Zalo AI Challenge 2022 was the only edition that
ran a liveness-detection track.** 2023's challenge covered different tasks
(e.g. an elementary-math-solving track); no evidence of a 2024 or 2025
edition, and no evidence of any later liveness-detection track, turned up in
search results or on Zalo's own GitHub/Kaggle presence. **No new Zalo
liveness data exists to pull in.**

## 4. Papers With Code / arXiv — newest face-liveness/anti-spoofing datasets

Checked `paperswithcode.com/task/face-anti-spoofing/latest` plus arXiv
search for 2024-2025 face-anti-spoofing dataset papers. Two real, genuinely
new (by publish date) candidates surfaced:

- **UniAttackData** (IJCAI 2024 / CVPR 2024 workshop, 1,800 subjects, 28,706
  videos, physical+digital attacks) — real and video-based, but **gated**:
  access requires signing a licensing agreement and emailing the authors for
  approval before a download link is shared. **Rejected on access gating**,
  same category as Day 299/300's PhysioNet/IEEE DataPort rejections.
- **FaceCoT** (arXiv 2506.01783, first submitted June 2025) — a genuinely
  new 2025 publication, claims CC BY 4.0 on its OpenReview page, but it is a
  **1.08M-sample VQA/chain-of-thought annotation dataset built on top of
  existing face-anti-spoofing image benchmarks**, not a new raw video
  corpus, and no public dataset repository/download link was found in this
  session (paper states intent to release, not yet located as downloadable).
  **Rejected on content-type mismatch** (annotation/QA layer over old
  images, not new liveness video) **and on unconfirmed availability**.

No other new (2024-2025) face-liveness video dataset paper with a confirmed
open license and a public download surfaced on Papers With Code or arXiv in
this session.

## Verdict

**Nothing genuinely new and usable was found.** Every real 2024-2025-dated
candidate failed the same two gates prior rounds already established:
license (TrainingDataPro/UniqueData family — uniformly CC BY-NC-ND 4.0
regardless of upload date; UniAttackData — EULA-gated) or content match
(FaceCoT — an annotation dataset over old images, not new raw video, and not
yet confirmed publicly downloadable). The Zalo AI Challenge, the original
source of the current 1,168-video corpus, has not run a liveness track since
2022 and has no newer/larger dataset to offer.

This is a real, verified negative result, not a budget-exhaustion artifact:
the TrainingDataPro/UniqueData license was confirmed via direct Kaggle API
metadata calls (not just search-result text) across three listings spanning
2023, 2024, and 2026 upload dates, with an identical NC-ND license every
time — a structural (vendor-licensing-policy), not a temporal, blocker. The
dataset landscape for real, open, video blink-liveness data has **not
meaningfully changed** since Day 294's three-round search or Day 302's
writeup. **No retrain was attempted this session** — there is no new real
data to retrain on, and the task's own instructions make a retrain
conditional on finding a genuinely new usable dataset first.

The 0.7518 AUC from Day 302 remains the current best real, documented result
for `m8_blink_liveness`.

## What this session did NOT do

- No retrain attempted (no qualifying new dataset found).
- No `zapsafe_mobile` detector/wiring/`.tflite`/`pubspec.yaml` files touched.
- No backend files touched.
- No `kaggle_notebooks` files touched (nothing to commit there — no retrain).
- No datasets downloaded in full; only Kaggle API `metadata`/`files` calls
  (lightweight JSON/listing calls, not bulk data downloads) and real web
  search/fetch were used for verification.

## Where this was committed

- `zapsafe_mobile`, branch `day306-m8-recent-datasets` (fresh worktree off
  `main` at commit `58a84c7`, via `git worktree add`): this doc only.
- Not pushed.
