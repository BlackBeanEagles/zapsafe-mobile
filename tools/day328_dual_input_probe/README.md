# Day 328 — dual-input model probes

Three standalone scripts that measure the shipped dual-input `.tflite`
assets under two input regimes: **the domain their training script built**,
and **what the app's sensor/audio pipelines actually feed on a phone**.

They exist because a conventional gate fixture cannot catch this class of
bug. A fixture drawn from the training data reports a healthy AUC for all
three models — 1.0000 for `s_crowd_panic`, 0.9959 for `k_confinement`,
1.0000 for `i_vehicle_crash` — while all three are non-functional on a real
phone. The gap between the two regimes *is* the finding.

Run with the project ML venv (TF 2.17 / numpy 1.26.4 / librosa 0.10.2):

```
C:\Users\hridy\Desktop\zapsafe\.mlvenv\Scripts\python.exe probe_s_crowd_panic.py
C:\Users\hridy\Desktop\zapsafe\.mlvenv\Scripts\python.exe probe_k_confinement.py
C:\Users\hridy\Desktop\zapsafe\.mlvenv\Scripts\python.exe probe_i_vehicle_crash.py
```

Each needs local datasets (`ml_datasets/motion/DS14_PAMAP2`,
`DS11_UCI-HAR`, `audio_events/DS07_AudioSet`, `DS21_ESC-50`) and prints its
own regime table. Findings and numbers:
`assets/models/DAY328_DUAL_INPUT_DEAD_ON_PHONE.md`.
