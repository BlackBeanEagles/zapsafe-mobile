# Day 350 — the four blocked models, re-checked exhaustively and still blocked

Day 348 reported zero candidates for M7, M8, `k_confinement` and
`i_vehicle_crash`. That scan had two weaknesses worth taking seriously, so
the zeros were re-tested properly.

## 1. What was wrong with the first scan

**It only opened ARCHIVES.** Anything already extracted to a folder was
invisible — including `D:\zapsafe\spoofing`, which is the M8 mask-attack
data, plus `ml_datasets/{motion,face_detection}`, `E:\datasets\*` and the
`kaggle_datasets/` trees.

**It matched against SAMPLES** — 22 tree entries and 8 metadata heads per
archive. A dataset sitting at entry 500 of 40,000 could not surface.

`work/blocked_hunt.py` walks loose directory trees in full, re-opens every
archive reading **every** entry name, and reads the header row of every
small CSV it finds, searching for the column names each model needs rather
than loose topical keywords.

## 2. Result: still blocked, and now with evidence rather than absence

### `k_confinement` — needs ambient light (lux)

```
path hits    2, both false positives
  DS07_AudioSet/train_wav/7Als67qlD9Q.wav   <- a YouTube id containing "Als"
  google-research-master/alx/als.py          <- alternating least squares
COLUMN hits  0
```

**Zero CSV anywhere declares a `lux`, `illuminance`, `ambient_light`,
`light_level` or `als_value` column.** For a model whose entire blocker is
a missing photometric channel, a column-level zero is about as definitive
as this can get without acquiring data.

### `i_vehicle_crash` — needs real crash IMU

```
path hits    3, all false positives
  DS_WIDER/.../5--Car_Accident/5_Car_Accident_Accident_5_109.jpg
      ^ WIDER is a FACE DETECTION corpus; these are photographs of
        accidents, not inertial traces
  google-research-master/CardBench_...        <- database benchmarks
COLUMN hits  0
```

No CSV declares `crash`, `collision`, `impact`, `airbag` or `severity`.

### M8 — needs live face video to pair against attack video

The two most promising names turned out to be **source repositories, not
datasets**:

```
CelebA-Spoof-master.zip   24 entries   5 .py, 5 .png, 3 .jpg, 3 .pdf
spoof-main.zip            75 entries   41 .py, 6 .yaml, 6 .ipynb
```

The remaining hits are word coincidences — TESS contains
`OAF_live_angry.wav` and `OAF_pad_angry.wav` because "live" and "pad" are
**spoken words** in its fixed sentence list.

`D:\zapsafe\spoofing` is the real M8 data and is what Day 348 missed. It is
the same **84 attack videos** Day 344 already used, the `Real/` folder is
**5 jpgs rather than video**, and the dataset card declares
**`cc-by-nc-4.0`**. So it is unchanged in size, still has no live half, and
could not ship commercially even if it did.

### M7 — needs multilingual victim-perspective distress text

71 path hits, every one a numeric filename coincidence:

```
DS07_AudioSet/train_wav/0jFN112eGVQ.wav          <- YouTube id
liveness_zalo/private_test/videos/112.mp4        <- clip index
DS_AccentDB/.../bangla_s01_112.wav               <- clip number
violene/train/Fight/asdasda_112/asdasda_112.avi  <- clip number
```

The 9 `language`-column hits are all emotional-speech corpora
(`file,emotion,gender,speaker,language`), not distress text. There is no
text corpus of victim-perspective distress on any drive.

## 3. What the exercise did change

Nothing for these four — but it produced the **licence roll-up** in
`DAY350_TRAINING_DATA_LICENCES.md`, which found that `ESD_Dataset` is
`cc-by-nc-4.0` and sits under both vocal-stress models. That was only
findable because this scan opened loose directories, and it is the more
consequential result of the two.

## 4. Standing position

| model | blocker | evidence |
|---|---|---|
| `k_confinement` | ambient light | **0 lux columns** across all drives |
| `i_vehicle_crash` | real crash IMU | **0 crash columns**; only accident *photos* |
| M8 | live face video at scale | 84 attack clips, 0 live, NC-licensed |
| M7 | multilingual distress text | 0 corpora; 71 numeric coincidences |
| M9 / `dcs_fusion` | paired beta incidents | needs real users |

These are not scheduling questions. Acquiring data is the only path, and for
M8 that data also has to be commercially licensed.

Reproduce: `work/blocked_hunt.py` (writes `blocked_hunt.json`).
