# Contributing

This repository ships a security skill that runs inside other people's projects. A wrong procedure here does not produce a wrong answer — it produces a missed vulnerability or a wasted week chasing something that was never exploitable. Contributions are reviewed with that in mind.

Everything here is in English, including commit messages. The reason is drift: the source material is English, and a translated procedure stops matching the identifier it cites and the output of the scanner it names. Note that the **squad's own reports are written in the user's language** — that is a runtime behaviour, not a repository language. See `skills/ethical-hacker-squad/references/report.md`.

## Branches

| Branch | Role | Direct pushes |
|---|---|---|
| `main` | channel `latest` | no — pull requests only |
| `stable` | weekly promoted channel | no — promoted automatically |
| `feat/*`, `fix/*`, `docs/*` | human work | n/a |
| `bot/knowledge-YYYY-WW` | automated knowledge loop | n/a |

`bot/` branches face **stricter** checks than human branches: protected-path enforcement, mandatory provenance on every changed item, and a diff-size cap. The prefix is a trust label. Loop pull requests are authored by a distinct bot identity, never by the maintainer, so that agent-written and human-written changes are distinguishable at a glance. That distinction is load-bearing in this repository's threat model, which is also why the `Co-Authored-By` trailer on agent-assisted commits stays.

Details of the channels and the promotion pipeline: `docs/release-channels.md`. Why the loop is the most dangerous component and how it is contained: `docs/knowledge-loop.md`.

## Issue types

The two first-class issue types are **audit-quality errors**, not crashes. A crash is obvious and cheap to find. A squad that confidently reports a non-issue, or quietly walks past a real one, is the failure mode that matters.

- **`false-positive`** — the squad reported something that is not exploitable. Something in a procedure is wrong: the pattern is too broad, or the `What rules it out` field is missing the compensating control that applies.
- **`false-negative`** — the squad missed a real finding. Either no procedure covers it, or the one that should have did not look in the right place.
- `knowledge-gap`, `licensing`, `tooling`, `bug`, `docs` — everything else.

Plus `area/*` per role, `severity/*`, and `origin/loop` versus `origin/human`. The full list is in `docs/gate-requirements.md` and it is what the automation wires; use those exact strings.

Use the issue forms. They exist to capture the minimum reproducible detail — the stack or artifact, what the squad reported, why it is or is not real, and which standard identifier applies — and, just as importantly, so that labelling can be **derived deterministically from structured fields**. Labelling from a model's reading of free prose would mean a language model taking write actions based on untrusted text submitted by strangers, which is precisely the attack chain this repository is built to avoid.

## The closure rule

**An issue is not closed by the fix. It is closed by the fix plus the check that stops it recurring.**

The question that decides it: *if someone reintroduces this tomorrow, does something go red without anyone having to remember?* If the answer is no, the issue stays open.

A `false-positive` "fixed" by rewording a paragraph is not fixed. Prose does not execute and nothing watches it. The fix is a corrected pattern or a sharpened false-positive criterion, **plus** a case in the corpus or a gate that fails if the old behaviour returns.

This is meant to be enforced, not requested: gate `G8` specifies that a pull request closing a `false-positive` or `false-negative` issue must also touch `scripts/gates/`, `tests/` or `references/knowledge/**`. Until CI lands, treat it as a review rule you apply by hand. If a case genuinely cannot be guarded, say so in the pull request and let the override happen in the open.

Every pull request declares which gate, test or corpus case now watches the regression, and uses `Fixes #N`.

## Adding or changing a procedure

Procedures live in `skills/ethical-hacker-squad/references/knowledge/*.md`. Each carries six fields, and each field has a job:

**Where to look** (paths and symbols per stack) · **Vulnerable pattern** (the construct, with a minimal snippet) · **What rules it out (false positive)** (compensating controls — **not optional**) · **Minimal test** (local, non-destructive; mark `REQUIRES AUTHORIZATION` for anything remote) · **Traceability** (standard identifiers) · **Tooling** (the command and what its output does not prove).

Four rules:

1. **Write it yourself.** Do not paste from any source. OWASP material is CC BY-SA and copying its wording would force this repository's derivative text under ShareAlike; CIS Controls are no-derivatives; the semgrep ruleset is proprietary. Cite the identifier, describe the requirement in your own words.
2. **Do not invent an identifier.** Cite at the granularity you actually verified — a category wildcard such as `WSTG-ATHN-*` or a chapter such as `ASVS 5.0 V6` is correct and honest. A fabricated ID is worse than none, because it survives review by looking right.
3. **Fill in what rules it out.** A procedure without false-positive criteria manufactures `false-positive` issues. Half the value of this corpus is knowing when *not* to report.
4. **Keep the IDs stable.** `WEB-07` is referenced from `traceability.md`, from findings and from issues. Append new ones; do not renumber.

Adding a new source means adding it to `docs/sources-allowlist.json` with its licence, and to `NOTICE.md`. That file is a protected path: the automated loop cannot extend its own reading list.

## Testing a branch before merge

The skill is prose plus structure, so most defects are structural and caught by the gates. Behavioural defects are not, and those need a real run.

Isolate the branch in a worktree, then load it. There are two ways, and the difference matters:

```bash
git worktree add ../ehs-test <branch>
```

**For iterating (preferred).** `--plugin-dir` loads the plugin from disk without going through the cache, so `/reload-plugins` picks up edits without a reinstall:

```bash
claude --plugin-dir ../ehs-test
# after editing a pack or an agent:
/reload-plugins
```

**For testing the real install path.** Register the worktree as a local marketplace. Note that Claude Code **copies** the plugin into its cache on install, so edits do *not* appear until you refresh:

```
/plugin marketplace add /absolute/path/to/ehs-test
/plugin install ethical-hacker-squad@ethical-hacker-squad
# after any edit:
/plugin marketplace update ethical-hacker-squad
```

Then run the squad against a deliberately vulnerable target you control — OWASP Juice Shop (MIT) is a good one — never against a stranger's system:

```
Use the ethical-hacker-squad skill to audit this repository without modifying files.
```

Clean up. Removing a marketplace uninstalls every plugin that came from it:

```
/plugin marketplace remove ethical-hacker-squad
```
```bash
git worktree remove ../ehs-test
```

What to check on that run: the leader staffed only roles the inventory justifies; each specialist loaded only the pack sections it needed; findings cite procedure IDs; every finding worked through its false-positive criteria; the coverage declaration is present and honest; and in `audit` mode `git status --porcelain` is empty afterwards.

That last one matters. Auditor agents are configured without `Edit` and `Write` — but they retain `Bash`, which can write through the shell. Removing the direct write tools is a real reduction and an incomplete control, so verify the working tree rather than assuming it.

Run the gates locally before opening the pull request: `scripts/gates/`. Each exits `0` for measured-and-fine, `1` for measured-and-failing, and `2` for could-not-measure. Exit `2` is a failure, never a pass: a gate that cannot tell a clean result from a tool that did not run is not a gate.

## Reporting a vulnerability in this repository

Do not open a public issue. See `SECURITY.md`.

## What will be rejected

Working exploits, weaponized payload collections, malware, command-and-control tooling, detection-evasion techniques, or anything whose primary use is unauthorized access. This is an audit skill operating under an explicit authorization contract. Minimal inert probes are welcome — they are the instrument of verification. Anything that works as a weapon on arrival is not.

Also rejected: text copied from a copyleft or proprietary source; fabricated identifiers; quantitative claims without a source; and changes that weaken the safety contract in `SKILL.md`. That last path is protected, and a change to it needs a reason that stands on its own.
