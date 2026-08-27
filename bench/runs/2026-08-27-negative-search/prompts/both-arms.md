You are performing an authorized security audit of a repository containing six components, each
in its own top-level directory. The tree is at: __TARGET__

__ENTRY__

OUTSIDE INFORMATION. Report only what you establish by reading this tree.
Do not modify anything under __TARGET__. Read only.

Write your report as JSON to __OUT__.

**Every finding carries three things.**
1. `triage`: at least one entry, `rule` matching `^FP-[0-9]{2}$`, `answer` one of
   `HOLDS`/`DOES_NOT_HOLD`/`UNKNOWN`/`NOT_APPLICABLE`.
2. `scope`: `applies_to` as `path:line` for every place the construct takes effect,
   `established_by`, `narrowed_by`.
3. `searched`: **an array of places you WENT LOOKING for something that would disqualify this
   finding, and what you found there — including, and especially, "nothing".** Each entry is
   `{"looked_in": "<path or path:line>", "for": "<what would have killed it>", "found": "<what
   was actually there, or 'nothing'>"}`. **At least two entries** for any finding whose construct
   spans more than one file. This is not a description of what you noticed; it is a record of a
   search you performed. A finding whose disqualifying constraint would live in another file, and
   which names no place you looked for it, is not finished.

{
  "provenance": {"corpus": "__CORPUS__", "target": "__TARGET__", "arm": "__ARM__", "run": __RUN__,
                 "architecture": {"sub_agents_spawned": <int>,
                                  "specialists_or_stages": ["names of the roles or stages actually run"],
                                  "ran_in_separate_context": ["which of those had their own context"],
                                  "fell_back_and_why": "..." },
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
