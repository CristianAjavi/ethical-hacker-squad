# The harness bypassed a shipped control, in all three rounds

Found after the third round was scored and published. It affects the decoy numbers on
**three pages**, and it is a defect in the measurement rather than in the product.

## What the contract requires

`skills/ethical-hacker-squad/references/findings.schema.json` — which ships, and which
`gate-findings-artifact.sh` enforces — requires **every** finding to carry:

```
required: id, title, procedure, status, severity, confidence, location,
          evidence, impact, recommendation, traceability, triage
```

and `triage` is not decorative:

```json
"triage": {"type":"array","minItems":1,"items":{
  "required":["rule","answer"],
  "rule":  {"pattern":"^FP-[0-9]{2}$"},
  "answer":{"enum":["HOLDS","DOES_NOT_HOLD","UNKNOWN","NOT_APPLICABLE"]}}}
```

**At least one false-positive rule must be named and answered for every finding reported.**
That is the control this project has for the exact failure the last two rounds measured.

## What the rounds asked for instead

Every round's `PROMPT.md` asked each arm for:

```
{title, location, class, severity, evidence, impact, recommendation}
```

No `triage`. No `procedure`. No `confidence`. **The harness asked for a shape that cannot
carry the answer**, so no arm was ever obliged to name an `FP-nn` rule against a finding
before reporting it.

The decoy rates on all three pages — 0.25, 9.75 and 9.50 — therefore measure these procedures
**with the shipped false-positive control removed by the measurement itself.**

## Why this is not an excuse, and what it does not undo

- The **recall** numbers are unaffected: nothing in the dropped fields makes a defect easier to
  find.
- The **eleven-product loss** (79.6% against 88.0%) was a recall loss and stands entirely.
- `mantis` audited under the same simplified shape, so the comparison is symmetric — but
  symmetric is not the same as valid. `mantis`'s own pipeline carries its false-positive
  filtering *inside* its stages and does not depend on the artifact shape to trigger it; this
  project's, on this evidence, does.
- The verdicts stand as published. **Nothing on those three pages is edited to a friendlier
  number.**

## What it does mean

The question *"does this project's false-positive discipline work"* **has not been measured
yet.** Three rounds asked it of a configuration that had the discipline switched off at the
door, and the honest state of the ledger is that its decoy rate under the shipped contract is
**unknown**, not high.

## What happens next, and the trap in it

Re-running a retired corpus now — after an unfavourable result, with a change that is expected
to help — is the exact shape of motivated re-analysis, and it does not become acceptable
because the reason is good. So the retired corpora stay retired.

The next round uses a **fourth corpus**, pre-registers the artifact contract as part of the
arm, and states this defect in its own pre-registration so that a favourable result there is
read against the knowledge that the previous three were measured with the control disabled.
