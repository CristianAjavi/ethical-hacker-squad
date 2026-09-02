# Knowledge pack — web and API (errors, logs and what a record is worth)

> **When to load this file:** the target logs anything an outside caller can influence, returns errors to a client, ships traces to a third party, renders logs in a viewer, or decides anything about a string before normalising, folding or re-encoding it.
> **Do not load it if:** the audit has no application code, or you are only looking at routes and authorization (`web-api.md`) or at client-side sinks, CSRF, CORS, business logic and cryptography (`web-api-clientside-logic.md`).
> **Cost:** ~226 lines. Two sections: one pair of procedures that face in opposite directions, and three that share a single question - which bytes, read as which characters, by whom.
> **Third file of this pack.** `web-api.md` is the entry point and holds §0-§5 with `WEB-01`..`WEB-12`, `WEB-24` and `WEB-25`; `web-api-clientside-logic.md` holds §6-§10 with `WEB-13`..`WEB-21`, `WEB-23`, `WEB-26` and `WEB-27`. This file exists because those two are at the per-file size budget, and a pack file that cannot grow stops being where the next procedure goes.

## Selective loading index

| Section | Load it if the inventory has | Procedures |
|---|---|---|
| §11 Errors, logs and information disclosure | exception handlers, a logger, stack traces, a log viewer, an aggregator | WEB-22, WEB-28 |
| §12 Encoding, charset and normalisation | a `Content-Type` written by hand, `normalize`/`casefold`/`toLowerCase`, a database connection charset, `open()` with no `encoding=` | WEB-29..WEB-31 |

## How to use a procedure

The six fields are a contract. `WEB-22` and `WEB-28` are the two halves of one surface and are worth reading in sequence: the first asks what leaks **out through** the log, the second what an attacker writes **into** it. A project can hold one and not the other, and the second is the one nobody looks for.

§12 is a different surface with the same shape. `WEB-29`, `WEB-30` and `WEB-31` each describe one layer deciding what a sequence of bytes means and a second layer deciding differently - the declaration a response never makes, the transformation applied after the check rather than before it, and the charset the escaper assumed versus the one the interpreter used. None of them is exploitable on its own: each is a disagreement, and the finding is always what the disagreement lets through. Read the three together, because a project that gets one wrong usually has no owner for the question at all.

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
python3 - "$TARGET" <<'PY'
import ast, sys, pathlib
sys.stdout.reconfigure(errors="backslashreplace")   # a path can hold bytes stdout cannot encode
root = pathlib.Path(sys.argv[1])
LOG = {"debug", "info", "warning", "warn", "error", "exception", "critical", "log"}
skipped = []


def is_log_call(n):
    if not isinstance(n, ast.Call):
        return False
    f = n.func
    if isinstance(f, ast.Attribute) and f.attr in LOG:          # logger.info(...)
        return True
    if (isinstance(f, ast.Call) and isinstance(f.func, ast.Name)  # getattr(logger, lvl)(...)
            and f.func.id == "getattr" and f.args):
        base = f.args[0]
        name = getattr(base, "id", "") or getattr(base, "attr", "")
        return "log" in name.lower()
    return False


for f in root.rglob("*.py"):
    try:
        tree = ast.parse(f.read_text(encoding="utf-8", errors="replace"))
    except (SyntaxError, OSError, UnicodeError) as e:
        skipped.append((f, type(e).__name__))       # LOC-16 shape 3: never silently
        continue
    for n in ast.walk(tree):
        if is_log_call(n) and n.args and (
                not isinstance(n.args[0], ast.Constant) or len(n.args) > 1):
            print(f"{f.relative_to(root)}:{n.lineno}")

if skipped:
    print(f"NOT READ: {len(skipped)} file(s) — this enumeration does NOT cover them:",
          file=sys.stderr)
    for f, why in skipped:
        print(f"  {f}: {why}", file=sys.stderr)
PY
```

**The dynamic-dispatch clause is not decoration, and it was added for a measured reason.**
Without it the query missed `CVE-2025-48432` entirely: Django selects the level at runtime
with `getattr(logger, level)(message, *args, ...)`, so the call is a `Call` and not an
`Attribute`, and 206 sites came back from 2,839 files with the vulnerable one absent. Adding
the clause returns **207** — exactly one more, and that one is the advisory. A query that
misses the defect it was written for is worse than no query, because the empty result reads
as coverage.

**The skip list is the same argument, one level down.** The loop used to swallow every
`SyntaxError` and move on, so a file it never parsed was indistinguishable from a file with
no log calls. Measured on a two-file fixture: one file holding an attacker-controlled log
call plus one file this interpreter cannot parse returned `plain.py:3` and exit code `0`,
with no mention of the second — the enumeration built to stop silent misses was itself
missing silently. It now names what it did not read, on stderr so it can never be mistaken
for a call site. The class is `LOC-16` in `local-app.md`; the reason `errors="ignore"` became
`errors="replace"` and the encoding became explicit is the same procedure.

It lists every logging call whose message is not a plain literal — deferred `%s` included,
because deferring changes when the string is built and nothing about what ends up in it. On
the 569-file repository above it returns **218** sites, one of which is the advisory. 218 is
a list a reviewer works through; 569 files is not. Adapt the accessor names for the language
in front of you; the shape of the query is what carries over.

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

## §12 Encoding, charset and normalisation

### WEB-29 A response whose character encoding the server never declares

**Where to look**
- Django: `HttpResponse(content_type="text/html")` with no `; charset=`; a view rebuilding the header by hand; `FileResponse`/`serve()` over an upload directory.
- Express: `res.set('Content-Type','text/html')` followed by `res.end(buf)` — the charset is appended only for string bodies by `res.send`; `express.static` pointed at uploads; a header rewritten inside the error handler.
- Spring: `@GetMapping(produces = "text/html")` and `ResponseEntity` built from `MediaType.TEXT_HTML` — neither carries a charset parameter.
- Rails: `render plain:`, `send_data type:` and `send_file` with no `charset:`. PHP: hand-written `header('Content-Type: text/html')`, an empty `default_charset`, `header()` called after output began (ignored, silently).
- The proxy layer counts: nginx `charset`/`types`, a CDN or WAF rewriting `Content-Type`. The framework default in the source is not the header on the wire.

**Vulnerable pattern** — a response carrying attacker-influenced bytes and no encoding declaration: the producer leaves the decoding to whoever reads it. `Content-Type: text/html` on a page echoing a stored profile field, or on a file whose bytes the uploader chose. The defect is the missing declaration; which decoder gets picked is a property of the consumer, not of the response.

> Checked, not folklore: UTF-7 is absent from the WHATWG Encoding Standard's table and that standard requires user agents "must not support any other encodings or labels". The 2010-era UTF-7 XSS is **historical** against a conforming browser — do not write it up as a live vector. The general case above is what survives.

**What rules it out (false positive)**
- The header does carry `charset=utf-8` **on the wire**. Measure it; do not infer it from the source.
- `application/json`: JSON is UTF-8 by definition and the parameter is undefined for it. Not a finding.
- The body is server-generated on every branch, with no external input (`FP-02`).
- `X-Content-Type-Options: nosniff` constrains MIME **type** sniffing; it supplies no charset, so on its own it does not close this. It narrows the type-confusion half only — `FP-10` at most, never `FP-01`.
- Not rendered as a document: `Content-Disposition: attachment`, or an API whose only client decodes explicitly.

Rules: FP-02, FP-10.

**Minimal test** — local, non-destructive: run the app on loopback and read the header rather than the code — `curl -sI http://127.0.0.1:PORT/ROUTE | grep -i '^content-type:'` — once per route *class*: HTML view, error page, static/upload handler, API. The gap is normally one handler, not the application. For a stored file, compare declaration against bytes with `file --mime-encoding FILE`.\
**Traceability**: `CWE-172` · `CWE-838` · `CWE-116` · `WSTG-CLNT-*` · `ASVS 5.0 V1` · `A05:2025`\
**Tooling**: `grep -rn "Content-Type" --include='*.py' --include='*.js' --include='*.rb' --include='*.php' .` finds the hand-written headers; only the wire settles it.

### WEB-30 Normalisation or case folding applied after the check

**Where to look**
- Python/Django: `unicodedata.normalize("NFKC"|"NFKD", ...)`, `str.casefold()`, `slugify()` (NFKD inside), `AbstractUser.normalize_username` (NFKC) running *after* a `clean_*` validator; `username__iexact` lookups.
- Node: `s.normalize('NFKC')`, `validator.normalizeEmail`, `path.normalize` or `decodeURIComponent` placed after an allowlist check.
- Java/Spring: `Normalizer.normalize(s, Form.NFKC)`; `toLowerCase()`, `toUpperCase()` and `equalsIgnoreCase` with **no `Locale` argument** — the JVM default locale decides, and a Turkish locale maps `I`→`ı` and `i`→`İ`.
- Rails: `String#unicode_normalize(:nfkc)`, `downcase` versus `downcase(:turkic)`, `Inflector.transliterate`; `find_by("lower(email) = ?")` against a column collation that folds differently.
- PHP: `Normalizer::normalize()`, `mb_strtolower`, and `iconv('UTF-8','ASCII//TRANSLIT',$s)`, which manufactures ASCII lookalikes after validation.

**Vulnerable pattern** — the value is validated, then transformed, then used, and the transformation collapses a character the filter accepted into one it would have rejected. Two mechanisms, overlapping but not equal, and the difference decides which probe finds the defect. Measured by codepoint on CPython 3.9, because U+212A and `K` render identically and a probe that compares rendered strings agrees with whatever it was told:

| Input | `unicodedata.normalize("NFKC", …)` | `str.casefold()` |
|---|---|---|
| `＜` U+FF1C, and the fullwidth `．／％` | `<`, `./%` — the metacharacters | unchanged |
| `ẞ` U+1E9E | unchanged | `ss` |
| `ſ` U+017F long s | `s` | `s` |
| `K` U+212A kelvin sign | `K` | `k` |
| `ı` U+0131 dotless i | unchanged | unchanged |

So a filter tested only against fullwidth characters misses a folding path, and one tested only against `ẞ` misses a normalising path. U+0131 belongs to neither: `admın` survives both mechanisms and becomes `admin` under an `upper()`→`lower()` round trip, which is what a Turkish-locale `toUpperCase()` produces in Java and what a `lower(email)` comparison produces against a collation that folds differently from the application. Example: `if not re.search(r"[<>]", s): s = unicodedata.normalize("NFKC", s)`.

**What rules it out (false positive)**
- The order is normalise → validate → use, with **no** transformation after the check. Name the three call sites in order (`FP-01`).
- The allowlist is ASCII-only and applied after the last transformation: the collapse has nothing left to smuggle.
- The sink escapes by context after the transformation — a template escaping at render, a bound parameter — so the collapsed character is inert where it lands (`FP-03`).
- Identity is decided on an immutable server-side key (numeric id, UUID) and the normalised string is only a label (`FP-02`).
- Non-Latin text is normalised because correct handling of Arabic, Hebrew or CJK requires it: `FP-09` covers exactly this. Normalising is not the defect; normalising *after* deciding is.

Rules: FP-01, FP-03, FP-09.

**Minimal test** — local unit test, no target needed: feed `U+FF1C U+FF1E U+FF0E U+FF0F U+FF05 U+FE64 U+2024 U+017F U+212A U+FB00 U+0131 U+0130` through the application's **own** validator and then its **own** transformation, in the production order, and diff. `python3 -c 'import unicodedata as u; print(u.normalize("NFKC","＜ſcript＞ ．．／"), "abcK".casefold())'` shows what each mechanism produces. Any probe the validator accepts and the transformation turns into a metacharacter — or into another user's identifier — is the finding.\
**Traceability**: `CWE-176` · `CWE-1289` · `CWE-20` · `WSTG-INPV-*` · `ASVS 5.0 V1` · `A05:2025`\
**Tooling**: `grep -rn "NFKC\|NFKD\|normalize(\|casefold\|toLowerCase()\|equalsIgnoreCase\|TRANSLIT" .` → then read the order of operations. A hit is a candidate; the sequence is the defect.

### WEB-31 Two layers, two charsets: validated in one, interpreted in another

**Where to look**
- Connection charset: PHP `SET NAMES` instead of `mysqli::set_charset()` or a PDO DSN `charset=`; JDBC `characterEncoding=`; Django `OPTIONS={'charset': ...}`; Rails `database.yml` `encoding:`. Flag any multibyte connection charset — `gbk`, `big5`, `sjis`, `cp932`.
- Column versus connection: MySQL `utf8` is `utf8mb3` (3 bytes) and is not `utf8mb4`; a `latin1` column behind a UTF-8 application. Postgres: a `SQL_ASCII` database stores bytes with no validation or conversion, and a `client_encoding` that disagrees with it.
- Truncation policy: `sql_mode` without `STRICT_TRANS_TABLES` — an unrepresentable value is cut instead of rejected.
- File and template layer: Python `open(path)` with no `encoding=` (the locale decides) and `errors='replace'`/`'ignore'`/`'surrogateescape'`, which repair malformed input instead of rejecting it; Java `new String(bytes)`/`getBytes()` with no `Charset`; a template read as `latin-1` and served as UTF-8.

**Vulnerable pattern** — escaping or validation happens under one charset and interpretation under another. The sharp case: the driver escapes assuming a single-byte charset while the server reads the connection as `gbk`, so a lead byte swallows the added backslash and releases the quote into the statement. The quiet case: the value is silently truncated at the first character the target column cannot represent, so `attacker@evil.com` + a 4-byte character + `@corp.example` is stored as the attacker's address alone, and every later check reads a string nobody validated.

**What rules it out (false positive)**
- Real server-side prepared statements — `PDO::ATTR_EMULATE_PREPARES = false`, parameters that never travel as text. Nothing is escaped, so nothing is escaped wrongly (`FP-01`, `FP-03`). This is the control that closes most of these and the one reports keep missing.
- The connection charset is single-byte or UTF-8: there are no lead bytes to consume the escape.
- `STRICT_TRANS_TABLES`, or Postgres, which errors by default: truncation becomes an error — unless a path catches it and continues, which is the finding again.
- The whole path is `utf8mb4`, connection included, with the column metadata to prove it.
- The truncated field feeds display only and no security decision hangs off it (`FP-07`).

Rules: FP-01, FP-03, FP-07.

**Minimal test** — local, against a throwaway copy, no writes to production data: `SELECT @@character_set_client, @@character_set_connection, @@sql_mode;` then `SELECT TABLE_NAME, COLUMN_NAME, CHARACTER_SET_NAME FROM information_schema.COLUMNS WHERE CHARACTER_SET_NAME <> 'utf8mb4';`. Insert a 4-byte character (U+1F600) and a `latin1`-unrepresentable one into a copy of the table **through the application's own connection**, read the row back and compare byte for byte. A shorter string coming out than went in is the defect, with no exploitation needed.\
**Traceability**: `CWE-436` · `CWE-175` · `CWE-173` · `CWE-20` · `WSTG-INPV-*` · `ASVS 5.0 V1` · `A05:2025`\
**Tooling**: `grep -rn "SET NAMES\|set_charset\|characterEncoding\|utf8mb3\|charset=latin1\|SQL_ASCII\|errors=" .` → then confirm against the live session variables, because the connection string is not always what the driver negotiated.
