# Day 363 — I never searched Kaggle. One "blocked" item wasn't.

Three items have been reported as blocked-on-acquisition for days:

```
i_vehicle_crash   "VZCrash is the only public crash-IMU corpus, gated AND CC BY-NC"
h_aggressive/m4   "needs new natural (non-acted) speech data"
M9 / dcs_fusion   "XD-Violence is SharePoint + Baidu links; needs a manual download"
```

Those searches covered HuggingFace, Zenodo and the open web. **Kaggle was
never searched** — despite the account being configured since June and five
Kaggle datasets already sitting on this disk.

## 1. XD-Violence was never blocked. I was wrong.

The correction was in this repository the whole time. A Day 305 commit in
`kaggle_notebooks`:

> "Adds XD-Violence (**MIT**, `bypktt/xd-violence` Kaggle mirror) as a second
> real data source alongside UCF-Crime"

So XD-Violence is MIT-licensed, mirrored on Kaggle, and **this project had
already downloaded and trained on it**. Every note saying it needed a manual
SharePoint or Baidu download was wrong.

Available now:

```
bypktt/xd-violence                        76 GB   full set (the one Day 305 used)
shubhamnitc/xd-violence-test-split-videos 10 GB   the 800 FRAME-LEVEL labelled videos
```

The test split is the interesting one for M9: frame-level labels are
per-moment incident labels, which is what a fusion needs, at a tenth of the
size.

**Caveat that still stands:** Day 305 trained M3 on XD-Violence and got
**0.4950** test accuracy, *below* its 0.5944 UCF-Crime baseline. So this
data is available, not magic. And the domain objection is unchanged — movies
and CCTV, against six speech corpora already rejected for corpus mismatch.

**Also unchanged: the fusion needs three inputs and XD-Violence supplies
two.** `dcs_inference_engine.dart` fuses `[scream, motion, scene]`.
XD-Violence has audio and video; it has no IMU. Training a 3-input model
with the motion input held at a constant default would teach it to ignore
motion, and the model would then *look* like it uses motion at runtime while
contributing nothing — the silent-failure class this project keeps hitting.
A 2-input fusion with the gap documented is the honest version, and it is a
change to the engine, not just a new asset.

## 2. crash — two new candidates found, both rejected, for better reasons

### `drabdulbari/smartphone-imu-road-accident-detection` — CC0. **Fabricated.**

On paper it is exactly right: smartphone IMU, road accidents, CC0 public
domain, no licence problem at all. It is synthetic data, and not subtly:

```
peak acceleration        1.56 g  across ALL 8,000 rows including every crash
                                 (a hard brake alone is ~0.8 g; a real
                                  collision is 20-100+ g)
timestamp step           exactly 1.000 s for all 7,999 intervals, zero jitter
gyroscope, crash vs not  0.019 vs 0.020 -- IDENTICAL
                                 (a real crash is violent rotation)
trivial logistic AUC     1.0000 in-sample, linearly separable on raw features
crash rows               LOW speed (10 km/h vs 50) -- backwards
```

A model trained on this scores 1.0 in validation, ships, and never fires on
a real crash. That is precisely the placebo-ML failure this project already
suffered once. **Rejected.**

### `dinupadevinda/byd-atto-bmi160-imu-driving-events` — CC BY 4.0. **Real, but no crashes.**

Genuine BMI160 data: 62,187 samples, 4.19 g peaks, real session files,
jittered sampling. Contents are `lane_change` (43,411) and `harsh_braking`
(18,776). **Zero crash events** — the same shape as the Zenodo set rejected
earlier.

It is not worthless: real hard-braking and lane-change data is exactly the
**hard negative** set a crash detector needs so it does not fire on ordinary
driving. But negatives alone cannot train a detector.

**crash stays blocked** — now having examined and disproved the only CC0
candidate rather than having failed to find one.

## 3. natural speech — the mirrors are licence laundering

Kaggle has what look like the two corpora that would move h_aggressive/m4:

```
sachinbiswas7/msp-podcast-un-proccesed    17 GB   licence "Unknown"
dejolilandry/iemocapfullrelease           12 GB   licence "Unknown"
sangayb/iemocap                         1021 MB   licence "CC0: Public Domain"
```

**These are re-uploads of corpora that require a signed agreement.**
MSP-Podcast and IEMOCAP are both distributed under institutional licences.
A third party re-uploading them to Kaggle does not grant a licence, and
`sangayb/iemocap` claiming **CC0** on IEMOCAP is simply false.

Using them would be the EmotionTalk mistake with the excuse removed — there
the licence was one directory away and I missed it; here the licence is
known and the mirror contradicts it. **Not used.**

Legitimately-licensed natural speech does exist on Kaggle, and it is small:

```
infobayai/audio-call-center-english        27 MB   CC BY 4.0
infobayai/audio-call-center-*  (7 langs)  8-19 MB  CC BY 4.0
ahmadnafibudianto/e-seravd-speech-emotion  6 GB    CC BY 4.0
```

Call-centre audio is genuinely spontaneous conversational speech — the right
*kind* of data. Whether it carries usable aggression/stress labels is not
established, and at 27 MB the English set is unlikely to be enough on its
own. Recorded as a lead, not a solution.

## 4. `kaggle_notebooks` is not dead weight — it is an unbacked-up risk

This was on the list as "~16 GB of stale snapshots awaiting a delete/keep
call". Checking before deleting:

```
kaggle_notebooks    11 GB   32 UNPUSHED commits, remote = NONE
zapsafe_mobile     4.9 GB   remote set, 0 unpushed, 5 dirty
the rest                    not git repos at all — plain directory copies
```

**`kaggle_notebooks` holds 32 commits that exist nowhere else** — Day 304
through Day 322, including the M1 scream retrain and the XD-Violence work
that produced the correction in section 1. Deleting it would have destroyed
them permanently.

It is not a cleanup target; it is a **backup gap**. It needs a remote, not a
`rm`. The 10 GB of bulk is untracked `*_push/kaggle_output/` artifacts, so
the history itself is small and cheap to preserve.

**Nothing was deleted.** The disk pressure that motivated this item is also
gone — C: went from 13 GB to 110 GB free on Day 362 — so there is no longer
a reason to be removing anything.

## Status

| item | before | after |
|---|---|---|
| M9 / XD-Violence | "needs manual download" | **wrong — MIT, on Kaggle, already used here.** Still needs a 2-vs-3 input decision |
| crash | "no alternative found" | **two candidates examined; one fabricated, one crash-free.** Blocked, better evidenced |
| h_aggressive/m4 | "needs natural speech" | unchanged — the mirrors that would help are licence-laundered |
| snapshots | "~16 GB, delete?" | **do not delete — 32 unpushed commits, no remote** |

Reproduce: `work/kaggle_search_blocked.py` lists what exists without
downloading; `work/crash_imu/` holds both crash candidates and the checks
that rejected them.
