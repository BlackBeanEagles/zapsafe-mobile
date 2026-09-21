# Day 346B — gunshot and glass, measured on a corpus nobody chose

Two detectors measured against FSD50K eval with deliberately hard negatives.
**For the first time this week, neither result is a correction.** Both work.

```
mg_gunshot_retrain    AUC 0.8071   95% CI [0.7544, 0.8605]   134 pos / 177 neg
m_glass_breaking_v3   AUC 0.7819   95% CI [0.7344, 0.8292]   265 pos / 127 neg
```

No collapse flags, no inversion, effect sizes well clear of the floor
(+0.1487 and +0.2909 against a 0.05 threshold).

## 1. A correction to what gunshot had on record

This was started on the belief that `mg_gunshot_retrain`'s number came from
a 24-clip **unlabelled** probe. That was wrong, and the claim was repeated
several times before being checked.

What it actually had:

* **AUC 0.9225** training-time held-out (`DAY262C`, superseding the 0.8913
  of the model it replaced — that 0.8913 is where "0.89" came from, and it
  was a real AUC of a real model, just an older one);
* a **labelled 598-clip UrbanSound8K** measurement behind its 0.70
  threshold — 149 gunshots vs 449 urban negatives, recall 0.960,
  precision 0.603.

The 24-clip unlabelled probe is the **gate's** fixture, which is why the
gate could only print `range`/`std`. That was a gap in the gate, not in the
model's evidence.

So gunshot was better evidenced than claimed. What it genuinely lacked was a
number from a corpus nobody involved in its training had chosen.

### The cross-corpus number, and why it is reassuring

```
training-time, own split       0.9225
UrbanSound8K, 598 clips        recall 0.960 / precision 0.603 @ t=0.70
FSD50K, 311 clips  (NEW)       AUC 0.8071
```

0.92 -> 0.81 across a corpus boundary is the **`motion_fall_v2` pattern**
(0.99 -> 0.95), not the `m3_violence_temporal` pattern (0.91 -> 0.48
measured the same day). **Gunshot generalises**, and it does so against
Explosion (158 clips) as its principal negative — the confusion that
matters, since a gunshot detector that cannot separate the two fires on
fireworks.

```
t=0.88  recall 0.709  precision 0.731
t=0.83  recall 0.791  precision 0.667
t=0.73  recall 0.881  precision 0.567
t=0.68  recall 0.910  precision 0.533
```

### One operational detail worth knowing

Gunshot's outputs occupy **[0.472, 0.984]**. A threshold of 0.5 therefore
fires on *everything* — the gate's `rec@0.5=1.000` is an artefact of that,
not a recall claim. The app ships **0.70**, which is correct and is where
the UrbanSound8K curve put it. No change needed; this is recorded so the
gate line is not misread later.

## 2. Glass: the AUC 1.0 was meaningless, and the model is still decent

`m_glass_breaking_v3` records **AUC 1.0 from 13 positives**. That is the
same shape as the scream number that collapsed on Day 345 (v3's 0.839 came
from 45 positives and measured 0.7675 on 287), and it did not survive
either:

```
recorded   AUC 1.0000   (13 positives)
measured   AUC 0.7819   (265 positives, CI [0.7344, 0.8292])
```

But 0.78 is a **working detector**, and its operating curve is the best in
this project:

```
t=0.60  recall 0.491  precision 0.922
t=0.51  recall 0.566  precision 0.882
t=0.41  recall 0.626  precision 0.856
t=0.22  recall 0.826  precision 0.830
```

**Recall 0.826 at precision 0.830** is better on both axes than anything the
scream or gunshot detector achieves. Glass-break is acoustically distinctive
— a short bright transient with a characteristic spectrum — and it shows.

The negatives here are hard on purpose: `Chink_and_clink` (168),
`Dishes_and_pots_and_pans` (48), `Cutlery_and_silverware` (39). A dropped
cutlery drawer should not read as a broken window, and largely it does not.

### It is still not shipped

The model lives only in `work/glass_retrain/`. Nothing in `lib/` references
it and there is no glass slot in the DCS pipeline. That is now a
**deliberate open decision rather than a missing measurement**: on this
evidence it is the strongest unshipped asset in the project, and wiring it
would need a slot, a threshold (0.22 on this curve) and pipeline work.

## 3. Method

Preprocessing is **lifted verbatim** from `real_mel_images()` in
`tools/verify_shipped_models.py`, including `np.resize`, which tiles and
truncates rather than interpolating. That is an odd route to a square image,
but it is what the gate feeds these models and therefore what they were
accepted against; "improving" it would measure a model that does not ship.

The two contracts differ and were not assumed — gunshot is 128x128x3 at
3.0 s, glass 96x96x3 at 2.0 s — and quantisation is applied and reversed
explicitly rather than left to chance.

Reproduce: `work/fsd50k_eval/evaluate_gunshot_glass.py`.

## 4. The gate now reports these properly

`real_mel_images_fsd50k()` was added and is preferred over the unlabelled
UrbanSound8K fixture, routing **by filename** because gunshot and glass
share the `[1,S,S,3]` contract but need opposite label sets — the same trap
that had two models sharing `[1,38]` with different feature definitions.

```
before   mg_gunshot_retrain   ok   n=24  range[0.5001, 0.9788] std=1.50e-01
after    mg_gunshot_retrain   ok   n=311 AUC=0.807 sep=0.1487
```

It falls back to the old fixture when the FSD50K extraction is absent, so
the gate still runs on a clean checkout.

## 5. Standing position after Day 346

| model | cross-corpus status |
|---|---|
| `motion_fall_v2` | **0.9472** — generalises |
| `scream_classifier_v5` | **0.8284** — shipped today, +0.0609 over v3 |
| `mg_gunshot_retrain` | **0.8071** — generalises |
| `m_glass_breaking_v3` | **0.7819** — works, not shipped |
| `m3_violence_temporal` | **0.4821** — at chance off its own corpus |
| `i_vehicle_crash`, `k_confinement` | measured non-functional |

**Nothing here has run on physical hardware.**
