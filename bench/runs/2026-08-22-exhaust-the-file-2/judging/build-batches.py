#!/usr/bin/env python3
import hashlib, json, pathlib, sys
SP = pathlib.Path("/private/tmp/claude-501/-Users-cristianajavi/ddae72cd-6c1e-4c0c-be51-8f91cd87d164/scratchpad")
cases = json.loads((SP/"wholerepo-cases.json").read_text())["cases"]
adv = [{"advisory_id": c["advisory"], "summary": c["advisory_summary"],
        "description": (c.get("advisory_description") or "")[:1800]}
       for c in cases if c["advisory"] == "GHSA-xhj3-7xw9-vr34"]
label, path = sys.argv[1], sys.argv[2]
d = json.loads(pathlib.Path(path).read_text())
items = []
for f in d.get("findings", []):
    loc = f.get("location") or {}
    where = f"{loc.get('path')}:{loc.get('line')}" if isinstance(loc, dict) else ""
    items.append({"title": f.get("title",""), "location": where,
                  "impact": f.get("impact",""), "evidence": (f.get("evidence") or "")[:900]})
items.sort(key=lambda x: hashlib.sha256(json.dumps(x, sort_keys=True).encode()).hexdigest())
obj = {"findings": [dict(item_id=f"N{i+1:02d}", **x) for i, x in enumerate(items)],
       "advisories_to_match": adv}
blob = json.dumps(obj)
for bad in ("corpus", "plain", "arm", "unaided"):
    if f'"{bad}"' in blob: sys.exit(f"blinding leak: {bad}")
out = SP/"prefix"/"judging"/f"batch-{label}.json"
out.write_text(json.dumps(obj, indent=1) + "\n")
print(f"{label}: {len(items)} findings vs {len(adv)} advisory")
