# Machinery manual

This document describes **the machinery**, not the product. For what the plugin does,
read the `README.md` at the root. Here you will find what runs on its own, what stops
it, how a version gets promoted, **how to turn everything off** and **how to roll back**.

The rule that orders everything else: this repository distributes **instructions that
Claude Code runs on other people's machines**, and part of the content is born from a
bot that reads the internet. That is, the pipeline is a channel for **indirect prompt
injection**. Everything that follows is written so that text written by a stranger never
reaches execution with permissions.

---

## 1. The exit codes (the doctrine)

Every gate and every script in this repo distinguishes three outcomes:

| Code | Meaning | Consequence |
|---|---|---|
| `0` | **Measured** and correct | Green |
| `1` | **Measured** and FAILING | Red |
| `2` | **COULD NOT MEASURE** (missing tool, missing input, unreadable file) | Red, and reported **separately** |

An `rc=0` can never mean "I did not review it". That is why `2` exists and why it breaks
the build just like `1`: if a check never happened, the honest result is not a pass.
Every gate additionally prints **what it reviewed and what it did not**.

---

## 2. The six workflows

| Workflow | When it runs | What it does | Permissions |
|---|---|---|---|
| `ci.yml` | `push` and `pull_request` to `main`/`stable` | Runs **every** gate. Job `gates` (no external tools) and job `workflow-hardening` (zizmor + actionlint) | `contents: read` per job |
| `issue-closure-gate.yml` | `pull_request` | Requires that closing a false positive/negative comes with the regression that watches it | `contents: read`, `issues: read` |
| `labels-drift.yml` | `schedule` Mondays, `push` to `main`, manual | Compares the declared taxonomy against the labels that exist **on GitHub** | `contents: read` |
| `release.yml` | `schedule` Mondays 06:17 UTC, manual | **The promotion to `stable`**. See section 4 | `contents: write` only in `promote` |
| `scorecard.yml` | `push` to `main`, `schedule` Saturdays | OpenSSF Scorecard. **Measures, does not block** | `security-events: write`, `id-token: write` |
| `supply-chain-audit.yml` | `schedule` Tuesdays, `push` to `main`, manual | zizmor audits that need network and token (impostor-commit, known-vulnerable-actions, stale-action-refs) | `contents: read` |

### Why they are split this way and not merged

- **`ci.yml` carries no token.** It analyzes the content of a PR, which from a fork is
  third-party content. The hard rule "no job that processes untrusted content receives
  secrets" forbids giving it one.
- **`supply-chain-audit.yml` exists because pinning actions by SHA turns off Dependabot
  alerts** (GitHub only alerts on actions using semantic versioning). Those audits need a
  token, so they live in a workflow that **is not triggered by `pull_request`** and is
  therefore unreachable from a fork.
- **`scorecard.yml` is not a gate.** The official action has no threshold input and never
  fails the job over a low score; besides, the aggregate can *go down* for doing things
  right (a check moves from `?` to scorable). Gating on it would be eternal red or a
  threshold that measures nothing.

### Forbidden triggers, in all of them

No workflow uses `pull_request_target`, `issues`, `issue_comment`, `discussion`,
`workflow_run` or `repository_dispatch`. Those are the paths by which text written by a
stranger enters a privileged context. `scripts/gh/tests/validate-workflow.py` checks it
and `scripts/gh/tests/test-workflow-mutations.py` checks that this validator **really
fails** when each one is injected into it.

---

## 3. The gates

They live in `scripts/gates/`. `scripts/gates/run-all.sh` discovers and aggregates them.

| Gate | What it measures | What it does NOT measure |
|---|---|---|
| `gate-workflow-hardening.sh` | Allowed triggers, `permissions: {}` at the root and minimal per job, 40-char SHA pin with a version comment, reads of the `secrets` context in workflows reachable from forks | Template injection in `run:`, YAML/cron syntax - that is the next one |
| `gate-actions-lint.sh` | zizmor + actionlint (+ shellcheck over the `run:` blocks) | Returns `2` if shellcheck is missing: without it, the `run:` blocks are not analyzed |
| `gate-plugin-integrity.sh` | Shape of the served tree (`skills/`, `agents/`, ...): symlinks, extensions, execute bit, size budgets, broken links, frontmatter allowlist | The **semantic content** of the `.md` files. It bounds shape, it does not judge text |
| `gate-plugin-version.sh` | That `latest` OMITS `version` and `stable` declares it; that it is not declared twice; `claude plugin validate --strict` | - |
| `gate-labels-taxonomy.sh` | That the issue forms only apply labels the taxonomy declares, and that the labels consumed by `gate-issue-closure.sh` and `governance.json` **exist** | Whether those labels exist **on GitHub**: that is `labels.sh --check` |
| `gate-issue-closure.sh` | That closing a `type/false-positive` or `type/false-negative` touches a gate, a test or the corpus | That the touched file really contains the case. It prints that as a WARNING |

### How they are discovered (and why it matters)

`run-all.sh` discovers **recursively and without filtering by extension**. A discoverer
that only looks at `gate-*.sh` one level deep makes invisible any gate written in Python
and any gate in a subfolder - and that already happened: a failing `.py` gate next to a
green `.sh` produced `rc=0`. On top of that:

- The list travels through **FD 3**, not stdin, and every gate is launched with
  `</dev/null`. With the list on stdin, the first gate that reads stdin (`cat`, `read`,
  `jq` without a file, `xargs`) swallows the rest and the loop ends early **declaring
  green what it never executed**.
- Explicit accounting: `discovered == executed + declared`. If it does not add up, `2`.
- Whatever cannot be launched is `2`, never a pass by omission.
- **Nothing is skipped silently.** `gate-issue-closure.sh` needs a PR in front of it, so
  outside that context it is declared as *not executed here* (it is run by
  `issue-closure-gate.yml`, and by `run-all.sh --pr-context` as well). A new gate that is
  neither declared nor executable makes `run-all.sh` return `2`: you cannot add a gate and
  have nobody run it without finding out.

```bash
scripts/gates/run-all.sh              # the gates that do not need a PR
scripts/gates/run-all.sh --pr-context # plus the ones that do
scripts/gates/run-all.sh --list       # inventory
scripts/gates/run-all.sh --selftests  # the gates' selftests
```

---

## 4. How promotion to `stable` works

Two channels, and **they have to resolve to different versions** or Claude Code treats
them as the same plugin and does not update:

| Channel | Branch | The version resolves to |
|---|---|---|
| `latest` | `main` | the commit **SHA** (`plugin.json` does **not** declare `version`) |
| `stable` | `stable` | the **semver** that the promotion writes into `plugin.json` |

The user picks the channel when adding the marketplace:

```
/plugin marketplace add CristianAjavi/ethical-hacker-squad          -> latest
/plugin marketplace add CristianAjavi/ethical-hacker-squad@stable   -> stable
```

### The sequence (`release.yml`, three jobs)

1. **`resolve`** (read only). Reads the contract from `scripts/gh/governance.json`,
   picks the candidate commit and computes the version.
2. **`verify`** (read only, no token). Runs **every** gate over the candidate tree.
3. **`promote`** (`contents: write`, the only one). Builds the `stable` tree, passes the
   identity gates and pushes the branch and the tag.

### What has to hold for anything to reach `stable`

- **Real rest.** The candidate is the most recent commit on the `--first-parent` chain of
  `main` that already satisfied `cooldown_days`. `--first-parent` is not cosmetic: `git
  rev-list --before` filters by **commit date**, and that date is chosen by whoever writes
  the commit (`GIT_COMMITTER_DATE`). Without `--first-parent`, a loop PR with a commit
  backdated by 8 days and merged today was promoted with **zero days of real rest**, and
  on top of that its tree only ever lived inside the PR branch: it was never a state of
  `main`. There is also a **hard membership invariant** on that chain, applied to the
  manual trigger too.
- **No open issue with `channel/stable-blocked`.** The block is **deterministic**: issues
  with that label are **counted**. The title and the body of an issue are never read.
- **Every gate green over the candidate tree.** A gate at `2` blocks just like a `1`:
  promoting on top of an incomplete verification is publishing blind.
- **The gates that judge come from `main`, not from the candidate.** The job does two
  checkouts (`tools/` = the tip of `main`, `source/` = the candidate), replaces
  `source/scripts/gates` with the one from `tools/` and checks with `cmp` that the copy is
  byte for byte the one from `main`. If the candidate could supply its own gates, it would
  be approving itself.
- **The version has to go up.** If `plugin.json` is not bumped, users receive nothing even
  though `stable` moved.
- **The `stable` tree is `main`'s.** A gate runs `git diff` between the candidate and the
  built tree, excluding only `plugin.json` and `CHANGELOG.md`; and inside `plugin.json`,
  the only allowed difference is `version`. This is the gate that holds up the whole
  model: it proves the promotion introduced **nothing** that did not go through `main`.
- **`stable` did not move while it was being verified** (TOCTOU guard): the
  `Source-Commit:` trailer seen at the start is compared against the current one, right
  before the push.
- **The push is fast-forward, no `--force`.** The `stable` commit is hung with
  `git commit-tree` off the **previous `stable`**, not off the candidate from `main`. If it
  hung off the candidate, the second release would not descend from the first and the push
  would be rejected as non-fast-forward: promotion would work **exactly once**.

### The contract lives in a single place

`scripts/gh/governance.json`, `promotion` block: `cooldown_days`, `stable_branch`,
`source_branch`, `tag_prefix`, `blocking_issue_labels`, `required_contexts`, `gates_dir`.
`release.yml` **reads** it (it does not duplicate the values) and fails closed if any of
them is empty or absurd. Duplicating them is how they diverged: the file said
`BLOCK_LABEL: channel-stable-block` while the taxonomy declared `channel/stable-blocked`,
and **GitHub silently ignores a label that does not exist**, so the channel brake was
decoration and the query always returned zero.

---

## 5. The labels

**A single authority**: `scripts/gh/labels.sh`. The issue forms, `gate-issue-closure.sh`
and `governance.json` only **reference** names from that list, and
`gate-labels-taxonomy.sh` fails if any of them does not exist.

```bash
scripts/gh/labels.sh --check     # gate: does GitHub match the taxonomy?
scripts/gh/labels.sh --dry-run   # what it would do
scripts/gh/labels.sh --apply     # apply it (requires write permission)
```

`apply-governance.sh` does **not** manage labels: it delegates to this script and folds
its `rc`. There used to be two lists and two scripts creating labels in the same repo,
each one seeing the other's as "undeclared".

---

## 6. How to turn everything off (kill switch)

**Disable the scheduled workflows.** Nothing else is needed: every automatic path runs on
`schedule` or `workflow_dispatch`.

```bash
gh workflow disable release.yml
gh workflow disable labels-drift.yml
gh workflow disable supply-chain-audit.yml
gh workflow disable scorecard.yml
```

With that, `latest` freezes at its current commit and `stable` stays where it is. `ci.yml`
and `issue-closure-gate.yml` can stay on: they only measure, they do not publish.

**To freeze only the `stable` channel, without touching anything else:** open an issue
with the `channel/stable-blocked` label. The next run reads it from `governance.json` and
does not promote while it stays open. It is the reversible lever, and it needs no special
permissions.

**To stop a run in progress:** `gh run cancel <run-id>`.

---

## 7. How to roll back

### A bad release on `stable`

Move `stable` back to the commit of the previous release. The marketplace will resolve the
old semver and `stable` users return to the previous snapshot on their next refresh;
`latest` users never notice.

```bash
git fetch origin
git push --force-with-lease=stable:$(git rev-parse origin/stable) \
         origin <PREVIOUS-GOOD-SHA>:refs/heads/stable
```

- `--force-with-lease` and not `--force`: if someone moved `stable` between your `fetch`
  and your `push`, the command refuses instead of deleting their work.
- The previous good SHA comes from `git log --oneline origin/stable` or from the tag of the
  previous release: `git rev-list -n1 ethical-hacker-squad--vX.Y.Z`.
- **A person has to run it, not the workflow.** The Actions `GITHUB_TOKEN` has `write` but
  is not an administrator, and `stable` is designed with `allow_force_pushes=false`. A bot
  able to rewrite the channel users consume would be a backdoor, not a convenience.
- **The tag is not deleted.** A published tag is a historical fact; if that version was
  bad, a new one is cut, the old one is not rewritten.

**Alternative without rewriting history** (preferable if people are already on that
version): revert the content on `main`, bump the version, and let the next promotion move
forward.

### A bad change on `latest`

`latest` is `main`. You revert it with a normal `git revert` and a PR. There is no rest
window protecting `latest`: **that is the deal for this channel** - whoever wants rest uses
`stable`, and whoever wants a full guarantee pins to a `sha`.

### The whole integration

This branch is additive over `main`: it only adds `.github/**`, `scripts/gates/**` and
`scripts/gh/**`. Rolling back means reverting the merge commit.

---

## 8. The test bench

The gates are tested too. `scripts/gh/tests/run-all.sh` runs 8 suites:

```bash
scripts/gh/tests/run-all.sh
```

All of them are hermetic: the GitHub API and the `gh` binary are replaced by doubles and
the git history is fabricated with backdated commits. **Zero network**, unless you export
`GOV_TESTS_NETWORK=1`.

The suites are **negative**: they do not ask "do the gates pass?" but "can this gate say
green without having looked?". `test-workflow-mutations.py` breaks the real workflow in 17
different ways and requires the validator to return `1` on all 17; if any one stops being
detected, the validator is worthless and the suite goes red.

The runner keeps its list of suites by hand, because the title it prints is what names a
red one — but it also **counts**: a `test-*` file sitting in that directory that no line
invokes makes the runner exit `2` and prints its name. A suite that runs nowhere is not a
test, and this repository has now found that shape twice.

### `merge-preview.sh` — the combination CI never judges

CI judges every pull request against `main` and can judge no combination of them, because
no single branch carries both halves of one. That gap is not theoretical: one branch added
a self-test battery that enumerated the eight files a gate reads, another split one of
those files in two, **each was green on its own**, and merged the gate asked for a file the
battery did not copy — twelve cases back as "could not measure", on a tree where nothing
was wrong.

```bash
scripts/gh/merge-preview.sh                 # every open PR, oldest first
scripts/gh/merge-preview.sh --union br1 br2 # keep both sides on a conflict
scripts/gh/merge-preview.sh --list          # print the plan and measure nothing
```

It merges into a throwaway worktree and touches nothing. A conflict is **reported and the
branch skipped**, never resolved by guesswork; `--union` retries with git's own union
resolution, which keeps both sides of every conflicting hunk — right for a table two
branches each append a row to, wrong for a real disagreement, which is why it is opt-in and
prints every file it touched that way.

`gate-tree-delta.sh` is skipped **by name and printed as skipped**: over a combined merge
its delta is the sum of every branch's growth, a number nobody will ever ship, because pull
requests land one at a time and the base moves under each.

---

## 9. What this machinery does NOT guarantee

Said out loud, because pretending otherwise would be worse than not having it:

- **A plausible procedure, well cited, well formatted and simply wrong, reaches users.**
  The gates bound shape, not truth. That class of error is collected through the
  `type/false-positive` and `type/false-negative` issues, and closed with the regression
  that watches it. The system **converges through use**; it does not guarantee correctness
  before publishing. Whoever needs an up-front guarantee should pin to a `sha` and review
  it.
- **There is no applied branch protection.** `scripts/gh/apply-governance.sh` describes and
  compares it, but until it is run with `--apply`, the gates are **advisory**: they have to
  be marked as *required checks* to block a merge.
- **The tags are annotated, not signed.** Signing them would mean handing a private key to
  an automated job, which is a worse risk than the signature provides.
- **No workflow has ever run on GitHub.** Everything above is measured locally. The first
  CI run will confirm it or disprove it.
- **The knowledge loop does not exist yet.** There is no bot workflow and no
  `bot/knowledge-YYYY-WW` branches. Therefore `gate-bot-diff-allowlist.sh` is missing, the
  control that will stop a bot PR from touching `.github/**`, `scripts/**` or
  `.claude-plugin/**` - that is, from editing its own judge and turning an indirect
  injection into persistence. **It must land in the same change as the bot, not before**: a
  gate with no subject cannot be tested.
- **`release.yml` does not check the candidate's check runs through the API.** It trusts
  that the gates are re-run over the tree (which is the stronger evidence), but it does not
  verify that CI **ran at the time** nor that the `github-actions` app (id 15368) reported
  it. `governance.json` already declares `required_contexts` for when that gets wired.
