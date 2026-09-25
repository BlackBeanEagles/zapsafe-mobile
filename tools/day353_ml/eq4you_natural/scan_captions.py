"""Day 355 - can EQ4You's free-text captions be mapped to m4/h_aggressive labels?

The captions are LLM-style descriptions over a wide affect vocabulary
("confusion and awkwardness", "disappointment and boredom", "serene and
poised"), not categorical labels. Before any audio is featurised, this
answers the only question that matters: does the corpus contain enough
clips whose caption clearly expresses ANGER or SADNESS, against clearly
calm/happy ones?

If anger is rare, EQ4You cannot serve h_aggressive however many clips it
has, and the remaining 876 tars would buy nothing.

TWO CORRECTIONS FROM THE FIRST PASS
===================================
1. ANGER originally included contempt/disgust/irritated/annoyed and matched
   captions like "a focused female voice ... displays determination with a
   hint of contempt" -- a composed speaker, not an angry one. Core anger
   words only now. Noisy positives are worse than fewer positives on a
   corpus whose labels are already machine-derived.
2. HAPPY was missing the noun forms, so "a mix of moderate distress and
   high excitement" scored as CLEAN sadness. Noun forms are covered.

NO BACKSLASHES IN THIS FILE, DELIBERATELY. An earlier edit round-tripped
"\\b" through a shell heredoc and delivered a literal backspace character,
so every regex silently matched nothing and anger_clean read 0. Lookarounds
give the same word-boundary behaviour with nothing to mangle.

STRICT BY DESIGN: a clip counts as angry only when an anger word appears
and no competing calm/positive word does. Ambiguous captions are dropped
rather than forced into a class.
"""
import collections
import re
import sys
import tarfile

def boundary(words):
    """Word-boundary alternation without a single backslash."""
    return re.compile("(?<![a-z])(" + "|".join(words) + ")(?![a-z])")

ANGER = boundary([
    "angry", "anger", "furious", "fury", "irate", "enraged", "rage",
    "raging", "outraged", "indignant", "hostile", "aggressive", "seething",
    "livid", "wrathful",
])
SAD = boundary([
    "sad", "sadness", "sorrow", "sorrowful", "grief", "despair",
    "despairing", "melancholy", "dejected", "depressed", "miserable",
    "unhappy", "anguish", "heartbroken", "mournful",
])
CALM = boundary([
    "calm", "calmness", "serene", "serenity", "relaxed", "tranquil",
    "peaceful", "composed", "poised", "content", "contentment", "neutral",
    "determined", "determination", "focused", "concentration",
])
HAPPY = boundary([
    "happy", "happiness", "joy", "joyful", "cheerful", "delighted",
    "pleased", "excited", "excitement", "enthusiastic", "enthusiasm",
    "amused", "amusement", "satisfied", "satisfaction", "elated", "upbeat",
])

def main():
    path = sys.argv[1]
    cnt = collections.Counter()
    ex = collections.defaultdict(list)
    t = tarfile.open(path, "r|")        # streaming, never extracts
    n = 0
    for m in t:
        if not m.isfile() or m.size >= 2000:
            continue                     # the big entries are the audio
        try:
            txt = t.extractfile(m).read().decode("utf-8", "replace").lower()
        except Exception:
            continue
        n += 1
        a = bool(ANGER.search(txt))
        s = bool(SAD.search(txt))
        c = bool(CALM.search(txt))
        h = bool(HAPPY.search(txt))
        if a:
            cnt["anger_any"] += 1
        if s:
            cnt["sad_any"] += 1
        if a and not (c or h or s):
            cnt["anger_clean"] += 1
            if len(ex["anger"]) < 3:
                ex["anger"].append(txt[:140])
        elif s and not (c or h or a):
            cnt["sad_clean"] += 1
            if len(ex["sad"]) < 3:
                ex["sad"].append(txt[:140])
        elif (c or h) and not (a or s):
            cnt["calm_happy_clean"] += 1
            if len(ex["calm_happy"]) < 2:
                ex["calm_happy"].append(txt[:140])
        else:
            cnt["ambiguous_dropped"] += 1
        if n % 25000 == 0:
            print("  scanned %d captions" % n, flush=True)
    t.close()

    print("\ntotal captions: %d" % n)
    for k, v in cnt.most_common():
        print("  %-20s %7d  (%.2f%%)" % (k, v, 100.0 * v / max(n, 1)))
    usable = cnt["anger_clean"] + cnt["calm_happy_clean"]
    print("\n  usable for h_aggressive (anger vs calm/happy): %d" % usable)
    print("  usable for m4 (anger+sad vs calm/happy): %d"
          % (usable + cnt["sad_clean"]))
    print("\nexamples:")
    for k in ("anger", "sad", "calm_happy"):
        for v in ex[k]:
            print("  [%-10s] %s" % (k, v))


if __name__ == "__main__":
    main()
