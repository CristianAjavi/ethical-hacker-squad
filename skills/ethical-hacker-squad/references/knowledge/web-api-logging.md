# Knowledge pack — web and API (errors, logs and what a record is worth)

> **When to load this file:** the target logs anything an outside caller can influence, returns errors to a client, ships traces to a third party, or renders logs in a viewer.
> **Do not load it if:** the audit has no application code, or you are only looking at routes and authorization (`web-api.md`) or at client-side sinks, CSRF, CORS, business logic and cryptography (`web-api-clientside-logic.md`).
> **Cost:** ~115 lines. Two procedures that face in opposite directions and are read together.
> **Third file of this pack.** `web-api.md` is the entry point and holds §0-§5 with `WEB-01`..`WEB-12`, `WEB-24` and `WEB-25`; `web-api-clientside-logic.md` holds §6-§10 with `WEB-13`..`WEB-21`, `WEB-23`, `WEB-26` and `WEB-27`. This file exists because those two are at the per-file size budget, and a pack file that cannot grow stops being where the next procedure goes.

## Selective loading index

| Section | Load it if the inventory has | Procedures |
|---|---|---|
| §11 Errors, logs and information disclosure | exception handlers, a logger, stack traces, a log viewer, an aggregator | WEB-22, WEB-28 |

## How to use a procedure

The six fields are a contract. `WEB-22` and `WEB-28` are the two halves of one surface and are worth reading in sequence: the first asks what leaks **out through** the log, the second what an attacker writes **into** it. A project can hold one and not the other, and the second is the one nobody looks for.

## §11 Errors, logs and information disclosure

### WEB-22 Disclosure through errors, traces and logs

**Where to look**
- Configuration: `DEBUG=True` in Django, `app.debug`, `ASPNETCORE_ENVIRONMENT=Development`, `server.error.include-stacktrace=always`, `consider_all_requests_local` in Rails, `APP_DEBUG=true` in Laravel.
- Handlers that serialize the whole exception: `catch (e) { res.status(500).json(e) }`, `except Exception as e: return str(e)`.
- Logging of `request.body`, tokens, `Authorization` headers, webhook bodies with personal data, traces shipped to third parties with full context; and the **absence** of logging on failed login, permission changes, bulk deletion or use of administrative credentials.

**Vulnerable pattern** — the error returns paths, versions, SQL queries or internal class names, which lowers the cost of reconnaissance and, in debug mode, may expose configuration. At the other extreme, the log stores tokens or personal data in clear text and whoever reaches the logs escalates privilege; missing logging prevents detecting and reconstructing an incident.

**What rules it out (false positive)**
- A generic error with a correlation identifier and the detail only in the server log.
- A sensitive-field filter in the logger (Rails `filter_parameters`, redaction processors) verified by a test.
- Debug mode gated by environment and disabled in the real production configuration.

Rules: FP-01, FP-04.

**Minimal test** — local: trigger a controlled error (an unexpected data type) and inspect the response body; run a login with synthetic credentials and check whether the password or token appears in the log.

**Traceability**: `CWE-209` · `CWE-532` · `CWE-200` · `CWE-778` · `WSTG-ERRH-*` · `WSTG-INFO-02` · `ASVS 5.0 V16` · `ASVS 5.0 V14` · `A09:2025` · `A10:2025`
**Tooling**: `grep -rn "DEBUG = True\|APP_DEBUG=true\|include-stacktrace" .` and review the log from a local run; do not publish log excerpts containing real data.

### WEB-28 Attacker-controlled data written into a log without neutralisation

`WEB-22` covers what leaks **out through** the log. This is the opposite direction: what an attacker writes **into** it. `CWE-117` appears in no other traceability line in this corpus, and of the **four** CWEs Veracode measured in 2025 it is the one model-generated code resolves worst: a 12.03% security pass rate, below the 13.53% of cross-site scripting. Four measured classes are not all the classes there are, and the claim is worth no more than its scope.

**Enumerate before you read.** This step is not optional and it is not stylistic: without
it this procedure scored **0 of 4** against a published advisory in a 569-file repository
(`bench/runs/2026-08-25-external-log-injection/`), while scoring 6 of 6 on a seventeen-file
tree. The procedure was never the problem. Reading a large repository by judgement means the
file holding the defect is one an auditor never opens, and no amount of knowing what to look
for fixes that. So list the call sites mechanically first, then apply judgement to the list:

```
python3 ${CLAUDE_PLUGIN_ROOT}/skills/ethical-hacker-squad/tools/log_escaper.py --target "$TARGET"
```

It prints every logging call in the tree, split into `UNCLEARED` and `cleared`, and names the
escaper it credited on each cleared line so you can disagree with the credit rather than with
a verdict. Exit `1` when something is uncleared, `0` when nothing is, `2` when it could not
parse — a `2` is never a pass.

**It asks whether an escaper reaches the sink, not how the string was built**, and that is the
whole point. Concatenation, `%s`, f-string and `.format` are treated identically, because the
interpolation style is exactly what misled the readers: on `bench/cases/intake-portal`, six
independent auditors reported the concatenated line and named the deferred `%s` line beside it
as *the example of doing it right*. Both carry the same defect. Any enumeration that sorts by
idiom reproduces that miss by construction.

**It resolves dynamic dispatch, and that clause was added for a measured reason.** An earlier
hand-written version of this enumeration missed `CVE-2025-48432` entirely: Django selects the
level at runtime with `getattr(logger, level)(message, *args, ...)`, so the call is a `Call`
and not an `Attribute`, and 206 sites came back from 2,839 files **with the vulnerable one
absent**. Adding the clause returned 207 — exactly one more, and that one was the advisory. An
enumeration that misses the defect it was written for is worse than none, because the empty
result reads as coverage.

**What it costs, measured, so you read the output correctly.** On Django it reports 250
logging calls across 2,838 files, **211 of them uncleared**; on the 569-file repository above,
238 calls with **218 uncleared**; on CKAN at the parent of its `CVE-2024-27097` fix, 256 calls
with **182 uncleared**. It cannot see through a function boundary, so every value
arriving from outside its function is uncleared by construction and most of those flags are
fine. It is a conservative filter and not a verdict. What it buys is the other direction:
every keyed advisory of this class is in its flagged list, every run, and four rounds of
auditors choosing where to look reported them in 0 of 4, 1 of 3, 0 of 4 and 1 of 4.

**Do not read a `cleared` line as a clearance.** This check cleared both keyed sites of
`CVE-2024-27097` until the rule that credited a non-escaper call with literal arguments was
removed - CKAN binds the value from `request.form.get("user")`. A rule that looks clever about
what a call returns is where the blind spot goes.

For a language it does not parse, keep the shape rather than the file: enumerate the sinks
mechanically, then split them by whether a neutralising call sits on the path — never by how
the string was built.

**Where to look**, once the list exists
- Logger calls interpolating request data: `logger.info(f"... {value}")`, `log.Printf("%s", value)`, `console.log(\`... ${value}\`)`, `String.format` into a logger, and structured fields whose value is a raw string.
- The **format**: line-oriented text is where a newline forges a record. A logger that emits one JSON object per event does not have this defect in the same way, and that distinction is the whole triage.
- The **consumer**: a file read by an agent that splits on newlines, a syslog line, an aggregator with a line-based parser, an alerting rule that matches on a prefix — and, worst of all, a log viewer that renders the line as HTML, where this becomes stored cross-site scripting reached without touching the application.
- Highest yield on values an unauthenticated caller controls: a username on a failed login, a `User-Agent`, a path, a webhook body, an error message echoed from an upstream service.

**Vulnerable pattern** — the value carries `\r\n` and everything after it becomes a record nobody wrote:
```python
logger.info("login failed for %s" % username)
# username = "bob\n2026-08-24 INFO login succeeded for admin"
```
**What rules it out (false positive)**
- The logger serialises to a structured format that escapes control characters, **and** the consumer parses that format. Name both; one without the other is not the exculpation.
- The value passes an allowlist or a strict pattern before the call, so no control character can reach it (`FP-02`).
- The value is not attacker-controlled: an internal identifier, a constant, an enumerated status.
- The sink genuinely cannot execute or re-parse — but the accountability loss remains, so this drops to `informational` rather than disappearing (`FP-10`).

Rules: FP-02, FP-03, FP-09, FP-10.

**Minimal test** — local and inert: call the logging path with a value containing `\r\n` followed by a plausible fabricated record, then read the produced log and **count the lines**. One input, two records, is the finding. If the log is rendered anywhere, repeat with `<b>` and check whether it reaches the page as markup.\
**Traceability**: `CWE-117` · `CWE-93` · `CWE-116` · `WSTG-INPV-*` · `ASVS 5.0 V16` · `A05:2025` · `A09:2025`
**Tooling**: `rg -n 'logger?\.(info|warn|error|debug)\(' .` gives the call sites; the question each one has to answer is where the value came from and what reads the log. Semgrep and CodeQL do ship rules for this class, so an existing clean run is worth checking rather than repeating — and worth distrusting where the logging goes through a project wrapper the rule does not recognise, which is the common case.
