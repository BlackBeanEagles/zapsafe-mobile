"""
Day 267 -- real-data triage for the 6 remaining flagged-weak staged models:
m4_vocal_stress_en_adversarial, m5_vocal_stress_apac_adversarial(+f32),
n_breathing_distress(+f32), j_whisper_distress (bn_ur_ar_crosslang +
adversarial_f32), i_vehicle_crash(+f32), mg_gunshot_f32 (stale leftover,
distinct from the shipped AUC-0.9225 mg_gunshot.tflite).

This file merges (and can reproduce) the two standalone scripts used for
these numbers: test_i_vehicle_crash.py and test_m4_m5.py, run manually
against local dataset caches during the Day 267 pass. Kept here for future
reproducibility, same pattern as check_fp32_vs_int8.py /
check_harness_reconciliation.py from Day 260.

Real result summary (numbers as measured, see DAY267_REMAINING_MODELS_TRIAGE.md
for the full writeup and per-model retrain/retire decision):

i_vehicle_crash / i_vehicle_crash_f32 -- CONFIRMED dual-input model
(serving_default_audio_mel [1,64,64,3] + serving_default_imu_window
[1,128,6], via interpreter.get_input_details()) -- same undocumented-
second-input bug class as k_confinement/s_crowd_panic. With both real
inputs supplied (real ESC-50 crash-proxy audio + real UCI-HAR IMU run
through the model's OWN inject_crash_spike() from day91_i_vehicle_crash.py):
  fp32 AUC 0.9622 (both real inputs) vs 0.8200 (imu=zeros, Day-259-style)
  int8 AUC 0.8733 (both real inputs) vs 0.7800 (imu=zeros)
Not confirmed-dead -- a harness bug, not a model bug. See
test_i_vehicle_crash.py (this directory) for the exact reproduction.

m4_vocal_stress_en_adversarial / m5_vocal_stress_apac_adversarial(+f32) --
fp32 vs int8 checked on real CREMA-D audio (day104's own collect_cremad
label recipe: SAD/ANG/FEA/DIS positive, NEU/HAP negative):
  m4: int8 AUC 0.6262 (pos median 0.5078, neg median 0.5039) vs
      fp32 AUC 0.6288 (pos median 0.5069, neg median 0.5037)
  m5: int8 AUC 0.6175 (pos median 0.5059, neg median 0.5000) vs
      fp32 AUC 0.6144 (pos median 0.5054, neg median 0.5007)
fp32 and int8 are within ~0.003 AUC and ~0.003-0.006 median-gap of each
other -- confirms Day 259's "quantisation noise, not signal" framing was
imprecise: the fp32 checkpoint ITSELF is already barely separable, so this
is not fixable by re-export (same conclusion pattern as mg_gunshot/
m_glass_breaking's fp32-first checks in DAY260_QUANTIZATION_ROOTCAUSE.md).
See test_m4_m5.py for reproduction.
"""
