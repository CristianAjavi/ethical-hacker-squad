# Knowledge pack — Mobile and APK (iOS specifics)

> **When to load this file:** the inventory includes an iOS project (Xcode, Swift/Objective-C, `Info.plist`, entitlements) or an `.ipa`.
> **Do not load it if:** the mobile scope is Android only, or there is no mobile client at all.
> **Cost:** ~55 lines. The entry point of the pack, `mobile.md`, holds §0-§6 and `MOB-01`..`MOB-12`. Read its §0 first: what you may assert from a compiled artifact rather than from source applies to iOS too, the MAS testing profile it requires you to declare applies to iOS too, and its §2, §5 and §6 (storage, TLS, cryptography) cover iOS as well as Android. The third file, `mobile-runtime-trust.md`, holds §7 and §9-§11 (`MOB-13`, `MOB-16`..`MOB-18`); `MOB-16` (local authentication) and `MOB-18` (code loaded after the store) have an iOS side and are worth opening for an `.ipa`.

## Selective loading index

| Section | Load it if the inventory has | Procedures |
|---|---|---|
| §8 iOS specific | `Info.plist`, entitlements, Keychain, pasteboard | MOB-14..MOB-15 |

## How to use a procedure

The six fields are a contract. **"What rules it out" is mandatory before you report**. "Minimal test" is static and local: running the app against a server, against someone else's device, or instrumenting it at runtime is marked `REQUIRES AUTHORIZATION`. MASVS controls are cited at group level, no `MASTG-TEST-NNNN` or `MASWE-NNNN` identifier is invented, and MASVS 2.1.0 defines no L1/L2/R control levels — the MAS profiles (`MAS-L1`, `MAS-L2`, `MAS-R`, `MAS-P`) are the engagement's adversary model and must be declared, as `mobile.md` §0 requires. The full statement of the contract is in `mobile.md`.

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
