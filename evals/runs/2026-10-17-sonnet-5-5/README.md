# Run 2026-10-17 — Sonnet 5.5, plugin at 77792b5

| | |
|---|---|
| Plugin under test | the integration branch of the 2026-10-15 review (#132) at `77792b5`: every procedure of #125, the quick mode of #130, the shell guard of #134 |
| Agent model / judge | `claude-sonnet-5-5` / `claude-sonnet-5-5` |
| Claude Code | 2.1.302, macOS, eval sandbox on |
| Runs | 3 per arm, with and without the plugin, `-j 3` |
| Cost | list-price estimate USD 2.61 for the whole suite (a Max subscription is not billed per token; this is the tool's measure of volume), 313 s |
| Result file | [`aggregate-result.json`](aggregate-result.json), machine paths replaced |

## What it says

| Case | With the plugin | Model alone | Δ | Cost per run, with / without |
|---|---|---|---|---|
| `full-audit` | 1.00 | 1.00 | **0.00** | USD 0.246 / 0.200 (+23%), 77 s / 64 s |
| `launch-check` | 0.94 | 0.94 | **0.00** | USD 0.223 / 0.189 (+18%), 67 s / 68 s |
| `security-review-builtin` | — | — | — | **not measured** (see below) |

**On this app the plugin adds nothing measurable to Sonnet 5.5, and costs about a fifth more.** The model alone found all nine planted defects in every `full-audit` run. The one place the arms differ is `d2` — a user who can set their own `role` or `plan` — which the plugin's quick audit named in 3 of 3 runs and the model alone in 1 of 3; that is the defect `WEB-31` was written for. Against it, one plugin run lost the false-alarm grader on two of three judge votes over an 8.8 KB report, which the tool itself flags as a noisy verdict on long input; the report in question does not present any of the three correct controls as a defect on a manual read, but the grader stands as scored.

**What this does not show.** The app was written by the author of the procedures it tests, and its defects are textbook: a model that has read the same documentation finds them unaided. A suite that cannot separate the arms on its target says the target is too easy, not that the arms are equal everywhere. The next step is targets nobody here designed — external repositories with defects labelled by someone else — and a smaller model, where the bench already saw the corpus behave differently.

## Why `/security-review` was not measured

The built-in command opens with a shell injection, `` !`git log --no-decorate origin/HEAD...` ``. Inside the eval sandbox on macOS, `/usr/bin/git` is Apple's `xcrun` shim, which tries to write a cache under `/var/folders` and is denied: the command aborts before the model runs (0 turns, under 20 s, USD 0.002). Putting the real `git` first on `PATH` did not help: the injection runs in the session's own shell environment. Both arms therefore scored only the false-alarm grader (0.18). That number measures the harness, not the command, and it is not reported as a result. The case should run on Linux, where `git` is a plain binary.
