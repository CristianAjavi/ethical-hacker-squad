# Run 2026-08-21 — a whole repository, no pointer, and the corpus loses


> **The run prompts for this round were not kept.** A later round measured the same unaided arm on the same target with the same blind instrument and a freshly written prompt, and scored 0.60 where this family of rounds scored 0.81 — twenty-one points from the prompt alone. **The numbers below are internally valid and are not comparable to numbers from another sitting.** See `../2026-08-21-unaided-pass/`, which archives every prompt it used.

Three rule-picked rounds ended 6/9, 6/9, 6/9, and a precision run found nothing refuted in any arm. Both dimensions saturated, so the measurements were testing the wrong thing: each arm had been handed **one to three files that already contained the known defect**. That task rewards careful reading, and a competent model saturates it with a corpus or without one.

The corpus is built for the other task — routing across a large unfamiliar codebase, deciding what to look at when you cannot read everything, and declaring what you did not cover. That had never been measured against anyone.

**Target: the whole repository.** `rabbitmq/rabbitmq-java-client` at `cbba12b8`, 461 files, 409 of them Java, 7.3 MB, carrying **two published advisories at once**. No arm was told a module, a file or that anything was wrong.

## Result

| Advisory | With the corpus | Without it | Competitor |
|---|---|---|---|
| `CVE-2026-63337` — unvalidated `Class.forName` from a JSON-RPC service description | **missed** | **missed** | *not measured* |
| `CVE-2026-69219` — oversized declared length sizes an allocation before any payload is read | **missed** | **found** | *not measured* |
| | **0 / 2** | **1 / 2** | — |

**The corpus arm lost.** On the one dimension where a written method was supposed to help most, the unaided senior engineer found a published advisory that the corpus arm did not.

## What actually went wrong, since routing did not

The obvious explanation is that routing sent the corpus arm to the wrong place. It did not.

- Both arms read a comparable slice: **33 of 409 Java files** for the corpus arm, about 30 for the control.
- The corpus arm's routing was sound. It inventoried the repository, matched four `coverage.md` rows, staffed four roles and said which rows it deliberately did not take.
- **It had the right file open.** Its `F-002` reports unbounded recursion in `ValueReader.readTable` — the same class, a few lines from `readBytes`, which is where the advisory lives. The judge scored that finding `partial`: same file, same pre-authentication entry point, different mechanism.

So the corpus arm was inside the file and reported the neighbouring defect. That is not a routing failure. **It is a missing procedure**, and the gap had already been named earlier the same day, by one of our own arms, in writing:

> *"resource exhaustion from untrusted input in a binary decoder has **no** procedure in this corpus"* — the round-3 arm, which reported the same class as `ad-hoc` rather than stretch `WEB-11` over it.

That declaration was logged as work to do and deliberately **not** acted on, because writing a procedure from a case an in-flight round was measuring would have contaminated the round. This run is the cost of that decision, paid in the open: the class stayed uncovered for one more round, and the round it decided was this one.

## What the corpus arm did produce

Eight findings, two `confirmed`: TLS enabled through the property configurator falling through to a trust-everything manager, so `ssl.enabled=true` with no truststore yields an encrypted but unauthenticated channel; and a 17-byte JSON-RPC body that kills the server mainloop with a delivery that is never acked. Neither is a published advisory. Both are real, and the second arm found the first one too.

Its coverage declaration is the part worth keeping: 172 test files, `codegen.py` and the AMQP framing it generates, the entire `impl/recovery` package, the SASL layer and the address resolvers are all named as **unexamined rather than clean**. That distinction is the thing this project sells, and it survives the loss.

## The competitor cell

Not measured. That arm was killed four times — three host sleeps and a stream watchdog — along with the parallel sub-auditors its own method spawns. It reached disk once with a 2.6 KB pre-review index, which is stored in `unfinished/` and **not scored**: it is raw researcher output, and scoring it would misrepresent the method. The same rule was applied earlier in the day when it cut the other way.

**One thing the empty cell hides, and it is fair to say it.** After that arm died, one of its Wave-2 sub-auditors completed and its output is on disk. It is strong work: 32 cited line numbers verified against the files, four TLS findings, and — more telling — **four negative results that killed its own leads**, including one refuted *empirically* by checking what the JDK actually does with a resolved address on Temurin 17.0.19, and one where it worked out that a suspicious-looking default is inert because every branch reaches a call that turns the check on anyway. It also ran code to settle a question, which is the same latitude the no-corpus arm took on `lima` earlier and is recorded the same way here. None of that is scored, because the pipeline that would have deduped, reviewed, criticised and calibrated it never ran — but a cell marked *not measured* should not be read as a cell with nothing in it.

**And a second sub-auditor went further, which has to be said plainly because it cuts against us.** Its wire-decoder lens filed `ValueReader.readBytes` allocating up to 2 GiB from a four-byte peer-supplied length — **the advisory the corpus arm missed** — together with the recursion and the `frame_max = 0` cap bypass, and it did so with a page of negative results proving what it had checked and found sound. That is raw research, not a report: the stages that would have kept, merged or killed it never ran, and the cell stays unmeasured because scoring pre-review output would misrepresent the method. But the honest sentence is that **the competitor's research reached the defect and ours did not**, and the empty column is an accident of this machine falling asleep, not a silence in its favour.

## What this changes

1. **The deferred procedure gets written now.** A length read off the wire that sizes an allocation before any payload is read, with its neighbours: mutual recursion with no depth cap, and a length multiplied without an overflow check. Round 3 is judged and published, so writing it can no longer contaminate anything.
2. **Whole-repository is now the benchmark that matters.** File-subset rounds are saturated for every arm and should stop being run as if they discriminate.
3. **One run, two advisories, two arms.** A 1–0 difference is one advisory, and this bench's measured resolution is five in fifty-three. **This result is inside its own noise**, and the only reason it is worth publishing at that size is that it points at a named, reproducible gap rather than at a score.

## Files

`arms/` holds both measured artifacts. `judgements-deblinded.json` holds all 36 verdicts with their reasons. `unfinished/` holds the competitor's partial index, unscored.
