# Knowledge pack — Web and API AppSec

> **When to load this file:** the inventory includes an HTTP server, an API (REST, GraphQL, RPC, WebSocket) or a web backend with routes, controllers, an ORM, sessions or tokens.
> **Do not load it if:** the scope is only an APK/IPA with no reachable backend, only IaC and containers, only dependencies, or a library with no network surface.
> **Cost:** ~303 lines. Load by section using the index; you do not need to read it end to end.
> **Second file of this pack:** `web-api-clientside-logic.md` holds §6-§11 and `WEB-13`..`WEB-22` — XSS and client-side sinks, CSRF/CORS/caching, business logic and rate limiting, cryptography and secrets, GraphQL and persistent channels, and disclosure through errors and logs. Open it as soon as the inventory reaches any of those; it carries its own index.

## Selective loading index

| Section | Load it if the inventory has | Procedures |
|---|---|---|
| §0 What tools do not see | always, before reporting | — |
| §1 AuthN and sessions | login, JWT, session cookies, OTP, OAuth | WEB-01..WEB-03 |
| §2 AuthZ | routes with `:id`, roles, tenants, admin panel | WEB-04..WEB-06 |
| §3 Injection | SQL/ORM, Mongo, shell, templates, LDAP | WEB-07..WEB-09 |
| §4 SSRF and outbound network | fetch to user-supplied URLs, webhooks, importers | WEB-10 |
| §5 Deserialization and files | pickle/Java/YAML, upload, download by path | WEB-11..WEB-12 |

Sections §6 to §11 (`WEB-13`..`WEB-22`) are in `web-api-clientside-logic.md`.

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

Rules: FP-01, FP-03, FP-09.

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

Rules: FP-01, FP-04, FP-09.

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

Rules: FP-01.

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

Rules: FP-01, FP-05, FP-07.

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

Rules: FP-01, FP-06.

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

Rules: FP-01, FP-07.

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

Rules: FP-01, FP-02.

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

Rules: FP-01, FP-02, FP-09.

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

Rules: FP-01, FP-02, FP-03.

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

Rules: FP-01, FP-02.

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

Rules: FP-01, FP-02, FP-03.

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

Rules: FP-01, FP-03.

**Minimal test** — local: request `..%2f..%2fetc%2fhostname` and a name containing separators, and assert that the resolved path still lies inside the base directory, without reading real system files.

**Traceability**: `CWE-22` · `CWE-434` · `CWE-23` · `WSTG-INPV-*` · `WSTG-CONF-*` · `ASVS 5.0 V5` · `A01:2025`
**Tooling**: `grep -rn "os.path.join(\|sendFile(\|extractall(" .` → every `join` with remote data requires you to see the canonicalization that follows.
