# Knowledge pack - verifier

> **When to load this file:** whenever you are checking somebody else's work - a patch in `harden` or `verify` mode (`VER-01`..`VER-08`), or **a finished finding list in `audit` mode, before the report leaves** (`VER-09`).
> **Do not load it if:** you are the one repairing. That is the sibling file, [remediation.md](remediation.md), which holds `REM-01`..`REM-07`. Never the same agent for both.
> **Cost:** ~250 lines.

## Selective loading index

| Section | Load it if | Procedures |
|---|---|---|
| §6 Adversarial posture | you are about to verify someone else's patch | VER-01 |
| §7 Negative checks | there is a reproducible case or a new control | VER-02, VER-03, VER-04, VER-08 |
| §8 Verification outcome | you are about to report the state of a fix | VER-05 |
| §9 Tooling limits | you are relying on SAST, linters or scanners | VER-06 |
| §10 What was not checked | always, at closing | VER-07 |
| §11 Attacking the finished list | `audit` mode, before the report leaves | VER-09 |

## How to use a procedure

Every verdict this pack emits - the status of a finding and the outcome of a verification - comes from the closed vocabulary in [../vocabulary.md](../vocabulary.md). `VER-05` is where that vocabulary is applied; it does not define its own.

In **Where to look** you locate the finding, the diff or the affected control. **Vulnerable pattern** describes the wrong way to verify, which is what this pack exists to prevent. **What rules it out** tells you when the apparently bad practice is acceptable. **Minimal test** is the evidence you must produce; if you cannot produce it, that gets recorded (VER-07), not assumed. Apply the identifiers in **Traceability** to the report.

# Part B - verifier

## §6 Adversarial posture

### VER-01 Try to refute the finding and the patch alike

**Where to look**
- The finding: does the evidence demonstrate real impact or only the presence of a pattern?; and the diff: which property exactly does it guarantee, and what is left out?

**Vulnerable pattern**
Verifying by reading the diff and confirming that it "makes sense". That validates intent, not effect. The two symmetric failures you must hunt: a finding that was never exploitable (the remediator touched correct code and may have introduced a defect) and a patch that looks right but leaves a path open.

**What rules it out (false positive)**
- No reading rules this procedure out; it always runs. What can vary is the depth, according to severity.

Rules: none (this procedure always runs; only its depth varies with severity).

**Minimal test**
Write down two hypotheses and try to confirm them: (a) "this finding is not exploitable in the real context because..."; (b) "this patch can be bypassed by...". Record the outcome of both, even when negative.

**Traceability**: internal process; use the one from the original finding
**Tooling**: manual reproduction. Reading the diff is not verifying.

## §7 Negative checks

### VER-02 The original case must fail now

**Where to look**
- The exact reproduction that documented the finding: same parameters, same identity, same environment

**Vulnerable pattern**
Treating the fix as verified because the test suite is green. **"The tests pass" is not the same as "the vulnerability does not reproduce".** The suite checks what someone thought of checking; the vulnerability is, by definition, what nobody thought of.

**What rules it out (false positive)**
- The finding had no executable reproduction (it was configuration or design): then you verify the control by inspection and the outcome is `partially verified` (VER-05), never `verified`.

Rules: FP-09.

**Minimal test**
Run the original reproduction as it was. It must fail, and **because of the new control**, not for another reason: a 500 from a type error is not a fix, it is another bug. Read the message and confirm the control is what blocks it. Running only this check is the single-run trap of VER-08: the original case also stops working when the patch broke the path for everybody, and this run cannot tell the two apart.

**Traceability**: the one from the original finding
**Tooling**: the same one that produced the initial evidence. Switching tools between finding and verification introduces differences that get mistaken for the fix.

### VER-03 Variants: try to bypass the new control

**Where to look**
- The exact point where the patch decides: what does it compare, over which value, at which moment?

**Vulnerable pattern**
The control works for the exact shape of the original case and is bypassed with a trivial variant. Axes you must always test, one by one:
- **Encoding**: upper/lower case, single and double URL-encoding, unicode equivalents, nulls, alternative whitespace; on AI inputs, the invisible ranges from AI-20.
- **Verb, protocol and route**: if `POST` was blocked, try `PUT`, `PATCH`, `DELETE`, `HEAD`; if there is a REST API and GraphQL, try the other one; and alternative routes (legacy endpoint, previous API version, admin route, internal endpoint, scheduled job, queue, file importer).
- **Role and identity**: another role, guest user, service token, expired session, another tenant.
- **Timing**: the check happens before a state change that invalidates it (race condition), or only on the first request of the session.

**What rules it out (false positive)**
- The control sits at a single unavoidable point (a mandatory layer, a database policy) and the alternative routes demonstrably pass through it.

Rules: FP-01.

**Minimal test**
At least one variant per applicable axis, with synthetic data and in an environment you own. If an axis cannot be tested, it gets recorded in VER-07 instead of being treated as covered.

**Traceability**: the one from the finding · `CWE-183` · `CWE-436` · `ASVS 5.0 V1` · `ASVS 5.0 V2` · `ASVS 5.0 V8`
**Tooling**: `curl` or the project client. One variant failing does not prove the others fail.

### VER-04 Verifying AI and agent patches without leaning on a judge

**Where to look**
- The `ai-safety` patch: is it deterministic (allowlist, filter, gate, isolation) or textual (instructions in the prompt)?

**Vulnerable pattern**
Verifying a prompt injection patch by running a red teaming tool and accepting its verdict. promptfoo and deepteam verdicts are issued by a judge model: a PASS is an opinion and does not prove a fix, just as a FAIL is an opinion and does not prove a vulnerability. On top of that, a test you run against the harness does not cover the production path, which adds a system prompt, tool permissions and an output filter.

**What rules it out (false positive)**
- The patch is deterministic and has a deterministic test: then it is verified like any other control, with no model in the loop.

Rules: FP-09.

**Minimal test**
Check the structural property, not the model's behavior: that the outbound tool rejects a destination outside the allowlist; that tainted state does not expose the sensitive tool; that the sanitizer strips the invisible test character. If you additionally run an adversarial suite against a live endpoint: `REQUIRES AUTHORIZATION`, a capped budget and supervision.

**Traceability**: `LLM01:2026` · `ASI01` · `ASVS 5.0 V16`
**Tooling**: the repository's deterministic test. Red teaming reports are cited as a signal, never as evidence of a fix.

### VER-08 The benign control: three runs, and (b) is the one that gets skipped

**Where to look**
- The three things a verification needs and of which usually only one exists: an unpatched copy of the code (a stash, the parent commit, a worktree), a legitimate input that has to keep working through the patched path, and the attack; and, run by run, the evidence that it reached the patched line — something the path itself produces, never the exit status of the client that sent it

**Vulnerable pattern**
Closing the verification with a single run: the attack no longer works. Three different states produce that same output and only one of them is a fix — the control rejected the attack, or the patch broke the path for everybody including legitimate users, or nothing ever reached the code (wrong host, service down, build broken, fixture missing, `exit 127`). A patch that broke the function is indistinguishable from a patch that removed the vulnerability when the only thing you ran is the attack. Three runs, each with a required result:

<!-- benign-control:rule VER-08 -->
| Run | What you send, and against what | Required result | What it means if it comes out otherwise |
|---|---|---|---|
| **(a) baseline** | the attack, against the **unpatched** code | it triggers, and for the reason the finding claimed | the test proved nothing: the finding was never reproduced, so the patched run cannot mean anything either. Outcome `inconclusive` |
| **(b) benign** | a **legitimate** input that has to travel the patched path | it succeeds, **and** leaves evidence that it reached the patched line | either the patch broke the function or the harness never arrived — two different defects, and until you know which, the outcome is `inconclusive`. It is never `verified` |
| **(c) attack** | the attack, against the patched code | it does not trigger, and it fails **through the new control** | a 500, a timeout or a connection error is not (c) coming out well; it is a second defect on top of the first, and the outcome is `inconclusive` |

**Missing (b)** is the ordinary case and the reason this procedure exists: a verification holding only (a) and (c) is **incomplete**, and its honest outcome is `partially verified` with functional preservation named as the part left open. It is never `verified`, however clean (a) and (c) came out.
<!-- /benign-control:rule -->

**What rules it out (false positive)**
- The patched path has no legitimate input by construction: the fix deleted a debug route, removed a deserialization entry point, withdrew a permission nobody should have held. Then (b) changes object instead of disappearing — it becomes the existing suite plus the callers of what was removed — and the report says at which level (b) was answered and why no direct benign input exists.
- (a) cannot be re-run because there is no revertible baseline in the tree: the change lives in infrastructure, in a managed configuration or in a third-party console. Then (a) is a dated observation of the previous state, quoted as it was recorded, and the outcome is `partially verified`. Asserting that the finding used to reproduce does not upgrade it.
- (b) fails and the cause is that the input was never legitimate: it carried the very property the control now rejects. That is not a regression, it is an intended behaviour change (REM-04), documented as such; (b) is then re-run with an input that is genuinely benign.

Rules: FP-02, FP-08, FP-09.

**Minimal test**
1. Get an unpatched copy — `git stash` of the production change only, or `git worktree add` at the parent commit — and run the attack there. Record the literal output. This is REM-05 step 1 re-executed rather than believed (VER-01).
2. Restore the patch and send the legitimate input through the same entry point, with the same client that produced the original evidence. Assert on something only the patched path can emit: the expected body, the row written, the log line the control leaves when it allows. An `exit 0` from a client that never connected is not evidence of reach.
3. Send the attack. It must fail with the control's own signal — 403, the validation error, the allowlist rejection — read from the message, not inferred from a non-zero status.
4. Put the three outputs in the report side by side. Whatever is missing or ambiguous is classified with VER-05, never rounded up.

**Traceability**: the one from the original finding · `A08:2025` when (b) exposes a behaviour change · `ASVS 5.0 V15` · `ASVS 5.0 V16`
**Tooling**: `git stash` or `git worktree add` for the baseline copy, and the same client as VER-02 for the three runs. Re-running in the working tree without reverting is not a baseline: it measures the patched code twice.

## §8 Honest classification of the result

### VER-05 Seven outcomes, and none of them is "secure"

**Where to look**
- What you actually executed against what you set out to execute

**Vulnerable pattern**
A binary fixed/not-fixed report that hides what was really checked. Its mirror image, which this corpus carried until 2026-08-21: an outcome set with no term for *the patch does not fix it*, which forces the most consequential result a verifier can produce into `inconclusive` - a word that says the run decided nothing. The reader assumes the strong case and makes decisions on a verification that never happened. The sharper form of the same mistake: a check that errored, timed out or never reached the code under test, recorded as if it had found nothing.

**What rules it out (false positive)**
- Nothing. Every closed finding carries exactly one of these outcomes, defined in [../vocabulary.md](../vocabulary.md) and reproduced here for use:

<!-- vocabulary:use verification status -->
| Outcome | What it means exactly |
|---|---|
| `verified` | I reproduced the original case, it now fails because of the new control, I tested variants along the applicable axes of VER-03, and the suite passes. |
| `partially verified` | The control exists and I checked it by inspection or with part of the tests; some axes or environments were left uncovered, and they are listed. |
| `not fixed` | I reproduced the original case after the patch and it still reproduces. The check reached the code; what it established is that the patch does not work. The finding stays open. |
| `refuted` | The check ran and established that the finding does not hold: the source was not controllable, the sink not reachable, or a control was already in place. The finding's status becomes `withdrawn` and stays in the report. |
| `inconclusive` | The check ran and settled nothing: nondeterministic result, harness or build failure, the test never reached the code under test. The patch may be correct; this run says nothing either way. |
| `not executed` | Nothing external stopped me and I did not run it: time, priority, or it fell outside the agreed plan. |
| `blocked` | A named external condition stopped me: it required touching production, a remote target, credentials I do not have, or generating load. It remains proposed with its procedure and with what would unblock it. |
<!-- /vocabulary:use -->

The bottom three are the finding-level form of this repository's `0/1/2` gate doctrine: not measuring is not a pass. What separates them is **why** the answer is missing — the check ran and answered nothing, nothing stopped it and it was not run, or something external stopped it. Collapsing them is how "the build failed" ends up read as "no bug found".

Rules: none (every closed finding carries exactly one outcome, and none of them is silence).

**Minimal test**
For each finding, one line with the outcome, what you executed, with what result and what is missing. A verification that never ran check (b) of VER-08 is `partially verified` at best, naming functional preservation as the open part. Never write that the system is secure or that it has no vulnerabilities: you verified one specific finding in one specific environment.

**Traceability**: internal process; `A09:2025` when the gap the outcome exposes is in the detection capability itself
**Tooling**: the report itself. The honesty of the state is the deliverable.

## §9 Tooling limits

### VER-06 A clean scan is not evidence of absence

**Where to look**
- What you leaned on: SAST, security linter, dependency scanner, secrets, containers; and what that tool actually covers: languages, active rules, whether it follows flow across files

**Vulnerable pattern**
Closing the verification with "the scanner reports nothing". Lipp et al. (ISSTA 2022), across 27 projects and 192 CVE-confirmed vulnerabilities, measured that **each SAST tool misses between 47% and 80% of the real vulnerabilities**; combining several, false negatives drop to the 30% to 69% range. That is: even with several tools chained, a good third of what is real still fails to appear. A green scanner bounds your confidence, not the system's.

**What rules it out (false positive)**
- The tool is used as a complement and the conclusion rests on manual reproduction: then the scan is one more data point, correctly weighted.

Rules: FP-10.

**Minimal test**
Always write down which tool you ran, with which version and which rules, and which failure classes that tool cannot see (business logic, authorization, race conditions, prompt injection). That list is as informative as the results.

**Traceability**: internal process
**Tooling**: whichever you use, declared with its version. Empty output = no matches against its rules; nothing more.

## §10 Record of what was not checked

### VER-07 What was not tested and why

**Where to look**
- The verification plan against what was executed: every item that fell by the wayside

**Vulnerable pattern**
Silently omitting what could not be tested. The report looks cleaner and the reader ends up worse informed: they believe that whatever is not mentioned was checked. Silence transfers the risk without warning anyone.

**What rules it out (false positive)**
- Nothing. This section is always written, even when empty, and in that case it says it is empty.

Rules: none (the section is always written, and says so when it is empty).

**Minimal test**
A closing table with: what was left unchecked, why (lack of environment, data, authorization or time), what would be needed to check it, and what residual risk it implies. If the reason was authorization, include the exact procedure so the user can grant it and it can be executed afterwards.

**Traceability**: internal process; the skill's security contract
**Tooling**: none. This is report discipline, and it is what separates a verification from a declaration.

### VER-09 Attack the finished list, in `audit` mode, where there is no patch to verify

**Where to look**
Every `confirmed` and `probable` finding, after the specialist stopped writing and before the report leaves. You did not find them, and you are not being asked whether they are well written.

**Vulnerable pattern**
A squad that triages *while* it writes and then ships. Triage inside the act of writing is the author checking their own work at the moment they are most committed to it — not an attack from a context that never wanted the finding to be true.

Measured, not asserted. Three arms, one target, a weak model, every claim checked twice by independent adversarial verifiers: a competing product with an explicit stage for this refuted **53%** of its own claims; this corpus, triaging only while writing, **62%**; unaided review with no method, **68%**. The stage is the difference — and this corpus already had the adversarial role, `VER-01`, wired only to `harden` where a patch exists. In `audit` nothing ever invoked it, so the list shipped unattacked.

**What rules it out (false positive)**
Nothing rules out running it; it costs one pass. What changes is the standard: with no patch and no reproduction you are attacking a claim about code, so the only evidence that counts is the code.

Rules: FP-01, FP-02, FP-08.

**Minimal test**
For each finding, in this order:

1. Try to find the line that kills it: a bound that is enforced, a guard that catches it, a caller that cannot reach it, a factual error about the code, or the absence of any attacker who could exercise it.
2. Only when you have genuinely failed, let it stand.

Three outcomes, and the third is not a courtesy:

- **killed** — into `ruled_out` with the line you relied on. It never just disappears: a finding written and then refuted is information the reader wants.
- **stands** — it survived an attack, a stronger claim than it had before.
- **undecidable here** — the answer lives outside the scope. That is `probable` with `what_would_settle_it`, never silence and never a polite `stands`.

Two failures this stage is for, both seen in real runs of this corpus and of the competitor: a claim that **states the code backwards**, and a claim whose premise is **inverted by the guard it cites**. Both read fluently; neither survives one hostile reading.

**Traceability**: internal process; the triage rules are the questions, and this is the pass that asks them again from a context that never wanted the finding to be true
**Tooling**: none. No scanner tells you a claim describes the opposite of what the code does.
