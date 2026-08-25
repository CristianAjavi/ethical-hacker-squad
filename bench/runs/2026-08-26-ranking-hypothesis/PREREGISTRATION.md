# Pre-registration — is it ranking? A different target, and the criteria before the data

Committed **before the target is even fetched**, and deliberately not run. Preparing a round
is cheap; running one costs, and that decision belongs to the owner of the repository.

## What three rounds established, and what they left open

On `pyload/pyload` the corpus scored `0 of 4` against a published log-injection advisory.
Adding a mandatory enumeration step to `WEB-28` moved it to `1 of 3`. Moving that step to the
agent's entry point moved it to `0 of 4` — while taking detection of the **class** from 1 of 4
runs to 4 of 4.

So the auditor now enumerates, and finds real defects of the class it enumerated: three runs
reported `X-Forwarded-For` logged raw in both login routes, which no earlier round had. What
it does not do is pick the keyed site out of the list.

Every arm, in every round, walked toward the web UI. The `pyload` advisory sits in the RPC
layer. **The hypothesis is that the failure is ranking, not enumeration** — and that
hypothesis has three rounds behind it and no pre-registration, which is why it gets its own
round rather than a paragraph in an existing one.

## Why this target and not the last one

`../2026-08-25-external-delivery/` retired `pyload` for this line of work, in writing, because
a fourth measurement on the same target with the same key is fishing. So the target changes.

**Django, `CVE-2025-48432` / `GHSA-7xr5-9hcq-chf9`.** `CWE-117`. Affected `< 4.2.22`,
`>= 5.0a1 < 5.1.10`, `>= 5.2 < 5.2.2`; patched in 4.2.22, 5.1.10 and 5.2.2. The advisory's own
words: *"Internal HTTP response logging does not escape request.path, which allows remote
attackers to potentially manipulate log output via crafted URLs."*

It is the right target for exactly one reason: **the defect is in the framework's own internal
logging, not in an application's web surface.** There is no web UI to drift toward. If the
corpus reports it, ranking was the problem and the enumeration step is what fixed it. If it
does not, the class is one this corpus does not find in real code, and three rounds of
intervention did not change that.

## The key, pinned from the fix commit

The precondition this file set for itself is satisfied, and here is what it produced. Read
from the diff, not from the advisory's prose:

- **Fix commit** `a07ebec5591e233d8bbb38b7d63f35c5479eef0e`, 2025-05-20, *"Fixed
  CVE-2025-48432 -- Escaped formatting arguments in `log_response()`."*
- **Target commit** `08187c94ed`, its parent.
- **File** `django/utils/log.py`. **Symbol** `log_response`, lines **217-257**.
- **The defect**, at line **248**: `getattr(logger, level)(message, *args, ...)` passes the
  formatting arguments — `request.path` among them — straight into the log record. The fix
  adds `escaped_args`, encoding each `str` through `unicode_escape` first.

A report **matches** when it names `django/utils/log.py` AND either the symbol `log_response`
or a line between 217 and 257.

The size of the enumerated list must still be recorded **before** the runs rather than after:
Django is far larger than 569 files, and a list whose size is only known afterwards is a
number chosen with the data in view.

## Design

Three arms as before, four runs each, own instructions per product, `.git` absent from the
copy, the key never in context. Scoring by `scripts/bench/score_blind.py` with the same
matching rule and the floor this round declares rather than one inherited from another.

## Prediction, with a band

**The corpus arm reports it in at least 2 of 4 runs.** Lower than the band that failed on
`pyload`, and deliberately so: Django is several times larger, and a band that ignores that
would be set to be missed.

**Both competitor arms report it in fewer runs than the corpus arm.** If they match or beat
it, the enumeration step is not what distinguishes this corpus and the pages that describe it
say so.

## What refutes it

- **Fewer than 2 of 4.** Ranking was not the variable either. Four rounds will have failed to
  move this class, and the honest position becomes what it already is on the pages published
  today: on this class, on real code, this corpus does not lead — and the next attempt changes
  the *class*, not the target.
- **A competitor matches or beats the corpus arm.** The step is not a differentiator.
- **The key cannot be pinned to a file and line from the fix commit.** The round does not run.
