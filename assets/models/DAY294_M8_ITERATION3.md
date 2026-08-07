# Day 294 — m8_blink_liveness iteration 3: real dataset search (no retrain)

Follow-up to `DAY292_M8_ITERATION2.md`, which fixed the feature extractor
(working MediaPipe FaceLandmarker replacing the coarse Haar-cascade proxy)
and moved AUC from 0.5829 to **0.7186** on the same 1,168-video
`hlly34/liveness-detection-zalo-2022` corpus (1,160 usable). Still below the
0.85 F1 acceptance bar. Day 292 diagnosed the remaining gap as likely
dataset size/diversity, not extractor quality — this session tests that by
searching for additional real, permissively-licensed video data to combine
with Zalo.

## 1. Real search performed

14 distinct Kaggle search-term variants were run (`kaggle datasets list -s
"<terms>"`), covering face-liveness-video, replay-attack-video,
presentation-attack-detection-video, deepfake-video, CASIA, OULU-NPU, SiW
("spoof in the wild"), blink-detection-video, idiap replay-attack,
mask-attack-video, and general anti-spoofing/liveness terms. Full query
list and per-candidate disposition are logged in the companion
`kaggle_notebooks` repo at
`day294_m8_dataset_search/SEARCH_LOG.md` (same branch,
`day294-m8-iteration3`).

Every candidate with any plausible license was checked with `kaggle
datasets metadata <slug>` and its real `licenses` field and description
read — not assumed from memory of Day 290's findings.

## 2. Real findings

- **Publisher-level licensing pattern confirmed and extended**: every
  `trainingdatapro/*` liveness/anti-spoofing set is CC BY-NC 4.0 (matches
  Day 290's earlier finding); this session additionally confirms the same
  restriction applies uniformly across **every** `axondata/*` set (CC
  BY-NC 4.0) and **every** `unidpro/*` and most `tapakah68/*` presentation-
  attack sets (CC BY-NC-ND 4.0) — all carry "contact us to buy the dataset
  for commercial use" language. These publishers together account for the
  large majority of liveness/anti-spoofing video results on Kaggle.
- **Two re-uploads of restrictive academic datasets** (`mizaku/oulu-npu-test`
  and `nagatoyuki1218/anti-spoofing-siw-dataset`) self-tag `apache-2.0`, but
  OULU-NPU and SiW are both real academic corpora that require a signed EULA
  from the original institution (University of Oulu / MSU) and grant no
  redistribution rights — a third-party Kaggle uploader has no real
  authority to relicense them as Apache-2.0, so this tag is not credible
  provenance and was rejected on that basis. The OULU-NPU re-upload is also
  static test frames, not video, independently confirming the earlier
  rejection of the frame-only OULU-NPU still holds.
- **Image-only datasets re-encountered**: NUAA (`aleksandrpikul222/nuaaaa`),
  LCC-FASD (`faber24/lcc-fasd`), and `harshalakshan/liveness-detection-dataset`
  are all static-image corpora, consistent with the already-established
  "static images ruled out" constraint.
- **No new video corpus found**: `firefliesqn/zalo2022-liveness` is a
  duplicate re-upload of the same Zalo AI Challenge 2022 data already used.
  DFDC and FaceForensics++ have real, permissively-usable video, but are a
  different task domain (AI face-swap/deepfake detection vs. physical
  print/replay/mask presentation-attack liveness) — mixing them in was
  judged likely to dilute rather than genuinely diversify the blink/EAR
  signal this model is trained on, so not pursued.

## 3. Real verdict

**No genuinely new, permissively-licensed real video liveness dataset was
found.** This is treated as a valid, expected outcome per the task
instruction, not a shortfall in search effort (14 query variants, 20+
individually license-checked candidates).

**No retrain was performed.** There is no new real data to combine with the
existing 1,160-usable-video Zalo pool; retraining on the same data again
would not produce a different, meaningful number. **Day 292's real result
stands as current: AUC = 0.7186, F1 = 0.6552** (below the 0.85 acceptance
bar).

**This is reported as the last reasonable iteration for `m8_blink_liveness`
without new real data collection**, per the task brief's own framing. The
model should be treated as "as good as it gets on this dataset family" —
closing the remaining gap to 0.85 F1 would need either genuinely new,
properly consented/licensed video collection (not available on Kaggle under
usable licenses as of this search), temporal augmentation/architecture work
on the existing data, or reconsidering the 0.85 bar itself (inherited from
Day 98's synthetic-data model, never validated against real replay-attack
video) — not a 4th dataset-search iteration.

- **This model was NOT wired into the app.** No detector/wiring,
  `.tflite`/pubspec/backend files touched this session. `zapsafe_mobile`
  still has no camera/face-capture pipeline (Day 290/292's finding, not
  re-verified here but unchanged).

## Files touched this session

- `assets/models/DAY294_M8_ITERATION3.md` (this file) — new, in
  `zapsafe_mobile`, branch `day294-m8-iteration3` (worktree off `main`).
- No detector/wiring files, `.tflite` files under `assets/models/`,
  `pubspec.yaml`, or backend code touched.
- Companion change in the separate `kaggle_notebooks` repo (not this repo),
  same branch name `day294-m8-iteration3`:
  - `kaggle_notebooks/day294_m8_dataset_search/SEARCH_LOG.md` — full query
    list and per-candidate license/format disposition from the real Kaggle
    search this session.
