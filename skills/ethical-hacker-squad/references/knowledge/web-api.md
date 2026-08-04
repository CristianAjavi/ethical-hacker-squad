# Knowledge pack — Web and API AppSec

> **When to load this file:** the inventory includes an HTTP server, an API (REST, GraphQL, RPC, WebSocket) or a web backend with routes, controllers, an ORM, sessions or tokens.
> **Do not load it if:** the scope is only an APK/IPA with no reachable backend, only IaC and containers, only dependencies, or a library with no network surface.
> **Cost:** ~485 lines. Load by section using the index; you do not need to read it end to end.

## Selective loading index

| Section | Load it if the inventory has | Procedures |
|---|---|---|
| §0 What tools do not see | always, before reporting | — |
| §1 AuthN and sessions | login, JWT, session cookies, OTP, OAuth | WEB-01..WEB-03 |
| §2 AuthZ | routes with `:id`, roles, tenants, admin panel | WEB-04..WEB-06 |
| §3 Injection | SQL/ORM, Mongo, shell, templates, LDAP | WEB-07..WEB-09 |
| §4 SSRF and outbound network | fetch to user-supplied URLs, webhooks, importers | WEB-10 |
| §5 Deserialization and files | pickle/Java/YAML, upload, download by path | WEB-11..WEB-12 |
| §6 XSS and client-side sinks | HTML templates, React/Vue, Markdown, postMessage | WEB-13..WEB-14 |
| §7 CSRF, CORS and caching | cookies, `Access-Control-*`, CDN or proxy | WEB-15..WEB-16 |
| §8 Business logic, rate limiting and idempotency | payments, balances, coupons, retries, queues | WEB-17..WEB-18 |
| §9 Crypto and secrets | hashing, homegrown encryption, `.env`, TLS | WEB-19 |
| §10 GraphQL and persistent channels | `/graphql`, WebSocket, SSE | WEB-20..WEB-21 |
| §11 Errors and logs | exception handlers, logging, stack traces | WEB-22 |

## How to use a procedure

The six fields are a contract, not decoration. "Where to look" narrows the search; "Vulnerable pattern" defines the concrete construct that makes it exploitable; **"What rules it out" is mandatory before you report**: if a compensating control applies, the finding drops to informational or is closed. "Minimal test" is local and non-destructive unless explicitly marked otherwise. Do not treat a grep hit or a tool match as a confirmed finding: it is a candidate until you trace input → transformation → sink and demonstrate impact.

## §0 What tools do not see

A clean SAST run is not evidence that no vulnerabilities exist. Measured over 27 real projects (1.15M LoC, 192 known vulnerabilities), each tool misses between 47% and 80% of the real vulnerabilities (Lipp et al., ISSTA 2022). On the SAP Java dataset, Semgrep, CodeQL, FindSecBugs and Snyk individually detect between 11% and 27%, and only 38.8% when all four are combined (Bennett et al., EASE 2024); the worst-detected classes are **CWE-502**, **CWE-20** and **CWE-79**. These classes require targeted manual reading:

- **BOLA/IDOR (CWE-639, API1:2023)**: the tool sees a parameterized query on `id` and approves it; it has no idea whose `id` that is. This is the number one class in APIs. → WEB-04.
- **BFLA and property-level issues (API3/API5:2023)**: a role decorator is missing, or the serializer exposes one field too many. → WEB-05, WEB-06.
- **Business logic and flow abuse (API6:2023)**: negative prices, duplicated refunds, stackable coupons. No static rule models the invariant. → WEB-18.
- **Race conditions and TOCTOU (CWE-367)**: the code reads correctly in sequence and breaks with two simultaneous requests. → WEB-17.
- **CWE-502 and CWE-20**: deserialization sinks behind several layers of indirection, and apparent validation that does not constrain the real domain of the value. → WEB-11.
- **Cross-file chains**: source in a middleware, sink three modules away; taint tracking breaks at interfaces, dependency injection and reflection.

When reporting, distinguish "not found" from "not looked for" and state which surfaces were left uncovered.

## §1 AuthN and sessions

### WEB-01 Real verification of JWTs and self-contained tokens

**Where to look**
- Node: `jsonwebtoken` → `jwt.decode(` (does not verify) versus `jwt.verify(`; `jose` with `decodeJwt`; NestJS `JwtStrategy` with `ignoreExpiration`.
- Python: `jwt.decode(token, options={"verify_signature": False})`, `algorithms=["none"]`, `verify=False`; SimpleJWT without its own `SIGNING_KEY`.
- Java/Spring: `Jwts.parser()` without `verifyWith()`/`setSigningKey()`; Go: `jwt.Parse` whose keyfunc does not check `token.Method`.

**Vulnerable pattern** — the server trusts the payload without validating signature, algorithm, `exp`, `iss` and `aud`. Two classic variants: accepting `alg: none`, and accepting `HS256` signed with the RSA *public* key when the verifier picks the algorithm from the token's own header. Example: `const c = jwt.decode(bearer); if (c.role === "admin") {...}`.

**What rules it out (false positive)**
- `verify` with an explicit algorithm allowlist and a fixed key, plus `iss` and `aud` checks.
- The `decode` only feeds logs or metrics and authorization is resolved from the server-side session.
- Opaque tokens validated against a store (introspection), not self-contained ones.

**Minimal test** — local: sign a test token with `alg: none` and another with an arbitrary key, and pass both to the verifier in a unit test; both must be rejected. Against a remote deployment: **REQUIRES AUTHORIZATION**.

**Traceability**: `CWE-347` · `CWE-345` · `WSTG-ATHN-*` · `ASVS 5.0 V9` · `A07:2025` · `API2:2023`
**Tooling**: `grep -rn "jwt.decode\|verify_signature\|algorithms=\[" .` → it tells you where to read; conclude nothing until you see whether the result governs an access decision.

### WEB-02 Session lifecycle and cookie attributes

**Where to look**
- Express `express-session` (`cookie.secure`, `httpOnly`, `sameSite`, in-memory store in production); Rails `session_store.rb`; Laravel `config/session.php`.
- Django: `SESSION_COOKIE_SECURE`, `SESSION_COOKIE_HTTPONLY`, `SESSION_COOKIE_SAMESITE`, `SECURE_SSL_REDIRECT`; ASP.NET Core `CookieAuthenticationOptions`; Spring `server.servlet.session.cookie.*`.
- The login handler: is the identifier regenerated on authentication? (`req.session.regenerate`, `reset_session`, `SessionAuthenticationStrategy`).

**Vulnerable pattern** — a session that survives a privilege change (fixation), a cookie without `HttpOnly`/`Secure`/`SameSite`, a logout that clears the client cookie without invalidating the server-side record, and sessions with no absolute expiry.

**What rules it out (false positive)**
- Identifier regeneration on login and on elevation, plus server-side invalidation on logout.
- `Secure` missing only in the development configuration: check the production file before reporting.
- A cookieless API with short-lived tokens and centralized revocation.

**Minimal test** — local: in a test, authenticate and compare the session identifier before and after login; inspect the `Set-Cookie` headers the app emits on your machine.

**Traceability**: `CWE-384` · `CWE-613` · `CWE-1004` · `WSTG-SESS-*` · `ASVS 5.0 V7` · `A07:2025`
**Tooling**: `grep -rn "SESSION_COOKIE\|sameSite\|httpOnly\|regenerate" .` → always separate development configuration from production configuration.

### WEB-03 Credential flows: login, recovery, OTP and enumeration

**Where to look**
- Routes `/login`, `/register`, `/forgot-password`, `/reset`, `/verify`, `/mfa`, `/resend`; `PasswordResetView` in Django, Devise in Rails, `PasswordBroker` in Laravel.
- Recovery token generation: `Math.random()`, `random.random()`, `uuid1()`, `rand()` versus `crypto.randomBytes`, `secrets.token_urlsafe`, `SecureRandom`.
- Secret comparison with `==` instead of `crypto.timingSafeEqual`, `hmac.compare_digest` or `MessageDigest.isEqual`.

**Vulnerable pattern** — different messages for "user does not exist" and "wrong password" (enumeration); a reset token that is predictable, never expires or can be reused; a short OTP with no attempt limit; a password or email change that neither requires the current password nor invalidates the remaining sessions.

**What rules it out (false positive)**
- Uniform response and timing on login and recovery, with identical wording in both cases.
- A single-use token, ≥128 bits from a CSPRNG, short-lived and stored hashed.
- Attempt lockout bound to the identity and not only to the IP, with session invalidation after the change.

**Minimal test** — local: generate 1000 tokens with the real code and check uniqueness and entropy; measure in a test the response difference between an existing and a non-existing user. Brute force against a deployed service: **REQUIRES AUTHORIZATION**.

**Traceability**: `CWE-640` · `CWE-330` · `CWE-204` · `CWE-307` · `WSTG-ATHN-*` · `WSTG-IDNT-*` · `ASVS 5.0 V6` · `A07:2025` · `API2:2023`
**Tooling**: `grep -rn "Math.random()\|uuid1()\|random.random()" .` → flags non-cryptographic PRNGs; it is only a finding if the value is used as a secret.

## §2 AuthZ: object, function and property

### WEB-04 BOLA/IDOR and tenant scoping

**Where to look**
- Every route carrying an identifier: `/:id`, `<int:pk>`, `{id}`, Next.js `[id]`; `req.params.id` flowing straight into `findById`; DRF with `queryset = Model.objects.all()` on a `RetrieveUpdateDestroyAPIView`.
- Spring: `repository.findById(id)` without `@PreAuthorize`; Rails: `Model.find(params[:id])` instead of `current_user.models.find(...)`.
- Go/gorm: `db.First(&obj, id)` without `Where("tenant_id = ?", ...)`; Laravel: route model binding without a `Policy` or `authorize()`.

**Vulnerable pattern** — the query is built solely from the client-supplied identifier: authentication exists (you know who you are) but nobody checks that the object is yours. A UUID is not an access control.

```python
class InvoiceDetail(RetrieveAPIView):
    queryset = Invoice.objects.all()   # any authenticated user reads any invoice
```

**What rules it out (false positive)**
- The queryset is scoped to the subject: `get_queryset` filters by `request.user` or tenant, or the ORM applies a mandatory scope.
- Middleware or an interceptor injects the tenant filter into every query and fails closed when it is missing.
- The object is public by design and holds no other user's data (verify this in the model).

**Minimal test** — local: an integration test with two synthetic users; A requests B's resource and must get 403/404, on read **and** on write and delete. Against a remote environment: **REQUIRES AUTHORIZATION**.

**Traceability**: `CWE-639` · `CWE-862` · `CWE-284` · `WSTG-ATHZ-*` · `ASVS 5.0 V8` · `A01:2025` · `API1:2023`
**Tooling**: there is no reliable tool for this class. Enumerate routes (`grep -rn "params.id\|params\[:id\]\|<int:pk>" .`) and review them one by one; the absence of alerts does not mean the absence of BOLA.

### WEB-05 BFLA: function-level authorization

**Where to look**
- Administrative and service routes: `/admin`, `/internal`, `/debug`, `/export`, `/impersonate`, management and metrics.
- Missing decorators: `@PreAuthorize`, `@Secured`, `[Authorize(Roles=...)]`, `permission_classes`, `@login_required`, `before_action :require_admin`, Laravel's `auth` middleware.
- The full route registry versus the list of routes that are actually protected; look for routes mounted *before* the authentication middleware.

**Vulnerable pattern** — the role check lives in the frontend (the button is not rendered) or only on the `GET`, while `POST`/`PUT`/`DELETE` stay open; also `AllowAny` inherited from a lax global default in the framework configuration.

**What rules it out (false positive)**
- Deny by default: a global filter requires a role and exceptions are declared in a short allowlist.
- The route is exposed only through a local binding or an internal network whose segmentation you can verify in the repository.
- The check lives in the service layer and every entry into the controller passes through it.

**Minimal test** — local: a test that calls every verb on the route with an unprivileged user; build the route × method × role matrix and compare it against the expected one.

**Traceability**: `CWE-862` · `CWE-863` · `WSTG-ATHZ-*` · `ASVS 5.0 V8` · `A01:2025` · `API5:2023`
**Tooling**: `grep -rn "AllowAny\|permitAll\|AllowAnonymous\|skip_before_action" .` → locates exceptions; each one needs an explicit justification.

### WEB-06 Mass assignment and property-level exposure

**Where to look**
- Node/Mongoose: `Model.create(req.body)`, `Object.assign(user, req.body)`, `findByIdAndUpdate(id, req.body)`; Prisma with `data: req.body`.
- DRF `fields = "__all__"`; Rails `params.permit!` or missing strong parameters; Laravel `$guarded = []` or `fill($request->all())`; Spring `@ModelAttribute` without a DTO; ASP.NET Core binding straight onto the EF entity.
- Output: serializers that return the whole model (`password_hash`, `is_admin`, `internal_notes`, payment provider identifiers).

**Vulnerable pattern** — input: the client adds `"role": "admin"` or `"balance": 999` to the body and the ORM persists it. Output: the API returns more fields than the UI shows, and the UI hides them at presentation level.

**What rules it out (false positive)**
- An explicit DTO with an allowlist on input and output, generated from a schema (zod, pydantic, a serializer with declared fields).
- Sensitive fields marked read-only and covered by a test.
- The model has no attribute with security impact (verify it, do not assume it).

**Minimal test** — local: send a body with an extra privileged field in a test and verify it is ignored; capture the full JSON of every endpoint and compare it against the list of authorized fields.

**Traceability**: `CWE-915` · `CWE-200` · `WSTG-INPV-*` · `ASVS 5.0 V4` · `A01:2025` · `API3:2023`
**Tooling**: `grep -rn "__all__\|permit!\|guarded = \[\]\|(req.body)" .` → candidates; confirm by reading the target model.

## §3 Injection

### WEB-07 Data-layer injection: SQL, ORM and NoSQL

**Where to look**
- Python: `cursor.execute(f"...")`, `.raw(`, `.extra(`, `RawSQL(`, SQLAlchemy `text()` with an f-string. Node: `sequelize.query(` with a template literal, `knex.raw(`, `createQueryBuilder().where("id = " + id)`.
- Java: `Statement` with concatenation, `createQuery("... " + p)` in JPA, an interpolated `@Query`. Go: `db.Raw(`, `fmt.Sprintf` inside `Exec`/`Query`. PHP: `DB::select(DB::raw(`.
- NoSQL: `find(req.query)` or `find({user: req.body.user})` without casting in Mongoose, `$where`, `mapReduce`; Elasticsearch query DSL built from client data.

**Vulnerable pattern** — request data reaching the query through concatenation or interpolation: `cursor.execute(f"SELECT * FROM orders ORDER BY {request.GET['sort']}")`. Watch the parts that **cannot** be parameterized (table, `ORDER BY` column, direction, `LIMIT`): the only valid control there is an allowlist. In NoSQL the injection targets **operators**: a body of `{"password": {"$ne": null}}` turns a comparison into a wildcard, and `$where` executes JavaScript on the database server.

**What rules it out (false positive)**
- Genuinely bound parameters (`?`, `%s`, `:name`) with no prior string formatting.
- The interpolated value is a code literal or comes from an enum validated against the model's real columns.
- Explicit casting to a primitive type or schema validation (zod, Joi, pydantic) before the NoSQL filter is built; `sanitizeFilter` enabled.

**Minimal test** — local, against a test database: send a single quote and see whether it produces a SQL syntax error (a sign of concatenation); for NoSQL, send `{"$ne": null}` and check whether the result count changes. Do not run payloads that modify or extract data.

**Traceability**: `CWE-89` · `CWE-943` · `WSTG-INPV-05` · `ASVS 5.0 V1` · `A05:2025` · `CAPEC-66`
**Tooling**: `semgrep --config p/sql-injection` or `grep -rn "\.raw(\|cursor.execute(f\|\$where" .` → a match with no user-controllable value is not a finding, and generic SQLi rules do not cover NoSQL operator injection.

### WEB-08 Operating system command execution

**Where to look**
- Node `child_process.exec`, `execSync`, `spawn(..., {shell: true})`; Python `os.system`, `subprocess.run(..., shell=True)`, `os.popen`.
- Java `Runtime.getRuntime().exec(`, `ProcessBuilder` with a shell string; Ruby backticks, `system`, `%x()`; PHP `exec`, `shell_exec`, `passthru`; Go `exec.Command("sh", "-c", ...)`.
- Typical wrappers: image conversion, ffmpeg, PDF generation, `git`, `zip`, `curl`, backup routines.

**Vulnerable pattern** — request data (a filename, a URL, a quality parameter) enters a string interpreted by the shell; the relevant metacharacters are `; | & $( ) \` > <` and the newline.

**What rules it out (false positive)**
- Execution without a shell and with arguments as a list: `spawn(bin, [arg])`, `subprocess.run([bin, arg])`, `ProcessBuilder(List.of(...))`.
- The argument comes from a closed allowlist or from a server-generated identifier.
- An in-process native library is used instead of invoking the binary.

**Minimal test** — local: in a test, pass a value containing `;` and check that it reaches the child process literally (for instance, that a file with that exact name is looked up) instead of being executed. Do not run commands with side effects.

**Traceability**: `CWE-78` · `CWE-77` · `WSTG-INPV-*` · `ASVS 5.0 V1` · `A05:2025`
**Tooling**: `grep -rn "shell=True\|child_process.exec\|Runtime.getRuntime().exec\|exec.Command" .` → many matches are deployment constants; check the origin of every argument.

### WEB-09 Templates and other interpreters (SSTI, expressions, LDAP, XPath)

**Where to look**
- Templates: `render_template_string` (Flask/Jinja2), `Template(...).render(user_input)`, Twig `createTemplate`, Thymeleaf with a dynamic fragment, Handlebars/EJS compiling input, Velocity and Freemarker.
- Expressions: SpEL with external data (`ExpressionParser`), OGNL, `eval`/`new Function` in Node, `eval`/`exec` in Python.
- LDAP: `search_s(base, scope, "(uid=" + user + ")")`, `ldapjs` with a concatenated filter, `InitialDirContext`. XPath: `evaluate("//user[name='" + n + "']")`.

**Vulnerable pattern** — user data becomes part of the **template or expression**, not of its data: `render_template_string("Hello " + request.args["name"])`. With SSTI and expression languages this usually amounts to server-side execution; with LDAP and XPath, to bypassing the authentication condition or reading other users' nodes.

**What rules it out (false positive)**
- The template is a fixed file and the data travels as context (`render_template("x.html", name=...)`).
- Interpreter-specific escaping: LDAP filter escaping (RFC 4515), bound variables in XPath, a template sandbox with no attribute access.
- The evaluated expression is constant and only the values vary.

**Minimal test** — local: send an inert arithmetic expression native to the engine (for example `{{7*7}}`) and see whether it comes back evaluated. The arithmetic marker is enough; do not chain towards execution.

**Traceability**: `CWE-1336` · `CWE-94` · `CWE-90` · `CWE-643` · `WSTG-INPV-*` · `ASVS 5.0 V1` · `A05:2025`
**Tooling**: `grep -rn "render_template_string\|new Function(\|ExpressionParser\|search_s(" .` → confirm that the dynamic string is the template and not the context.

## §4 SSRF and outbound network

### WEB-10 SSRF and egress control

**Where to look**
- HTTP clients that receive a user-supplied URL: `axios`, `fetch`, `got`, `requests`, `httpx`, `urllib`, `RestTemplate`, `WebClient`, `net/http`, `Faraday`, `Guzzle`.
- Typical features: import from URL, link preview, client-configurable webhooks, avatar by URL, HTML to PDF, image proxy, dynamic `redirect_uri`/issuer in OAuth.
- XML parsers that resolve external entities (XXE) and clients that follow redirects by default.

**Vulnerable pattern** — the server makes the request from its own network position: it reaches `127.0.0.1`, the internal network, the cloud metadata service (`169.254.169.254`) or non-HTTP schemes (`file://`, `gopher://`). String-based denylists break with redirects, DNS resolving to internal addresses, IPv6, decimal notation and `@` in the authority.

**What rules it out (false positive)**
- An allowlist of specific domains or services, resolved and validated **after** following redirects, or with redirects disabled.
- Egress restricted at the network layer (mandatory outbound proxy, container network policy) verifiable in the repository.
- The URL is never user-controlled: it is a configuration constant.

**Minimal test** — local: point the parameter at your own canary on `127.0.0.1:<test port>` that you started yourself and check whether it receives the connection. Any target other than your local canary: **REQUIRES AUTHORIZATION**.

**Traceability**: `CWE-918` · `CWE-611` · `WSTG-INPV-*` · `ASVS 5.0 V4` · `A01:2025` · `API7:2023`
**Tooling**: `grep -rn "requests.get(\|axios.get(\|http.Get(\|RestTemplate" .` → filter for the ones taking a variable; prior validation must be read, not inferred.

## §5 Deserialization and files

### WEB-11 Deserialization of untrusted data

**Where to look**
- Python `pickle.loads`, `yaml.load` without `SafeLoader`, `jsonpickle`, `dill`, `marshal`; PHP `unserialize(`; Ruby `Marshal.load`, `YAML.load`.
- Java `ObjectInputStream.readObject`, XStream without an allowlist, SnakeYAML with the default constructor, Jackson with open `enableDefaultTyping`/`@JsonTypeInfo`; .NET `BinaryFormatter`, `LosFormatter`, `TypeNameHandling.All`; Node `node-serialize`, `vm.runInNewContext`.
- Common sources: serialized session cookies, queues and background jobs, caches, file import, internal messaging.

**Vulnerable pattern** — the format reconstructs arbitrary objects and executes code during reconstruction. An HMAC over the blob only mitigates if the key is uncompromised and it is verified **before** deserializing.

**What rules it out (false positive)**
- A pure data format (JSON, Protobuf) with no dynamic type resolution, mapped onto a declared DTO.
- `yaml.safe_load`, a class allowlist, or data coming exclusively from an internal trusted source you can substantiate.
- Integrity verification with a server key prior to deserialization, with the key kept outside the repository.

**Minimal test** — local: a test that passes a serialized object of an unexpected class and verifies it is rejected. Do not build gadget chains.

**Traceability**: `CWE-502` · `WSTG-INPV-*` · `ASVS 5.0 V15` · `A08:2025`
**Tooling**: `grep -rn "pickle.loads\|readObject(\|unserialize(\|BinaryFormatter\|yaml.load(" .` → this is one of the three worst-detected classes for SAST (Bennett et al., EASE 2024); also look for in-house wrappers that hide the sink.

### WEB-12 File upload and path traversal

**Where to look**
- Upload: `multer`, `django.core.files`, `MultipartFile`, `ActiveStorage`, `IFormFile`, `$request->file()`; check where the destination path is assembled and whether the original filename is used.
- Serving and download: `res.sendFile(`, `send_file(`, `File.read(params[:path])`, `os.path.join(base, user_input)`, `http.ServeFile`, endpoints such as `/download?file=`.
- Extraction: `zipfile.extractall`, `tar.extractall`, `unzip` without validating entry paths (zip slip).

**Vulnerable pattern** — the client's name or path takes part in the final path: `../` escapes the base directory and `%2e%2e%2f` defeats string filters; a file with an executable extension inside a directory served by the web server turns into execution. Validating only `Content-Type` is useless: the client chooses it.

**What rules it out (false positive)**
- A server-generated name (UUID) and a canonical path verified with `realpath`/`Path.normalize` against the base directory before opening.
- Storage outside the web root or in a bucket with no execution, served with `Content-Disposition: attachment` and a fixed type.
- An extension allowlist with real content verification, plus size and file-count limits.

**Minimal test** — local: request `..%2f..%2fetc%2fhostname` and a name containing separators, and assert that the resolved path still lies inside the base directory, without reading real system files.

**Traceability**: `CWE-22` · `CWE-434` · `CWE-23` · `WSTG-INPV-*` · `WSTG-CONF-*` · `ASVS 5.0 V5` · `A01:2025`
**Tooling**: `grep -rn "os.path.join(\|sendFile(\|extractall(" .` → every `join` with remote data requires you to see the canonicalization that follows.

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

**Minimal test** — local: send boundary values (zero, negative, very large, decimal, different unit) and check the invariant. Sustained load against a remote environment: **REQUIRES AUTHORIZATION**.

**Traceability**: `CWE-770` · `CWE-799` · `CWE-20` · `WSTG-BUSL-*` · `ASVS 5.0 V2` · `A06:2025` · `API4:2023` · `API6:2023`
**Tooling**: enumerate routes and cross them against the limiter configuration; the missing rule is the finding, and no tool will propose it.

## §9 Cryptography and secrets

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

**Minimal test** — local: connect to your instance with an arbitrary `Origin` and see whether the handshake is accepted; with two synthetic users, try to subscribe to the other user's channel.

**Traceability**: `CWE-346` · `CWE-862` · `CWE-770` · `WSTG-CLNT-*` · `ASVS 5.0 V4` · `A01:2025` · `API2:2023`
**Tooling**: `grep -rn "new WebSocket\|socket.io\|AsyncWebsocketConsumer\|ActionCable" .` → locate the handshake and read the authorization there, not in the HTTP router.

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

**Minimal test** — local: trigger a controlled error (an unexpected data type) and inspect the response body; run a login with synthetic credentials and check whether the password or token appears in the log.

**Traceability**: `CWE-209` · `CWE-532` · `CWE-200` · `CWE-778` · `WSTG-ERRH-*` · `WSTG-INFO-02` · `ASVS 5.0 V16` · `ASVS 5.0 V14` · `A09:2025` · `A10:2025`
**Tooling**: `grep -rn "DEBUG = True\|APP_DEBUG=true\|include-stacktrace" .` and review the log from a local run; do not publish log excerpts containing real data.
