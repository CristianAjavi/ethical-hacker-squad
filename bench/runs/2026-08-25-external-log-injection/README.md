# 2026-08-25 — a published advisory, on code nobody here wrote


> **Scoring note, added 2026-08-26.** The reports in this directory were transcribed by the
> orchestrator from what each arm returned, not written by the arms themselves, so they carry
> no provenance block. `scripts/bench/score_blind.py` now refuses to score an untraced report
> by default; reproducing this round's numbers needs `--allow-untraced`. That flag is not a
> convenience — it is the record that these particular artefacts passed through a person's
> hands, and the reason it exists is on the scorer's own page.

**The prediction is refuted.** `WEB-28`, the `CWE-117` procedure this project added the same
day, did not survive contact with a 569-file repository. Nobody found the defect — not this
corpus, not either competitor.

## What was measured

`pyload/pyload` at `6c52b198d`, the parent of its own fix commit `ddf8a48`. The key is
public: one file, `Api.add_package`, escaping `\n` and `\r` before the package name reaches
`log.info`. Advisory `GHSA-3wwm-hjv7-23r3`. **Nobody here wrote this defect.**

| arm | runs | reported the advisory | total claims | empty runs |
|---|---|---|---|---|
| this corpus | 4 | **0 / 4** | 25 | 0 |
| `Tencent/AI-Infra-Guard` @ `32df94d` | 4 | **0 / 4** | 8 | 0 |
| `google/mantis` @ `56377ad` | 4 | **0 / 4** | 3 | 3 |

## What this forces, in the words the pre-registration chose

> **The corpus arm reports it in zero of four.** `WEB-28` does not survive contact with a
> 569-file repository, and the ledger records that the procedure added for this class has no
> measured effect outside the case this project planted.

So that is what the ledger records. On the one class this project spent the day claiming as
its own — a defect written in the shape of its own remediation — **it does not lead, and it
does not even find the instance somebody else already published.**

The `intake-portal` numbers do not transfer. On a 17-file tree this corpus reported the
concatenated half of the pair in 6 of 6 runs. On 569 files it reported neither half, in any
run. Whatever `WEB-28` does, it does not do it at the scale a real audit works at.

## What the round does not say

**Nothing here ranks the three products.** This corpus produced 25 claims against 8 and 3,
and was the only arm with no empty run — that is engagement, not detection, and the
pre-registration does not license reading it as anything else. `mantis` returned an empty
array in 3 of its 4 runs; a product that reports nothing has perfect precision and no
recall, which is why claim counts are printed and never used as a score.

One competitor finding is worth recording precisely because it cuts against this project's
story. `AI-Infra-Guard` reported that `UnTar.py`'s guard against `CVE-2007-4559` is
**broken** — it uses `os.path.commonprefix` on raw strings rather than a real path-boundary
check — and says it verified the bypass with a proof of concept. That is exactly *a control
that runs and cannot fail*, in real code, found by a competitor. This corpus's fourth run
reported it too. The class this project named is not one it has to itself.

## Why the answer is what it is

This is the fourth round in three days pointed at whether this corpus is the best for code
a model wrote, and it is the first on code nobody here planted. It says no.

The rounds that said something favourable — 1.00 on the hiding class, 0.83 recall — were
all on `intake-portal`, written here, and each of those pages says in its own words that a
pass there is weak evidence. This page is what the strong evidence looks like, and it points
the other way.

## What ships

Every report from all twelve runs is in `runs/`. The key is a public commit anyone can
check out and diff. The target was copied out of the repository with `.git` absent, so no
history was reachable from it.
