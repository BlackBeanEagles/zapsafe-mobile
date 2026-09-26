# Day 359C — scream stays NC, and the remaining blockers are structural

Glass and gunshot both went permissive today with large gains. Scream does
not, and the four unbuilt models are blocked for reasons no amount of
searching changes. This records both so neither is retried blindly.

## 1. Scream: the permissive subset loses

```
shipped scream_classifier_v5 (NC)   0.9057
permissive seed 42                  0.8186
permissive seed 7                   0.8596
```

Measured on the gate's FSD50K eval fixture (2,224 clips, 123 positives),
both models through their real inference path. The run died before the third
seed, but two seeds sitting 0.05–0.09 below the baseline settle it.

**This is the outcome that was predicted, and the prediction was right this
time** — unlike gunshot, where I expected a close A/B and got a landslide.
The difference is data volume: glass had 92 training positives and gunshot's
baseline was weaker than the gate suggested, while scream trains on **five
corpora** and the permissive FSD50K subset offers only **218 positives**.

Worth recording: scream reads **0.9057** on the full fixture against the
gate's **0.828**, because the gate subsamples to n=1764. The flagship
detector is stronger than the gate's number implies — the same subsampling
that made me mispredict gunshot, in the opposite direction.

`scream_classifier_v5` keeps ESC-50 (CC BY-NC 3.0) and stays Non-Commercial.

## 2. The NC position after today

```
this morning   h_aggressive_v5, m5_vocal_stress_v3, m_glass_breaking_v3,
               mg_gunshot_retrain, scream_classifier_v5          (5)
now            h_aggressive_v5, m5_vocal_stress_v3,
               scream_classifier_v5                              (3)
```

The three that remain have **no permissive replacement**:

* `h_aggressive_v5` — TESS (CC BY-NC 4.0), RAVDESS (CC BY-NC-SA 4.0)
* `m5_vocal_stress_v3` — EmotionTalk (CC BY-NC-SA 4.0)
* `scream_classifier_v5` — ESC-50 (CC BY-NC 3.0), measured above

Emotional-speech corpora are essentially all NC. That is a property of the
field, not a gap in the search.

**New obligation:** glass and gunshot now train on CC BY data, which requires
**attribution**. The app owes FSD50K contributors a credit somewhere a user
can reach. That is a real product task covering two shipped models.

## 3. Why the four unbuilt models are structurally blocked

A deeper sweep was run across HuggingFace (licence-filtered and with
alternate phrasings), Zenodo, figshare, Microsoft Research and the SHL
project page. What it found, and why none of it helps:

| candidate | for | why it fails |
|---|---|---|
| Driving Events Dataset (CC-BY, 183 MB) | `i_vehicle_crash` | 169 events, **one driver, one car, no crashes** — aggressive turns and braking only, plus the single-participant confound |
| SHL (light + IMU, 750 h) | `k_confinement` | has the lux channel but **3 participants** — a worse confound than ExtraSensory's 16, which already failed |
| SecondLook digital dating abuse (CC-BY) | text | `access: restricted`, no downloadable files |
| AxonData / UniDataPro / SARSpoof | M8 | NC, NC-ND, or restricted; the two CC-BY sets have **5 real faces** |
| permissive abusive-text sweep | trac | **zero** ungated CC0/CC-BY/Apache/MIT results |

The underlying reasons are structural, and worth stating plainly because
they will not change with more searching:

* **Crash IMU** is collected by insurance and fleet telematics, where it is
  commercially valuable. VZCrash (31,090 verified crashes) is the only public
  corpus and is gated *and* CC BY-NC. A model trained on simulated crashes
  would be the ExtraSensory failure again — right shape, wrong answer.
* **Confinement** is not collected by anyone: it is rare, traumatic, and
  unethical to stage at scale. Every dataset with the right sensors carries
  only proxies (phone-in-pocket, elevator), and Day 357 measured what that
  proxy costs — **participant identity alone scored 0.88**.
* **Face anti-spoofing** is commercially valuable, so free releases are
  teasers. Market structure, not a search failure.
* **Victim-perspective distress text** would require recording people in
  danger.

## 4. Disk

Raw data for every **rejected** corpus was deleted after verifying its
extracted features survive, so any future test can re-run without
re-downloading:

```
deleted   eq4you tars + clips, NaturalVoices archive + clips,
          LEGOv2.zip, ExtraSensory raw_acc + proc_gyro
kept      every .npz feature cache (9-44 MB each) and the permissive
          FSD50K mel caches that glass and gunshot were built from
D: free   83 GB -> 163 GB
```

## 5. Status

| | |
|---|---|
| scream | **stays NC** — permissive subset loses 0.82-0.86 vs 0.906 |
| NC models | **3**, down from 5 |
| attribution owed | FSD50K contributors, covering glass and gunshot |
| `i_vehicle_crash`, `k_confinement`, M7, M8 | structurally blocked, reasons above |
| M9 / `dcs_fusion` | needs real users, not a dataset |
| D: free | 163 GB |

Reproduce: `work/permissive/build_train_scream.py`.
