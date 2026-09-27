"""Day 363 - search Kaggle for the datasets I have been calling unavailable.

WHY THIS EXISTS
===============
Three items have been reported as blocked-on-acquisition for days:

    i_vehicle_crash   "VZCrash is the only public crash-IMU corpus, gated
                       AND CC BY-NC"
    h_aggressive/m4   "needs new natural (non-acted) speech data"
    M9 / dcs_fusion   "XD-Violence downloads are SharePoint and Baidu links;
                       needs a manual download"

The last one is already known to be wrong. A Day 305 commit in this very
repo reads: "Adds XD-Violence (MIT, bypktt/xd-violence Kaggle mirror)".
It was on Kaggle the whole time, MIT-licensed, and this project had already
used it.

That search was done against HuggingFace, Zenodo and the open web.
**Kaggle was never searched**, despite the account being configured since
June and five Kaggle datasets already sitting on this disk. If one "blocked"
item was wrong for that reason, the others deserve the same check before the
word blocked is used again.

This only LISTS what exists, with size and licence. It downloads nothing.
"""
from __future__ import annotations

import os

QUERIES = {
    "crash / IMU": [
        "car crash accelerometer", "vehicle collision imu",
        "crash detection sensor", "accident detection accelerometer",
        "driving events imu", "harsh braking accelerometer",
    ],
    "natural emotional speech": [
        "spontaneous emotional speech", "natural emotion speech dataset",
        "podcast emotion speech", "call center emotion audio",
        "conversational emotion audio", "msp podcast", "iemocap",
    ],
    "fusion / multimodal incident": [
        "xd-violence", "ucf crime", "multimodal violence detection",
    ],
    "environmental negatives (permissive)": [
        "environmental sound classification", "urban noise dataset",
    ],
}


def main():
    os.environ.setdefault("KAGGLE_CONFIG_DIR",
                          os.path.expanduser("~/.kaggle"))
    from kaggle.api.kaggle_api_extended import KaggleApi
    api = KaggleApi()
    api.authenticate()

    for topic, qs in QUERIES.items():
        print("\n" + "=" * 78)
        print("## %s" % topic)
        print("=" * 78)
        seen = set()
        for q in qs:
            q = " ".join(q.split())
            try:
                res = api.dataset_list(search=q, sort_by="hottest")
            except Exception as e:
                print("  [%s] ERROR %s" % (q, type(e).__name__))
                continue
            rows = []
            for d in res[:8]:
                ref = str(d.ref)
                if ref in seen:
                    continue
                seen.add(ref)
                lic = getattr(d, "licenseName", "?")
                size = getattr(d, "size", "?")
                rows.append((ref, size, lic))
            if rows:
                print("\n  query: %s" % q)
                for ref, size, lic in rows:
                    print("    %-52s %-9s %s" % (ref[:52], size, lic))


if __name__ == "__main__":
    main()
