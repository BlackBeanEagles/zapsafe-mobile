# Day 286 — m1_pocket_muffled actor-level split retrain (real Kaggle run, verified)

## Status: leakage theory tested and NOT confirmed as the (sole) cause — model remains near chance on a true held-out split. Still NOT shippable, NOT wired.

Day 283 fixed a degenerate constant-1.0 output bug but its reported AUC
0.8525 was flagged as inflated by sample-level train/test leakage (the
same pattern on record for `m1_scream_v2` in `PREPROCESSING_SPEC.md`).
This session implemented and ran the actual fix — an actor/source-level
split enforced *before* augmentation — and independently re-verified the
result on RAVDESS actors the model genuinely never trained on. The
leakage was real and is now closed, but closing it did **not** produce a
real-world-competitive model: independent AUC on the true held-out
actors is 0.50–0.56, versus the model's own (now leakage-free) reported
0.837. The confound this task set out to test is confirmed to exist and
is now fixed, but it was **not** the dominant cause of the Day 283
inflated number — something else is going on (see Section 5).

## 1. What changed vs Day 283

`kaggle_notebooks/m1_pocket_muffled_push` (worktree
`kaggle_notebooks_day286`, branch `day286-pocket-muffled-actorsplit`,
commit `d2d5b45`) — `day286_m1_pocket_muffled_actorsplit.py`:

1. `find_ravdess_files()` now also returns a `path -> source_id` map,
   where source_id is the RAVDESS **actor id** parsed from the filename
   (field 7 of `modality-vocalchannel-emotion-intensity-statement-
   repetition-actor.wav`). `find_esc50_negatives()` returns a similar
   map keyed by each ESC-50 file's own stem (one group per file, since
   ESC-50 clips aren't duplicated across each other but each file still
   spawns multiple augmented samples).
2. New `group_split()` helper: splits a list of **source ids** (not
   paths, not samples) into train/test partitions, then assigns every
   path whose source id falls in a partition to that side. No augmented
   variant of a source clip can appear on both sides, by construction.
3. `main()` rewritten: RAVDESS actors (shared by positives and RAVDESS
   negatives) are split 70/15/15 into train/val/test actor sets
   (`random_state=42` for train vs. temp, `43` for the temp→val/test
   split) *before* any augmentation. ESC-50 files get their own
   analogous split. `build_dataset()` is now called **three times**,
   once per split, each only ever seeing paths whose source id belongs
   to that split — augmentation happens strictly inside each already
   disjoint partition.
4. Explicit verification: `assert` statements check zero source-id
   overlap between train/val, train/test, and val/test before training
   starts; the run would have crashed (kernel status `error`) if this
   didn't hold. It held — see Section 2.
5. Pocket-only test set (`build_pocket_test_set`) is now built from
   **test-split-only** positive/negative paths, so it can't share actors
   with training data either.
6. Noise pool for SNR mixing is now drawn only from train-split ESC-50
   clips (a smaller additional leakage-hardening, not central to the
   fix).
7. Report JSON now includes a `leakage_fix` block recording the actual
   number of train/val/test source ids and `zero_overlap_verified`.

## 2. Real Kaggle run — what actually happened

Kernel `hridyajain/day286-m1-pocket-muffled-actor-split`, pushed and
polled to completion this session (`kaggle kernels status`, real
terminal states):

- v1: pushed, ran ~running for ~13 minutes, completed successfully on
  the first attempt (`status: complete`) — no crash/retry needed this
  time.

**Official report** (`m1_pocket_muffled_report.json`, from the kernel's
own actor-disjoint split):

```
auc: 0.837
accuracy: 0.7315
precision_scream: 0.5596
recall_scream: 0.7992   (target 0.82 -- not met)
pocket_recall: 0.79     (target 0.85 -- not met)
support_positive: 1280, support_negative: 2676
leakage_fix:
  split_level: source_id (RAVDESS actor / ESC-50 file)
  n_train_sources: 1417
  n_val_sources: 303
  n_test_sources: 304
  zero_overlap_verified: true
```

24 RAVDESS actors were split into train=17, val=3, test=4 actors (the
1417/303/304 "sources" figure also includes the much larger pool of
individually-grouped ESC-50 files). The zero-overlap assertions in the
script passed (the run would have raised `AssertionError` and the
kernel would show `status: error` otherwise — it showed `complete`).

## 3. Independent re-verification (the check that matters)

Re-ran the same real-RAVDESS clean/muffled x pos/neg methodology used in
Day 283, but restricted strictly to the **4 RAVDESS test-split actors**
(actors 06, 11, 14, 16 — recovered by re-running the training script's
own `group_split()` logic with the same random seeds, so this is exactly
the actor set the model never trained or validated on). n=80 per class
(320 predictions per checkpoint: 80 pos + 80 neg, each in clean and
muffled form).

**Degenerate-constant check — PASSED, no regression:**

| checkpoint | std | min | max | exact-1.0 | exact-0.0 |
|---|---|---|---|---|---|
| `m1_pocket_muffled.tflite` (int8) | 0.210 | 0.109 | 0.938 | 0 | 0 |
| `m1_pocket_muffled_float32.tflite` | 0.135 | 0.242 | 0.971 | 0 | 0 |

**Real-world discrimination check — FAILED, at/near chance:**

| checkpoint | overall AUC | clean-only AUC | muffled-only AUC |
|---|---|---|---|
| `m1_pocket_muffled.tflite` (int8) | 0.498 | 0.531 | 0.494 |
| `m1_pocket_muffled_float32.tflite` | 0.560 | 0.599 | 0.480 |

These numbers (0.50–0.56) are essentially the same as Day 283's
independent numbers (0.51–0.59) — despite the split now being
genuinely actor-disjoint and verified so. The official in-run AUC
(0.837) does **not** hold up on true held-out actors.

## 4. Comparison

| | official (in-script) AUC | independent held-out AUC |
|---|---|---|
| Day 283 (sample-level split) | 0.8525 | 0.51–0.59 |
| Day 286 (actor-level split) | 0.837 | 0.50–0.56 |

Fixing the leakage barely moved the official number (0.8525 → 0.837)
and did not move the independent number at all. If sample-level leakage
had been the dominant cause of the Day 283 gap, closing it should have
pulled the official number down toward the independent one, or at least
narrowed the gap. It did neither.

## 5. Honest conclusion

**The leakage theory is not confirmed as the (sole or dominant) cause.**
The specific mechanism this task set out to test — augmented variants of
the same source clip appearing on both sides of the split — is real,
was really present in the Day 283 script, and is now genuinely fixed and
verified fixed (zero source-id overlap, checked by assertion, not
assumed). That part of the diagnosis is validated: it was a real bug in
the pipeline and is now closed.

But eliminating it did not close the AUC gap. The model's own
actor-disjoint held-out split still reports 0.837 while true
generalization to actors and any downstream deployment context is at
chance. This means either:

- the official 0.837 is still inflated by some *other* channel this fix
  didn't touch (e.g., the model may still be exploiting other
  RAVDESS-recording-specific artifacts — mic/room signature, background
  hiss level, or `pocket_muffle()`'s specific random-noise seed
  behavior — that generalize across an actor's clips but not to
  genuinely new recording conditions, which a same-corpus actor split
  cannot fully rule out even when disjoint), or
- the task itself (recognizing screams under heavy 800 Hz low-pass +
  50–70% attenuation, from a single 1-second mel-spectrogram frame,
  trained only on RAVDESS *acted* speech as positives) is a genuinely
  hard, thin-signal problem where within-corpus validation numbers
  (leakage-free or not) simply don't transfer, and a broader/more
  diverse audio source would be needed to know if the task is solvable
  at all with this architecture.

Either way: `m1_pocket_muffled` remains unshipped and unwired. This
retrain is real progress on data-pipeline hygiene (a documented, real
leakage bug is fixed and the fix is verified working), but it is not
progress on the model actually working, and should not be reported as
such.

## 6. Artifacts from this run

- `kaggle_notebooks_day286/m1_pocket_muffled_push/day286_m1_pocket_muffled_actorsplit.py`
  (the actor-split training script, committed to `kaggle_notebooks` on
  branch `day286-pocket-muffled-actorsplit`, commit `d2d5b45`)
- `kaggle_notebooks_day286/m1_pocket_muffled_push/kernel-metadata.json`
  (new kernel id `hridyajain/day286-m1-pocket-muffled-actor-split`)
- `kaggle_notebooks_day286/m1_pocket_muffled_push/output_day286/` (local,
  not committed: `.tflite` + `_float32.tflite`, report JSON, checkpoints,
  SavedModel dirs) — kept for reference, NOT copied into
  `zapsafe_mobile/assets/models/` per this task's explicit instruction
  not to touch shipped `.tflite` files.

## Next step (not done here)

The remaining gap between official (0.837) and independent held-out
(0.50–0.56) AUC needs its own root-cause pass — start by checking
whether `pocket_muffle()`'s Gaussian "rustling" noise (fixed `np.random`
global state, not reseeded per-sample in a way that ties it to content)
or any other per-run artifact correlates with label in a way an
actor-disjoint split still can't catch. Until that gap is explained and
closed, no AUC number for this model is trustworthy enough to consider
wiring.
