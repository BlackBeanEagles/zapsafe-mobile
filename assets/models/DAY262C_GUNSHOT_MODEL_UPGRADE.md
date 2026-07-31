# Day 262C — `mg_gunshot_retrain.tflite` upgraded to the real AudioSet re-run (AUC 0.8913 -> 0.9225)

Follow-up to `DAY262_GUNSHOT_MOTIONB_WIRING.md` (wired the AUC 0.8913
Kaggle v1 retrain) and `DAY262B_AUDIOSET_RERUN.md` (documented a further
retrain with real AudioSet data, AUC 0.9225, but explicitly left the
`.tflite` files un-copied — "No `.tflite` files were copied into
`zapsafe_mobile/assets/models/`"). This session did that copy for real.

## 1. Real v2 kernel output re-pulled from Kaggle

`kaggle kernels output` has no `--version` flag (confirmed via
`kaggle kernels output --help`) — it always fetches the kernel's current
(latest) output, which is version 2 here since no version 3 was ever
pushed (`kaggle kernels status hridyajain/zapsafe-day261-mg-gunshot-retrain`
-> `"complete"`, matching `DAY262B`'s "Kernel version 2 successfully
pushed"). Pulled fresh into a scratch dir:

```
$ kaggle kernels output hridyajain/zapsafe-day261-mg-gunshot-retrain -p . -o
Output file downloaded to .\mg_gunshot_retrain.tflite
Output file downloaded to .\mg_gunshot_retrain_ckpt/best.weights.h5
Output file downloaded to .\mg_gunshot_retrain_f32.tflite
Output file downloaded to .\mg_gunshot_retrain_report.json
Output file downloaded to .\mg_gunshot_retrain_training_log.csv
```

**Verified it's really the v2/AudioSet run, not stale v1, on two
independent axes:**

- `mg_gunshot_retrain_report.json` (freshly downloaded, not copied from
  the doc):
  ```json
  {
    "model": "mg_gunshot_retrain",
    "auc": 0.9225,
    "recall_gunshot": 0.9757,
    "f1_gunshot": 0.7812,
    "precision": 0.6514,
    "support_pos": 247,
    "support_neg": 248,
    "real_positives_loaded": 1647,
    "real_negatives_loaded": 5661
  }
  ```
  Matches `DAY262B`'s numbers exactly (auc 0.9225, support_pos 247,
  real_positives_loaded 1647) — not the stale local v1 output in
  `kaggle_notebooks/day261_mg_gunshot_retrain_push/kaggle_output/`, whose
  `report.json` shows `support_pos=236, real_positives_loaded=1573`.
- `mg_gunshot_retrain.tflite` real file size: `wc -c` -> 2,874,160 bytes,
  matching `DAY262B`'s claimed size exactly.
- Belt-and-suspenders: `md5sum` of the previously-wired
  `assets/models/mg_gunshot_retrain.tflite` (v1) vs. the freshly-pulled
  file showed **different MD5s despite identical byte size**
  (`498a4399cb95a17ad89eed39668a1760` vs.
  `9df95d856e517a92ea7691c4b724ec7e`) — confirms this is genuinely a
  different trained model, not a same-file no-op.

## 2. Tensor shape/quantization check (real, via `get_input_details()`/`get_output_details()`)

```
INPUT  shape=[1,128,128,3] dtype=int8 quantization=(0.003921568859368563, -128)
OUTPUT shape=[1,1]         dtype=int8 quantization=(0.00390625, -128)
```

Identical to the v1 model documented in `DAY262_GUNSHOT_MOTIONB_WIRING.md`
§1 (same architecture, same export pipeline — only the training data/
weights changed). `GunshotDetectorV2`'s preprocessing and int8 quantize/
dequantize logic reads scale/zero_point from the loaded interpreter at
runtime (not hardcoded), so no Dart code changes were needed.

## 3. File swap

`assets/models/mg_gunshot_retrain.tflite` replaced with the real v2 file
(2,874,160 bytes, md5 `9df95d856e517a92ea7691c4b724ec7e`).

## 4. Real test results after the swap

Backend (`docker compose up -d` in `zapsafe_backend`, waited for the
`db` container's healthcheck to report `healthy`, matching the prior
wiring session's real Docker startup pattern):

```
$ docker compose exec web python manage.py test ml.test_day262_gunshot_motion_b_wiring -v 2 --keepdb
...
Ran 6 tests in 1.756s

OK
```

All 6 pass unmodified — expected, since this is a pure binary asset swap
and the backend test only exercises the `DetectionEvent` API/DB path, not
the model file itself. No backend code or schema changes were made or
needed (`EventType.GUNSHOT` already existed from Day 262).

Mobile:

```
$ flutter test test/gunshot_detector_test.dart
...
00:00 +9: All tests passed!
```

**The quantization golden fixture (`test/fixtures/gunshot_quant_golden.json`)
did NOT need regeneration.** It passed as-is because the new model's
input/output scale and zero_point are bit-identical to the old model's
(confirmed in §2 above) — the retrain changed weights/data, not the
quantization scheme, so the fixture (which encodes real scale/zero_point
values) remains valid against the new file.

## 5. Summary

| | before (v1, `DAY262`) | after (v2, this session) |
|---|---|---|
| AUC | 0.8913 | **0.9225** |
| Recall | 0.9958 | 0.9757 |
| Precision | 0.5065 | **0.6514** |
| F1 | 0.6714 | **0.7812** |
| File size | 2,874,160 bytes | 2,874,160 bytes (same size, different weights — md5 differs) |
| Quantization | int8, scale 0.00392.../-128 in, 0.00390625/-128 out | unchanged |

Real, more balanced classifier (higher precision/F1, slightly lower
recall) trained with real AudioSet gunshot positives and hard negatives,
per `DAY262B_AUDIOSET_RERUN.md`'s analysis. No app code changes required
for this upgrade — model-file swap only.
