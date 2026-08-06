# Day 297 — j_whisper_distress retrain on real SLR110 whisper audio

Follow-up to Day 296's wider-web dataset search, which found OpenSLR-110
(Thorsten Muller German Emotional-TTS, CC0) as a genuinely real
whisper-vs-normal-voice corpus for `j_whisper_distress`, previously
confirmed blocked because the "whisper" positive class was purely a
synthetic `apply_whisper()` gain-reduction transform (multiply by 0.10,
add a little noise) applied to normal-voice emotion clips — no real
recorded whisper speech anywhere.

## 1. Real training script found

`kaggle_notebooks/j_whisper_distress_push/day92_j_whisper_distress.py` is
the real Day 92 training script. Confirmed:
- Task: binary classifier, "distress" (RAVDESS fear/anger/disgust,
  CREMA-D ANG/DIS/FEA, EmoDB W/E/A) vs "calm_whisper" (neutral/happy
  emotion clips, VoxCeleb-Indian normal speech, ESC-50 quiet ambient),
  ALL passed through `apply_whisper()` — literally `y = y * 0.10` plus
  Gaussian noise. That is the entire "whisper" simulation.
- Input: 38-dim handcrafted prosody feature vector (f0 mean/std, jitter,
  shimmer, HNR, 13 MFCC mean+std, RMS mean, ZCR, spectral centroid,
  spectral rolloff), extracted from a random 3s window at 16kHz.
- Model: Dense(128)-BN-Dropout-Dense(64)-Dropout-Dense(32)-Dense(1,sigmoid),
  exported int8 TFLite.
- Confirmed reason for block: no real whisper corpus, only a synthetic
  gain transform. Matches Day 296's documented finding exactly.

## 2. Real dataset verification (independent, not trusted blindly)

Fetched `https://openslr.org/110/` directly this session (not from the
Day 296 report). Confirmed on the actual page:
- License: **Creative Commons (CC0) Licence**, explicit, no restrictions.
- Content: 300 identical phrases x 8 deliveries, 2,400 recordings, 175 min
  total, including **whispering: 22 min** and **neutral: 19 min**.
- 22.05kHz mono, normalized -24dB, `thorsten-emotional_v02.tgz`, 399MB
  (actual downloaded size: 399,301,812 bytes, matches).

Downloaded and extracted the real archive. Verified directly:
- `whisper/` = 299 real `.wav` files, `neutral/` = 300 real `.wav` files.
- `README.md` inside the archive independently re-confirms CC0 licensing
  in the author's own words ("i contribute this dataset under CC0
  licence").
- `thorsten-emotional-metadata.csv` confirms filenames are content-hash
  GUIDs of the phrase text, reused identically across all 8 emotion
  subfolders (e.g. `f2b06aa1103c26d530cc919c5b423224.wav` = "Bisher kein
  einziges Mal." in every folder) — this is what made a real
  phrase-disjoint train/test split possible without relying on any
  assumed numbering scheme.

Re-uploaded as a Kaggle dataset (`hridyajain/zapsafe-slr110-thorsten-whisper`,
380MB zipped) for kernel use; verified live and file-listed via
`kaggle datasets files` before use (not assumed from the create-command
response alone).

## 3. Integration

New script: `kaggle_notebooks/j_whisper_slr110_push/day297_j_whisper_slr110.py`.

- Real SLR110 whisper/neutral audio is used **raw** (no synthetic
  transform) as the primary whisper-acoustic signal, split **phrase-disjoint**
  (train/test never share a spoken sentence) — 479 real train / 120 real
  test samples.
- The old Day 92 emotion corpora (RAVDESS/CREMA-D/EmoDB + VoxCeleb/ESC-50
  negatives) are kept only as a **supplementary distress-content** signal,
  still run through the legacy synthetic `apply_whisper_synthetic()`
  transform, and clearly labeled `synthetic_supplement` in the report so
  real and synthetic contributions are never conflated (9,316 samples).
- Two evaluations are reported separately: real held-out (SLR110 only,
  phrase-disjoint) and combined validation (real + synthetic mixed, 15%
  held out from the full training pool).

## 4. Retrain — real Kaggle run, monitored to completion

Kernel: `hridyajain/zapsafe-j-whisper-slr110-retrain`. Pushed, polled
`kaggle kernels status` every ~20-30s from push until `"complete"`
(~1h27m real wall-clock runtime — CPU-bound librosa feature extraction
over ~10k emotion-corpus clips + SLR110). Outputs pulled with
`kaggle kernels output` and verified as real files (not just the log
claiming success): `.tflite` (24.0KB int8), `_f32.tflite`, `_norm.json`,
`_report.json`, `_training_log.csv`, checkpoint weights.

Kernel log directly confirms real data loaded (not fabricated):
```
[SLR110 REAL] whisper=299 neutral=300
SLR110 phrase-disjoint split: train=479 test=120
TRAIN POOL: pos=5446 neg=4349 (real_train=479, synthetic_supplement=9316)
REAL held-out (SLR110, phrase-disjoint) AUC=1.0000 ACC=1.0000
```

## 5. Real evaluation

**Real held-out (SLR110, phrase-disjoint split, 120 samples, 60/60 class
balance): AUC = 1.0000, accuracy = 1.0000, precision/recall/F1 = 1.0 on
both classes.**

**Combined validation split (real + synthetic-supplement mixed, 1,305
samples): AUC = 0.7718, accuracy = 0.684** — the synthetic-supplement
distress-detection task is noticeably harder and much less clean than the
real whisper-vs-neutral acoustic separation.

### Honest sanity check — single-speaker overfitting concern

A perfect 1.0 AUC/accuracy on a single-speaker, single-session real corpus
is exactly the red flag the task anticipated: the model may simply be
learning "this is Thorsten's recording chain in whisper mode" rather than
"this is what whispering sounds like in general." A phrase-disjoint split
only rules out sentence memorization, not speaker/session memorization —
with one real speaker there is no way to build a genuinely disjoint
speaker split.

**Informal n=2 generalization check, independent source** (not SLR110, not
any Day 92 emotion corpus): two real audio clips fetched directly from
Wikimedia Commons this session —
`Whispering-example.ogg` (real English whisper) and
`Watt_Wikipedia_article_spoken_version.ogg` (real English narrated
speech, used as the normal-voice clip). Ran the trained int8 model against
sliding 3s windows of each via a second Kaggle kernel
(`hridyajain/zapsafe-j-whisper-slr110-gencheck`), polled to completion,
real output pulled:

```
wiki_whisper1.ogg (true=whisper): predicted_label=neutral, mean_prob_whisper=0.0076  -> WRONG
wiki_normal1.ogg  (true=neutral): predicted_label=neutral, mean_prob_whisper=0.2999  -> correct (barely; one 3s window scored 0.996, near-miss)
```

**This confirms the overfitting concern with real evidence.** The model
completely fails to recognize a real whisper clip from a different
speaker/language/recording chain (predicts it as confidently NOT whisper,
prob 0.008), and only weakly/inconsistently gets the normal-speech clip
right (window-level variance 0.00006 to 0.996). This is a genuine,
informative failure, not a benchmark result — n=2, one language switch
(German training data vs English test clips) confounds the check further
— but it is real, directly-run evidence that the perfect SLR110 held-out
score does not reflect general whisper-detection ability.

## 6. Plain verdict

`j_whisper_distress` moves from **"confirmed blocked, no data"** to
**"real signal exists, but confirmed single-speaker/session-overfit, not
yet generalizable."** This is genuine progress — a real recorded
whisper-vs-normal corpus now exists and trains cleanly (real 1.0 AUC
in-domain) where none existed before — but the informal cross-source
check shows the model does not yet transfer past Thorsten's specific
voice/session, consistent with having only one real speaker and one real
recording session as ground truth. Per the task brief, **this model is
NOT wired into the app or detector.** A future session would need either
more real speakers/languages, or an explicit reframing of the eval to
report the single-speaker result honestly as a ceiling rather than a
generalizable metric.

## What this session did

- Real SLR110 archive downloaded (399,301,812 bytes verified) and
  extracted; license re-verified independently via WebFetch on the live
  openslr.org page and the archive's own bundled README.md.
- Real Kaggle dataset upload, verified live via `kaggle datasets files`.
- Real retrain kernel pushed and polled to `"complete"` (~1h27m), real
  outputs pulled and inspected.
- Real generalization-check kernel (independent Wikimedia Commons audio,
  not part of any training corpus) pushed and polled to `"complete"`,
  real output pulled and inspected.
- No detector/wiring files, `.tflite` production bundle, `pubspec.yaml`,
  or backend files touched.

## Where this was committed

- `zapsafe_mobile`, branch `day297-whisper-slr110-retrain` (fresh worktree
  off `origin/main`): this doc only.
- `kaggle_notebooks`, branch `day297-whisper-slr110-retrain` (fresh
  worktree off local `master`): `day297_j_whisper_slr110.py`,
  `day297_generalization_check.py`, both `kernel-metadata.json` files.
- Not pushed (either repo).
