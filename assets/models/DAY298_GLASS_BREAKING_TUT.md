# Day 298 — `m_glass_breaking`: TUT Rare Sound Events 2017 licensing verification

Follow-up to Day 296's wider-web search, which flagged the **TUT Rare Sound
Events 2017 (DCASE2017 Task 2)** dataset on Zenodo as a genuinely new
candidate for `m_glass_breaking`, with an explicit caveat: the license is
per-clip (Freesound-sourced) rather than a single blanket CC0/CC-BY badge,
and needed a real follow-up check before any retrain.

This session's job was: do that licensing check first, as a hard gate, and
only retrain if it came back genuinely clear.

## Licensing investigation (real, done this session)

Checked both records directly via their live Zenodo pages:

- **Evaluation set** — https://zenodo.org/records/1160455
- **Development set** — https://zenodo.org/records/401395

**Finding 1 — Zenodo's own top-level license classification.**
Both records are classified by Zenodo/the depositor (Tampere University
Audio Research Group) as **"Other (Non-Commercial)"** in the record
metadata itself. This is not a per-clip nuance — it's the license badge
Zenodo shows for the dataset as a whole.

**Finding 2 — LICENSE.txt (1.0 kB) contents.**
The evaluation record's `LICENSE.txt` states the archive's audio is
governed by a mix of: **CC BY-NC 3.0, CC BY 3.0, Sampling Plus 1.0, and
CC0 1.0**, split across three separate components, each with its own EULA:
`source_data/bgs/EULA.pdf` (background recordings), `mixture_data/EULA.pdf`
(generated mixtures), and
`TUT_Rare_sound_events_mixture_synthesizer/EULA.pdf` (the synthesis
software), with additional per-clip terms recorded in individual `.yaml`
metadata files paired with each sound event recording.

**Finding 3 — FREESOUNDCREDITS.txt (17.9 kB).**
Confirmed present and would list individual Freesound clip attributions,
but per-clip license type isn't broken out on the Zenodo page itself —
resolving it fully would require downloading the archive and cross-referencing
each credited clip's Freesound license, since the dataset mixes at least
one NC-restricted license class among CC0/CC-BY/Sampling Plus.

## Verdict: licensing-blocked, no retrain performed

This is a genuine, confirmed blocker, not an assumption:

1. **CC BY-NC 3.0 is explicitly named** as one of the licenses covering
   part of the archive (background recordings and/or mixtures) — this is
   real, confirmed NC contamination, not a hypothetical.
2. The dataset's components (source events, backgrounds, mixtures,
   synthesizer) each carry **separate EULAs**, and the "glass break"
   positive-class training data is not cleanly separable from the
   NC-covered components without downloading and parsing the full 7.4GB
   archive plus every per-clip `.yaml` file and all three EULA.pdf terms —
   this is not a case where you can just take one folder and know it's
   clean.
3. Zenodo/the depositor's own record-level classification for **both**
   the dev and eval sets is **"Other (Non-Commercial)"** — the dataset's
   own custodians label the release as non-commercial, which is
   independent corroboration of the per-clip finding, not just an
   inference from Freesound norms.

Per this project's established rule (same standard applied to the
`m8_blink_liveness` NC-license rejection earlier this session): a model
trained on data with confirmed, non-trivial NC contamination cannot be
shipped in a commercial app, and "mostly clear with some NC mixed in" is
treated as blocked, not filtered-and-used, unless the NC-covered files can
be cleanly and verifiably excluded before training. Here, exclusion would
require full-archive download + per-clip cross-referencing against
Freesound's own license API for every credited clip in
`FREESOUNDCREDITS.txt`, which is out of scope for "clear enough to use
today," and even after such filtering the archive's own custodians and its
per-component EULA structure still frame the release as non-commercial in
nature (background/mixture components in particular).

**Conclusion: TUT Rare Sound Events 2017 is NOT used. No retrain was
performed this session.**

`m_glass_breaking` remains at its prior best: **fp32 AUC 0.7485, recall
0.535**, trained on ESC-50/FSD50K/NIGENS/AudioSet real data (per this
session's context). This is a real legal/licensing blocker, reported
plainly, not a training or evaluation result.

## What this session did NOT do

- No dataset was downloaded (the 7.4GB archive was not pulled; only the
  Zenodo record pages, `LICENSE.txt` metadata, and file manifests were
  read directly).
- No retrain was attempted — the licensing gate blocked it before any
  training step.
- No `zapsafe_mobile` detector/wiring files touched, no `.tflite` files
  changed, no `pubspec.yaml` changed, no backend files touched.
- No `kaggle_notebooks` commit was made (no retrain happened, so there is
  no script/kernel-metadata to commit).

## Where this was committed

- `zapsafe_mobile`, branch `day298-glass-breaking-tut` (fresh worktree off
  `origin/main`): this doc only.
- Not pushed.
