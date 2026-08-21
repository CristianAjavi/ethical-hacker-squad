# Run 2026-08-21 — a second whole repository, and the number that matters is zero

The first whole-repository round ended 0/2 for the corpus against 1/2 for an unaided engineer. One run on two advisories concludes nothing, and the corpus had since gained `WEB-26`, the procedure written from that loss. So the round was repeated on a target chosen by the same published rule, in a new ecosystem, taken in rule order.

**Target:** `Unleash/unleash` at `8b09768` — **6,490 files, 3,954 of them TypeScript**, fourteen times the previous repository. One published advisory: an unauthenticated single-request denial of service through the OpenAPI validation error formatter.

## Result

| | With the corpus | Without it |
|---|---|---|
| `CVE-2026-63462` | **missed** | **missed** |
| findings reported | 13 | 16 |
| blind verdicts | 0 `yes`, 0 `partial`, 29 `no` | |

**Neither arm found it.** Not one of the 29 findings names the formatter, the error middleware, `JSON.stringify` recursion, JSON nesting depth or process termination.

## Both whole-repository rounds together

| | Corpus | No corpus |
|---|---|---|
| round 4 — 461 files, 2 advisories | 0/2 | 1/2 |
| round 5 — 6,490 files, 1 advisory | 0/1 | 0/1 |
| **total** | **0 / 3** | **1 / 3** |

The headline is not the one-advisory gap. It is that **whole-repository recall on a specific published defect is near zero for both methods**. Three advisories, two methods, one hit between them — and this bench's measured resolution is five in fifty-three, so the 1–0 difference is inside the noise and says nothing about which method is better.

What it does say is about the task. On a repository nobody can read in full, finding the one defect a CVE happens to name is close to a lottery: both arms opened 45–50 files out of thousands, both produced substantial and largely accurate findings, and neither landed on the file the advisory was about. Any product claiming otherwise on this task should be asked for its number.

**That is the strongest argument in this whole directory for what the coverage declaration is worth.** If recall against a named defect is near zero, then the thing a reader can actually rely on is knowing what was looked at and what was not. Both arms did that here, and their gaps are specific: the no-corpus arm lost the subagent auditing the data-access layer and says ~50 raw-SQL call sites are unexamined; the corpus arm says object-level authorization across ~100 admin controllers was never exercised, so *the absence of an IDOR finding means nobody looked*.

## An asymmetry I introduced, and it is mine

**The artifact contract changed while this round was in flight.** A new requirement — a `probable` finding must name what would settle it — landed mid-run. The corpus arm reports that the validator began rejecting `probable` with no explanation and that it isolated the behaviour across sixteen variants before the change arrived. That is effort burned by the operator, in one arm and not the other: the no-corpus arm emits a flat schema and never touched the validator.

I was careful not to write procedures during a measured round and then did exactly that with the schema. It does not change the verdicts — both arms missed the advisory — but it is an operator-introduced asymmetry in the arm that lost, and it is recorded here rather than left out.

## What each arm did that the score does not show

**Corpus arm, 13 findings, 4 `confirmed`:** a template injection in a workflow, a hardcoded session signing key whose per-instance replacement is stranded behind an unreachable fallback, a session identifier never rotated at login, and the full user directory readable by any authenticated principal from a route whose ADMIN-gated sibling returns the same list. It treated two delegated sweeps as **pointers, not findings** — every claim was re-read at the cited line, and its two most serious candidates did not survive that check and are written up as refuted.

**No-corpus arm, 16 findings, 3 high:** an unconditional `trust proxy` defeating every brute-force limiter, an unbounded user-supplied regex hanging the event loop, and a stored `javascript:` URL reaching a same-tab href. It dropped the claims of a subagent it could no longer restate rather than passing them on, and flagged two library-behaviour assumptions as unconfirmed because nothing was executed.

Neither of those lists is noise, and none of it is scored, because this bench has a key for one advisory and nothing else.

## Files

`arms/` holds both artifacts. `judgements-deblinded.json` holds all 29 verdicts with their reasons.
