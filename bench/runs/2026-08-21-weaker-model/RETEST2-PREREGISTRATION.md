# Pre-registration — the second retest: does making a dismissal expensive bring D1 back?

**Written before the second retest ran, and after the first retest was published.** Neither earlier round is amended.

## The defect this targets

The first retest confirmed its prediction: the loading rule took the weak-model corpus arm from 2/6 to 4/6, and **D2 from zero of three runs to three of three**. But **D1 fell from 2 of 3 to 1 of 3**, and not by silence. Two runs *actively refuted* it:

- one wrote that the array allocation bounds "are actually correct";
- one argued the length was bounded because short strings cap at 255 bytes — a cap in a different method than the one the defect lives in.

D1 is real. Every frontier run in both arms found it every time.

The asymmetry that produces this is in the contract itself. **`confirmed` costs everything** — every triage rule answered, none `HOLDS`, none `UNKNOWN`, confidence not `low`. **A dismissal cost one sentence.** On a budget too short to pay the first price, the second is the only affordable move, and a reviewer that cannot afford to confirm will refute instead. Silence would be honest; a confident refutation is not.

## The change

A dismissal now pays what an assertion pays. `engagement.unaided_pass.dropped[]` carries a `resolution`, and each category carries its own evidence:

- **`refuted`** requires `control_at`: the `path:line` where the control that makes the candidate harmless is enforced, **on the path that reaches the sink**. A refutation names where the bound *is*, exactly as a confirmation names where it is not.
- **`merged`** requires `merged_into`, and that finding must exist in the artifact.
- **`out_of_scope`** requires the reason to name what is out of scope.

Enforced by the validator, carried in `team.md` and in all seven auditor subagents, with the sentence that matters: *if you cannot point at the control, you have not refuted anything — you have run out of time, and `probable` with `what_would_settle_it` is how you say so.*

## The prediction

Same target, same model, same run prompts, same blind judge prompt, same mechanism descriptions, three fresh corpus-arm runs.

**Prediction:** D1 is found in at least 2 of 3 runs, recovering the ground it lost, and the total is at least 4/6.

**What refutes it:** D1 in one run or fewer, or a total below 4/6.

**What a refutation would mean.** That the cheap-dismissal asymmetry is not why D1 was lost, and the cause is something the contract cannot reach — most likely that the loading rule buys attention for whatever is read first and spends it against whatever is read second. In that case the honest next step is to measure *what the arm reads*, not to add another field.

## Fixed in advance

- The unaided arm is not re-run. Its 5/6 stands.
- Three runs, two defects, one model, one target. Only a clear move is reportable.
- Both earlier corpus results (2/6 before the loading rule, 4/6 after) stay published exactly as they are.
