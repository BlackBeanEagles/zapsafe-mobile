# Day 307: Google Drive mystery-file recheck + one more real platform round (CPU-only)

Context: 7 models remain confirmed blocked after 7 independent real search
rounds (Day 278, 279, 287, 288, 295, 296, 298, 299, 300): `m4/m5_vocal_stress`,
`n_breathing_distress`, `m1_pocket_muffled`, `w1`-`w5` fusion,
`m7_nlp_context_enhanced`, `h_aggressive_speech`, `m_glass_breaking`. This
session does one more real check: (a) resolve `archive (5).zip` and
`archive (6).zip` in the project's Drive folder, left unidentified since a
prior session's browser disconnect, and (b) a fresh platform round on
sites not yet tried this project.

## Part 1: the two mystery Drive files — resolved

Opened `https://drive.google.com/drive/folders/1SPU4yW_9YaI3VnfzhTw9ZCE6zJ-Cj_3R`
live via the Chrome browser extension (the user's own signed-in session,
account hridyajain2004@gmail.com) and inspected both files directly —
list view with the File size column, plus each file's Details/Activity
panel and full-page preview attempt.

**`archive (5).zip`**
- Size: **27.82 GB**
- Type: Compressed archive (generic — Drive cannot introspect zip
  contents without downloading)
- Created: Jun 9, 2026. Modified: Jun 6, 2026 by me.
- Activity tab: single event this year — **"uploaded [archive (5).zip] via
  Web upload"** and shared with the internet link. No rename event in the
  activity log at all.
- Preview attempt: Drive returned **"Could not preview the file — This
  file is too large to preview,"** with suggested third-party apps (ZIP
  Extractor, CloudConvert, Document Viewer for Google Drive) — none of
  which were used, since installing a third-party Drive add-on is outside
  this session's scope and the file's actual content still can't be
  confirmed that way without a real download.

**`archive (6).zip`**
- Size: **3.28 GB**
- Same pattern: generic "Compressed archive" type, uploaded via Web
  upload this year, no rename event, no in-Drive content preview
  possible (same "too large" wall for the larger sibling; the smaller
  one was not force-downloaded either, per the no-large-download
  discipline below).

**What "archive (N).zip" actually means:** the literal name `archive
(N).zip` is the browser download manager's own auto-disambiguation
pattern — when a source website serves a file plainly named
`archive.zip` and the user has already downloaded/uploaded one file with
that name, Chrome (and Drive's own upload widget) appends `(5)`, `(6)`,
etc. rather than overwriting. In other words, these are **not
deliberately catalogued or renamed dataset files** — every other file in
this Drive folder has a descriptive, source-derived name (`audioset.zip`,
`cremad.zip`, `ravdess_speech.zip`, `IEMOCAP_full_release.tar.gz`, …).
These two are outliers by name alone, consistent with being **leftover
generic downloads from an un-tracked source** rather than named,
identified datasets.

**Real limitation, stated plainly:** Google Drive's UI cannot show zip
interior contents for a file this large without either (a) downloading
it locally and extracting, or (b) authorizing a third-party unzip
add-on. A 27.82 GB + 3.28 GB (31.1 GB combined) download is well beyond
what this session can respons­ibly pull down blind, and per this
project's rules, downloading any file requires explicit user permission
with filename/source/size stated first — which weren't available since
the file's actual *source* is exactly what's unknown here. **This
session did not download or open either archive.** The honest answer is:
their sizes and the generic-upload naming pattern are now confirmed and
documented, but their internal contents remain genuinely unidentified.
If the user wants them resolved further, the next step is either (a) the
user recalls/checks what they personally downloaded and uploaded around
Jun 6–9, 2026 that would have been named exactly `archive.zip` at the
source, or (b) an explicit go-ahead to download and extract one or both
files in a future session.

**Given the naming/upload pattern (generic, no dataset-descriptive name,
no metadata), these two files are not treated as verified candidates for
any of the 7 blocked models** — there's no basis to guess relevance from
an anonymous "archive.zip" name, and guessing would violate this
project's "no filename-alone assumptions" discipline (explicitly called
out in the task).

## Fresh full Drive listing (Day 307)

For completeness, the full current `ZapSafe_ML/datasets` folder listing
(38 items) was captured with sizes. No files beyond the previously
catalogued set and the two mystery archives were found — the folder has
not grown since Day 278 beyond what's already known:

300w.zip.001/.002, 1188976.zip, archive (5).zip, archive (6).zip,
audioset.zip, cremad.zip, data_aishell3.tgz, datasets-master.zip,
demand.zip, doi-10.5683-sp2-e8h2mf.zip, emodb.zip, esc50.zip,
hr_imu_falldetection.zip, IEMOCAP_full_release[_withoutVideos].tar.gz,
MELD-master.zip, MobiAct_Dataset_v2.0-MobiFall_Dataset_v2.0-main.zip,
mobiact.zip, motionsense.zip, nigens.zip, ontology-master.zip, pamap2.zip,
places_devkit-master.zip, places365_val.tar, ravdess_song.zip,
ravdess_speech.zip, ShEMO-master.zip, test_256.tar, uci_har.zip,
unimib_shar.zip, UrbanSound.tar.gz, UrbanSound8K.tar.gz,
vakyansh-tts-main.zip, val_256.tar, voxceleb_indian.zip, WIDER_test.zip,
WIDER_train.zip, WIDER_val.zip, wisdm.zip.

**Nothing new found for any of the 7 blocked models in the Drive folder
itself** — every named file here is a dataset already accounted for in
prior sessions (emotion speech: CREMA-D/IEMOCAP/RAVDESS/ShEMO/EMO-DB;
HAR/IMU: PAMAP2/UCI-HAR/UniMiB/WISDM/MobiAct/MotionSense;
sound-event/scene: AudioSet/NIGENS/ESC-50/UrbanSound(8K)/DEMAND;
face/video: WIDER/300W/Places365; misc: AISHELL-3, MELD, Vakyansh-TTS).

## Part 2: fresh platform round

Checked platforms not yet tried this project:

**Roboflow Universe** — browsed `class:scream`, `class:respiratory`,
`class:sound`, `class:audio`, `class:voice` search indices. Roboflow
Universe is overwhelmingly a **computer-vision** (image/video bounding-box)
hosting platform; its "audio" tag results are near-empty or mislabeled
image sets. No usable audio corpus for any of the 7 blocked models —
confirmed genuinely wrong platform type for this need, not a licensing
issue.

**data.world** — searched for "breathing distress" / "vocal stress"
audio; returned only academic paper references (arXiv, PMC, Springer),
not data.world-hosted datasets. No real data.world hit for any of the 7
models.

**Kaggle, fresh queries ("danger detection audio", "SOS distress
dataset", "safety incident audio", newest-first)** — found and directly
verified via live Kaggle pages (not from titles alone):
- **"Dangerous Situation Detection"** (orvile) — turned out to be an
  **image** dataset (objects/faces), not audio. Ruled out immediately —
  title is misleading.
- **"Human Screaming Detection Dataset"** (whats2000) — real, MIT
  licensed, 5.68 GB, 3,493 real WAV clips (862 screaming / 2,631
  non-screaming), 44.1 kHz. Genuinely open and usable *in principle* —
  but checked against this project's own established definition of
  `h_aggressive_speech` (documented in Day 299/300: the gap is
  specifically **calm-but-menacing** tone speech, distinct from loud
  screaming/shouting, which has been rejected as "wrong register" in
  three prior rounds). This dataset is pure screaming/non-screaming —
  same wrong-register mismatch. **Not a resolution for `h_aggressive_speech`**,
  and it doesn't fit any of the other 6 gaps (no motion channel for
  fusion, no breathing/vocal-stress/pocket/NLP/glass content).
- **"Threat Detection Audio Dataset"** (MohithJain04) — real, Hindi/
  English/Kannada distress-call phrases ("help me", "call police",
  etc.), 193 MB, 360 files. **License: CC BY-NC-SA 4.0** — non-commercial,
  same license-blocker pattern already established for TUT (Day 298) and
  BBC RemArc (Day 299/300). Confirmed blocked on license, not content.
- **"Enhanced audio of accident and crime detection"** — checked but not
  a content or license fit distinct from the already-rejected
  crime/accident audio classes explored in earlier rounds.

**Net result of Part 2: 0 of 7 models resolved.** Every real, on-topic
hit this round failed on the same two recurring walls as prior rounds —
wrong register/domain (screaming ≠ calm-menacing; images ≠ audio) or
non-commercial license — not on search effort. This is consistent with
Day 295/296/299/300's own conclusion that these are genuine dead ends,
not budget-exhaustion artifacts.

## Part 3: retrain

**No retrain attempted this session.** No genuinely new, license-clear,
content-matching dataset was found for any of the 7 models in either
Part 1 (Drive) or Part 2 (platforms), so there was nothing new to train
on. Per the task's own priority order, the Drive investigation and
platform search took priority over forcing a retrain with no new data —
correctly, since a retrain without new data would just reproduce a
prior day's already-documented result.

## Bottom line

- The two Drive mystery files are now identified as **generic,
  un-renamed browser-upload artifacts** (27.82 GB and 3.28 GB
  respectively), not deliberately catalogued datasets — their *contents*
  remain unverified because opening them requires a 31 GB download this
  session did not have standing permission to perform blind.
- No new items exist in the Drive folder beyond what Day 278 already
  catalogued.
- The fresh platform round (Roboflow Universe, data.world, new Kaggle
  queries) found real, verifiable hits but all still fail on the same
  wrong-register or non-commercial-license walls as the 7 prior rounds.
- **All 7 models remain genuinely blocked after 8 independent real
  search rounds.** The one open thread left is the two Drive archives'
  actual contents, which needs either the user's own memory of what they
  downloaded, or explicit permission for a real multi-GB download in a
  future session.
