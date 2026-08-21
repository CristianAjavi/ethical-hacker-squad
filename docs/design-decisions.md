# Design decisions

The non-obvious choices, with the reasoning and the cost. Written so a future maintainer can overturn one on evidence rather than rediscover why it was made.

## Status: what exists today

The corpus, the plugin and this documentation exist on `main`. **The automation that enforces the rules described in `docs/gate-requirements.md`, `docs/knowledge-loop.md` and `docs/release-channels.md` is being built and has not landed yet.** There is no `stable` branch, no tagged release, and no CI.

Those documents are written in the present tense because they are specifications — the contract the machinery is built to satisfy. Read them as design until the first `stable` release exists. This note is here because a security repository that describes controls it does not yet run is committing the exact error its own corpus teaches readers to detect, and a disclaimer buried in one file is not enough.

## 1. Ship subagents in the plugin, rather than injecting role prompts from the leader

**Decision:** publish eight subagents under `agents/`.

**Alternative considered:** keep the original design, where the leader spawns `general-purpose` agents and copies the role order, the coverage rows and the safety contract into each prompt. That is simpler, has no plugin-schema dependency, and works identically whether the skill is installed as a plugin or copied into a skills directory.

**Why the subagents won.** The deciding argument is not convenience, it is enforcement. A subagent definition declares its `tools`, and the harness applies that list. Auditors declared without `Edit` and `Write` cannot call them. Under the injection approach, "do not edit any file" is a sentence in a prompt — the same category of control as asking a model nicely, and this repository's own AI-safety pack documents at length why that category fails under adversarial input. Auditing untrusted repositories is precisely where a prompt-level restriction is most likely to be subverted.

Second argument: the safety contract travels with the agent. A subagent inherits neither the skill nor the leader's context, so under the injection approach every constraint depends on the leader remembering to copy it into every prompt, every time. One forgotten paragraph and a specialist operates without its contract. Baking it into the definition makes that failure impossible rather than unlikely.

**The cost, stated plainly.** Subagents ship only through the plugin install path. A user who copies the skill into `~/.claude/skills/` gets none of them, which is why `SKILL.md` documents an explicit fallback. Eight agents also appear in the user's agent roster, which is visible clutter, and each carries a `description` that makes it auto-invocable outside the squad — a specialist could be summoned without the leader's inventory and scope. That is a real downside; it is accepted because a specialist reading its own pack and refusing to act outside its contract still behaves safely on its own.

**What would overturn this:** if tool restrictions on plugin subagents turned out to be advisory rather than enforced, the enforcement argument collapses and the simpler injection design wins.

## 2. Cite identifiers, never text — and cite only at the granularity actually verified

**Decision:** no third-party text anywhere in the corpus. Identifiers, versions and test names only. Where an individual test ID could not be confirmed at the source, cite the category with a wildcard (`WSTG-ATHN-*`) or the chapter (`ASVS 5.0 V6`).

**Why.** Two separate reasons that happen to point the same way. Legally, OWASP is CC BY-SA: reproducing its wording forces the derivative under ShareAlike and is incompatible with MIT. CIS Controls are no-derivatives; the semgrep ruleset forbids redistribution. Copying would quietly make this repository's licence a lie.

Epistemically, a fabricated identifier is worse than a missing one. It survives review by looking correct, and a reader who checks it against the standard finds a mismatch and loses trust in everything else. A wildcard is honest about what was verified, and it degrades gracefully: `WSTG-ATHN-*` stays true across editions, while a specific test number may not.

**The cost:** the traceability matrix is coarser than it could be, and cannot say "this procedure implements exactly this test". Coarse and true beats precise and invented.

## 3. Two channels, and no `version` field in `plugin.json`

**Decision:** `main` is `latest` and resolves to the commit SHA; `stable` carries a semver in the marketplace entry.

**Why.** Version resolves as `plugin.json`, then the marketplace entry, then the commit SHA. The original manifest hardcoded `"version": "1.0.0"`, which meant every future commit resolved to the same version and therefore delivered nothing to anyone who had already installed the plugin. The corpus could have been corrected weekly with no user ever receiving it. Removing the field is what makes `latest` actually update, and keeping the semver in exactly one place avoids the documented trap where declaring it in both files lets `plugin.json` win silently.

Two channels rather than one because the audiences differ: someone auditing their own project wants corrections immediately, and someone embedding this in a review process wants a snapshot that rested. Both channels must resolve to *different* versions or the client treats them as the same plugin, which a rolling SHA against a semver satisfies by construction.

**The cost:** two branches to keep in sync, and `latest` users are effectively the test population for `stable`. That is stated in `docs/release-channels.md` rather than hidden.

## 4. Automated promotion with a rest period, instead of human review

**Decision:** promotion to `stable` runs without waiting for a person, gated by deterministic checks, an independent verifier agent with no web access, and roughly seven days of elapsed time.

**Why.** A maintenance model that requires a human to be available fails the first busy week and then decays. The rest period converts calendar time into review: it is the window in which someone using `latest` hits a wrong procedure and opens an issue. The verifier has no network access on purpose — it cannot be influenced by the same poisoned page that influenced the researcher.

**The cost, unvarnished:** a plausible, well-cited, correctly formatted, *wrong* procedure will reach users. Nothing in the pipeline catches that class. The system converges on correctness through use — via the `false-positive` and `false-negative` issue types and the closure rule — rather than guaranteeing it before release. Anyone needing a pre-release guarantee should pin to a `sha`.

## 5. `false-positive` and `false-negative` as first-class issue types

**Decision:** the two primary issue types are audit-quality errors, not crashes.

**Why.** A crash is obvious, cheap to reproduce and gets reported anyway. The failure that actually costs a user is a confident report about something unexploitable, or a real finding walked past in silence. Naming those as the primary types tells contributors what this project considers a defect, and it makes the closure rule enforceable: a false positive means a procedure's pattern is too broad or its false-positive criteria are missing a compensating control, which is a concrete, fixable, testable thing.

## 6. Prose that repeats a number needs a check watching it

**Decision:** every declared count, threshold and protected-path list has exactly one authoritative home, and a gate verifies the derived copies.

**Why.** During construction, the procedure count was written as 137 in two files when the real number was 122, and the protected-path list was enumerated in three places and had already diverged before the first release. Both are the same failure: a fact restated by hand drifts, and the copy is usually the one someone trusts. Where duplication cannot be removed, `G3b` measures it.

**Deliberate exception:** the eight agent definitions repeat the safety contract and the return format. That is not drift — a subagent inherits nothing, so the repetition is what makes each one safe alone. It is duplication with a reason, and the reason is written down here so nobody "cleans it up".

## 7. Keep the plugin at the repository root; do not split it into a `plugin/` subdirectory

**Decision:** discard the proposed move of the plugin into a `plugin/` subdirectory addressed by a `git-subdir` source.

**The concern was real.** Installing a marketplace copies it to `~/.claude/plugins/marketplaces/<name>/`, and this repository *is* its own marketplace with the plugin at `./`. So the maintenance machinery - `.github/`, `scripts/`, `docs/` - lands on the disk of everyone who installs the plugin, even though it is inert for them.

**Measured, rather than assumed.** `git-subdir` exists and is real: the official marketplace uses it with `url`, `path`, `ref` and `sha` to point at plugins living inside *other* organisations' repositories. But for its own plugins it uses plain relative sources, and its cache directory contains `LICENSE` and `README.md` at the root - repository files that belong to no plugin. The marketplace clone is repository-wide regardless of how individual plugin sources are addressed.

So the move would not achieve its goal. `git-subdir` would only help if the marketplace lived in a *different* repository pointing at this one by subdirectory - a two-repository split, which is a large permanent cost for roughly 190 KB of inert text.

**What actually bounds the cost** is the served-tree budget in `gate-plugin-integrity.sh`, which is enforced per commit, and the per-file 32 KiB budget, which is what any single agent has to read. Both stay.

**What would overturn this:** evidence that Claude Code performs a sparse checkout of only the plugin path when the marketplace and the plugin share a repository. The cache observed here shows it does not.

## 8. Uncommitted work in an ephemeral directory is not work

**Decision:** every agent working on a branch commits its own unit of work, and integration branches live under a persistent path, never in a scratch directory.

**Why, and it cost something to learn.** The governance branch was rebuilt in a scratch worktree with instructions not to commit, so that the merge could land as one reviewable change. The directory was pruned automatically mid-flight and 87 of 97 files reverted. The ten survivors were simply the most recently written.

The intent - an atomic, reviewable merge - was reasonable. The mechanism was wrong: reviewability is achieved by squashing or by review, not by leaving work unwritten. Holding an hour of work in a prunable path converts a tidiness preference into a data-loss risk, and the risk is invisible until it fires.

**The rule now:** agents commit their own scope as they finish it; the maintainer composes the merge afterwards from commits that exist.
