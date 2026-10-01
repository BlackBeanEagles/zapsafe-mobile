# Day 368D — v6 recalibrated; the swap regresses the burst trigger, so it is NOT merged

`scream_classifier_v6` passed its pre-registered 10-seed rule (Day 368C). Its
two app thresholds were then re-derived to keep v5's operating points.
Reproduce: `tools/day353_ml/permissive/scream_v6_recalibrate.py`; numbers are
in `scream_v6_recalibration.json`.

## 1. Detector threshold: v6 is better

`ScreamDetectorV2.kDefaultThreshold`. Kept v5's recall on FSD50K eval (287
real screams):

```
v5  t = 0.20      recall 0.843   precision 0.281
v6  t = 0.00365   recall 0.843   precision 0.310   (+0.029)
```

The low value is correct. v6 is decisive, with a median score of 0.002
against v5's 0.186. Reusing 0.20 would have silently cut recall.

## 2. Camera-burst trigger: v6 is WORSE

`ViolenceBurstCoordinator.kTriggerThreshold`. Matched on how often a burst
fires on ordinary media audio. Measured on all 800 labelled XD-Violence test
videos: 62,737 3-second windows at a 1.5 s hop, 34,350 ambient and 28,387
violent, with both models scoring the identical windows:

```
                  threshold   ambient fires   violent fires   ratio
v5                 0.90          4.88%           14.38%        2.95x
v6 (matched)       0.6535        4.88%            9.24%        1.89x
```

At equal cost (camera bursts on ordinary TV), v6 investigates **36% fewer**
violent windows.

Side finding: Day 364D's figure for v5 at 0.90 was 3.2% of ambient windows,
from 60 videos. Over all 300 non-violent videos it is 4.88%, so v5 fires on
ordinary media audio about 1.5x more often than recorded.

## 3. Why this decides it

Scream has had no vote in the DCS escalation decision since Day 364D. The
burst trigger is the **only** consumer of the scream score that changes what
the app does. The detector threshold drives only detection-event logging,
whose pipeline the app does not start (Day 367).

So the swap improves a number nothing acts on and degrades the one path that
matters. The 10-seed rule measured scream-vs-other-vocalisation (FSD50K,
Nonspeech7k). It never measured violent-vs-ambient media audio, and that is
the gap. Nonspeech7k teaches screams apart from breaths, coughs and laughs,
which does not help with television.

**Decision: v5 stays on the working branch.** The complete swap (asset, both
thresholds, attributions, tests) is on branch `scream-v6-swap`, ready if
priorities change. One example: if scream detection is later used directly,
rather than only to point the camera.

## What would change the answer

A future rule for scream should include the burst metric (violent fires at
matched ambient rate on XD-Violence) alongside FSD50K. The cached windows
make that cheap: `D:\zapsafe\fusion\xd_windows_mel.npz`, 2.1 GB.
