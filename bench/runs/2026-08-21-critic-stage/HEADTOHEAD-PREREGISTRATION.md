# Pre-registration — v2 against the competitor at comparable N

**Written before the additional runs.**

## Why this round is needed and why the last one cannot answer it

The blind critic (`VER-09` v2) posted **0% refuted over 6 claims** with 6/6 ground-truth recall. The competitor, `google/mantis`, posted **53% refuted over 17 claims**.

**That is not a comparison, and this project's own round said so**: six claims cannot carry a proportion against seventeen. Publishing "we now beat them on precision" from those numbers would be the same unsupported arithmetic this bench has retracted three times.

The fix is not an argument. It is more runs.

## Method, fixed in advance

- **Six additional v2 runs**, same target, same weak model, same run prompt, same corpus — bringing the pooled v2 claim count to roughly the competitor's 17.
- All v2 claims pooled and blinded together, exactly as the competitor's three runs were pooled.
- **The same verifier prompt, byte for byte.** Two independent adversarial passes.
- Ground-truth recall scored per run by the same blind judge, and reported beside precision. **Precision is never reported alone**; that rule exists because v1 posted better precision than the competitor while deleting true defects.
- The competitor's 53% over 17 claims is **not** re-measured. It stands.

## The prediction

**Prediction: at a pooled claim count of 15 or more, v2's refuted proportion stays below 53%, and pooled ground-truth recall stays at or above 4 of every 6 slots.**

**What refutes it:** a refuted proportion at or above 53%, **or** pooled recall below 4/6, **or** a pooled claim count still under 15 after six runs — in which case the comparison is declared unmeasurable at this N rather than reported.

## What each outcome forces

- **Prediction holds** — then on precision at weak scale, at comparable N, against the strongest published competitor, this corpus is ahead. That claim is **one dimension, one scale, one target, one competitor**, and it must be written that way. It does not touch the eighteen capability measurements where this corpus leads on nothing.
- **Prediction fails** — then the v2 result was a small-N artefact, the competitor keeps the precision lead, and the README says so with the same prominence it currently gives every other loss.

## The threat to validity, stated again because it has not gone away

The critic and the grader are the same kind of instrument: adversarial refutation of a claim against code. An arm that filters itself with the grader's own framing scores better on that grader almost by construction. The competitor's `review` and `critic` stages are the same kind of thing and were measured the same way, so the comparison is fair — but the number measures **how well a product filters its own bad claims**, not truth. Recall travels beside it for exactly that reason.
