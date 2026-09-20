"""Day 343 — does adding attack-type diversity help M8 generalise?

THE EXPERIMENT, AND WHY IT IS NOT THE OBVIOUS ONE
=================================================
The obvious test — train with and without the 84 extra videos, evaluate on a
held-out Zalo split — **cannot answer the question**. The extra videos are
latex/silicone/textile-3D/wrapped-paper masks; a Zalo-only test set contains
none of those, so the extra data would be judged on attack types it was not
added to cover. It would most likely score as noise either way.

The claim being tested is specifically: *does training on a wider range of
attacks help against an attack type the model has never seen?* That needs a
**leave-one-attack-type-out** design:

    for each attack type T:
        baseline  = train on Zalo only
        combined  = train on Zalo + every extra attack EXCEPT T
        test both on:  T's videos (spoof) + held-out Zalo live videos

Baseline has seen no mask attacks at all; combined has seen five of six. If
diversity transfers, combined beats baseline on T. If it does not, the two
are indistinguishable and the honest answer is that 84 videos are not enough
to buy generalisation.

A plain Zalo-held-out number is also reported, for comparability with the
0.7186 / 0.752 baselines from Days 292 and 302.

Both arms use the same architecture, seeds and epochs; only the training data
differs.
"""
from __future__ import annotations

import json
import pathlib

import numpy as np

SEED = 42
SEQ_LEN, FEAT_DIM = 24, 12
OUT = pathlib.Path(r"C:\Users\hridy\Desktop\zapsafe\work\m8_combined")
CACHE = OUT / "feats_paths.npz"


def attack_type(path_str: str) -> str:
    """Top-level folder under spoofing/ — the attack family."""
    p = path_str.replace("\\", "/")
    for part in p.split("/"):
        if part in ("Cutout_attacks", "Latex_mask", "Replay_display_attacks",
                    "Replay_mobile_attacks", "Silicone_mask",
                    "Wrapped_3D_paper_mask"):
            return part
        if part.startswith("Textile"):
            return "Textile_3D_mask"
    return "unknown"


def build(tf):
    m = tf.keras.Sequential([
        tf.keras.layers.Input((SEQ_LEN, FEAT_DIM)),
        tf.keras.layers.Conv1D(32, 3, padding="same", activation="relu"),
        tf.keras.layers.BatchNormalization(),
        tf.keras.layers.Bidirectional(tf.keras.layers.LSTM(32)),
        tf.keras.layers.Dropout(0.3),
        tf.keras.layers.Dense(32, activation="relu"),
        tf.keras.layers.Dense(1, activation="sigmoid"),
    ])
    m.compile(optimizer=tf.keras.optimizers.Adam(1e-3),
              loss="binary_crossentropy",
              metrics=[tf.keras.metrics.AUC(name="auc")])
    return m


def fit_eval(tf, Xtr, ytr, Xte, yte, seed):
    from sklearn.metrics import roc_auc_score
    tf.keras.utils.set_random_seed(seed)
    mu = Xtr.reshape(-1, FEAT_DIM).mean(0)
    sd = Xtr.reshape(-1, FEAT_DIM).std(0) + 1e-8
    nz = lambda a: ((a - mu) / sd).astype(np.float32)
    m = build(tf)
    npos, nneg = float(ytr.sum()), float((1 - ytr).sum())
    cw = {0: len(ytr) / (2 * max(nneg, 1)), 1: len(ytr) / (2 * max(npos, 1))}
    m.fit(nz(Xtr), ytr, validation_split=0.12, epochs=60, batch_size=32,
          class_weight=cw, verbose=0,
          callbacks=[tf.keras.callbacks.EarlyStopping(
              monitor="val_auc", mode="max", patience=10,
              restore_best_weights=True)])
    p = m.predict(nz(Xte), verbose=0).ravel()
    return float(roc_auc_score(yte, p)), m, (mu, sd)


def main():
    import tensorflow as tf
    from sklearn.metrics import roc_auc_score
    d = np.load(CACHE, allow_pickle=True)
    X, y, src = d["X"], d["y"], np.array([str(s) for s in d["src"]])
    print(f"sequences {X.shape}  live {int(y.sum())}  spoof {int((1-y).sum())}")
    zal, ext = src == "zalo", src == "spoof_extra"
    print(f"  zalo {int(zal.sum())}   spoof_extra {int(ext.sum())}")

    # --- 1. plain Zalo held-out, for comparability with 0.7186 / 0.752 ----
    rng = np.random.RandomState(SEED)
    zi = np.where(zal)[0]
    rng.shuffle(zi)
    n_te = int(len(zi) * 0.2)
    te_idx, tr_idx = zi[:n_te], zi[n_te:]
    a_base, _, _ = fit_eval(tf, X[tr_idx], y[tr_idx], X[te_idx], y[te_idx], 0)
    ei = np.where(ext)[0]
    a_comb, _, _ = fit_eval(tf, X[np.concatenate([tr_idx, ei])],
                            y[np.concatenate([tr_idx, ei])],
                            X[te_idx], y[te_idx], 0)
    print(f"\n[A] Zalo held-out ({len(te_idx)} clips) — the comparable number")
    print(f"    Zalo only          AUC={a_base:.4f}")
    print(f"    Zalo + 84 attacks  AUC={a_comb:.4f}   delta {a_comb-a_base:+.4f}")
    print("    (expected to move little: this test set has none of the new "
          "attack types)")

    # --- 2. leave-one-attack-type-out — the real question -----------------
    types = (np.array([attack_type(s) for s in d["path"]])
             if "path" in d.files else None)
    print("\n[B] leave-one-attack-type-out")
    if types is None:
        print("    per-video paths were not cached, so attack type cannot be "
              "recovered; re-extract with paths to run this arm.")
        json.dump({"zalo_heldout_baseline": round(a_base, 4),
                   "zalo_heldout_combined": round(a_comb, 4)},
                  open(OUT / "m8_combined_report.json", "w"), indent=2)
        return

    live_pool = te_idx[y[te_idx] == 1]
    rows = []
    for T in sorted(set(types[ext]) - {"unknown"}):
        hold = np.where(ext & (types == T))[0]
        keep = np.where(ext & (types != T))[0]
        Xte = np.concatenate([X[hold], X[live_pool]])
        yte = np.concatenate([y[hold], y[live_pool]])
        if len(set(yte.tolist())) < 2:
            continue
        ab, _, _ = fit_eval(tf, X[tr_idx], y[tr_idx], Xte, yte, 1)
        ac, _, _ = fit_eval(tf, X[np.concatenate([tr_idx, keep])],
                            y[np.concatenate([tr_idx, keep])], Xte, yte, 1)
        rows.append((T, len(hold), ab, ac))
        print(f"    {T:24s} n={len(hold):3d}  Zalo-only {ab:.4f}   "
              f"+5 other attacks {ac:.4f}   delta {ac-ab:+.4f}", flush=True)
    if rows:
        d_all = np.array([r[3] - r[2] for r in rows])
        print(f"\n    mean delta {d_all.mean():+.4f}  "
              f"(helped {int((d_all>0).sum())}/{len(rows)} attack types)")
    json.dump({"zalo_heldout_baseline": round(a_base, 4),
               "zalo_heldout_combined": round(a_comb, 4),
               "leave_one_attack_out": [
                   {"type": t, "n": n, "zalo_only": round(b, 4),
                    "with_other_attacks": round(c, 4),
                    "delta": round(c - b, 4)} for t, n, b, c in rows]},
              open(OUT / "m8_combined_report.json", "w"), indent=2)
    print("report written")


if __name__ == "__main__":
    main()
