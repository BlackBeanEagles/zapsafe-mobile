"""Apply a translation bundle into assets/translations/<code>.json.

Refuses to write when a string would drop or invent a runtime placeholder,
because `{seconds}` silently vanishing from an SOS countdown is the kind of
break that only shows up in the emergency it exists for.

Also refuses to overwrite an existing non-empty value: bundles only FILL
gaps. Reruns are therefore no-ops, and a hand-corrected string cannot be
clobbered by a later batch.

Preserves each file's CRLF line endings, 2-space indent and UTF-8-without-BOM,
and reorders every touched section into en.json's key order so diffs stay
readable.
"""
import io
import importlib.util
import json
import os
import re
import sys

ROOT = (r"C:\Users\hridy\Desktop\zapsafe\letsstartbuilding"
        r"\zapsafe_mobile_main_reconcile\assets\translations")
PH = re.compile(r"\{(\w+)\}")


def flat(d, p=""):
    o = {}
    for k, v in d.items():
        kk = f"{p}.{k}" if p else k
        if isinstance(v, dict):
            o.update(flat(v, kk))
        else:
            o[kk] = v
    return o


def load_bundle(path):
    spec = importlib.util.spec_from_file_location("b", path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m.BUNDLE


def main(bundle_path):
    en_raw = json.load(io.open(os.path.join(ROOT, "en.json"), encoding="utf-8"))
    en = flat(en_raw)
    bundle = load_bundle(bundle_path)

    for code, tr in sorted(bundle.items()):
        p = os.path.join(ROOT, code + ".json")
        raw = json.load(io.open(p, encoding="utf-8"))
        added = skipped = 0
        touched = set()
        for dotted, val in tr.items():
            if dotted not in en:
                raise SystemExit("%s: key %s is not in en.json" % (code, dotted))
            want, got = set(PH.findall(str(en[dotted]))), set(PH.findall(val))
            if want != got:
                raise SystemExit(
                    "%s/%s placeholder mismatch: en has %s, translation has %s"
                    % (code, dotted, sorted(want) or "none", sorted(got) or "none"))
            sec, leaf = dotted.split(".", 1)
            node = raw.setdefault(sec, {}) if "." not in leaf else None
            if node is None:
                raise SystemExit("%s: nested key %s not supported" % (code, dotted))
            if leaf in node and str(node[leaf]).strip():
                skipped += 1
                continue
            node[leaf] = val
            added += 1
            touched.add(sec)

        # reorder touched sections into en.json's order
        for sec in touched:
            order = list(en_raw[sec].keys()) if isinstance(en_raw.get(sec), dict) else []
            cur = raw[sec]
            raw[sec] = {k: cur[k] for k in order if k in cur}
            for k in cur:
                if k not in raw[sec]:
                    raw[sec][k] = cur[k]

        txt = json.dumps(raw, ensure_ascii=False, indent=2) + "\n"
        with io.open(p, "w", encoding="utf-8", newline="\r\n") as fh:
            fh.write(txt)
        print("  %-4s +%-4d filled  %d already present" % (code, added, skipped))
    print("done")


if __name__ == "__main__":
    main(sys.argv[1])
