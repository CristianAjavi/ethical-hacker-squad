# Run 2026-08-21 — the weak unaided arm's 5/6 was mostly noise

`PREREGISTRATION.md` was committed before any verifier saw a claim. It predicted that **at least 6 of the 28 claims** from the three unaided Haiku runs would be refuted by both adversarial passes.

**Measured: 19 of 28 refuted by both passes. Four supported by both. Inter-pass agreement 25/28 (89%).**

| | count |
|---|---|
| claims from the three unaided weak runs | 28 |
| **refuted by both passes** | **19** |
| supported by both | **4** |
| passes disagreed | 3 |
| undecidable by both | 2 |

## The four that survived are the two defects, and nothing else

`C06` is D1 — the byte array sized from a peer-controlled length and allocated before `readFully` runs. `C15`, `C23` and `C25` are D2, the same uncapped mutual recursion filed once by each run.

**That is the entire list.** Beyond the two defects the ground truth already names, the unaided arm on a weak model produced **nothing that survived being attacked**.

## What that does to the weaker-model headline

The weaker-model round measured the unaided arm at 5/6 ground truth against the corpus arm's 2/6, then 4/6 after the loading rule, while the unaided arm reported 8, 10 and 10 findings to the corpus arm's 2, 2 and 2. The counterweight published with it said: *5/6 says the defects are in the list, not that the list is good.*

It was not good. **Two thirds of it is refutable from the file in front of the reviewer**, and the refutations are not judgement calls:

- `C11` states the code backwards — `if (!table.containsKey(name))` keeps the **first** value; the claim says early values are lost.
- `C27` inverts its own premise — a strict `<` sends `Integer.MAX_VALUE` to the exception branch, so the `NegativeArraySizeException` it describes cannot occur.
- `C07`, `C12`, `C17` all need a scale outside 0–255 from a `readUnsignedByte()`.
- `C01`, `C20`, `C26` call collection growth unbounded when it is proportional to bytes actually delivered — the exact distinction that makes D1 real and makes these not.
- `C04`, `C13`, `C22` are a missing log line and two style preferences.

So the recall comparison was, in substantial part, **measuring output volume**. A weak reviewer with no method produces many claims, a few of which are the defects; recall counts the hits and never looked at the rest.

## What this does NOT establish

**The corpus arm's claims were not verified in this round, and that was decided in advance.** Its runs produced 2, 2 and 2 findings, and putting six claims against twenty-eight yields a ratio nobody should trust. So:

- **Nothing here says the corpus arm is more precise.** It says the unaided arm is not, and that its recall advantage came bundled with an error rate this bench had never measured.
- The corpus arm's own dismissals are separately known to be unreliable at this scale: two of its runs refuted D1 with arguments that do not survive reading — one asserting the allocation bounds were correct, one citing the length cap of a different method.

**Both arms make confident wrong statements on a weak model.** The unaided arm makes them as findings; the corpus arm makes them as refutations. Which failure a reader would rather receive is a real question and this bench has not answered it.

The obvious next measurement — verifying the corpus arm's claims under the same adversarial protocol — is worth running **as its own pre-registered round with its small-N caveat stated**, not by quietly reversing a decision recorded before the results existed.

## The instrument, measured on itself

**Inter-pass agreement: 25 of 28 (89%)**, against 91% for the same protocol on the frontier bench. The three disagreements sit on one boundary: `C03`, `C08` and `C28` each bundle a claim that is refutable in-file with one that needs `TruncatedInputStream`, which is not in the two-file target. One pass judged the bundle by its refutable half, the other by its undecidable half. That is the same boundary — where the code stops deciding and something outside it starts — that has produced every disagreement this bench has recorded.

## Files

`PREREGISTRATION.md` is what was committed first. `claims.json` is the blinded batch exactly as both verifiers received it. `verdicts-deblinded.json` holds both passes for every claim, joined back to their runs afterwards.
