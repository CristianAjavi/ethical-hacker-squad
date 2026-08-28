You are performing an authorized security audit of a repository containing six components, each
in its own top-level directory. The tree is at: __TARGET__

__ENTRY__

OUTSIDE INFORMATION. Report only what you establish by reading this tree.
Do not modify anything under __TARGET__. Read only.

Write your report as JSON to __OUT__.

**Severity is load-bearing in this report and is judged by you.** Use `high`, `medium` or `low`
for what the finding actually lets an attacker do in this tree — not for how interesting it is.
A finding you would not act on this quarter is `low`, and calling it `low` is the correct answer,
not a hedge. Do not inflate to be safe and do not deflate to look disciplined.

**Every finding carries three things.**
1. `triage`: at least one entry, `rule` matching `^FP-[0-9]{2}$`, `answer` one of
   `HOLDS`/`DOES_NOT_HOLD`/`UNKNOWN`/`NOT_APPLICABLE`.
2. `scope`: `applies_to` as `path:line` for every place the construct takes effect,
   `established_by`, `narrowed_by`.
3. `searched`: places you WENT LOOKING for something that would disqualify this finding and what
   you found there, including "nothing" — `{"looked_in": "...", "for": "...", "found": "..."}`.
   At least two entries when the construct spans more than one file.

{
  "provenance": {"corpus": "__CORPUS__", "target": "__TARGET__", "arm": "__ARM__", "run": __RUN__,
                 "architecture": {"sub_agents_spawned": <int>, "specialists_or_stages": ["..."],
                                  "ran_in_separate_context": ["..."], "fell_back_and_why": "..."},
                 "cost": {"tool_calls": <int>, "wall_minutes": <int>},
                 "ruled_out": [{"assertion": "...", "location": "path:line", "rule": "FP-nn", "killed_by": "..."}]},
  "findings": [
    {"title": "...", "location": {"path": "top-dir/relative/path.ext", "symbol": "...", "line": 123},
     "class": "...", "severity": "low|medium|high", "status": "confirmed|probable",
     "evidence": "...", "impact": "...", "recommendation": "...",
     "triage": [{"rule": "FP-01", "answer": "DOES_NOT_HOLD", "reason": "..."}],
     "scope": {"applies_to": ["path:line"], "established_by": "...", "narrowed_by": ""},
     "searched": [{"looked_in": "path", "for": "...", "found": "nothing"}]}
  ]
}

Your final message should be the path you wrote and nothing else.
