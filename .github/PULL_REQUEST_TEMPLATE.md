<!--
  Do not delete the sections. Fill them in; mark the ones that do not apply as
  "not applicable" with a reason.

  WHAT ACTUALLY BLOCKS (scripts/gates/gate-issue-closure.sh, on every PR):
  if this PR declares that it closes an issue labeled type/false-positive or type/false-negative
  and does NOT touch any file under scripts/gates/, tests/ or
  skills/*/references/knowledge/ (contract G8 of docs/gate-requirements.md),
  the gate fails (rc=1).
  Deleting that file does not count either: the gate discards the files the PR removes.

  WHAT DOES NOT BLOCK (a human reviews it): declaring no issue does not fail the gate,
  because there are legitimate PRs with no issue (infrastructure, the knowledge loop).
  It also cannot check that the touched file REALLY contains the case for this
  regression. That is what gets reviewed by reading the sections below.
-->

## What it closes

<!--
  REQUIRED. One closing keyword per issue, in the BODY of this PR:
  Fixes #N   |   Closes #N   |   Resolves #N
  (GitHub only links it if the PR targets the default branch of the repo.)
  If this PR closes no issue, write: "Closes no issue because <reason>"
  and open the issue first if the change fixes an observed behavior.
-->

Fixes #

## What is now watching the regression

<!--
  REQUIRED when closing an issue of type/false-positive or type/false-negative.
  Repo doctrine: an issue is not closed with the fix, it is closed with the fix
  PLUS the check that keeps it from coming back. A fix without a check is a scheduled relapse.

  Fill in the three lines. The gate requires the PR to really touch a gate or the case corpus.
-->

- **Gate or case:** <!-- exact path: scripts/gates/<x>.sh, tests/fixtures/<x>, or the case added to skills/*/references/knowledge/<x>.md -->
- **What it detects:** <!-- the concrete input that used to pass and now fails -->
- **How it fails if the regression returns:** <!-- expected output and exit code: 1 = measured and failing -->

Negative verification (required for new or modified gates):

```
# paste the command and its output: first with the defect present (must give rc=1),
# then with the fix applied (must give rc=0)
```

## Change

<!-- What changes and why. If it touches the skill instructions, say which role it affects. -->

## Distribution impact

<!-- Check what applies -->

- [ ] Touches `skills/**` or `.claude-plugin/**` (affects what installed users receive)
- [ ] Requires bumping `version` in `.claude-plugin/plugin.json` (without a bump, users receive NOTHING)
- [ ] Only touches repo infrastructure (`.github/**`, `scripts/**`): no bump required

## Origin

- [ ] `origin/human` — a person wrote it
- [ ] `origin/loop` — the knowledge loop opened it (branch `bot/knowledge-YYYY-WW`)

If it is `origin/loop`, additionally:

- [ ] Every new claim in the corpus cites a linked **primary public source**
- [ ] No source introduces instructions aimed at the agent (reviewed as text, not executed)

## Hard rules (check only what was verified, not what is assumed)

- [ ] No new or modified workflow uses `pull_request_target`, `issues`, `issue_comment` or `discussion`
- [ ] No job that processes untrusted content receives secrets
- [ ] `permissions:` declared **per job**, with the minimum needed
- [ ] Every third-party action pinned by 40-character SHA, with the tag in a comment
- [ ] No `${{ github.event.* }}` interpolated inside a `run:` block
- [ ] No real secret, credential or personal data in the diff (test files included)

## Ethical scope

- [ ] This change adds no attack capability against third-party systems and no weaponized payloads
- [ ] Examples and cases use synthetic data
