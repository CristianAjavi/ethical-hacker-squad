# Run 2026-08-21 — `WEB-23`, and what a repaired miss is worth

The three-arm run ended in a flat tie, and its shared miss was a configured request-body cap that was declared, assigned from the environment, documented, and read by nothing. `WEB-23` was written from that miss. This directory measures it — and then argues against reading the result as a win.

## Two measurements

**On a fresh construct built for the class** — `bench/cases/gateway-limits`, one blinded specialist, no key in reach:

| | |
|---|---|
| planted instances detected | **2 of 2** — an unread cap on an unauthenticated upload route, and a throttle that reads its configured burst and is registered nowhere |
| decoys reported | **0 of 2** |

The decoys are the part that cost something to build. Both look identical to the finding at the place you first see them — a name that states a bound, in the same `var` block. One is read by a middleware that **is** in the request chain; the other is consumed **by name** through a struct tag, so a symbol search finds no reader while the enforcement is real. The specialist ruled out the first on `FP-01` and the second on `FP-09`, and said in as many words what separated them: *the contrast between a bare variable assigned in `Load()` and a field carrying `env:` tags with a named consumer.* That is the procedure's own exculpation clause doing the work it was written for.

**On the advisory all three arms missed** — the same `new-api` target, the same prompt, the same blind judging protocol, the only difference being that the corpus now contains `WEB-23`:

| | |
|---|---|
| `CVE-2026-64868` | **found**, judged `yes` by a context that saw only the advisory text and the finding text |

The judge's words: it *"names the advisory's three endpoints verbatim, the same unbounded-read mechanism, the same availability-only consequence, and lands on exactly the control whose introduction the advisory calls the patch."*

## Why that second number is weaker than it looks

**The procedure was written from this case.** Finding it again afterwards demonstrates that `WEB-23` encodes what was learned; it does **not** show the class generalises, and anyone reading the two numbers as `3/3 vs 2/3 vs 2/3` would be reading a repaired miss as a competitive result. It is not one. The comparison in `../2026-08-21-three-arm-go/` was run once, blind, with every arm on the same footing, and **that table is not amended by this run** — the tie stands as it was measured.

What would settle it is the next rule-picked advisory of this shape, found blind, by a corpus that already contained the procedure before anyone knew the case existed. That run does not exist yet.

**The bench-case number is the stronger of the two**, and it is still ours: we wrote the case and we wrote the decoys. It shows the procedure survives contact with constructs built to defeat it, which is what a bench can show and no more.

## What this does establish

A gap the field's own products share — three independent methods walked past a declared control nothing enforced, and one of them read the declaration as proof the control was present — is now a written procedure with an exculpation clause, a bench case, two decoys and a measurement. That is the loop this repository claims to run, executed on itself, in public, starting from a loss.

## Files

`findings-gateway-limits.json` and `score-gateway-limits.txt` are the bench-case run. `findings-new-api-second-pass.json` and `judgements-new-api-second-pass.json` are the second pass on the advisory and its blind verdicts.
