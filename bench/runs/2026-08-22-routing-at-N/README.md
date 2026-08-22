# Run 2026-08-22 — whole repositories: 0/3 for both arms, and both missed by nine lines

> # RETRACTED — the targets were already patched
>
> **This round measured both arms against code from which the defects had already been removed.** The targets were cloned with `git clone --depth 1` of the default branch, which is *after* each fix commit. `cases-picked.json` records a `parent` field for exactly this reason — the pre-fix commit — and it was ignored.
>
> Verified in the cloned tree: `openapi3filter/req_resp_decoder.go` carries `maxSliceMapToSliceGap = 10000` (line 980) and the bound at line 1006, which **is** the fix for `GHSA-xhj3-7xw9-vr34`; and `validation_error_encoder.go:127` handles `e.Parameter == nil` explicitly, which is the fix for `GHSA-mmfr-pmjx-hw9w`.
>
> **Every number below is void.** 0/3 against absent defects measures nothing. The conclusions drawn from it — including the change to this repository's published headline — are withdrawn with it.
>
> **How it was caught, and it matters:** a later run, following this corpus's own rule that a refutation must name the line of the control, wrote in its `ruled_out` section that `sliceMapToSlice` *"rejects the input when `max + 1 - len(m) > maxSliceMapToSliceGap` (10000, declared at line 980)"*. Had that arm merely stayed silent about the function, this error would have shipped as a result. The rule that a dismissal must cite its control is what turned a silent non-finding into a caught mistake.
>
> The round is re-run against the parent commits in `../2026-08-22-routing-at-N-2/`. Nothing below is edited; it is left standing as the record of the error.


`PREREGISTRATION.md` was committed before any arm ran, with targets picked by a published rule before the prediction was written. It predicted **both arms at or below 1 of 3, with a gap of one advisory or less** — that the dimension is hard for everyone — and named what would refute that.

**Measured: 0/3 and 0/3. Gap zero. The prediction holds.**

| Advisory | repository | with the corpus | without it |
|---|---|---|---|
| `GHSA-xhj3-7xw9-vr34` — largest-index preallocation in `deepObject` decoding | `getkin/kin-openapi` | no | no |
| `GHSA-mmfr-pmjx-hw9w` — nil deref in `ConvertErrors` on malformed multipart | `getkin/kin-openapi` | no | no |
| `GHSA-26w5-6g95-gj28` — path traversal in workspace handling | `runatlantis/atlantis` | no | no |

Whole repositories, no pointer: 293 and 450 Go files, no arm told a module, a file, or that anything was wrong. Both arms carried the outside-information policy **identically** — the first whole-repository round in this bench where they did. Scoring blind, one judge per repository, seeing findings with opaque ids and no arm label.

## The near-miss is the finding

`GHSA-xhj3-7xw9-vr34` lives in `sliceMapToSlice`, at `openapi3filter/req_resp_decoder.go:936`: a `deepObject` array parameter is rebuilt by reading the **largest attacker-supplied index** and allocating a slot for every position up to it, before `maxItems` validation runs. Twenty-four bytes of request, about six gigabytes of heap.

**Both arms reported an unchecked type assertion in `deepSet`, at line 945.** Nine lines away, same function neighbourhood, same decode path, same untrusted input — and a different defect. Neither list mentions `sliceMapToSlice` anywhere.

That is not a routing failure. Both arms routed to the right file, read it, and found a real bug in it. What neither did was enumerate *the other ways that same code can be driven*, which is what the advisory required.

The same shape repeats on the second advisory: both arms found a panic on the error-rendering path (`SchemaError.Error()`, a YAML-derived map that will not JSON-encode) and neither touched `validation_error_encoder.go`, where the published nil-deref lives.

## What this changes about what this repository publishes

Whole-repository evidence is now **six advisories** rather than three:

| | corpus | unaided |
|---|---|---|
| earlier rounds (3 advisories) | 0/3 | 1/3 |
| this round (3 advisories) | 0/3 | 0/3 |
| **total** | **0 / 6** | **1 / 6** |

The pre-registration said what this outcome forces, and it is done: the published statement stops being *this corpus does not lead* and becomes **the task is not solved by anyone**. Two methods, six published advisories, six hundred files per target, and one hit between them — which is itself inside this bench's stated resolution and says nothing about which method is better.

**No product in this field should claim whole-repository detection without publishing a number, and as of the survey in `../2026-08-21-field-transparency/`, four of five publish none.**

## What both arms did produce, since the score does not show it

Both independently found the same real defect that no advisory names: `GET /api/locks` in Atlantis reaches `ListLocks` with no `RequireAuth` and no `APISecret` check, while every sibling handler on the same controller has one, and the basic-auth middleware exempts the whole `/api/` prefix. It returns repository names, project paths, PR numbers and the usernames holding each lock. Two independent reviews converging on it is worth more than either alone.

The corpus arm added a `--var-file` allowlist bypass — the checker matches only the single-dash spelling, while the repo's own blocked-args list covers both spellings of two other flags, which is the maintainers' own statement that the double-dash form reaches the CLI. It is filed `probable` with the inference named, because no Go toolchain existed on the host.

## What this round does not establish

- **Three advisories over two repositories**, two of which share a repository, so effective independence is closer to two. Declared in the pre-registration rather than fixed by re-picking.
- One model, one run per arm per repository. No run died, which is unusual for this bench and worth recording.
- **Neither arm could execute anything** — no Go toolchain on the host. Every claim on both sides is read from code, and both arms said so.
- A 0/6-versus-1/6 difference is one advisory. It is inside the resolution and is **not** evidence that either method is better.

## Files

`PREREGISTRATION.md` is what was committed first. `cases-picked.json` is the rule's output, population 30, rejected 0. `judging/` holds the four blinded batches exactly as the judges received them and their verdicts with quotations.
