You are performing an authorized security audit of a repository containing six small services and tools,
each in its own top-level directory. The tree is at: __TARGET__

__ENTRY__

OUTSIDE INFORMATION. Report only what you establish by reading this tree.
Do not modify anything under __TARGET__. Read only.

Audit every top-level directory. Write your report as JSON to __OUT__.

**The report has a contract, and it is the point of this run.** Every finding must carry a
`triage` array with at least one entry naming a false-positive rule and answering it:

    "triage": [{"rule": "FP-01", "answer": "DOES_NOT_HOLD", "reason": "..."}]

`rule` matches `^FP-[0-9]{2}$`. `answer` is exactly one of `HOLDS`, `DOES_NOT_HOLD`,
`UNKNOWN`, `NOT_APPLICABLE`. A rule that `HOLDS` rules the finding out — do not report it. An
`UNKNOWN` caps the finding at `probable` and it may not be reported as `confirmed`.

{
  "provenance": {"corpus": "__CORPUS__", "target": "__TARGET__", "arm": "__ARM__", "run": __RUN__,
                 "directories_audited": ["..."],
                 "ruled_out": [{"assertion": "...", "location": "path:line", "rule": "FP-nn", "killed_by": "..."}]},
  "findings": [
    {"title": "...",
     "location": {"path": "top-dir/relative/path.ext", "symbol": "function_or_class_or_key", "line": 123},
     "class": "short class name", "severity": "low|medium|high",
     "status": "confirmed|probable",
     "evidence": "what you read that establishes it", "impact": "...", "recommendation": "...",
     "triage": [{"rule": "FP-01", "answer": "DOES_NOT_HOLD", "reason": "..."}]}
  ]
}

Report every finding you can establish. Your final message should be the path you wrote and
nothing else.
