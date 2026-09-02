# Knowledge pack — Web and API AppSec (client surface, business logic, crypto and protocols)

> **When to load this file:** second file of the `web-api` pack. Load it when the inventory has browser-rendered output or client-side sinks, cross-origin or caching configuration, business flows moving money, state or quotas, cryptography or secret handling, GraphQL or persistent channels, or any control whose presence is being taken as proof that it works.
> **Do not load it if:** the work is confined to authentication, authorization, injection, SSRF, deserialization or file handling — those are `web-api.md` §0-§5 — or to errors and logs, which are §11 in `web-api-logging.md`.
> **Cost:** ~306 lines. Load by section using the index. The entry point of the pack, `web-api.md`, holds §0-§5 with `WEB-01`..`WEB-12`, `WEB-24` and `WEB-25`; its §0 lists the classes tooling systematically misses and is worth reading first. The third file, `web-api-logging.md`, holds §11 with `WEB-22` and `WEB-28`, and §12 with `WEB-29`..`WEB-31` — encoding, charset and normalisation, which is where a filter and the thing it protects read the same bytes as different characters.

## Selective loading index

| Section | Load it if the inventory has | Procedures |
|---|---|---|
| §6 XSS and client-side sinks | HTML templates, React/Vue, Markdown, postMessage | WEB-13..WEB-14 |
| §7 CSRF, CORS and caching | cookies, `Access-Control-*`, CDN or proxy | WEB-15..WEB-16 |
| §8 Business logic, rate limiting and idempotency | payments, balances, coupons, retries, queues | WEB-17..WEB-18 |
| §9 Crypto, secrets and the controls that are only apparent | hashing, homegrown encryption, `.env`, TLS; declared limits, validators, verifiers | WEB-19, WEB-23, WEB-26, WEB-27 |
| §10 GraphQL and persistent channels | `/graphql`, WebSocket, SSE | WEB-20..WEB-21 |

Section §11 (`WEB-22`, `WEB-28`) is in `web-api-logging.md`. Open it whenever the target logs anything an outside caller can influence.

## How to use a procedure

The six fields are a contract, not decoration. **"What rules it out" is mandatory before you report**: if a compensating control applies, the finding drops to informational or is closed. "Minimal test" is local and non-destructive unless explicitly marked otherwise. A grep hit or a tool match is a candidate, never a confirmed finding, until you trace input → transformation → sink and demonstrate impact. The full statement of the contract is in `web-api.md`.

## §6 XSS and client-side sinks

### WEB-13 XSS in server-side rendering

**Where to look**
- Jinja2/Django: `|safe`, `{% autoescape off %}`, `mark_safe(`; Rails `raw`, `html_safe`, `sanitize` with a permissive allowlist.
- Handlebars `{{{...}}}`, EJS `<%- %>`, Thymeleaf `th:utext`, Blade `{!! !!}`, Razor `@Html.Raw`.
- Non-HTML contexts inside the template: data placed inside a `<script>` block, in an event attribute or in a URL (`href="{{ url }}"` accepts `javascript:`).

**Vulnerable pattern** — automatic escaping is disabled for a value that at some point came from the user (profile, comment, imported field), or the value lands in a context where HTML escaping is not the right one (JavaScript, attribute, URL, CSS).

**What rules it out (false positive)**
- The value marked as safe is generated entirely on the server and incorporates no external input on any branch.
- Sanitization with an allowlist library (`bleach`, `sanitize-html`, DOMPurify server-side) applied **after** the last transformation.
- A strict CSP with a nonce and no `unsafe-inline`: it reduces impact but does not remove the defect; adjust severity, do not close it.

Rules: FP-01, FP-02, FP-10.

**Minimal test** — local: store an inert payload that only marks execution (`<svg onload=window.__xss=1>`) and check in the rendered HTML whether it comes out escaped or literal. No cookie theft and no outbound requests.

**Traceability**: `CWE-79` · `CWE-116` · `WSTG-INPV-*` · `ASVS 5.0 V1` · `A05:2025`
**Tooling**: `grep -rn "mark_safe\|html_safe\|Html.Raw\|{{{\|th:utext" .` → CWE-79 is among the worst detected by SAST; enumerate by hand every point where escaping is disabled.

### WEB-14 Client-side sinks, DOM XSS and CSP

**Where to look**
- React `dangerouslySetInnerHTML`; Vue `v-html`; Angular `bypassSecurityTrustHtml`; Svelte `{@html ...}`.
- Plain DOM: `innerHTML`, `outerHTML`, `document.write`, `insertAdjacentHTML`, `eval`, `setTimeout` with a string, `location`/`href` assigned from `location.hash` or `searchParams`; `addEventListener("message", ...)` without checking `event.origin`; `postMessage(..., "*")`.
- Headers: `Content-Security-Policy` (look for `unsafe-inline`, `unsafe-eval`, host wildcards), `X-Content-Type-Options`, `Referrer-Policy`, `frame-ancestors`; in Next.js, `headers()` in `next.config` and the middleware.

**Vulnerable pattern** — data from the URL, from local storage or from a cross-window message reaches a sink that interprets HTML or JavaScript. In an SPA the source is often the fragment (`#`), which never reaches the server: it will not show up in the logs.

**What rules it out (false positive)**
- The value passes through an allowlist sanitizer right before the sink, or the sink receives text (`textContent`, normal framework interpolation).
- The `message` handler validates `event.origin` against a closed list and validates the message schema.
- The string is a bundle constant and does not depend on the URL or on storage.

Rules: FP-01, FP-02, FP-03.

**Minimal test** — local, with the app served on your machine: put the inert marker in the URL fragment and observe whether it executes (setting a global variable, no network).

**Traceability**: `CWE-79` · `CWE-1021` · `CWE-346` · `WSTG-CLNT-*` · `ASVS 5.0 V3` · `A05:2025` · `A02:2025`
**Tooling**: `grep -rn "dangerouslySetInnerHTML\|innerHTML\|v-html\|postMessage(" .` → most matches are static content; confirm where the data comes from.

## §7 CSRF, CORS and caching

### WEB-15 CSRF and ambient credential confusion

**Where to look**
- Django `CsrfViewMiddleware` and its `@csrf_exempt` uses; Rails `protect_from_forgery` and `skip_before_action :verify_authenticity_token`; Laravel `VerifyCsrfToken::$except`; Spring `http.csrf().disable()`; ASP.NET Core `[ValidateAntiForgeryToken]`; Express with `csurf` or equivalent.
- State-changing endpoints that accept `application/x-www-form-urlencoded`, `multipart/form-data` or `text/plain` (types that do not trigger a preflight).
- APIs that accept JSON but keep the session in a cookie: check whether the cookie alone is enough to authorize with no extra header.

**Vulnerable pattern** — the request is authorized solely by a credential the browser attaches on its own (cookie, Basic, Kerberos). The classic case: CSRF was disabled "because it is an API" while the session still lives in a cookie.

**What rules it out (false positive)**
- Authorization exclusively through the `Authorization` header, with no alternative cookie path.
- A session cookie with `SameSite=Lax` or `Strict` **and** an unsafe method (`POST`, `PUT`, `DELETE`); `Lax` does not protect a state-changing `GET`.
- An anti-CSRF token verified server-side, bound to the session and not reflected to another origin.

Rules: FP-01, FP-09.

**Minimal test** — local: replay a state-changing request with no anti-CSRF token and no custom headers against your instance; it must fail.

**Traceability**: `CWE-352` · `WSTG-SESS-*` · `ASVS 5.0 V3` · `A01:2025`
**Tooling**: `grep -rn "csrf_exempt\|csrf().disable()\|skip_before_action :verify" .` → every exemption must be justified; not all of them are vulnerable.

### WEB-16 CORS, headers and caching of private responses

**Where to look**
- `cors()` with no options in Express, `CORS_ALLOW_ALL_ORIGINS` in Django, `@CrossOrigin("*")` in Spring, `AllowAnyOrigin().AllowCredentials()` in ASP.NET Core.
- Origin reflection: code that copies `req.headers.origin` into `Access-Control-Allow-Origin`, or validates with unanchored `startsWith`/`endsWith`/regex (`yourdomain.com.example.invalid`).
- Caching: `Cache-Control` on authenticated responses, missing `Vary` when the response depends on a header, a CDN or proxy that ignores `Set-Cookie`, and cache keys that drop relevant parameters.

**Vulnerable pattern** — a reflected origin together with `Access-Control-Allow-Credentials: true` turns any page into an authenticated reader of the API. In caching, a personalized response stored on a shared node is served to another user, and the same mechanism allows poisoning through a header that is not part of the cache key.

**What rules it out (false positive)**
- An allowlist of exact origins with full comparison, and no credentials when the origin is a wildcard.
- Authenticated responses with `Cache-Control: no-store` or `private` and a correct `Vary`.
- The endpoint returns identical data for every user and carries no credentials.

Rules: FP-01, FP-07.

**Minimal test** — local: issue a request with an arbitrary `Origin` against your instance and review the response headers, including those of the authenticated routes.

**Traceability**: `CWE-942` · `CWE-524` · `CWE-346` · `WSTG-CONF-*` · `WSTG-CLNT-*` · `ASVS 5.0 V13` · `A02:2025` · `API8:2023`
**Tooling**: `curl -sI -H "Origin: https://example.invalid" http://localhost:PORT/route` → look at `Access-Control-Allow-Origin`, `-Credentials` and `Cache-Control`; against a remote host, **REQUIRES AUTHORIZATION**.

## §8 Business logic, rate limiting and idempotency

### WEB-17 Race conditions, TOCTOU and idempotency

**Where to look**
- Read-decide-write sequences with no transaction or lock: check the balance then debit it, validate a coupon then mark it used, verify stock then reserve it.
- Missing `select_for_update()` (Django), `with_lock`/`lock!` (Rails), `SELECT ... FOR UPDATE`, `@Transactional` at an adequate level, `Clause{Locking}` in gorm, or missing unique constraints in the database.
- Payment, redemption, transfer and quota-bound creation endpoints, and queue consumers with no idempotency key.

**Vulnerable pattern** — two concurrent requests clear the same check before either one writes: double redemption, negative balance, exceeded quota. The code reads perfectly in sequence and no SAST detects it.

**What rules it out (false positive)**
- A unique or `CHECK` constraint in the database that makes the second write fail, with conflict handling.
- A conditional atomic update (`UPDATE ... WHERE balance >= x`) or pessimistic/optimistic locking with a version column.
- A persisted, verified idempotency key, with the original response replayed on retries.

Rules: FP-01.

**Minimal test** — local: a test that fires N concurrent requests at the same resource and checks the invariant (a single redemption). Concurrency against a remote environment: **REQUIRES AUTHORIZATION**.

**Traceability**: `CWE-367` · `CWE-362` · `CWE-841` · `WSTG-BUSL-*` · `ASVS 5.0 V2` · `A06:2025`
**Tooling**: no static tool covers this reliably; locate the business invariants and test concurrency by hand.

### WEB-18 Rate limiting and business flow abuse

**Where to look**
- Limiting middleware: `express-rate-limit`, `django-ratelimit` or DRF `throttle_classes`, `Rack::Attack`, Laravel's `RateLimiter`, `bucket4j`; check whether the key is the IP (evadable) or the identity, and whether it covers the expensive route.
- Costly operations with no quota: SMS and email sending, PDF generation, exports, unpaginated searches, endpoints accepting arbitrarily large lists.
- Implicit business rules: stackable discounts, repeated partial refunds, negative or decimal quantities, client-supplied prices.

**Vulnerable pattern** — a legitimate flow runs at a rate or in an order the design never anticipated: a thousand coupons a minute, a refund larger than the payment, an order with quantity `-1` that credits the balance; also unbounded resource consumption from valid requests.

**What rules it out (false positive)**
- Limits per identity **and** per resource, enforced server-side, with cost proportional to the operation.
- Domain validation of the value (range, sign, precision) and invariants verified server-side against the authoritative price.
- A queue with concurrency control and a per-account budget for the expensive operation.

Rules: FP-01.

**Minimal test** — local: send boundary values (zero, negative, very large, decimal, different unit) and check the invariant. Sustained load against a remote environment: **REQUIRES AUTHORIZATION**.

**Traceability**: `CWE-770` · `CWE-799` · `CWE-20` · `WSTG-BUSL-*` · `ASVS 5.0 V2` · `A06:2025` · `API4:2023` · `API6:2023`
**Tooling**: enumerate routes and cross them against the limiter configuration; the missing rule is the finding, and no tool will propose it.

## §9 Cryptography and secrets

### WEB-23 A declared limit that nothing enforces
**Where to look**
- A constant whose **name states a bound** — `Max*`, `*Limit`, `*MB`, `*Timeout`, `*Quota`, `*TTL`, `*Burst`, `*MaxAge` — declared in a config or constant module and assigned from the environment. Then search for its **readers**. Zero readers inside the scope you were given is the finding.
- The same shape one level up: a middleware or decorator that is defined and never registered on any route; a validator function defined and never called; a feature flag that gates nothing; a `.Use(...)` list that omits the limiter the config file configures.
- Highest yield on **unauthenticated** handlers — webhooks, callbacks, uploads, health and metrics — because there the missing limit is reachable with no credential at all.

**Vulnerable pattern**
```go
// constant/env.go
var MaxRequestBodyMB int                                   // declared

// common/init.go
constant.MaxRequestBodyMB = GetEnvOrDefault("MAX_REQUEST_BODY_MB", 128)   // assigned, documented

// nothing anywhere calls http.MaxBytesReader, c.Request.Body = ..., or reads
// constant.MaxRequestBodyMB. The knob exists, the operator can set it, the
// deployment guide mentions it, and every request is still unbounded.
```
**What rules it out (false positive)**
- The reader is real and lives outside the files you were given. That is `UNKNOWN`, not `HOLDS`: report the search you ran and its bound, and say which package would settle it. A partial scope is the normal case for this class and it is the reason to write the limit down rather than drop it.
- The value is consumed by name rather than by symbol — dependency injection, reflection, a template, generated code, a `viper`/`env`-tagged struct read wholesale — so a symbol search finds no reader and the enforcement is real. Prove it by naming the consumer.
- A layer in front enforces the same bound and its configuration arrived: an ingress `proxy-body-size`, an API gateway, a WAF. Without that artifact the answer is `UNKNOWN` (`FP-08`), because "the platform takes care of it" is how a real finding disappears.

Rules: FP-08, FP-09.

**Minimal test**: list every constant whose name declares a bound, and for each one count its readers — `rg -n 'MaxRequestBodyMB|MaxUploadMB|RateLimitBurst'` and subtract the declaration and the assignment. Zero is the finding; one reader that is itself never called is the same finding one level down. Then cross-reference the routes that reach the unlimited path with the ones that need no credential.\
**Traceability**: `CWE-400` · `CWE-770` · `CWE-1188` · `A04:2025` · `A05:2025` · `ASVS 5.0 V11` · `NIST 800-53 SC`\
**Tooling**: no scanner reports this, and the reason is worth knowing: dead-code analysis flags **unused** symbols, and a package variable that is assigned at start-up is used — `staticcheck`'s `U1000` and its equivalents stay quiet on exactly this shape. `rg` and the question *who reads this* are the tool. This procedure exists because a blinded three-arm run — the corpus, an unaided senior engineer and a competing product — **all three missed** a published advisory of exactly this shape, and one of them read the declaration as proof the control was present (`bench/runs/2026-08-21-three-arm-go/`).

### WEB-27 A control that runs, and cannot fail

`WEB-23` finds the control that never runs. This finds the one that runs: registered, called, returning — with no path in its body that says no. The two are not the same axis, and this one is the more expensive, because an **absent control adds a finding while an inert control deletes them**. Taint analysers model a sanitiser by name or by configured signature, so a function called `sanitize_input()` that returns its argument unchanged **clears the taint** and removes every downstream finding. In this corpus's own triage it is the canonical way to answer `FP-01` wrongly: a compensating control is named, and it compensates nothing.

**Where to look**
- Predicates whose name promises a decision — `is_valid`, `check_*`, `verify_*`, `validate_*`, `authorize`, `has_permission`, `sanitize_*`, `escape_*` — whose body has **no branch that returns the negative**: a single `return True`, a body that only logs, a `pass` in the failure arm, a `TODO` where the comparison belongs.
- Comparisons that read one operand: `if token:` where a value should be compared, an equality against something derived from the same input, `hmac.compare_digest(a, a)`.
- The exception that swallows the decision: `try: verify(...) except Exception: pass`, `except: return True`, `.catch(() => true)`.
- `assert` used as the control where the interpreter can be run with assertions disabled; a check behind a debug-only flag.
- **The caller.** `validate(x)` on a line of its own, with nothing branching on the result, is a control nobody consults — and it is the variant that reads best in review.

**Vulnerable pattern**
```python
def verify_signature(payload, signature):
    expected = hmac.new(KEY, payload, hashlib.sha256).hexdigest()
    if not signature:                 # the only rejection
        return False
    return True                       # expected is computed and never compared
```
**What rules it out (false positive)**
- The framework performs the real check and this function is a hook it wraps. Name the framework call and the version.
- It is a base-class default that every subclass in use overrides. Show the subclasses, not the base.
- The real control is elsewhere and this is defence in depth: that is `FP-10` — the severity drops, the finding is still written.
- The permissive arm does not exist in what ships: a test double, a development branch, a path behind a flag production does not set (`FP-04`).

Rules: FP-01, FP-04, FP-09, FP-10.

**Minimal test** — one test per candidate, and it is a *negative* test: feed the control a value that **must** be rejected and assert the rejection. A control that cannot be made to fail is the finding, and the failing test is the evidence. Then check the callers with `rg -n 'validate\(|verify_|is_valid' .` and mark every call whose result is not branched on. Do this **before** trusting any clean analyser result over the same code: a green scan downstream of an inert sanitiser is the scan agreeing with the defect.\
**Traceability**: `CWE-754` · `CWE-390` · `CWE-697` · `CWE-345` · `CWE-20` · `WSTG-BUSL-*` · `ASVS 5.0 V1` · `A04:2025`
**Tooling**: no scanner reports it and several are actively silenced by it. The nearest published mechanism is Veracode's own explanation of why generated code resolves output encoding so poorly — sanitisation appearing as a reaction to a **common variable name** rather than to a dataflow fact — which is exactly a control placed by resemblance instead of by need. **State the limit out loud when you report this class: nobody has published a prevalence figure for it.** The procedure stands on its mechanism and on its cost, not on a rate, and `bench/cases/` is where this repository measures it rather than asserting it. `SUP-22` is the same axis in the supply chain, where the verification accepts any signer; treat both as failed controls, never as hardening suggestions, because the project already believes it holds them.

### WEB-26 A length from the wire decides the size of an allocation
**Where to look**
- Any decoder that reads a **count or a length from untrusted input and uses it to size something** before the payload arrives: `new byte[len]`, `make([]T, n)`, `new T[count]`, `ByteBuffer.allocate(len)`, `malloc(n)`, `Array.new(n)`, a pre-sized list from a declared element count.
- The guard beside it. A cast-safety test (`len < Integer.MAX_VALUE`, `n >= 0`) is **not** a limit: it stops the arithmetic from wrapping and lets everything below the ceiling through. The question is whether the value is compared against something the peer does **not** control — a configured maximum, the bytes actually remaining in the frame, the size of the buffer already read.
- Two neighbours of the same family, in the same files: **mutual recursion with no depth counter** (`readValue` → `readTable` → `readArray` → `readValue`), where nesting costs the attacker a few bytes per stack frame; and a length **multiplied or added** without an overflow check (`count * itemSize`, `offset + len`).
- Highest yield **before authentication**: a protocol greeting, a server-properties table, a TLS-less handshake, a webhook body, anything parsed to decide who the peer is.

**Vulnerable pattern**
```java
long contentLength = readUnsignedInt();          // four bytes, peer's choice
if (contentLength < Integer.MAX_VALUE) {         // a cast guard, not a limit
    byte[] buffer = new byte[(int) contentLength];   // ~2 GB committed here
    in.readFully(buffer);                        // ... and only now does it fail
}
```
**What rules it out (false positive)**
- The length is checked against a bound the peer does not set — a configured maximum, the negotiated frame size, `min(declared, remaining)` — **and that check runs before the allocation**. Quote both lines and their order; a limit applied after the array exists has already lost.
- The structure grows as bytes arrive rather than being pre-sized: appending to a builder, `ByteArrayOutputStream`, a chunked read loop whose total is capped.
- There is no second principal: the input comes from the same trust domain as the process, and `local-app.md` §0 can name why.

Rules: FP-01, FP-02, FP-06.

**Minimal test**: list every allocation whose size expression traces back to input — `rg -n 'new byte\[|allocate\(|make\(\[\]|malloc\(' ` — and for each one name, in writing, **the check that bounds it and the line it is on**. An allocation with no such line is the finding; a check that only prevents a cast from wrapping is an allocation with no such line. Then walk the recursive entry points and look for a depth parameter: if the signature does not carry one, there is no cap.\
**Traceability**: `CWE-789` · `CWE-400` · `CWE-674` · `CWE-190` · `A04:2025` · `ASVS 5.0 V11` · `NIST 800-53 SC`\
**Tooling**: nothing reports this reliably. It is a data-flow question with a semantic step in the middle — *is this bound attacker-controlled* — that a taint tracker cannot answer, so the sink looks guarded to it. `rg` for the allocations and read the guard yourself. This procedure exists because it was **missed twice, by us, and named by us in between**: a specialist reported the class as `ad-hoc` and wrote that *"resource exhaustion from untrusted input in a binary decoder has no procedure in this corpus"*; the write-up was deferred so it could not contaminate a round then in flight; and in the next run — a whole repository, no pointer — the corpus arm **had the right file open, reported the neighbouring recursion, and missed the allocation**, while an unaided engineer found it (`bench/runs/2026-08-21-whole-repo-3arm/`).

### WEB-19 Crypto in transit and at rest, and secret management

**Where to look**
- Password hashing: `md5`, `sha1` or bare `sha256` versus bcrypt, scrypt or Argon2 (`BCryptPasswordEncoder`, `password_hash`, `PasswordHasher`).
- Symmetric encryption: ECB mode, a fixed or null IV, unauthenticated encryption (CBC without HMAC) instead of AES-GCM; keys derived from a short string; `Math.random`/`new Random()` for tokens or session identifiers.
- Secrets and TLS: a versioned `.env`, keys in `settings.py`/`application.properties`/`appsettings.json`, a default `SECRET_KEY`, `DEBUG=True`, `verify=False`, `rejectUnauthorized: false`, `TrustAllCerts`, `InsecureSkipVerify: true`.

**Vulnerable pattern** — cryptography assembled by hand (choosing mode, IV and padding in application code) or TLS validation disabled "for development" and inherited by production. A versioned secret is compromised from the moment it was pushed: the finding is the exposure and the rotation, not silently replacing the file.

**What rules it out (false positive)**
- Authenticated primitives from a maintained library, with keys injected from a secret manager and rotatable.
- The value is a test value, plainly inert, and the real environment uses another source (verify it, do not assume it from the filename).
- The weak hash is a checksum unrelated to security (deduplication, caching) and governs no access decision.

Rules: FP-01, FP-04, FP-09.

**Minimal test** — local: `git log -p -- <configuration file>` to see whether a secret was ever versioned; encrypt the same plaintext twice and compare the output (identical ⇒ ECB or a fixed IV). Do not use the secret you found and do not transcribe it in full.

**Traceability**: `CWE-327` · `CWE-330` · `CWE-798` · `CWE-916` · `CWE-295` · `WSTG-CRYP-*` · `ASVS 5.0 V11` · `ASVS 5.0 V12` · `A04:2025` · `A02:2025`
**Tooling**: `gitleaks detect --no-banner` or `grep -rn "verify=False\|InsecureSkipVerify\|MODE_ECB" .` → secret scanners fire on any high-entropy string; validate the format before escalating and never paste the full value.

## §10 GraphQL and persistent channels

### WEB-20 GraphQL: authorization, introspection and query cost

**Where to look**
- Schema and resolvers: `schema.graphql`, `resolvers.ts`, `graphene`, `strawberry`, `graphql-java`, Absinthe. Authorization must live in every resolver or in the service layer, not only on the `/graphql` route.
- Server configuration: introspection or playground enabled in production, missing `depthLimit`/`costAnalysis`, unbounded operation batching.
- Mutations exposing internal fields and nested resolvers that query the database per element.

**Vulnerable pattern** — an authenticated endpoint whose resolvers do not re-check object ownership reproduces BOLA at scale. Deep or cyclic queries turn one request into thousands of operations, and alias batching defeats limits based on request counts.

**What rules it out (false positive)**
- Authorization in the data layer, traversed by every resolver and covered by per-type tests.
- Depth, complexity and operations-per-document limits, plus persisted queries in production.
- Introspection disabled outside development (hardening, not an access control on its own).

Rules: FP-01, FP-10.

**Minimal test** — local: run an introspection query against your instance and review the exposed types and mutations; with two synthetic users, check that a nested resolver does not return another user's data. Against a remote server: **REQUIRES AUTHORIZATION**.

**Traceability**: `CWE-639` · `CWE-770` · `WSTG-APIT-01` · `ASVS 5.0 V4` · `A01:2025` · `API1:2023` · `API4:2023`
**Tooling**: `grep -rn "introspection\|depthLimit\|costAnalysis" .` → their absence suggests default configuration; confirm at server startup.

### WEB-21 WebSocket, SSE and long-lived channels

**Where to look**
- Servers: `ws`, `socket.io`, Django Channels (`consumers.py`), Spring `SimpMessagingTemplate`, Rails ActionCable, ASP.NET Core SignalR.
- Handshake: `Origin` validation on connect (cookies are sent regardless and the same-origin policy does not apply), and whether authentication happens on `connect` or on every message.
- Subscriptions: a channel or room name built from client data (`subscribe(room_id)` without a membership check); broadcasts that send one user's data to every connected client.

**Vulnerable pattern** — a page from another origin opens the socket with the victim's cookies because the server neither validates `Origin` nor requires its own token; or a client subscribes to someone else's channel because membership is never verified server-side. Add to that the lack of per-connection message and size limits.

**What rules it out (false positive)**
- Authentication with an explicit token in the handshake (not just a cookie) and `Origin` validated against a closed list.
- A server-side membership check every time a subscription is resolved, not only on connect.
- Per-connection quotas: message size, frequency and number of subscriptions.

Rules: FP-01.

**Minimal test** — local: connect to your instance with an arbitrary `Origin` and see whether the handshake is accepted; with two synthetic users, try to subscribe to the other user's channel.

**Traceability**: `CWE-346` · `CWE-862` · `CWE-770` · `WSTG-CLNT-*` · `ASVS 5.0 V4` · `A01:2025` · `API2:2023`
**Tooling**: `grep -rn "new WebSocket\|socket.io\|AsyncWebsocketConsumer\|ActionCable" .` → locate the handshake and read the authorization there, not in the HTTP router.
