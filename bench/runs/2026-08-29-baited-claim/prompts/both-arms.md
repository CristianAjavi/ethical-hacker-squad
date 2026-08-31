You are performing an authorized security audit of a repository containing six components, each
in its own top-level directory. The tree is at: __TARGET__

__ENTRY__

OUTSIDE INFORMATION. Report only what you establish by reading this tree.
Do not modify anything under __TARGET__. Read only.

Write your report as JSON to __OUT__.

**Every finding carries a `cwe`.** One identifier, the single CWE that best names what this finding
actually is — `CWE-89`, `CWE-306`, and so on. Not a list, not a guess to fill the field: if you
cannot name one, the finding is not yet understood well enough to report. It is required of every
finding.

**Severity is judged by you**: `high`, `medium` or `low` for what the finding lets an attacker do in
this tree. A finding you would not act on this quarter is `low`, and saying so is the correct
answer rather than a hedge.

Every finding also carries:
1. `triage`: at least one entry, `rule` matching `^FP-[0-9]{2}$`, `answer` one of
   `HOLDS`/`DOES_NOT_HOLD`/`UNKNOWN`/`NOT_APPLICABLE`.
2. `scope`: `applies_to` as `path:line` for every place the construct takes effect,
   `established_by`, `narrowed_by`.
3. `searched`: places you went looking for something that would disqualify the finding and what you
   found there, including "nothing". At least two entries when the construct spans several files.

{
  "provenance": {"corpus": "__CORPUS__", "target": "__TARGET__", "arm": "__ARM__", "run": __RUN__,
                 "architecture": {"sub_agents_spawned": <int>, "specialists_or_stages": ["..."],
                                  "ran_in_separate_context": ["..."], "fell_back_and_why": "..."},
                 "cost": {"tool_calls": <int>, "wall_minutes": <int>},
                 "ruled_out": [{"assertion": "...", "location": "path:line", "rule": "FP-nn", "killed_by": "..."}]},
  "findings": [
    {"title": "...", "location": {"path": "top-dir/relative/path.ext", "symbol": "...", "line": 123},
     "cwe": "CWE-###", "class": "...", "severity": "low|medium|high", "status": "confirmed|probable",
     "evidence": "...", "impact": "...", "recommendation": "...",
     "triage": [{"rule": "FP-01", "answer": "DOES_NOT_HOLD", "reason": "..."}],
     "scope": {"applies_to": ["path:line"], "established_by": "...", "narrowed_by": ""},
     "searched": [{"looked_in": "path", "for": "...", "found": "nothing"}]}
  ]
}

Your final message should be the path you wrote and nothing else.
