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
anything, and all ten now carry a probe:

| case | defects | cross-check |
|---|---|---|
| `cli-packer` | 5 | four patches, so both halves run |
| `analytics-service` | 3 | no patch ships, so only the unpatched half |
| `rag-agent` | 2 | no patch ships, so only the unpatched half |

The other 33 need `anthropic`, `sqlalchemy`, `marshmallow` or `flask_restful`, or are not
Python at all — 6 JavaScript, 4 Terraform, 4 YAML, 5 JSON, 2 Go, 2 Java.

**A green here is ten defects proved, not a bench reproduced.** Fourteen measurements: ten
probes on the unpatched cases, four on the patched variants.

## Not every probe proves the same thing

Counting ten as if they were interchangeable would be inflating the number, so each probe
declares what kind of evidence it offers:

- **exploit** — a file lands outside its destination, a planted binary runs. The strongest.
  All five in `cli-packer`.
- **exposure** — a specific value that should not have left the process arrives where it
  should not be: a national id in a response body, an email in a log line, model output
  read back out of a store. `P-24`, `P-29`, `P-30`.
- **absent control** — nothing records where a document came from, nothing consults consent
  before third-party tags render. `P-28`, `P-32`.

An absence is the weakest evidence a probe can offer, because *nothing happened* is also
what a broken probe looks like. So no absence is asserted alone: **every probe outside
`cli-packer` also runs the safe sibling the case ships beside the defect**, and reports a
finding only if the two differ. A property that also holds of the hardened function is a
property of the harness, and the probe says that rather than claiming a defect.

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

## Where a probe runs

A probe sets `PATH`, changes the umask and chdirs. Run inside the harness, a probe that
died halfway left the harness holding whatever it had changed. So probes run in a child
process, and where the machine allows it, in a sandbox.

| environment | what it gives | available here |
|---|---|---|
| `inprocess` | nothing; fastest | always, and below the declared floor |
| `subprocess` | the probe's damage dies with the child, plus CPU, address-space and file-size limits | wherever python3 runs |
| `seatbelt` | the same, with the network denied through `sandbox-exec` | macOS only |

`key.json` declares `minimum_isolation`, and a run weaker than it answers **2**. Falling
back quietly to a weaker sandbox and returning 0 would be an unmeasured run wearing a
green, which is the one thing this project's exit codes exist to prevent.

The sandbox is not taken on trust. `scripts/bench/selftest_isolation.py` runs the same
socket open in both environments and the battery requires the unsandboxed one to succeed
and the sandboxed one to fail — measured, because a sandbox that leaks and a sandbox
nobody exercised look identical from outside. On a machine with no `sandbox-exec` that
case reports a skip and is not counted as a pass.

### What the neighbouring product has here, measured

Four backends, of which exactly one runs on this machine. `gce_env.py` (606 lines) wants a
Google Cloud account, `gvisor_env.py` (321) wants Docker and `runsc` — Linux only — and
`microsandbox_env.py` (234) wants the `msb` binary. None of the three is present. The one
that runs is `static_env.py`: 145 lines that import `os` and isolate nothing.

That is the honest shape of the comparison. On infrastructure they are ahead and it is not
close — a cloud VM per run is a capability this has no answer to. On what can actually be
executed on a developer's machine, a denied network beats no isolation at all.

## Safety

Probes run against fixture code this repository owns, offline, in a temporary directory
the harness creates and removes. Nothing is written outside it, and no real `gpg` or
`uploader` is ever invoked — a recorder on `PATH` answers what argv the case *built*,
which is the question, without running anything that signs or uploads.

Running probes against code this project does **not** own is a separate decision, and not
an infrastructure one: it changes what the engagement rules permit. Building the isolation
did not require it, and taking it is not implied by having built this.

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
