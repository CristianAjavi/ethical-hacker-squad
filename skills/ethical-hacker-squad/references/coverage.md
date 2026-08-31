# Coverage — when a file is done

`triage.md` decides whether a finding is real. This file decides when you have finished
looking, which is a different question and the one this corpus measurably got wrong.

## The measurement that produced this file

On 2026-08-26 this corpus and `google/mantis` audited the same eleven vibecoded products, 54
planted defects, four runs each ([`bench/runs/2026-08-26-eleven-products/`](../../../bench/runs/2026-08-26-eleven-products/)).
It lost by 8.3 points of recall, and the loss decomposes:

| | this corpus | `mantis` |
|---|---|---|
| reach — union over 4 runs | 49 / 54 | 52 / 54 |
| reported in an average run | 43 | 47.5 |
| **dropped per run from inside its own reach** | **6.0** | 4.5 |

Only **three** defects were outside this corpus's reach entirely. The rest of the gap was
finding something and stopping. On the 14 files carrying more than one planted defect —
**34 of the 54** — this corpus reported **2.05 findings per file against 2.50**, and reached
two or more findings in **8.8 of 14 files against 11.5**.

It was worst where the defects are densest and least code-like:

| file | planted | this corpus | `mantis` |
|---|---|---|---|
| `node-supply/package.json` | 2 | **1.0** | 3.2 |
| `terraform-platform/.github/workflows/deploy.yml` | 2 | **2.0** | 3.0 |
| `rag-agent/agent/memory.py` | 2 | **1.8** | 2.5 |
| `cli-packer/packer.py` | 5 | 4.5 | 4.8 |

A long Python file gets worked through. A twenty-line manifest gets read, yields its one
obvious problem, and is closed.

## COV-01 A file that produced a finding is not a file that is done

After reporting a finding, **return to the same file and ask what else is in it.** The
instinct that a file has been "handled" once it has yielded something is the single largest
measured source of missed defects in this corpus.

## COV-02 Manifests and configuration are enumerated, not read

`package.json`, `pyproject.toml`, `*.tf`, `*.yml`, `Dockerfile`, `settings.py`, `.env*`: go
**key by key**, and say what each key does or does not do. These files pack several
independent defects into a few lines — an install hook *and* a wildcard version *and* a
registry override — and none of them is visible to a reading that stops at the first one.

Reading a manifest top to bottom for "the problem" is the failure this rule names. There is
usually more than one, and they do not look alike.

## COV-03 Declare the density you found, per file

In the coverage declaration, for every file you reported anything in, state **how many
distinct defects you looked for and how many you found**. A file with one finding and no
statement that you went back is indistinguishable, to a reader, from a file you gave up on.

## What this file does not say

It does not say to report more. Padding a report with weak findings is the defect
`triage.md` exists to prevent, and this corpus's decoy rate — **0.25 per run against
`mantis`'s 1.00** — is the one number it led on in that round and is not to be traded away.

**Look again; report only what survives triage.** Both, not either.
