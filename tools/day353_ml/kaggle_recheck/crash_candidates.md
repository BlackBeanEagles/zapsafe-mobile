# Crash-IMU candidates examined on Day 363

Both found by searching Kaggle, which earlier "no alternative exists"
conclusions had never covered.

## drabdulbari/smartphone-imu-road-accident-detection-dataset — CC0 — REJECTED, fabricated

`road_accident_imu_dataset_8000.csv`, 8,000 rows, 1,000 labelled crashes.

| check | value | what it should be |
|---|---|---|
| peak accel, all rows | **1.56 g** | a real collision is 20-100+ g |
| timestamp step | exactly 1.000 s x 7,999 | real logging jitters |
| gyro, crash vs normal | 0.019 vs 0.020 | a crash is violent rotation |
| trivial logistic AUC | **1.0000** in-sample | not linearly separable |
| crash speed | 10 km/h vs 50 normal | backwards |

Synthetic. A model trained on it validates at 1.0 and never fires on a real
crash.

## dinupadevinda/byd-atto-bmi160-imu-driving-events — CC BY 4.0 — REAL, but no crashes

62,187 samples, BMI160, 4.19 g peaks, real session files, jittered sampling.
Contents: `lane_change` 43,411, `harsh_braking` 18,776. **No crash events.**

Useful as real-world **hard negatives** for a crash detector — ordinary
violent driving it must not fire on — but cannot supply positives.

## Verdict

`i_vehicle_crash` stays blocked. VZCrash (gated + CC BY-NC) remains the only
real public crash-IMU corpus found.
