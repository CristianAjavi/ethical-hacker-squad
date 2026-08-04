# Knowledge pack — Mobile and APK

> **When to load this file:** the inventory includes an `.apk`, `.aab`, `.ipa`, an Android project (Gradle, Kotlin/Java, `AndroidManifest.xml`) or an iOS project (Xcode, Swift/Obj-C, `Info.plist`), or a backend whose only client is a mobile app.
> **Do not load it if:** the scope is only web, API or infrastructure with no mobile client.
> **Cost:** ~345 lines. Load by section using the index; you do not need to read it end to end.

## Selective loading index

| Section | Load it if the inventory has | Procedures |
|---|---|---|
| §0 Compiled APK vs source code | always, before asserting anything | — |
| §1 Manifest and exported surface | `AndroidManifest.xml`, activities, services, receivers | MOB-01..MOB-02 |
| §2 Storage and logs | `SharedPreferences`, SQLite, files, `Log.*` | MOB-03..MOB-04 |
| §3 WebViews and bridges | `WebView`, `WKWebView`, hybrids (Cordova, Capacitor, RN) | MOB-05..MOB-06 |
| §4 Deep links and intents | `<intent-filter>`, `CFBundleURLSchemes`, App Links | MOB-07..MOB-08 |
| §5 Network and TLS | `network_security_config.xml`, `TrustManager`, pinning | MOB-09..MOB-10 |
| §6 Crypto and embedded secrets | `Cipher`, `SecureRandom`, `strings.xml`, `BuildConfig` | MOB-11..MOB-12 |
| §7 Mobile backend and client-side controls | API consumed only by the app, on-screen validation | MOB-13 |
| §8 iOS specific | `Info.plist`, entitlements, Keychain, pasteboard | MOB-14..MOB-15 |

## How to use a procedure

The six fields are a contract. "Where to look" changes depending on whether you hold the compiled artifact or the source; **"What rules it out" is mandatory before you report**. "Minimal test" is static and local: anything that involves running the app against a server, against someone else's device, or instrumenting it at runtime is marked `REQUIRES AUTHORIZATION`. Do not treat a tool match as a finding until you confirm the code is reachable and the data is sensitive.

On traceability: MASVS controls are cited at group level (`MASVS-PLATFORM-*`) except for `MASVS-STORAGE-1` and `MASVS-PRIVACY-1`, and no `MASTG-TEST-NNNN` identifiers are invented; the corresponding test group is referenced instead. MASVS v2.1.0 does **not** define L1/L2/R levels: do not use them.

## §0 Compiled APK vs source code: what you can assert

These are two different kinds of evidence and they do not get mixed inside one finding.

- **Source code**: you see intent, branches per build variant (`debug` vs `release`), comments and Gradle configuration. You **cannot** assert what ended up in the shipped artifact: `buildTypes`, `manifestPlaceholders`, library manifest merging and R8 change the result. If you report from source, say "in the code of variant X".
- **Compiled APK**: you see what is actually distributed (merged manifest, resources, certificates, native libraries). You **cannot** see the original names if obfuscation was applied, nor runtime behavior, nor which branch a condition takes. If you report from the APK, say "in the analyzed artifact, version X, signature Y".
- Ideally you cross both: the pattern in the source and its actual presence in the artifact.

**Hard rule, no exceptions**: obfuscation does **not** replace a server-side control. A secret present in the APK is compromised by definition, because anyone holding the file can extract it. The finding reads "an embedded secret exists; it must be rotated and moved to the server", never "it should be obfuscated better". The same applies to business validation: if it only lives on the client, it does not exist.

**Permitted local static tooling** (no network and no device required):

- `aapt2 dump badging app.apk` (package, version, SDK, permissions, main activity) · `apktool d app.apk -o out/ --no-src` (readable manifest and resources without decompiling).
- `jadx -d out/ --no-res --no-debug-info app.apk` (approximate Java from the DEX) · `apksigner verify --print-certs --verbose app.apk` (signature schemes and certificate).
- `apkleaks -f app.apk --json` (candidate strings) · MobSF in local static mode.

**How these tools lie to you** (always verify before reporting):

- **jadx** produces decompiled code that may be corrupt or incomplete; you will see `// decompilation failed` and empty method bodies. A `grep` over that output produces phantom findings (code that does not exist in that form) and false negatives (methods that were never decompiled). Cross-check against the smali from `apktool` whenever the finding depends on logic.
- **apkleaks** is pure regular-expression matching: it flags any 32-40 character base64 or hex string as an "AWS key", and reports *public* keys (for example the Google Maps one, which ships in the client by design and is protected with application restrictions in the provider console) as if they were secrets. Every result requires checking the format, the actual use, and whether the provider considers it public.
- **MobSF** flags **every** activity with `exported="true"` as a risk without looking at reachability, `android:permission`, or whether the component does anything sensitive. Its listing is a starting point, not a list of findings.

**Excluded from the automated pipeline: `frida` and `objection`.** They are dynamic instrumentation: they disable the application's controls at runtime, modify its state and the device's, and require a device you own or have rooted plus written authorization from the owner. They are not launched in an automated audit. If dynamic analysis is needed, propose it as separate work with explicit scope and permission.

## §1 Manifest and exported surface

### MOB-01 Exported components and their access control

**Where to look**
- APK: `out/AndroidManifest.xml` after `apktool`; look for `android:exported="true"` and every component with an `<intent-filter>` (which implies exported unless stated otherwise).
- Source: `app/src/main/AndroidManifest.xml` plus the library manifests that get merged; `registerReceiver` without `RECEIVER_NOT_EXPORTED`; a `ContentProvider` with `android:grantUriPermissions` or with no read/write permission; handlers (`onCreate`, `onStartCommand`, `onReceive`) that read `getIntent().getExtras()` and act on sensitive data or screens.

**Vulnerable pattern** — another app installed on the device invokes the component directly and reaches a screen or an action that should require a session (skipping login, triggering a transfer, reading a provider). The severe case is an exported `ContentProvider` that returns user data with no permission of its own.

**What rules it out (false positive)**
- `android:exported="false"`, or exported with a `signature`-level `android:permission` and an effective caller check.
- The exported component is the launcher, a system receiver or a documented public integration that exposes neither data nor privileged actions.
- Session and authorization are re-validated inside the component, independently of how it was reached.

**Minimal test** — static: list the exported components and, for each one, follow its handler down to the first sensitive decision. Invoking them on a real device: **REQUIRES AUTHORIZATION**.

**Traceability**: `CWE-926` · `CWE-200` · `MASVS-PLATFORM-*` · `MASTG-TEST-*` from the PLATFORM group
**Tooling**: `apktool d app.apk -o out/ --no-src`, then read the manifest → MobSF will flag every exported component; only the ones reaching something sensitive without authorization are findings.

### MOB-02 Build flags and leftover development code

**Where to look**
- Manifest: `android:debuggable="true"`, `android:allowBackup="true"`, `android:usesCleartextTraffic="true"`, `android:testOnly`, and the `dataExtractionRules`/`fullBackupContent` rules.
- Source: `build.gradle` (`buildTypes.release` with `minifyEnabled false`, `debuggable true`, a debug `signingConfig`), `BuildConfig.DEBUG` enabling dangerous paths, "demo mode" flags; leftovers such as staging endpoints, test credentials, diagnostic activities and `WebView.setWebContentsDebuggingEnabled(true)`.

**Vulnerable pattern** — `debuggable` allows attaching a debugger and reading memory and private data without root; `allowBackup` allows extracting the private directory through a backup on devices that support it; diagnostic code exposes internal functionality in production.

**What rules it out (false positive)**
- The flags appear only in the debug variant and the published artifact (verified with `aapt2 dump badging`) does not carry them.
- `allowBackup` enabled but with extraction rules that exclude the sensitive data, and with no credentials in the backed-up directory.
- The diagnostic activity is not exported and does not alter business state.

**Minimal test** — static: `aapt2 dump badging app.apk` and read the manifest of the real artifact, not the source one. Compare against the Gradle `release` variant.

**Traceability**: `CWE-489` · `CWE-530` · `MASVS-CODE-*` · `MASVS-RESILIENCE-*` · `MASTG-TEST-*` from the CODE group
**Tooling**: `apksigner verify --print-certs --verbose app.apk` → also confirms whether it is signed with a debug certificate; an artifact signed in debug is not a production build.

## §2 Local storage and data leakage

### MOB-03 Storage of sensitive data on the device

**Where to look**
- Android: `getSharedPreferences(...)` in clear text (and the deprecated `MODE_WORLD_READABLE`/`MODE_WORLD_WRITEABLE`), unencrypted SQLite, `openFileOutput`, `getExternalFilesDir`/`getExternalStorageDirectory` (shared storage, readable by other apps holding the permission), `File` in `cacheDir`, `Realm` with no key. Correct alternatives that may be missing: `EncryptedSharedPreferences`, keys in the Android Keystore (`KeyGenParameterSpec`, `setUserAuthenticationRequired`), SQLCipher.
- What gets stored: session token, refresh token, password, PIN, full API responses, personal data, paths to photographed documents.

**Vulnerable pattern** — the long-lived credential sits in plain text inside the private directory or, worse, in external storage. On a rooted, compromised or backed-up device the attacker gets the full session without ever touching the server.

**What rules it out (false positive)**
- Sensitive material is stored encrypted with a non-exportable Keystore key, or is not stored at all (token in memory, renewed against the server).
- What is persisted is non-sensitive cache or public identifiers with no authentication value.
- Server-side invalidation exists: a stolen token can be revoked and expires within minutes (reduces impact; does not remove the finding).

**Minimal test** — static: locate every write and classify the data. On an APK, inspect `res/xml/` and `assets/` for preloaded databases. Extracting data from a device: **REQUIRES AUTHORIZATION**.

**Traceability**: `CWE-312` · `CWE-922` · `CWE-921` · `MASVS-STORAGE-1` · `MASTG-TEST-0001`
**Tooling**: `jadx -d out/ --no-res --no-debug-info app.apk` and `grep -rn "getSharedPreferences\|getExternalFilesDir\|MODE_WORLD" out/` → remember jadx may fail to decompile: an empty method does not mean the code is absent.

### MOB-04 Logs, screenshots, pasteboard and telemetry

**Where to look**
- Android: `Log.d/v/i/w/e`, `System.out.println`, `printStackTrace()`, HTTP interceptors in `BODY` mode (OkHttp `HttpLoggingInterceptor.Level.BODY`) still active in release.
- Sensitive screens without `FLAG_SECURE`, password or card fields that can be copied to the clipboard, unrestricted autofill.
- Third-party SDKs (analytics, crash reporting, advertising) receiving the whole user object: review `setUserProperty`, breadcrumbs and custom attributes.

**Vulnerable pattern** — the token, the identity document number or the full API body ends up in the device log or in a third party's dashboard. Logs are readable by development tooling and by vendor diagnostic processes; crash reports travel outside the organization's control.

**What rules it out (false positive)**
- Logging gated by `BuildConfig.DEBUG` and stripped by R8 in release, verified in the artifact.
- Explicit redaction of sensitive fields before logging or before sending to third parties, covered by a test.
- The SDK receives only a pseudonymous identifier with no personal data attached.

**Minimal test** — static: enumerate log calls on paths handling credentials and follow the argument. Capturing logs from a real device: **REQUIRES AUTHORIZATION**.

**Traceability**: `CWE-532` · `CWE-359` · `CWE-200` · `MASVS-STORAGE-*` · `MASVS-PRIVACY-1` · `MASTG-TEST-*` from the STORAGE group
**Tooling**: `grep -rn "Log\.\(d\|v\|i\)\|HttpLoggingInterceptor\|printStackTrace" out/` → most hits are harmless; the finding is the one printing sensitive data and surviving into release.

## §3 WebViews and native bridges

### MOB-05 WebView configuration and content origin

**Where to look**
- Android: `setJavaScriptEnabled(true)`, `setAllowFileAccess(true)`, `setAllowFileAccessFromFileURLs`, `setAllowUniversalAccessFromFileURLs`, `setAllowContentAccess`, `setDomStorageEnabled`, `loadUrl` with a URL coming from an intent or from a network response.
- iOS: `WKWebView` with `allowFileAccessFromFileURLs`, `loadHTMLString` with remote content, `UIWebView` (deprecated and without modern isolation).
- Hybrids: Cordova/Capacitor configuration (`allow-navigation`, `allow-intent`), React Native `WebView` with `originWhitelist={['*']}`.

**Vulnerable pattern** — the WebView loads content the app does not control (a URL from a deep link, HTML from a response) with JavaScript enabled and `file://` access. That turns a remote XSS into a read of the app's private storage.

**What rules it out (false positive)**
- File access disabled and navigation restricted to an allowlist of the organization's own domains, enforced in `shouldOverrideUrlLoading`/`decidePolicyFor`.
- The content is local and static, bundled in `assets/`, with no parameters from outside.
- External links open in the system browser, not inside the app's WebView.

**Minimal test** — static: trace the `loadUrl` argument back to its origin; check whether any deep link can reach it. Loading a test URL on a device: **REQUIRES AUTHORIZATION**.

**Traceability**: `CWE-79` · `CWE-939` · `MASVS-PLATFORM-*` · `MASTG-TEST-*` from the PLATFORM group
**Tooling**: `grep -rn "setJavaScriptEnabled\|setAllowFileAccess\|loadUrl(\|originWhitelist" out/` → also confirm the configuration merging that hybrid libraries perform.

### MOB-06 Native bridges and silenced TLS errors in the WebView

**Where to look**
- `addJavascriptInterface(object, "name")` and the methods annotated with `@JavascriptInterface`: each one is a native function callable from whatever JavaScript gets loaded.
- `WebViewClient.onReceivedSslError` with an empty body or one that calls `handler.proceed()`.
- iOS: `WKScriptMessageHandler` and its `userContentController(_:didReceive:)`; in hybrids, plugins exposed to the JavaScript bridge.

**Vulnerable pattern** — a bridge method does something sensitive (read files, fetch the token, execute a payment) while the WebView loads untrusted content, so that content calls the method. An `onReceivedSslError` whose body is `handler.proceed()` cancels certificate validation for the entire WebView: any intermediary sees and modifies the loaded content, which in turn talks to the bridge.

**What rules it out (false positive)**
- The bridge only exposes harmless operations and the WebView loads exclusively verified first-party content.
- `onReceivedSslError` cancels (`handler.cancel()`) or is not overridden at all.
- The bridge message validates the document origin and the message schema before acting.

**Minimal test** — static: inventory every `@JavascriptInterface` method, its effect, and the set of URLs the WebView can load. The intersection of "sensitive method" and "external URL" is the finding.

**Traceability**: `CWE-749` · `CWE-295` · `MASVS-PLATFORM-*` · `MASVS-NETWORK-*` · `MASTG-TEST-*` from the PLATFORM group
**Tooling**: `grep -rn "addJavascriptInterface\|@JavascriptInterface\|onReceivedSslError" out/` → if jadx left the method bodyless, cross-check against the smali before concluding it is empty.

## §4 Deep links, intents and inter-app communication

### MOB-07 Deep links and origin verification

**Where to look**
- Manifest: `<intent-filter>` with `<data android:scheme="myapp">`; custom schemes (any app can register the same one) versus verified App Links (`android:autoVerify="true"` plus `assetlinks.json` on the domain).
- The link handler: `getIntent().getData()`, parameters selecting a screen, a resource identifier, a URL to load or a token.
- iOS: `CFBundleURLSchemes` in `Info.plist` versus Universal Links (`com.apple.developer.associated-domains` and `apple-app-site-association`).

**Vulnerable pattern** — the link carries data the app treats as trusted: `myapp://reset?token=...` processed without validation, or a `next=` parameter redirecting to an arbitrary URL inside the WebView. With custom schemes, a malicious app can register the same scheme and intercept the link (and with it, any token travelling in the URL).

**What rules it out (false positive)**
- Verified App Links or Universal Links, with no equivalent custom scheme accepting the same parameters.
- The handler validates the parameter against an allowlist and requires an active session before any action.
- The link only navigates to public screens with no sensitive data or actions.

**Minimal test** — static: list the declared schemes and hosts and follow every parameter to its use. Firing links on a device: **REQUIRES AUTHORIZATION**.

**Traceability**: `CWE-939` · `CWE-940` · `MASVS-PLATFORM-*` · `MASTG-TEST-*` from the PLATFORM group
**Tooling**: `aapt2 dump badging app.apk` for the summary and the `apktool` manifest for the `<data>` detail → a declared scheme does not imply an exploitable handler; you have to read it.

### MOB-08 Implicit intents, redirection and PendingIntent

**Where to look**
- Sending: `startActivity(intent)` with an implicit intent carrying sensitive data, `sendBroadcast` with no permission, `setResult` returning private information to an arbitrary caller.
- Forwarding: an exported component that takes an `Intent` from its extras and executes it (`startActivity(getIntent().getParcelableExtra("next"))`), the intent redirection pattern that allows reaching internal components.
- `PendingIntent` with a base intent lacking an explicit component, or created without `FLAG_IMMUTABLE` where it matters.

**Vulnerable pattern** — the app acts as a middleman: it receives an intent from another app and forwards it under its own identity, reaching non-exported activities or internal providers. A mutable `PendingIntent` lets the receiver fill in fields and act with the sending app's permissions.

**What rules it out (false positive)**
- Explicit intents with a pinned component and immutable `PendingIntent`s.
- The forwarding component validates the destination against an allowlist of its own components.
- The broadcast requires a custom permission and the receiver checks the sender.

**Minimal test** — static: look for places where an `Intent` coming from outside is used as the target of a call; that hop is the finding.

**Traceability**: `CWE-927` · `CWE-925` · `CWE-863` · `MASVS-PLATFORM-*` · `MASTG-TEST-*` from the PLATFORM group
**Tooling**: `grep -rn "getParcelableExtra\|PendingIntent.get\|sendBroadcast(" out/` → check each one against the manifest to know whether the entry point is reachable from another app.

## §5 Network and TLS

### MOB-09 Cleartext traffic and network security configuration

**Where to look**
- Android: `res/xml/network_security_config.xml` (referenced by `android:networkSecurityConfig`); look for `cleartextTrafficPermitted="true"`, `<domain-config>` blocks relaxing a specific domain, and `<trust-anchors>` including `<certificates src="user"/>`.
- Manifest: `android:usesCleartextTraffic="true"`; code: `http://` URLs in constants, endpoint values in `BuildConfig`, configuration inside `assets/`.
- iOS: `NSAppTransportSecurity` in `Info.plist` with `NSAllowsArbitraryLoads`, `NSAllowsArbitraryLoadsInWebContent` or per-domain exceptions (`NSExceptionAllowsInsecureHTTPLoads`).

**Vulnerable pattern** — unencrypted traffic to the backend or to an auxiliary service (images, analytics, updates) that discloses the session or allows tampering with content. `<certificates src="user"/>` makes the app trust CAs installed by the device user: any locally installed proxy intercepts the traffic, which defeats the purpose of the channel for sensitive data.

**What rules it out (false positive)**
- `cleartextTrafficPermitted="false"` globally, with exceptions limited to `localhost` or to a test domain that does not exist in production.
- System-only trust anchors in the release configuration; the debug variant may differ and is not a finding if it is not published.
- The cleartext endpoint serves public content whose integrity is guaranteed by other means (resource signing), verifiable in the code.

**Minimal test** — static: extract `network_security_config.xml` from the artifact with `apktool` and read it in full, including nested `<domain-config>` blocks. Intercepting real traffic: **REQUIRES AUTHORIZATION**.

**Traceability**: `CWE-319` · `MASVS-NETWORK-*` · `MASTG-TEST-*` from the NETWORK group
**Tooling**: `apktool d app.apk -o out/ --no-src`, then review `out/res/xml/` → the artifact's configuration overrides whatever the repository says.

### MOB-10 Certificate validation and pinning

**Where to look**
- Android: `X509TrustManager` with an empty `checkServerTrusted`, a `HostnameVerifier` that always returns `true`, a custom `SSLSocketFactory`, `OkHttpClient` with `CertificatePinner` (and whether the pin is on the leaf or the intermediate, and whether a backup pin exists).
- iOS: `URLSessionDelegate` with `urlSession(_:didReceive:completionHandler:)` calling `.useCredential` with the trust unevaluated; legacy `NSURLConnection`.
- Declarative configuration: `<pin-set>` in `network_security_config.xml` with an already-past `expiration`.

**Vulnerable pattern** — chain or hostname validation is disabled "to make it work with the test certificate" and the code reaches production; the result is that any intermediary on the user's network reads and alters the traffic. Missing pinning is not a vulnerability on its own, but for high-value data its absence is a hardening observation, not a defect.

**What rules it out (false positive)**
- Use of the platform's default `TrustManager` without overriding verification.
- The permissive `TrustManager` is confined to the debug variant and absent from the published artifact (check the DEX, not just the source).
- Pinning in place with a backup pin and a documented rotation procedure.

**Minimal test** — static: look for `X509TrustManager` implementations in the jadx output and check whether the verification method has a body. Proxy interception testing: **REQUIRES AUTHORIZATION**.

**Traceability**: `CWE-295` · `CWE-297` · `MASVS-NETWORK-*` · `MASTG-TEST-*` from the NETWORK group
**Tooling**: `grep -rn "checkServerTrusted\|HostnameVerifier\|CertificatePinner\|ALLOW_ALL_HOSTNAME" out/` → an empty method in jadx can be a decompilation artifact; cross-check it before reporting.

## §6 Cryptography and embedded secrets

### MOB-11 Cryptography and randomness

**Where to look**
- Android: `Cipher.getInstance("AES")` (which resolves to ECB by default in several implementations) or `"AES/ECB/PKCS5Padding"`, a constant IV or one derived from the username, `PBEKeySpec` with too few iterations, `MessageDigest` MD5/SHA-1 used for authentication.
- Randomness: `java.util.Random`, `Math.random()`, `SecureRandom` manually seeded with `setSeed` on a fixed value, misapplied `arc4random` on iOS.
- Key management: a literal key in the code or one derived from a constant, instead of the Android Keystore or the Secure Enclave.

**Vulnerable pattern** — local encryption reversible by anyone holding the app, because the key ships inside the artifact itself or the mode leaks the content (ECB reveals repeated patterns). Identifiers generated with `Random` are predictable and work neither as tokens nor as key material.

**What rules it out (false positive)**
- AES-GCM (or another authenticated primitive) with a random per-operation IV and a non-exportable Keystore key.
- `SecureRandom` with no fixed seed for every value with a security function.
- The weak hash is a checksum unrelated to security and governs no decision.

**Minimal test** — static: locate every `Cipher.getInstance` and classify mode, IV origin and key origin; for every `Random` use, determine whether the value has a security function.

**Traceability**: `CWE-327` · `CWE-330` · `CWE-1204` · `MASVS-CRYPTO-*` · `MASTG-TEST-0204`
**Tooling**: `grep -rn "Cipher.getInstance\|new Random(\|setSeed(\|MessageDigest.getInstance" out/` → the algorithm string usually survives obfuscation literally, because it is an API parameter.

### MOB-12 Secrets embedded in the artifact

**Where to look**
- Resources: `res/values/strings.xml`, `res/raw/`, `assets/`, provider configuration files (`google-services.json` and equivalents), `BuildConfig` generated from `gradle.properties` or from CI environment variables.
- Code and native: constants in configuration classes, `libs/*.so` and `lib/<abi>/*.so` (run `strings` over the native library; putting the secret in C does not protect it).
- Type of secret: a server-to-server API key, cloud storage credentials, a webhook token, a request-signing key, a local database password.

**Vulnerable pattern** — any secret with server-side value shipped inside an artifact distributed to users. It does not matter whether it is obfuscated, split into chunks, encrypted with another embedded key, or buried in a native library: whoever holds the file holds the secret.

**What rules it out (false positive)**
- The value is a **public** key by design (for example a maps or client SDK key), restricted by package and signature in the provider console; document the restriction instead of reporting it as a secret.
- It is a non-confidential identifier (project id, application id) or an inert test value.
- The secret is only obtained at runtime after the user authenticates and is never persisted in clear text.

**Minimal test** — static: use `apkleaks` as a candidate generator and manually verify the format and use of each hit; on source, run `git log -p` to see whether the key was ever versioned. Do not use the secret and do not transcribe it in full in the report: redact it and describe its type and location.

**Traceability**: `CWE-798` · `CWE-200` · `MASVS-STORAGE-1` · `MASVS-CRYPTO-*` · `MASTG-TEST-*` from the STORAGE group
**Tooling**: `apkleaks -f app.apk --json` → extremely high false-positive rate from regex matching; every high-entropy string it flags needs checking whether it is a real key, a hash, an identifier or base64 of a resource. The recommendation is always to rotate and move it server-side, never to obfuscate it better.

## §7 Mobile backend and client-only controls

### MOB-13 Controls enforced only on the client

**Where to look**
- Validation that exists only in the app: price or discount computed on the device and sent to the server, quantity capped in the interface, a role read from a local preference, "premium user" resolved from a stored flag.
- Environment checks treated as security: root or jailbreak detection, emulator detection, signature verification performed by the app itself.
- The API the app consumes: if the backend is in scope, apply the `web-api.md` pack (BOLA, BFLA, rate limiting); if it is not, document the surface and do not test it.

**Vulnerable pattern** — the server trusts what the client sends because "only the app talks to it". Anyone can replay the requests with an ordinary HTTP client: the app is an interface, not a trust boundary. Anti-tampering checks raise the attacker's cost, but they are not an access control.

**What rules it out (false positive)**
- The server recomputes and validates every value with impact (price, balance, role, quota) against its own authoritative source.
- Authorization is resolved from the token identity server-side, not from body fields.
- The client-side check is a user-experience improvement and its server-side equivalent exists.

**Minimal test** — static: for every impactful value the app sends, locate the re-validation in the backend. If the backend is out of scope, report it as a probable risk with the client-side evidence. Replaying requests against a real server: **REQUIRES AUTHORIZATION**.

**Traceability**: `CWE-602` · `CWE-639` · `CWE-863` · `MASVS-AUTH-*` · `MASVS-RESILIENCE-*` · `API1:2023`
**Tooling**: extract the list of endpoints and the fields each one sends from the code, then cross it against the backend. No static tool can infer what gets re-validated on the other side.

## §8 iOS specific

### MOB-14 iOS: Info.plist, ATS, URL schemes and entitlements

**Where to look**
- `Info.plist`: `NSAppTransportSecurity` (`NSAllowsArbitraryLoads`, per-domain exceptions), `CFBundleURLSchemes`, `LSApplicationQueriesSchemes`, `UIFileSharingEnabled`/`LSSupportsOpeningDocumentsInPlace` (which expose the documents directory), and the permission purpose strings (`NS*UsageDescription`) versus the permissions actually used.
- Entitlements (`*.entitlements`, or `codesign -d --entitlements` over the binary): `com.apple.developer.associated-domains`, App Groups and Keychain Access Groups shared with other apps, `get-task-allow` (the debuggable equivalent) in a distribution build.
- Extensions and capabilities: share extensions, widgets and background modes that widen the surface.

**Vulnerable pattern** — ATS relaxed globally to allow a legacy endpoint; a custom URL scheme exposing sensitive actions with no origin verification; keychain access groups shared with more apps than necessary, which widens the blast radius of a compromise.

**What rules it out (false positive)**
- ATS enabled with narrow, justified per-domain exceptions and no `NSAllowsArbitraryLoads`.
- Verified Universal Links instead of custom schemes, or a handler that validates the link and requires a session.
- Shared groups limited to apps from the same owner with a documented need.

**Minimal test** — static: unpack the `.ipa` and read `Info.plist` and the binary's entitlements; cross every declared permission against its use in the code.

**Traceability**: `CWE-319` · `CWE-939` · `CWE-732` · `MASVS-NETWORK-*` · `MASVS-PLATFORM-*` · `MASTG-TEST-*` from the PLATFORM group
**Tooling**: `plutil -p Info.plist` to read it in clear → an `NSAllowsArbitraryLoads` accompanied by per-domain exceptions may be less severe than it looks; read the whole dictionary.

### MOB-15 iOS: Keychain, local storage and pasteboard

**Where to look**
- Keychain: the chosen `kSecAttrAccessible*` attribute (`kSecAttrAccessibleAlways` and variants without `ThisDeviceOnly` let the item travel in backups and onto another device), `kSecAttrAccessControl` with biometrics when the data warrants it.
- Storage: `UserDefaults` holding tokens or personal data, files in `Documents/` without adequate `NSFileProtection`, unencrypted Core Data or Realm stores, `URLCache` entries caching authenticated responses.
- Interface and system: `UIPasteboard.general` with sensitive data (the general pasteboard is shared and, with Universal Clipboard, can cross devices), app snapshots when backgrounding, third-party keyboards in sensitive fields.

**Vulnerable pattern** — the credential is stored in `UserDefaults` (a plaintext plist inside the container) instead of the keychain, or in the keychain with a more permissive accessibility class than needed, so it survives a backup and is restored onto another device.

**What rules it out (false positive)**
- Keychain items using `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` (or stricter) for sensitive material, and default file protection not lowered.
- What lives in `UserDefaults` is preferences with no authentication value.
- The pasteboard is cleared after use or marked local, and sensitive screens are hidden in the app switcher.

**Minimal test** — static: enumerate every keychain write and its accessibility class, and every `UserDefaults` key with its expected content. Inspecting a device container: **REQUIRES AUTHORIZATION**.

**Traceability**: `CWE-312` · `CWE-922` · `CWE-359` · `MASVS-STORAGE-1` · `MASVS-PRIVACY-1` · `MASTG-TEST-0001`
**Tooling**: `grep -rn "kSecAttrAccessible\|UserDefaults.standard.set\|UIPasteboard.general" .` over the source → with an `.ipa` and no source, the compiled binary sharply limits what you can assert; say so in the report instead of assuming.
