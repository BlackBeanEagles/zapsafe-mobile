# Day 311: m7_nlp_context_enhanced — deep check of 6 hate-speech-catalog candidates + a fresh distress-search angle (verification/discovery only, no training)

Context: `m7_nlp_context_enhanced` needs a labeled **multilingual** text corpus for
detecting **personal distress** ("I am in danger", "someone is following me",
"help me") — a victim's-perspective signal. This is a different label
semantics from hate-speech-toward-others (racism, misogyny, group-targeted
toxicity). Day 309 already rejected one English-only candidate ("Mental
Health Corpus" via the StressScan notebook) for the multilingual requirement.
This session does **not** re-run a blind hate-speech-catalog sweep — the
project owner supplied ~80 real academic hate-speech datasets (the standard
hatespeechdata.com catalog), most of which are the wrong task by title alone.
This session instead reads the **real annotation guidelines and real example
sentences** (not just category names) for the 6 specific candidates flagged
as worth a closer look because they have explicit "threat"/"violence"
sub-labels, plus does one broader search specifically for "crisis text" /
"distress detection" / "help me" classification datasets — a different
search angle than "hate speech", not directly tried in prior NLP rounds
(Day 296, 299, 300, 307, 309).

## 1. Hindi/Hindi-English Aggression-annotated Corpus (Kumar et al., LREC 2018)

GitHub: `kraiyani/Facebook-Post-Aggression-Identification`. Paper read in
full: `https://arxiv.org/pdf/1803.09402` ("Aggression-annotated Corpus of
Hindi-English Code-mixed Data", Kumar, Reganti, Bhatia, Maheshwari, LREC
2018). The GitHub README itself only advertises the top-level 3-way
OAG/CAG/NAG scheme and does **not** mention "Physical Threat" at all — the
"Physical Threat" sub-category lives one level deeper, in the paper's real
**Discursive Effect** tagset (10 kinds: PTH, SAG, GAG, RAG, CoAG, CaAG, PAG,
GeAG, NtAG, CuAG), documented in Section 4.3–4.9 of the paper.

**Real definition (Section 4.3, verbatim):** "Any aggressive text that
threatens to hurt the victim (an individual or a community) physically or
even kill her/him can be classified as physical threat. It also includes
suicide intentions, mass killings, etc."

**Real quoted example (Section 4.3, the paper's own PTH example):**

> Muh kala hai dogle ka dil bhi kala gaddar hai mujhe tum dikh jaye sala juta
> marunga dogala deshdrohi
>
> ("This hypocrite has lost his face, his heart is also bad, as soon as I
> shall see you moron, I will hit you with a shoe, you hypocritical
> anti-national")

**Verdict: (b) WRONG TASK — perpetrator-threat, not victim-distress.** The
example is the *speaker* threatening to physically hit the *addressee* — a
first-person aggressor voice ("I will hit you with a shoe"), not a
first/third-person victim expressing "someone is following me" / "I am in
danger". The paper's own annotation convention section confirms this
reading structurally too: PTH is one of 10 "Discursive Effect" tags applied
alongside a "Discursive Role" of Attack/Defend/Abet — i.e., the tag
describes what the *aggressor's utterance does to a target*, not what a
victim reports about their own situation. Confirmed wrong label semantics,
not a usable proxy.

## 2. Roman Urdu Hate Speech (`haroonshakeel/roman_urdu_hate_speech`)

Real `label_definitions.txt` from the repo confirms the actual scheme has
**no threat or distress-adjacent category at all**:
- Coarse-grained: `0=Abusive/Offensive`, `1=Normal`
- Fine-grained: `0=Abusive/Offensive`, `1=Normal`, `2=Religious Hate`,
  `3=Sexism`, `4=Profane/Untargeted`

**Verdict: (b) WRONG TASK — no personal-distress-adjacent subcategory
exists.** Unlike the Hindi corpus above, there isn't even a "threat"
category to evaluate here — the closest label is "Religious Hate" /
"Sexism", both group-targeted-toxicity categories with nothing resembling
first-person danger/distress expression. Faster rejection than candidate 1,
but the same underlying reason (wrong label semantics for this project).

## 3. CAD — Contextual Abuse Dataset (Vidgen et al., NAACL 2021)

Real paper read in full: `https://aclanthology.org/2021.naacl-main.182.pdf`
("Introducing CAD: the Contextual Abuse Dataset"). The real taxonomy
(Figure 1) has "Threatening" as a secondary category under both
Identity-directed abuse and Affiliation-directed abuse (not Person-directed,
which only has "Abuse to them" / "Abuse about them" — no threatening
sub-label there).

**Real definition (Section 3.1, verbatim):** "Threatening language: Language
which either expresses an intent/desire to inflict harm on a group, or
expresses support for, encourages or incites such harm. Harm includes
physical violence, emotional abuse, social exclusion and harassment."

**Real quoted example (Table 1, Identity-directed/Threatening row):**

> "Gotta kick those immigrants out... now!"

**Verdict: (b) WRONG TASK — speaker's own incitement, not distress.** The
definition explicitly centers on the *speaker's* intent/desire/incitement
to inflict harm on a group; the quoted example is a call to action against
a group, not a first-person expression of being in danger. Same
perpetrator-voice pattern as candidate 1, formalized differently (identity-
group target vs. individual target) but structurally identical mismatch.

## 4. ETHOS multi-label (Mollas et al., 2020)

Real paper read: `https://arxiv.org/pdf/2006.08328v2` ("ETHOS: an Online
Hate Speech Detection Dataset"). The "violence" label (1 of 8 multi-label
dimensions, 433-comment multi-label variant) is defined via the exact
crowdsourcing question put to annotators: **"Does this comment incites
violence?"** — a yes/no vote normalized to [0,1], not a separate free-text
category.

**Real quoted example (Figure 1, the paper's own worked example, comment
that scored Hate Speech 87%, Incites Violence 92%, Directed 100%,
Disability 100%):**

> "Wish you cut your veins. Don't shout out you have mental problems. Act.
> Cut them;"

**Verdict: (b) WRONG TASK — perpetrator's violent/incitement speech directed
AT a target, not the target's own distress signal.** The comment is
addressed *to* a disabled person, instructing/goading them toward
self-harm — hateful, violent speech from an attacker's voice, the opposite
of a victim saying "I am in danger" or "help me". "Incites violence" as a
concept is fundamentally about what the labeled text does to provoke harm,
not about what a person experiencing danger would say about themselves.

## 5. OAA — Online Abusive Attacks (Alharthi et al., IEEE Access 2023)

Real paper read: `http://www.zubiaga.org/publications/files/alharthi2023access.pdf`
("Target-Oriented Investigation of Online Abusive Attacks: A Dataset and
Analysis"). Confirmed real structure: the dataset collects each **target's**
own source tweets plus the **direct replies they received**, then labels
only the **replies** (the abusive content aimed at the target) using Google
Jigsaw's Perspective API's six attributes — Toxicity, Severe_Toxicity,
Identity_Attack, Insult, Profanity, and **Threat** — thresholded at 0.9.
Real worked examples from Table 6 (all reply-side, perpetrator-authored):

> "@username Latino male culture. Make me puke." — labeled PROFANITY 0.912
>
> "@n username What a fucking surprise. They probably aren't fans of well
> meaning white elites telling them they're not good enough to live up to
> the standards of white people and therefore society must be torn apart so
> they are no longer." — labeled PROFANITY 0.912

**Verdict: (b) WRONG TASK for the labeled text, though the target/perpetrator
structure is genuinely interesting and worth noting.** The "threat" attribute
scores are applied to the *perpetrator's* reply tweets (content directed at
the target), not to anything the target themselves wrote — the target's own
source tweets are collected (144 account metadata fields, full timeline) but
are **not** annotated for fear/distress/danger at all; they're just whatever
topic-related tweet triggered the abusive replies. So the task's own
speculative hope — "target's-perspective reactions to being threatened could
be a real distress-adjacent signal" — does not hold up on real inspection:
there is no distress-labeled target-authored text in this dataset, only
unlabeled target tweets plus labeled-abusive perpetrator replies. Same
wrong-voice problem as the others, just with richer (but unused-for-this-
purpose) contextual metadata.

## 6. Gab Hate Corpus — "Call for Violence" (Kennedy et al., 2022)

Real paper read: `https://par.nsf.gov/servlets/purl/10322251` ("Introducing
the Gab Hate Corpus: defining and applying hate-based rhetoric to social
media posts at scale"), cross-checked against the OSF-hosted supplemental
codebook link cited in the paper.

**Real definition (Section 3.2.1, verbatim):** "'Calls for violence' (CV)
are an explicit call for, or endorsement of, violence on the basis of these
descriptions or justifications... language classified with CV was judged to
be a particular incitement to violence, which either directly or indirectly
called for or otherwise advocated violence against a group or an individual
because of their group membership."

The annotation workflow diagram (Fig. 1) confirms CV is reached by asking
"...endorse or express aggression or violence **toward** the targeted
group/person?" — i.e., the labeled post is doing the endorsing/expressing,
aimed outward at a target.

**Verdict: (b) WRONG TASK — explicit incitement/endorsement by the poster,
not a victim's distress report.** No real CV example sentence was found
quoted verbatim in the accessible portion of the paper (the definition
itself, read directly from the annotation workflow and coding-typology
sections, is unambiguous enough to make the call without one): CV is
defined and operationalized entirely around what the speaker is advocating
against a target group/individual, structurally identical to candidates 1,
3, 4, and 5.

## Pattern across all 6 candidates

Every single one of the 6 "threat"/"violence" sub-labels checked this
session — Hindi/Hindi-English PTH, CAD Threatening, ETHOS violence, OAA
threat, Gab CV, and (implicitly, since it has no threat category at all)
Roman Urdu — encodes **the speaker's own aggression, incitement, or intent
to harm a target**, not **a victim's report of being in danger**. This is
not a coincidence: standard hate-speech "threat" annotation is built around
identifying dangerous *speech acts* (who is being threatening), which is
definitionally the opposite grammatical/pragmatic frame from *danger
disclosure* (who is reporting being threatened). None of the 6 are usable
even as a rough proxy — this isn't a partial-fit compromise situation, it's
a clean label-semantics mismatch confirmed with real quoted text in 4 of 6
cases and a real, unambiguous definition in the other 2.

## Broader check: "crisis text" / "distress detection" search (new angle)

Searched Hugging Face and GitHub specifically for "crisis text detection",
"distress detection" text classification, and "help me"-style personal-
safety corpora — a different search angle from "hate speech", not directly
tried in this project's prior NLP rounds (Day 296, 299, 300, 307, 309 all
searched from an emotion-speech or hate-speech angle).

- **Crisis Text Line's own corpus** (100M+ real crisis text messages,
  described on `crisisnlp.qcri.org` and Crisis Text Line's own "Open Data
  Collaborations" page) — this is genuinely the closest real match to
  "personal distress text" in concept, but confirmed **access-gated**: it
  requires a formal Crisis Text Line Fellowship application, institutional
  affiliation, and IRB approval before any scrubbed/anonymized data is
  released — not obtainable this session, same access-gated (not
  license-blocked) category as K-EmoCon/EAV from Day 309.
- **CrisisNLP (`crisisnlp.qcri.org`)** — real site, real datasets (19+
  disaster events, HumAID, CrisisMMD, MEDIC, IDRISI, etc.), but every single
  one is **natural-disaster / humanitarian-crisis** labeled (floods,
  earthquakes, hurricanes, damage assessment) — "crisis" here means
  large-scale disaster, not interpersonal danger. Wrong domain, confirmed
  via direct fetch of the resource list, not from the site name alone.
- **`community-datasets/disaster_response_messages`** (HuggingFace, the
  well-known Figure-Eight/Appen Haiti-earthquake corpus) — checked in
  detail since it's genuinely multilingual with **real** non-English text
  (English + French + Haitian Creole, e.g. real quoted message: "Nou bezwen
  dlo, manje, medikaman, tant, vtman" = "We need water, food, medications,
  tents, clothes"). Real, permissively-available, real multilingual
  content. **But wrong domain**: all 36+ labels are natural-disaster aid
  categories (medical help, water, shelter, missing people, floods, storms,
  earthquakes) — confirmed **no interpersonal-threat or personal-danger
  label exists** (no stalking, no assault, no "someone is following me"
  equivalent). Closest genuinely-new multilingual hit this session, but
  content mismatch, not usable for m7 as-is.
- **`ourafla/Mental-Health_Text-Classification_Dataset`** (HuggingFace,
  Suicidal/Depression/Anxiety/Normal 4-class) — same English-only mismatch
  already established for the "Mental Health Corpus" in Day 309; not
  re-verified in further depth since the multilingual blocker is identical
  and already confirmed.
- **`nvidia/Nemotron-Safety-Guard-Dataset-v3`** — real, multilingual
  (12 languages incl. Hindi), but confirmed wrong task on inspection: this
  is an **LLM prompt-safety/guardrail** dataset (Aegis 2.0 hazard taxonomy
  for classifying whether a *prompt to an AI model* is harmful), not text
  expressing personal distress from a person in danger.

**Verdict on the broader search: nothing genuinely usable found, but one
real access-gated lead (Crisis Text Line's own corpus) is now explicitly on
record as the closest conceptual match in this entire project's NLP search
history** — closer in concept than any hate-speech dataset checked to date,
blocked purely on the same access-approval pattern as K-EmoCon/EAV (Day
309), not on content mismatch or license. If the user wants to pursue this,
next step is applying to the Crisis Text Line Fellowship/data-sharing
program directly — outside this session's scope to submit on the user's
behalf.

## Retrain

**No retrain attempted this session**, per the task's explicit instruction —
this was verification/discovery only. `m7_nlp_context_enhanced` still has
no confirmed usable dataset after this session; the multilingual
personal-distress requirement remains unmet by every real candidate checked
across Day 309 and Day 311 combined.

## Bottom line

- **All 6 hate-speech "threat"/"violence" sub-label candidates are
  confirmed wrong task** — real annotation guidelines and (for 4 of 6) real
  quoted example sentences all show the labeled text is the *aggressor's*
  speech act (threatening, inciting, calling for violence against a
  target), never a *victim's* report of being in danger. This is a
  structural mismatch in label semantics, not a borderline judgment call.
- **The broader "crisis text"/"distress detection" search angle found one
  real, genuinely closer-matching lead** (Crisis Text Line's own corpus) —
  access-gated, not obtainable this session, but a legitimate lead for a
  future session if the user wants to apply.
- **`m7_nlp_context_enhanced` remains genuinely blocked** — no dataset
  found across either Day 309 or Day 311 clears "real, downloadable now,
  license-clear, multilingual, personal-distress-labeled" simultaneously.
