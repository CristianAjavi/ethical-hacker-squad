# Knowledge pack — web and API (errors, logs and what a record is worth)

> **When to load this file:** the target logs anything an outside caller can influence, returns errors to a client, ships traces to a third party, or renders logs in a viewer.
> **Do not load it if:** the audit has no application code, or you are only looking at routes and authorization (`web-api.md`) or at client-side sinks, CSRF, CORS, business logic and cryptography (`web-api-clientside-logic.md`).
> **Cost:** ~66 lines. Two procedures that face in opposite directions and are read together.
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

**Where to look**
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
