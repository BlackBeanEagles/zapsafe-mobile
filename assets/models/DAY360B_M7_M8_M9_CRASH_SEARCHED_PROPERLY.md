# Day 360B — M7, M8, M9 and crash, searched properly this time

After h_aggressive showed "structurally blocked" could be wrong, these four
got the same treatment: not "does a drop-in corpus exist" but "what does the
model actually need, and what is the closest thing that exists". One of them
is genuinely reframed. Three are confirmed closed, now with evidence rather
than assertion.

## 1. M9 — the framing was wrong, and it is trainable in principle

Every previous note said M9 "needs real beta incidents". That is not quite
right. `dcs_fusion` combines **detector outputs** into one decision, so what
it needs is *co-occurring modalities carrying an incident label* — not
necessarily incidents from this app's users.

**XD-Violence** provides exactly that: 4,754 untrimmed videos, 217 hours,
**audio and video with violence labels**, 3,954 train (video-level) and 800
test (frame-level). Running the existing scream / glass / gunshot /
m3_violence detectors over that audio yields per-modality scores against a
known label — which is fusion training data.

So M9 moves from "impossible without users" to **"trainable in principle,
blocked on acquisition and likely blocked on domain"**:

* **Acquisition.** The raw downloads are SharePoint share links and Baidu
  Netdisk. `curl` against the SharePoint link returns HTTP 200 with
  `content-length: 131713` — a 128 KB viewer page, not the archive. Baidu
  needs an account. The only directly fetchable release is **VGGish audio
  features**, which are useless here because the detectors need raw audio
  for their own mel front-ends.
* **Domain.** XD-Violence is movies, web video, sport streams and CCTV. Six
  speech corpora were rejected this week for exactly this reason, with
  corpus-ID AUC of 0.98–1.00 every time. A fusion trained on movie audio
  would very likely partition rather than generalise.

**This is the one item where a download by hand would unlock real work.**
If the training videos are fetched manually, the premise is testable.

## 2. M7 — the closest corpus that exists, examined and rejected

Found and downloaded `community-datasets/disaster_response_messages`:
21,046 messages, ungated, multilingual (en, es, fr, Haitian Creole, Urdu),
36 aid categories. On paper that is a strong match for "multilingual
victim-perspective distress".

It is not. The messages are **humanitarian aid requests after natural
disasters**:

```
"My house is destroyed in Carrefour"
"Please save me! ... one who already has a fever and non-stop diarrhea"
"we have problems. I have a lot of people in my house. Help me!"
```

A keyword probe for personal-safety phrasing (following me / threatening /
kidnap / assault) matched 504 rows — 2.4% — and inspecting them shows they
are earthquake-aftermath aid requests that happen to contain "help me".

The `security` column (402 rows) looked like the answer and is not. It is
disaster-zone **public-order reporting**, community perspective:

```
"There are a lot of criminals in Jacmel city. We are asking the police to come"
"please send the police so the street vendors can lower the price"
"We need potable water, medicines, food, lamp oil, and security"
```

M7 needs first-person, present-tense danger from a *person* — "someone is
following me". This is third-person reporting of conditions after a
disaster. Training M7 on it would produce a detector for "I need aid after
an earthquake" and label it as personal-safety distress, which
`DAY347_DISTRESS_TEXT_DECISION.md` names as "the most consequential mislabel
in the project".

Licence is `unknown` in any case. **M7 stays unmet.**

## 3. M8 — the literature answers this directly

The survey work states it plainly: **"none of the public datasets are
licensed for commercial use"**; academic face anti-spoofing sets are
restricted to academic use despite being freely available.

The closest candidate, **WildFAS**, collects its *live* set under Creative
Commons — but it is not on HuggingFace or Zenodo, and nothing was found
about the licence on its **attack** half, which is the part that matters.
The commercially-licensed option is vendor-sold (Axon Labs, Unidata).

That is a property of the market — face data is commercially valuable, so
free releases are teasers — not a gap in searching. **M8 is closed, and now
for a documented reason.**

## 4. i_vehicle_crash — unchanged

VZCrash (31,090 verified crashes) is still the only public crash-IMU corpus:
HF `gated: auto`, HTTP 401, and CC BY-NC. `nexar_collision_prediction` is
also gated. The one CC-BY alternative found, the Zenodo Driving Events
Dataset, has 169 events from **one driver in one car with no crashes**.

## 5. What this changes

| item | before | after |
|---|---|---|
| M9 | "needs real beta incidents" | **trainable in principle** — needs XD-Violence fetched by hand; domain risk is high |
| M7 | "nothing exists" | closest corpus found, downloaded, **examined and rejected** on construct |
| M8 | "free sets are NC" | confirmed: **no public FAS dataset permits commercial use**, per the literature |
| crash | gated + NC | unchanged |

Nothing shipped from this. The value is that three of the four now have
evidence behind the "no" and the fourth has a concrete, hand-actionable
path.

Reproduce: the M7 corpus is at `work/m7_disaster/` (2.8 MB, kept so the
judgement can be re-checked rather than taken on trust).
