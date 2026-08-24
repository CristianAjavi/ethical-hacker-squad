#!/usr/bin/env python3
"""Pool both arms' claims into ONE blinded batch. Arm, model and run never enter
the file; the order is fixed by a digest of each claim's own text, so the id a
claim gets cannot carry information about where it came from."""
import hashlib, json, pathlib, sys
R = pathlib.Path("/private/tmp/claude-501/-Users-cristianajavi/ddae72cd-6c1e-4c0c-be51-8f91cd87d164/scratchpad/repl")
def flatten(v):
    """One arm writes evidence as prose, the other as a structured object. The
    verifier must see the same KIND of field from both or the shape itself
    labels the arm."""
    if v is None:
        return ""
    if isinstance(v, str):
        return v
    if isinstance(v, list):
        return " ".join(flatten(x) for x in v)
    if isinstance(v, dict):
        return " ".join(f"{k}: {flatten(x)}" for k, x in v.items())
    return str(v)


runs = sys.argv[1:]
rows, prov = [], []
for run in runs:
    f = R / run / "findings.json"
    if not f.exists():
        print(f"SKIP {run}: no artifact - not measured, not a zero", file=sys.stderr); continue
    for x in json.loads(f.read_text()).get("findings", []):
        loc = x.get("location")
        if isinstance(loc, dict):
            where_f, where_l = loc.get("path", ""), loc.get("line", "")
        elif isinstance(loc, str) and loc:
            # "config/mcp.json, line 6" - one arm writes the location as prose
            part = loc.split(",", 1)
            where_f = part[0].strip()
            where_l = part[1].replace("line", "").strip() if len(part) > 1 else ""
        else:
            where_f, where_l = x.get("file", ""), x.get("line", "")
        # Path STYLE labels an arm as surely as a name would: one writes the
        # absolute path, another the path relative to the target. Normalise.
        where_f = str(where_f or "").replace(str(R / "target") + "/", "").replace(str(R / "target"), "")
        where_f = where_f.lstrip("./")
        rows.append({"title": x.get("title", ""), "file": where_f, "line": str(where_l or ""),
                     "severity": x.get("severity", ""), "impact": x.get("impact", ""),
                     "evidence": flatten(x.get("evidence"))[:1000], "_run": run})
rows.sort(key=lambda r: hashlib.sha256(json.dumps({k: v for k, v in r.items() if k != "_run"},
                                                  sort_keys=True).encode()).hexdigest())
claims = []
for i, r in enumerate(rows):
    cid = f"R{i+1:02d}"
    prov.append({"claim_id": cid, "run": r.pop("_run")})
    claims.append(dict(claim_id=cid, **r))
blob = json.dumps({"claims": claims})
for bad in ("corpus", "mantis", "competitor", "scratchpad", "repl/", "SKILL.md", "findings.schema"):
    if bad in blob:
        sys.exit(f"blinding leak: {bad!r} appears in the batch")
(R / "verify" / "claims.json").write_text(json.dumps({"claims": claims}, indent=1) + "\n")
(R / "keys" / "provenance.json").write_text  # NEVER beside claims.json: it maps every claim to its arm(json.dumps({"map": prov}, indent=1) + "\n")
import collections
print(f"pooled {len(claims)} claims from {len(set(p['run'] for p in prov))} runs:",
      dict(collections.Counter(p["run"] for p in prov)))
