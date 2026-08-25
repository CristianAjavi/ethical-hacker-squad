# Reproduction

Executable proof that a planted defect still happens — not that the code looks wrong,
that the defect **happens**.

## Why this exists

An outside rubric docked a finding of ours in the third-competitor round for carrying no
reproduction evidence, and that round's own note records the deduction as this project's
self-imposed restriction showing up on somebody else's scoreboard. A neighbouring product
ships proofs-of-concept and four sandbox backends to run them in. This is the answer to
that gap, and it is deliberately not a copy of their sandbox.

## What makes it different from running a proof-of-concept

This corpus carries **two independent keys over the same files**:

- `bench/ground-truth.json` says where each defect was planted.
- `bench/patch-truth.json` says what each patch actually achieves — and the patches here
  are deliberately imperfect, so several are declared `not fixed`.

Running the probes across the patched variants therefore checks the patch key, while the
patch key checks the probes. Neither is trusted on its own, and **a product with only one
key cannot run this check at all.** That is the whole argument for building it this way.

Only two outcomes are forced, which is what makes the cross-check machine-checkable
rather than a matter of taste:

| The key says | The probe must |
|---|---|
| unpatched case | reproduce — a probe that does not means the probe **or** the planted key is wrong, and the run names both candidates rather than deciding for the key |
| `not fixed` | still reproduce |
| `verified` | stop reproducing |
| `partially verified` | nothing is forced; `key.json` states in prose which aspect survives |

## What is measured today, and what is not

Of the **43** planted defects in this corpus, **10** are reproducible without installing
anything. Five of those ten live in one file, `bench/cases/cli-packer/packer.py`, and
those five are what ships here. The other 33 need `anthropic`, `sqlalchemy`,
`marshmallow` or `flask_restful`, or are not Python at all — 6 JavaScript, 4 Terraform,
4 YAML, 5 JSON, 2 Go, 2 Java.

**A green here is five defects proved, not a bench reproduced.** Nine measurements: five
probes on the unpatched case, four on the patched variants.

## Two things the probes had to get right

**The traversal form is `./../<marker>` and not `../<marker>`.** `PC-02` rejects only
names that *start* with `..`, so the obvious form would have been blocked by a patch whose
own key calls it `not fixed` — and the probe would have agreed with the wrong answer. The
form also has to survive extraction: the longer `inner/../../` cousins raise
`FileExistsError` while tarfile walks the literal parent directories, which reads as a
refusal rather than as the probe misfiring.

**The gpg probe asks a structural question.** The declared defect is that the path reaches
gpg with no `--` terminator. `PC-03` scrubs dashes out of the path, which stops one
filename while leaving the next caller one dash away from the same defect — which is why
its key says `not fixed`. A probe that only tried a dashed filename would have called it
fixed.

## Safety

Probes run against fixture code this repository owns, offline, in a temporary directory
the harness creates and removes. No network, no installs, nothing written outside that
directory, and no real `gpg` or `uploader` is ever invoked — a recorder on `PATH` answers
what argv the case *built*, which is the question, without running anything that signs or
uploads.

## Running it

```
python3 scripts/bench/reproduce.py            # human summary
python3 scripts/bench/reproduce.py --json     # the observations, stdout only
scripts/gates/gate-reproduction.sh            # the same, as a gate
```

Exit codes are the project's: `0` measured and consistent, `1` measured and contradictory,
`2` could not measure — which is never a pass. That last one is load-bearing here rather
than decorative. CPython made `data` the default tarfile extraction filter in 3.14; on
such an interpreter the traversal is stopped by the runtime and not by the code, so the
probe answers `2` rather than reporting a defect somebody fixed. The harness shipped a
second instance of the same mistake and its own battery caught it: a patch that failed to
apply was recorded as a note and the run still signed a `0`.
