# Pre-registration — a second competitor, on its own home ground

Committed before the new arm runs.

## The weakness this attacks, named by the claim itself

The capability claim restored in `../2026-08-22-recall-resolution/` says *precision at weak scale against the strongest published competitor*, and carries its own limit: **one competitor, one target, one model scale.** Of the six products surveyed in `../2026-08-21-field-transparency/`, exactly one has ever been run as an arm. "Best in this field" cannot rest on a sample of one.

## The new arm, and why it is the hardest available choice

**`Tencent/AI-Infra-Guard` @ `4908db1deab794a02ee9eaa77d3583ad590e7b27`, Apache-2.0**, specifically its `skill-scan` subproject: an LLM-driven multi-stage code-audit pipeline — Info Collection → Code Audit → Vulnerability Review — with its own system prompt and agent definitions. Followed as written, nothing of theirs copied into this repository, exactly as `google/mantis` was.

Three things make it the least comfortable competitor to pick, which is why it is picked:

1. **It is the only product in this field that publishes detection quality** — F1, precision, recall and FPR on its own `SkillTrustBench`. It is the one that has already survived being measured.
2. **The target is its home domain.** `rag-agent` is an AI-agent surface with prompt injection, tool authorisation and memory poisoning; `skill-scan` exists to audit exactly that, with a purpose-built taxonomy for it. This corpus is general-purpose.
3. It is a **three-stage** pipeline with a dedicated vulnerability-review stage, which is the shape that beat this corpus on precision the first time it was measured against `mantis`.

## Setup

- Target `bench/cases/rag-agent`, unchanged. `claude-haiku-4-5`. Six runs for the new arm.
- **The corpus and `mantis` arms are not re-run.** Their twelve artifacts from `../2026-08-22-recall-resolution/` are reused unchanged, and **every claim from all three arms is re-pooled into ONE fresh blinded batch and re-judged by two NEW adversarial passes.** No arm's number is carried over from a previous judging.
- That re-judging is deliberate and is a second test in its own right: **it asks whether the corpus arm's 0% reproduces under a different verifier pair.** A number that moves under a fresh instrument was never a property of the arm.
- Recall against the same 7 planted defects, blind, same judge prompt.
- Same outside-information clause for every arm, archived.

## Prediction — and it bets against this project

**`AI-Infra-Guard` lands at or below `mantis`'s refuted proportion, and at or below this corpus's.** A domain specialist with a published detection number, reviewed on its own home ground, is expected to beat a general-purpose corpus here. **Its recall is at or above this corpus's 4.50 of 7.**

**What refutes it: this corpus stays clearly ahead of `AI-Infra-Guard` on precision — a gap of 10 points or more — with recall inside the 0.5 band.**

## What each outcome forces

- **The prediction holds — the new competitor matches or beats us.** The README stops saying *the strongest published competitor* and names `AI-Infra-Guard` as the arm that is ahead, with its number. The precision claim narrows to what it actually is: **ahead of `mantis`, not ahead of the field.** If it beats us on both, the capability claim comes down again, and this time it comes down against the product that publishes its own numbers.
- **The prediction is refuted — we stay ahead of both.** The claim goes from one competitor to **two, including the only one that publishes detection quality**, and the sentence about being ahead of the field becomes defensible for the first time. It stays one target and one model scale, and those stay in the text.
- **The corpus arm's 0% does not reproduce under the new verifier pair.** That is reported first, ahead of any comparison, and the restored claim is re-opened: a precision number that moves with the instrument is a property of the judges, not of the arm.
- **An arm dies or the pipeline cannot run read-only and offline.** Not measured, recorded as such, and the round reports what it could not do rather than dropping the arm quietly.

## Declared weaknesses

- **Still one target and one model scale.** This round buys a second competitor and nothing else.
- `skill-scan`'s three-stage mode is designed to run through its own CLI against a skill project. Run here as a followed-prompt pipeline like `mantis`, read-only and offline, which is its floor rather than its ceiling — the same handicap `mantis` carries, and it is a handicap.
- The verifier and the critic are the same kind of instrument for all arms.
