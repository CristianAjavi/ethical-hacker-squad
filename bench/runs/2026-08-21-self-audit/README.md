# Run 2026-08-21 — the squad against this repository

Every other run in this directory scores the squad against a bench **this project wrote**. This one does not: the target is `scripts/` and `.github/` of this repository — real automation, no planted defects, no answer key, and no way to score recall because nobody knows what is in there.

What can be measured without a key is **precision**: how many findings survive an independent attempt to destroy them.

## Result

| | |
|---|---|
| Findings written | 7 |
| Constructs ruled out | 13 |
| **Refuted by the verifier** | **0** |
| Verified outright | 2 |
| Partially verified — the claim holds, a named part is narrower | 5 |
| Severity **overstated** by the auditor | 2 |
| Severity **understated** by the auditor | 2 |

Two contexts, both fresh: one specialist wrote the findings knowing nothing about who wrote the code, and one verifier was told to **refute** them and to test each triage rule as a hypothesis. Every mechanical claim was reproduced inertly before it was accepted.

## What it found in our own machinery

**The gate that exists to stop false greens shipped one.** `gate-actions-lint.sh` detected a workflow outside the audited directory, printed `FAIL`, incremented a variable **nothing in the file read**, and exited `0`. The comment three lines above calls that check the reason the zizmor scope exclusion is safe. It was written in this same session, by us, hours earlier.

**A cache hit skipped the pin the file advertises.** The tool bootstrap verified a SHA-256 at download time and then reused whatever sat in `$TMPDIR/ehs-gate-tools` on every later run, with no comparison at all — and that path is writable by any local principal on a shared runner.

**`python3` shadowing in the release pipeline.** The verify job runs main's gates with the candidate tree as the working directory, and `python3 -c`, a heredoc on stdin and `python3 -` all put that directory first on `sys.path`. A `yaml.py` in the candidate would be imported by the gates judging it — which defeats the invariant the promotion model rests on: *who judges is always main*. The verifier called this the most serious of the seven.

**The secret scanner was deleting findings.** Its noise filter tested the whole **line**, so one `https://s3.example.com` in a trailing comment suppressed a live-format key sitting next to it. Reproduced on three of four synthetic files.

## What the verifier corrected, in both directions

Inflation: `F-001` and `F-003` were written `high` on exploit narratives that do not hold everywhere — the verifier measured that macOS `mktemp` ignores `TMPDIR` and lands in a per-user `0700` directory, so the second principal the finding assumes does not exist there.

Under-calling: `F-007` was filed `hardening`, which means *no weakness demonstrated*, for a reproducible control bypass; and `F-001` buried an unconditional integrity defect — the advertised pin is never enforced on a cache hit, on any host, with no preconditions — inside a `probable` exploit story.

Both directions are reportable defects. A report that inflates gets ignored; a report that under-calls gets filed.

## What this measures, and what it does not

It measures that on code with no planted anything, seven findings out of seven survived an adversarial reading, and that the two labels the verifier disputed were labels, not existence. It does **not** measure recall: nobody knows what else is in those files, and the audit's own coverage declaration names what it did not look at.

It is also not independent in the way that matters most: the code is ours, so the auditor and the author share a project even though they shared no context. The measurement that would settle it is the squad against a codebase nobody here has touched, with ground truth from someone else — and that is not in this directory.

## What was fixed from it, and what was filed

Fixed in the same branch, each with the check that stops it returning: the false green (`escalate`, the check lifted out of the tool-dependent block, `EHS_REPO_ROOT` honoured, and the self-test the gate never had); the unverified cache hit (per-user `0700` cache, an install stamp, and a cache that does not match its stamp is ignored — proved by tampering with the cached binary and watching it be rejected); the module shadowing (`PYTHONSAFEPATH` in the release workflow and in the governance helper); and the line-level noise filter, now applied to the match rather than to the line.

The rest is filed as issues rather than fixed in a rush.
