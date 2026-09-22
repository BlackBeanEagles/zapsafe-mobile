# Day 334 — `m3_violence_temporal` wired, and verified end-to-end

`m3_violence_temporal` has been trained since Day 326 at held-out AUC 0.9124
and unwired ever since, because its input is `[1, 16, 576]` — a sequence of
**16 MobileNetV3Small embeddings**, not pixels — and `assets/models/` shipped
no encoder. The head had nothing to consume.

## What ships

| asset | size | shape |
|---|---|---|
| `mobilenetv3small_encoder_float16.tflite` | 1.85 MB | `[1,224,224,3] -> [1,576]` |
| `m3_violence_temporal_v1.tflite` | 685 KB | `[1,16,576] -> [1,1]` |

`ViolenceBurstDetector` loads both **as a pair** and verifies all four tensor
shapes, returning null and closing whichever interpreter did open if anything
mismatches — either stage alone is useless, and a detector that silently ran
with one missing would be worse than one reporting itself unavailable.

`CameraFrameService.captureBurst()` supplies the frames: 16 sequential
`takePicture()` calls at a 150 ms gap. The gap is not arbitrary. The head was
trained on 16 frames **evenly spaced across a whole clip**, and the source
clips run 2–5 s, so 150 ms gives ~2.4 s of coverage. Bursting as fast as the
camera allows would sample a much shorter window than training and compress
the very dynamics being classified. A short burst returns null rather than
padding, because repeating or zero-filling a frame fabricates motion (or its
absence) that the head then reads as signal.

`violenceBurstDetectorProvider` **only loads** the detector — there is no
pipeline provider beside it, unlike scream/motion. 16 `takePicture()` calls
plus 16 encoder passes is far too expensive for a timer. This is an on-demand
check for when something else has already raised suspicion.

## Verified end-to-end, because `flutter test` cannot

`flutter test` has no native TFLite interpreter, so the Dart tests cover
shapes and scaling conventions only. The chain itself is exercised by
`tools/day334_m3_burst/probe_end_to_end.py` against real held-out val clips:

```
SHIPPED chain, raw [0,255], training-matched frame sampling
  n=70+70   AUC=0.9176   sep=+0.5293   span=0.9875
  fires>=0.5:  49/70 Fight,  9/70 NonFight
```

Against the head alone on the training-time cached features, all 670 val
clips: **AUC 0.9126** (the Day 326 report claims 0.9124). The wiring
reproduces the trained number.

**float16 export costs nothing measurable.** The shipped float16 encoder
scores 0.7025 where the full Keras float32 encoder scores 0.7066 on the same
44-clip subset — a 0.004 gap, with embeddings matching to mean |diff| 0.0060
on a mean magnitude of 0.47.

## The input-scaling hazard, now measured rather than argued

This app now contains **two MobileNetV3-based models with opposite input
conventions, fed from the same `CameraFrameService` byte source**:

| model | expects | why |
|---|---|---|
| `scene_analyzer_v1` (`SceneDetectorV2.normalise`) | `pixel / 255.0` | trained end-to-end on `/255`-scaled input despite `include_preprocessing=True` |
| this encoder (`ViolenceBurstDetector.packFrameRaw`) | **raw `0-255`** | `Rescaling(1/127.5, -1.0)` is a layer inside the exported graph, and `mobilenet_v3.preprocess_input` is a verified pass-through |

Both take a flat `224*224*3` list, so nothing in the type system prevents
handing the wrong one to the wrong model. What that costs, measured:

```
raw [0,255]   AUC=0.9176  span=0.9875  fires 49/70 fight,  9/70 nonfight
/255 scaled   AUC=0.6467  span=0.0013  fires  0/70 fight,  0/70 nonfight
```

Scaled input pins the output at ~0.022 with a span of **0.0013** — the exact
`COLLAPSED` signature the Day 330 gate check was written to catch, produced
here by nothing but a wrong pixel range. Nothing throws. `day334_violence_
burst_test.dart` pins the distinction, including that the two packers differ
by exactly 255×.

## A correction worth recording

The first end-to-end probe returned **AUC 0.7025** and looked like a degraded
chain. It was the probe, not the model: it **skipped clips shorter than 16
frames** instead of padding by repeating the last frame (what
`train_m3_temporal.sample_frames` does), and took the first 22 paths
alphabetically rather than sampling. With training-matched sampling on a
random 140-clip draw the same code gives 0.9176.

Two diagnostics were run before concluding anything — the head on cached
training features (0.9126, so the head is fine) and float16 against Keras
(0.004 apart, so the export is fine) — which is what localised the fault to
the probe rather than the assets.

## Not done

* **Nothing triggers a burst yet.** The detector loads; no caller invokes it.
  What should raise suspicion — a scream, a fall, a DCS score — and whether a
  burst is acceptable at that moment are product decisions.
* **The 0.5 threshold is uncalibrated.** At the midpoint this is 70% recall
  on Fight with 13% firing on NonFight, which is a lot of false positives for
  anything that escalates. The model's own curve offers `t=0.8` at recall
  0.538 / precision 0.930. No device footage has been used to tune it.
* **Not in the DCS fusion.** The scene slot still contributes 0, so Day 327's
  0.80 ceiling and the unreachable 0.85 auto-SOS threshold are unchanged.
  Wiring M3 there is the change that would raise it.
* **Nothing has run on a physical device.**

821 tests pass, `flutter analyze` unchanged at 57 issues, 0 errors.
