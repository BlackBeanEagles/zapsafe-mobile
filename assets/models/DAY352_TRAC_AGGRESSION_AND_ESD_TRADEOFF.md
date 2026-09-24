# Day 352 — TRAC-1 aggression model, and what ESD actually buys

Two results. One is a new model on the only permissively licensed text
corpus in the project; the other turns the m4/m5 licence question from a
judgement call into a measured trade.

## 1. `trac_aggression_v1` — English + Hindi, Apache-2.0

```
AUC 0.8312   95% CI [0.8196, 0.8423]
  english 0.7830    hindi 0.8310
length+punctuation baseline 0.6177   ->  beats shortcut by +0.2134

t=0.60  recall 0.675  precision 0.896
t=0.50  recall 0.819  precision 0.855
t=0.40  recall 0.886  precision 0.832
```

Trained on TRAC-1 (Trolling, Aggression and Cyberbullying, COLING 2018):
24,000 train / 6,002 dev Facebook comments, binary aggressive (OAG+CAG) vs
non-aggressive (NAG). The corpus ships its own train/dev; dev is never
trained on.

### The shortcut control was necessary

Aggressive comments genuinely are longer and shoutier, and a model using
**only** length, character count, `!`/`?` counts, uppercase ratio and mean
word length reaches **0.6177**. The model beats that by +0.2134, so the
signal is lexical rather than stylistic. Running this first is the habit
that nearly caught `distress_text_v1` out (word-count alone scored 0.9010
pooled there).

### A tokenizer bug that would have silently deleted Hindi

`distress_text_v1` tokenizes with `[a-z0-9']`, which is deliberately trivial
so Dart can reproduce it. That filter removes **every Devanagari
character** — every Hindi row would have become an empty string and the
Hindi half would have read as a bad model rather than a broken tokenizer.
The class is widened to `[a-z0-9']+|[^\x00-\x7f]+` and an assert on a real
Hindi row guards it.

### Conv1D, not a GRU, on purpose

The recurrent version scored **0.8430** — 0.012 better — but compiled to
TFLite with `SELECT_TF_OPS`: `FlexTensorListReserve`,
`FlexTensorListSetItem`, `FlexTensorListStack`. That needs the Flex delegate
linked into the Android build. Paying a delegate dependency for 0.012 on a
model nobody consumes yet is deployment cost up front for accuracy nobody
is using, so the shipped export is Conv1D + GlobalMaxPooling, **builtin ops
only**, asserted at conversion.

### What it is NOT

It does **not** satisfy M7. M7 needs multilingual **victim-perspective**
distress — "someone is following me", "help me". TRAC is
**aggressor-perspective**: text written *by* the aggressor. Conflating them
is exactly what `DAY347_DISTRESS_TEXT_DECISION.md` refused to do with
clinical text. **M7 remains blocked.**

What it does enable is a different, real capability: detecting threatening
or abusive messages *sent to* a user, in Hindi as well as English. Unlike
`distress_text_v1` it makes no inference about the user's own mental state.

**Not copied into `assets/`** — nothing loads it yet, and shipping an asset
with no consumer is the dead weight `scream_classifier_v3` was removed for.
It lives at `work/trac_aggression/`.

Limitation: the corpus carries no author id, so no author-level grouping is
possible and a prolific commenter can appear on both sides of the
train/dev split. Recorded rather than papered over.

## 2. What ESD actually buys m4 and m5

Day 350 flagged that `ESD_Dataset` declares `cc-by-nc-4.0` (and its official
NUS/SUTD page states **no licence at all**, only a citation request), and it
is the acted half of both vocal-stress models. No permissive replacement
exists locally: `ai4ser` is 3,500 clips but **Italian**, `huma` is
`cc-by-4.0` but **sixteen files**.

Part of the decision is measurable. Retraining on natural speech only:

```
            acted             natural
m4 no-ESD   0.3180 (-0.456)   0.6458 (+0.022)
m5 no-ESD   0.4619 (-0.325)   0.7826 (+0.002)
```

**ESD contributes nothing to natural speech and everything to acted
speech.** Natural performance is unchanged to within noise; acted collapses
to chance or below.

### How to read that

The `acted >= 0.70` bar is inherited from m5's original report
(`clears_ship_floor_070`), and it was measured on ESD because ESD was the
training data. **A phone hears natural speech.** If no deployment scenario
involves studio-acted emotion, dropping ESD costs nothing that matters and
removes the NC exposure outright.

Two reasons this is not being done unilaterally:

* The acted numbers do not merely fall, they go **below chance** (m4
  0.3180). That implies acted and natural emotional prosody are partly
  *inverted* for this task — the mirror image of Day 349, where
  acted-trained models sat at chance on natural speech. It is a real
  finding and it deserves a second look before being treated as harmless.
* Dropping ESD removes the *NC* exposure only. MELD still states no licence
  and derives from copyrighted broadcast; EmotionTalk ships with no card at
  all. The licence question is narrowed, not closed.

Artifacts: `work/m4_m5_v3_noesd/` (models exported only if they clear the
bars — they do not, so nothing was exported).

Reproduce: `work/trac_aggression/train_trac.py`,
`work/m4_m5_v3_noesd/train_noesd.py`.
