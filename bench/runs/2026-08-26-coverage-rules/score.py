#!/usr/bin/env python3
"""Score the coverage round against the corpus-v2 key.

WHY THIS IS NOT scripts/bench/score.py
    The pre-registration named that scorer. It reads bench/ground-truth.json,
    whose planted entries carry a `lines` RANGE; corpus-v2's key carries a
    single `line`. The scorer could not consume it, so this file exists and the
    deviation is on the record rather than absorbed.

    The matching rule is otherwise the same and is applied identically to every
    arm: same file AND (same symbol OR line within +/- WINDOW).

    WINDOW is a choice this file's author made, so `--sensitivity` re-scores at
    0, 3, 6 and 12 and prints whether the verdict moves. A verdict that depends
    on the window is a verdict about the window.

Exit codes: 0 = measured | 2 = could not measure.
"""
from __future__ import annotations
import argparse, glob, json, os, statistics as st, sys
from collections import Counter, defaultdict


def norm(p): return (p or "").replace("\\", "/").lstrip("./")


def match(loc, it, window):
    p = norm(loc.get("path", ""))
    full = norm(f"{it['case']}/{it['path']}")
    if not (p.endswith(norm(it["path"])) or full.endswith(p)):
        return False
    if it["case"] not in p:
        return False
    if (loc.get("symbol") or "") == it["symbol"]:
        return True
    ln = loc.get("line")
    return isinstance(ln, int) and abs(ln - it["line"]) <= window


def score(reports, key, window):
    arms = defaultdict(list)
    for f in reports:
        arm = os.path.basename(f).split("-")[0]
        doc = json.loads(open(f).read())
        if not isinstance(doc.get("provenance"), dict):
            arms[arm].append(None); continue
        locs = [x.get("location") or {} for x in doc.get("findings", [])]
        det = {it["id"] for it in key["planted"] if any(match(l, it, window) for l in locs)}
        dec = {it["id"] for it in key["decoys"] if any(match(l, it, window) for l in locs)}
        arms[arm].append((det, dec, locs))
    return arms


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--reports", required=True)
    ap.add_argument("--key", required=True)
    ap.add_argument("--window", type=int, default=6)
    ap.add_argument("--sensitivity", action="store_true")
    a = ap.parse_args(argv)

    files = sorted(glob.glob(os.path.join(a.reports, "*.adapted.json")))
    if not files:
        print(f"UNMEASURABLE no adapted reports under {a.reports}"); return 2
    key = json.loads(open(a.key).read())
    T = len(key["planted"])

    def run(window, verbose):
        arms = score(files, key, window)
        out = {}
        for n, rows in sorted(arms.items()):
            valid = [r for r in rows if r]
            if len(valid) < 3:
                print(f"UNMEASURABLE arm {n}: only {len(valid)} valid run(s)"); return None
            rec = [len(d) / T for d, _, _ in valid]
            dec = [len(x) for _, x, _ in valid]
            out[n] = (st.mean(rec), st.mean(dec), min(rec), max(rec),
                      st.mean(len(l) for _, _, l in valid))
            if verbose:
                print(f"{n:<8} {len(valid)} runs  recall {st.mean(rec)*100:5.1f}%  "
                      f"({min(rec)*100:.0f}-{max(rec)*100:.0f}%)  decoys {st.mean(dec):5.2f}  "
                      f"findings {st.mean(len(l) for _,_,l in valid):5.1f}")
        return out

    print(f"=== window ±{a.window} lines ===")
    o = run(a.window, True)
    if o is None: return 2
    gap = o["ours"][0] - o["mantis"][0]
    worse_decoys = o["ours"][1] > o["mantis"][1]
    print(f"\nrecall gap (ours - mantis): {gap*100:+.1f} points")
    print(f"decoy rate: ours {o['ours'][1]:.2f} vs mantis {o['mantis'][1]:.2f}"
          f"  -> ours is {'WORSE' if worse_decoys else 'not worse'}")
    print("\nPRE-REGISTERED BAND: supported iff gap >= +5 points AND our decoy rate is NOT higher")
    if o["mantis"][0] >= o["ours"][0]:
        v = "REFUTED (mantis recall >= ours)"
    elif gap >= 0.05 and not worse_decoys:
        v = "SUPPORTED"
    elif gap >= 0.05 and worse_decoys:
        v = "NOT SUPPORTED — recall condition met, decoy condition FAILED (the band is a conjunction)"
    else:
        v = "INCONCLUSIVE (ahead by less than 5 points)"
    print(f"VERDICT: {v}")

    byfile = defaultdict(list)
    for p in key["planted"]:
        byfile[f"{p['case']}/{p['path']}"].append(p["id"])
    multi = [f for f, v in byfile.items() if len(v) > 1]
    print(f"\n=== registered mechanism test: {len(multi)} multi-defect files ===")
    arms = score(files, key, a.window)
    mech = {}
    for n, rows in sorted(arms.items()):
        per, ge2 = [], []
        for r in [x for x in rows if x]:
            c = Counter()
            for m in multi:
                base, case = m.split("/")[-1], m.split("/")[0]
                c[m] = sum(1 for l in r[2] if base in norm(l.get("path", "")) and case in norm(l.get("path", "")))
            per.append(st.mean(c[m] for m in multi)); ge2.append(sum(1 for m in multi if c[m] >= 2))
        mech[n] = (st.mean(per), st.mean(ge2))
        print(f"  {n:<8} findings/file {st.mean(per):.2f}   files with >=2: {st.mean(ge2):.1f}/{len(multi)}")
    ok = mech["ours"][0] >= mech["mantis"][0] and mech["ours"][1] >= mech["mantis"][1]
    print(f"  MECHANISM: {'CONFIRMED' if ok else 'NOT CONFIRMED'} "
          f"(band: ours findings/file >= mantis AND files-with-2+ >= mantis)")

    if a.sensitivity:
        print("\n=== sensitivity to the line window ===")
        for w in (0, 3, 6, 12):
            oo = run(w, False)
            if oo is None: continue
            g = oo["ours"][0] - oo["mantis"][0]
            print(f"  ±{w:<3} ours {oo['ours'][0]*100:5.1f}%  mantis {oo['mantis'][0]*100:5.1f}%  "
                  f"gap {g*100:+5.1f}  decoys {oo['ours'][1]:.2f}/{oo['mantis'][1]:.2f}  "
                  f"-> {'ours ahead' if g>0 else 'mantis ahead'}, decoys {'worse' if oo['ours'][1]>oo['mantis'][1] else 'not worse'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
