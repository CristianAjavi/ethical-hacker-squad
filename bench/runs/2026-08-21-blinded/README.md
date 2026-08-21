# Run 2026-08-21 — first blinded run

The first measured detection numbers this project has, and the first any product in its competitive set publishes at all.

## Result

| | |
|---|---|
| Planted defects detected | **10 / 10** |
| Decoys reported | **0 / 11** |
| Unlabelled findings | 0 |
| Statuses | 5 `confirmed`, 5 `probable`, each `probable` naming its inferred link |

`score.txt` is the full output; `score.json` the machine copy.

## How it was run

Two specialists, in **fresh contexts**, each pointed at a copy of one case in a scratch directory that contained the case and the reference material **and nothing else** — no repository, no answer key, no path that reaches one. Their instructions were the fallback dispatch from `references/team.md`: the pack, the triage rules, the artifact contract, the safety contract, and the return format. Neither agent was told how many defects existed, nor that decoys existed at all beyond one sentence saying the target contains both real defects and constructs that resist.

Each emitted `findings.json`, which was validated with `gate-findings-artifact.sh --deliverable` **before** scoring. Both conformed on the first attempt.

## What was corrected after the run, and why it does not launder the result

Two defects were found in the scoring machinery by this run, and both were fixed afterwards. Saying so is the difference between a measurement and a press release.

1. **The scorer matched prose, not location.** Its first output was 4 detections and *six decoys reported*. Reading them showed the cause: a finding that contrasts the defect with the control next to it mentions both symbols, and the scorer matched any mention. It now matches on `location.line` inside the item's span, and falls back to the finding's **title** — what a finding is about — never its evidence or impact. The change is structural and the self-test has a case for it; nothing in it was tuned to these five findings.
2. **The key named one location for a defect that spans two files.** The SSRF lives in the route that accepts the URL and in the helper that fetches it. The squad reported it at the helper; the key named the route, and scored a correct finding as a miss. Items may now carry `also_at`, checked by the integrity gate like any other location.

The audited artifacts were **not** touched. They are in this directory exactly as the two agents wrote them, and they can be re-scored against any future version of the key.

## What this number is and is not

It is **recall on this bench**: ten defects a project planted in code it wrote, found by specialists reading procedures the same project wrote. It shows the routing works and the patterns match code shaped like this. It is **not** a detection rate on code nobody here has seen, and nothing in this repository will claim it is.

The number that resists that objection is the other one: **0 of 11 decoys**. Every decoy is a construct built to look exactly like the defect beside it — the scoped queryset, the escaped sink, the allowlist checked after parsing, `extractall(filter="data")`, `mkstemp`, `gpg --`, `0600`-in-`0700`. Reporting one costs a client a day and costs us the finding's credibility. Both specialists rejected all of them and wrote *why* into `ruled_out`, citing the triage rule that settled it.

Two honest caveats on the composition: `local-app` findings came back mostly `probable` rather than `confirmed`, because the CLI case has a single dispatch branch and most functions have no observed call site — the specialist named that gap in `inference` instead of promoting the finding, which is the behaviour the vocabulary is for. And the bench exercises two packs of eight; it is **silent** about the other six, not clean.
