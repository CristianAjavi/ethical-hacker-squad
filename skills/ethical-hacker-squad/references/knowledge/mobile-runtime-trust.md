# Knowledge pack — Mobile and APK (runtime trust: local auth, screen integrity, code after the store)

> **When to load this file:** third file of the `mobile` pack. Load it when the app has a screen that authorizes an effect (a payment, a transfer, adding a beneficiary, approving a factor, changing credentials), a biometric or local-PIN unlock, code or bundles loaded at runtime (`DexClassLoader`, CodePush, Expo Updates, Capacitor live updates), or a backend whose only client is the app.
> **Do not load it if:** the mobile work is confined to the manifest, storage, WebViews, deep links, TLS or embedded secrets — those are `mobile.md` §0-§6.
> **Cost:** ~110 lines. The entry point of the pack is `mobile.md` (§0-§6, `MOB-01`..`MOB-12`): read its §0 first, because what you may assert from a compiled artifact versus from source governs every procedure here, and its §5 (TLS) is a precondition of `MOB-18`. The iOS specifics are in `mobile-ios.md` (§8, `MOB-14`..`MOB-15`).

## Selective loading index

| Section | Load it if the inventory has | Procedures |
|---|---|---|
| §7 Mobile backend and client-only controls | API consumed only by the app, on-screen validation | MOB-13 |
| §9 Local authentication | `BiometricPrompt`, `LAContext`, a local PIN or unlock screen | MOB-16 |
| §10 Screen integrity and overlays | a screen that authorizes an effect, `SYSTEM_ALERT_WINDOW`, accessibility | MOB-17 |
| §11 Code that arrives after the store | `DexClassLoader`, `System.load`, CodePush, Expo Updates, live updates | MOB-18 |

Sections §0-§6 (`MOB-01`..`MOB-12`) are in `mobile.md`; §8 (`MOB-14`..`MOB-15`), the iOS specifics, is in `mobile-ios.md`. Same pack, same role, one numbering.

## How to use a procedure

The six fields are a contract. **"What rules it out" is mandatory before you report**. "Minimal test" is static and local: running the app against a server, against someone else's device, or instrumenting it at runtime is marked `REQUIRES AUTHORIZATION`. Three procedures here have a severity that depends on the adversary you declared — state the MAS testing profile as `mobile.md` §0 requires. The full statement of the contract, the citation policy and the tooling caveats are in `mobile.md`.

## §7 Mobile backend and client-only controls

### MOB-13 Controls enforced only on the client

**Where to look**
- Validation that exists only in the app: price or discount computed on the device and sent to the server, quantity capped in the interface, a role read from a local preference, "premium user" resolved from a stored flag.
- Environment checks treated as security: root or jailbreak detection, emulator detection, signature verification performed by the app itself.
- The API the app consumes: if the backend is in scope, apply the `web-api` pack (BOLA and BFLA in `web-api.md`, rate limiting in `web-api-clientside-logic.md`); if it is not, document the surface and do not test it.

**Vulnerable pattern** — the server trusts what the client sends because "only the app talks to it". Anyone can replay the requests with an ordinary HTTP client: the app is an interface, not a trust boundary. Anti-tampering checks raise the attacker's cost, but they are not an access control.

**What rules it out (false positive)**
- The server recomputes and validates every value with impact (price, balance, role, quota) against its own authoritative source.
- Authorization is resolved from the token identity server-side, not from body fields.
- The client-side check is a user-experience improvement and its server-side equivalent exists.

**Minimal test** — static: for every impactful value the app sends, locate the re-validation in the backend. If the backend is out of scope, report it as a probable risk with the client-side evidence. Replaying requests against a real server: **REQUIRES AUTHORIZATION**.

**Traceability**: `CWE-602` · `CWE-639` · `CWE-863` · `MASVS-AUTH-*` · `MASVS-RESILIENCE-*` · `API1:2023`
**Tooling**: extract the list of endpoints and the fields each one sends from the code, then cross it against the backend. No static tool can infer what gets re-validated on the other side.

## §9 Local authentication

### MOB-16 Biometric and local authentication not bound to a cryptographic key

**Where to look**
- Android: which `authenticate(` overload is used — `authenticate(promptInfo)` versus `authenticate(promptInfo, cryptoObject)`; `setAllowedAuthenticators` (`BIOMETRIC_STRONG` versus `BIOMETRIC_WEAK` versus `DEVICE_CREDENTIAL`); the key declaration in `KeyGenParameterSpec.Builder` (`setUserAuthenticationRequired(true)`, `setInvalidatedByBiometricEnrollment(true)`, `setUserAuthenticationParameters(...)` or the older `setUserAuthenticationValidityDurationSeconds(...)`); the deprecated `FingerprintManager`.
- iOS: `LAContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics)` and what its `success` boolean gates, versus keychain items created with `SecAccessControlCreateWithFlags` and `.biometryCurrentSet` / `.userPresence`; whether `evaluatedPolicyDomainState` is compared across launches.
- What happens after success: is anything unwrapped or decrypted, or is a flag set (`isUnlocked = true`) and a screen pushed?
- The way around it: a local PIN compared against a stored hash, a "skip for now" path, a weaker authenticator accepted for the same action, and whether the protected material is reachable without the prompt at all (a cached token, `MOB-03`; a backup, `MOB-02`).

**Vulnerable pattern** — `biometricPrompt.authenticate(promptInfo)` with no `CryptoObject`, whose success callback only navigates. The biometric result is a branch in the app's own code, so the session token and the local data are equally available whether or not the check passed: whoever patches the branch and repackages, or runs the app on a device they control, reaches the same state. The bound version differs in kind — the key that decrypts the material lives in the Keystore or the Secure Enclave, was created requiring user authentication, and is only usable inside the authenticated `CryptoObject`, so there is no branch to flip. Two adjacent failures: a key that survives an enrolment change, so whoever adds a fingerprint to a stolen unlocked device inherits access; and a weak authenticator, or a long authentication validity window, accepted for a high-value action.

**What rules it out (false positive)**
- Success unwraps a key created with `setUserAuthenticationRequired(true)` and `setInvalidatedByBiometricEnrollment(true)` (Android, with `BIOMETRIC_STRONG`, which `CryptoObject` requires) or protected by `.biometryCurrentSet` (iOS), **and** the material it protects is reachable by no other route.
- The prompt is a convenience shortcut over a server-side session that is itself authenticated and revocable: no local material of value is gated by the boolean, and the server re-authorizes the action (`MOB-13`), so flipping the branch gains nothing.
- The action behind the prompt has no security value — reopening a read-only screen, a preference, a re-display of data already on screen.
- Severity, not a rule-out: an unbound check is a defect under any profile, but it is only exploitable by an adversary who holds the device or the artifact. If the engagement declared MAS-L1, report it and say so; do not silently drop it.

**Minimal test** — static and executable: `jadx -d out/ --no-res --no-debug-info app.apk` then `grep -rn "authenticate(\|BiometricPrompt\|CryptoObject\|setUserAuthenticationRequired\|setInvalidatedByBiometricEnrollment\|evaluatePolicy(" out/`. For every `authenticate(` hit read the argument count and follow the success callback to answer one question: does anything cryptographic happen, or does control flow merely change? Then list the keys that declare user authentication and confirm the same material is not reachable another way. Hooking the callback on a device is dynamic instrumentation, excluded from the automated pipeline by `mobile.md` §0 and **REQUIRES AUTHORIZATION**.

**Traceability**: `CWE-287` · `CWE-603` · `CWE-522` · `MASVS-AUTH-*` · `MASVS-CRYPTO-*` · MASWE AUTH group · `MASTG-TEST-*` from the AUTH group
**Tooling**: the grep above → the presence of `BiometricPrompt` says nothing at all; the finding is decided by the **absence** of a `CryptoObject` on the call and of user authentication on the key. jadx may render the overload wrongly or drop the callback body: confirm against the smali from `apktool` before concluding (`mobile.md` §0).

## §10 Screen integrity and overlays

### MOB-17 Confirmation screens without overlay and accessibility defenses

**Where to look**
- Android layouts (`res/layout/*.xml` in the source, `out/res/layout/` after `apktool`): `android:filterTouchesWhenObscured="true"` on the confirming view **and its container**; in code, `setFilterTouchesWhenObscured(true)`, an `onFilterTouchEventForSecurity` override, or a touch handler that discards `MotionEvent` carrying `FLAG_WINDOW_IS_OBSCURED` / `FLAG_WINDOW_IS_PARTIALLY_OBSCURED`; `Window.setHideOverlayWindows(true)` with the `HIDE_OVERLAY_WINDOWS` permission (API 31+); whether the app itself requests `SYSTEM_ALERT_WINDOW`.
- The screens where it matters, which you get by reading the app and not by grepping: confirming a payment or transfer, adding a beneficiary, granting a runtime permission, approving a second factor, changing the password, e-mail or phone number, enrolling a biometric.
- Accessibility: whether the app declares an `AccessibilityService` of its own (`BIND_ACCESSIBILITY_SERVICE` in the manifest), and whether sensitive views are excluded from other services and from autofill (`android:importantForAccessibility`, `android:importantForAutofill`, `android:accessibilityDataSensitive` on API 34+).
- iOS: the platform does not let one app draw over another, so this class largely does not apply; the analogous checks are the app-switcher snapshot and third-party keyboards (`MOB-15`).

**Vulnerable pattern** — a screen that authorizes an irreversible effect accepts touches while another app's window is drawn over it. The attacker's window shows a harmless control, the user taps what they read as "Cancel", and the touch lands on "Confirm transfer" underneath; this is the delivery mechanism behind most Android banking trojans. The platform only reports the condition through the obscured flags — deciding to reject the touch is the app's, and the defense is one property the confirming screen either declares or does not. The accessibility variant reaches further: a service the user granted under a pretext reads the screen and injects the taps, so the operation is authorized without the user ever seeing it. The finding is not that the platform allows overlays; it is that the screen authorizing the effect declares no defense against them.

**What rules it out (false positive)**
- Every view that authorizes the effect filters obscured touches — declaratively or by discarding the flagged events — and the flow hides overlay windows while it is displayed. Confirm the attribute in the **shipped** resource, not only in a theme or a base class the release variant may not apply.
- The screen is rendered with Compose (or any non-XML toolkit) and the guard is applied at the host window or view level. An XML-only grep returns nothing on an app that is correctly defended; check the host before reporting.
- Confirmation is out of band: the effect needs a code, a signature or an approval originating outside that screen, so a stolen tap alone authorizes nothing.
- The screen authorizes nothing irreversible — it navigates, displays, or edits state that the server can undo. Do not report the settings screen.
- Severity, not a rule-out: for apps targeting API 31+ the platform blocks touches passing through untrusted overlays, which lowers exposure on Android 12 and later devices. It is a property of the device and the target SDK, not of the screen; it does not cover the accessibility variant, and the app's `minSdk` tells you the install base that stays exposed.

**Minimal test** — static and executable, no device and no overlay app: `apktool d app.apk -o out/` (with smali, because the guard may live in code and not in the layout) then `grep -rlE "filterTouchesWhenObscured|FLAG_WINDOW_IS_(PARTIALLY_)?OBSCURED|setHideOverlayWindows" out/`, and for a specific screen `aapt2 dump xmltree app.apk --file res/layout/<confirm_layout>.xml`. The list of screens that authorize an effect comes from reading the app; the intersection of that list with "no guard in its layout or its touch path" is the finding. Building an overlay to demonstrate it would mean writing an attacking app: out of scope for this squad, and unnecessary, because the absent control is the evidence.

**Traceability**: `CWE-1021` · `CWE-451` · `MASVS-PLATFORM-*` · MASWE PLATFORM group · `MASTG-TEST-*` from the PLATFORM group
**Tooling**: the grep above over layouts, smali and sources → zero hits in an app that moves money is the finding, not a tooling failure. It is also the field where a grep is least sufficient: it cannot tell you which activity confirms a payment, and a guard applied in a shared base class or at the window level will not appear in the layout resources.

## §11 Code that arrives after the store

### MOB-18 Dynamic code loading and over-the-air bundle updates

**Where to look**
- Android: `DexClassLoader`, `PathClassLoader`, `InMemoryDexClassLoader`, `System.load(` and `System.loadLibrary(` pointing outside the APK, `Class.forName` over a downloaded name, plugin frameworks that load a downloaded APK, DEX or JAR, and `evaluateJavascript(` or `loadUrl("javascript:` with remote script.
- Cross-platform: React Native CodePush, `expo-updates`, Capacitor live updates, Flutter deferred components, Unity asset bundles carrying scripts. For each: the update URL and its scheme, and whether a signature over the bundle is verified before it is applied (CodePush bundle signing with a public key in the app, `expo-updates` code signing with a certificate embedded in the build).
- Where the artifact lands: `getFilesDir()` (private) versus `getExternalFilesDir()`, `getExternalStorageDirectory()` or a shared cache. A writable or shared directory means another app on the device — or an intermediary on the network — chooses what executes.
- iOS: the review rules forbid shipping executable code this way, so the equivalent is a JavaScript bundle executed in a web view or JS engine; the three questions below are identical.

**Vulnerable pattern** — a loader pointed at a file in shared storage, instantiated with nothing verified: `new DexClassLoader(new File(getExternalFilesDir(null), "plugin.dex").getPath(), ...).loadClass(...)`. Code that was never reviewed, never signed by the store and absent from the artifact you analyzed runs with the app's full identity, permissions and data. The OTA bundle case is the same defect dressed as a product feature: a channel that fetches JavaScript and executes it is remote code execution by design, and its only real controls are a verified signature over the bundle and a transport that cannot be stripped (`MOB-09`, `MOB-10`). It is also what ends the reach of a static review: what ships is not what runs.

**What rules it out (false positive)**
- The loaded artifact ships inside the package (`assets/`, `lib/`) or in the app's private directory, is written only by the app, and its signature or hash is verified against a key pinned in the artifact **before** loading, with a failure path that aborts. A hash that is computed and logged, or checked after the class is loaded, is not a control.
- The OTA channel verifies a code-signing signature over the bundle before applying it, fails closed, rolls back, and reaches an endpoint over TLS that `MOB-09`/`MOB-10` confirm cannot be downgraded or intercepted.
- The mechanism is the platform's own delivery — Play Feature Delivery or dynamic feature modules, iOS on-demand resources — where the store performs the verification and the payload is not served from an app-controlled endpoint.
- The loader exists in the source but R8 removed it from the release build. Rule it out only from the artifact: `grep` the DEX output, never the source (`mobile.md` §0).

**Minimal test** — static and executable: `apktool d app.apk -o out/` and `jadx -d jadx-out/ --no-res --no-debug-info app.apk`, then `grep -rn "DexClassLoader\|InMemoryDexClassLoader\|System.load(\|CodePush\|expo-updates\|codeSigningCertificate\|evaluateJavascript(" out/ jadx-out/`; on a source tree also read `app.json` / `Info.plist` / `strings.xml` for the update endpoint and the signing key. For every loader answer three questions — where does the artifact come from, who can write to that path, and what is verified before it is loaded. Missing any one of the three is the finding. Serving a modified bundle to a device: **REQUIRES AUTHORIZATION**.

**Traceability**: `CWE-494` · `CWE-829` · `CWE-114` · `MASVS-CODE-*` · `MASVS-RESILIENCE-*` · MASWE CODE group · `MASTG-TEST-*` from the CODE group
**Tooling**: the greps above → a hit inside a third-party SDK (analytics, A/B testing, a feature-flag vendor) still counts: the app that ships the loader owns the finding. jadx may reconstruct a reflective loader badly or hide it behind string decryption; cross-check the smali, and treat the update endpoint found in resources as authoritative over the one in the repository.
