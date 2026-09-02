# Knowledge pack — Local applications: desktop shells, local IPC and code that arrives at runtime

> **When to load this file:** the inventory has an Electron, Tauri or embedded-WebView shell, a registered URL scheme or file association, a unix socket, a named pipe, a `127.0.0.1` listener or debug port, a self-updater, or a directory of plugins loaded at runtime.
> **Do not load it if:** the target is a plain command-line tool or a published library with none of the above — those are `local-app.md`, which is also where §0 lives.
> **Cost:** ~90 lines. Three sections that share one attacker: something outside the process reaches into it.
> **Second file of this pack.** `local-app.md` is the entry point and holds §0-§5 and §9-§10 with `LOC-01`..`LOC-10`, `LOC-15` and `LOC-16`. **Read its §0 first, always**: on a local surface a finding that cannot name the second principal is a hardening note, and that rule is written there, not here. This file exists because the pack reached the 32 KiB per-file budget `gate-plugin-integrity.sh` enforces, and a pack file that cannot grow stops being where the next procedure goes.

## Selective loading index

| Section | Load it if the inventory has | Procedures |
|---|---|---|
| §6 Desktop shells | Electron, Tauri, embedded WebView, protocol handlers | LOC-11..LOC-12 |
| §7 Local IPC and listeners | unix sockets, named pipes, `127.0.0.1` servers, debug ports | LOC-13 |
| §8 Update and plugin loading | self-update, plugin directories, runtime downloads | LOC-14 |

## §6 Desktop shells

### LOC-11 Renderer isolation and the preload surface
**Where to look**
- Electron: `BrowserWindow` `webPreferences` with `nodeIntegration: true`, `contextIsolation: false`, `sandbox: false`, `webSecurity: false`, `allowRunningInsecureContent`, `<webview>` with `nodeintegration`; the preload script and every `contextBridge.exposeInMainWorld` surface; `ipcMain.handle` without validating the channel payload; `shell.openExternal` reached from renderer input.
- Tauri: capability and allowlist entries granting `shell`, `fs` with a `**` scope, or `http` with a wide allowlist.
- Embedded WebViews in native desktop apps; for Android and iOS WebViews use `mobile.md` instead.

**Vulnerable pattern** — content the application did not author is rendered in a context that can reach Node, the shell or the filesystem. With `contextIsolation` off or a broad `contextBridge` API, a single cross-site scripting in the renderer becomes command execution on the user's machine.

**What rules it out (false positive)**
- `contextIsolation: true`, `sandbox: true`, `nodeIntegration: false`, and a preload that exposes a small, typed API which validates every argument before acting.
- Only local, application-authored content is loaded; remote URLs are opened in the OS browser rather than in a window.
- The `fs` or `shell` capability is scoped to a specific directory or command, not to a wildcard.

Rules: FP-01, FP-02, FP-05.

**Minimal test** — read `webPreferences` and the preload together; then, in a scratch build, load a local page that calls each exposed bridge method with an out-of-contract argument and observe whether it is rejected.\
**Traceability**: `CWE-829` · `CWE-79` · `CWE-1188` · `ASVS 5.0 V3`\
**Tooling**: `rg -n "webPreferences|contextIsolation|nodeIntegration|contextBridge|ipcMain|openExternal"`; for Tauri read the capability files. The absence of a match is not proof — check the defaults of the framework version in use.

### LOC-12 Custom URL schemes, deep links and file associations
**Where to look**
- macOS `Info.plist` `CFBundleURLTypes` and `CFBundleDocumentTypes`; Linux `.desktop` entries with `Exec=` and `%u`; Windows registry protocol handlers; Electron `setAsDefaultProtocolClient` plus the `open-url` and `second-instance` handlers; the argv parser that receives the URL.

**Vulnerable pattern** — any web page can cause the application to be launched with an attacker-chosen string. If the handler interpolates that string into a command line, a path, or a window that then loads it, the browser has become a remote entry point into a local process. The `%u` placeholder in a `.desktop` file and a handler that concatenates are the two recurring shapes.

**What rules it out (false positive)**
- The handler parses the URL, validates the scheme and host, and maps it to a fixed set of actions with no path or command interpolation.
- Any action with side effects requires a user confirmation that names what will happen.
- The scheme is registered but the handler ignores everything except a known token format.

Rules: FP-01, FP-05.

**Minimal test** — construct a payload URL locally and invoke it through the OS (`open "app://..."` on macOS, `xdg-open` on Linux), with the application instrumented to print the argv it received. Inspect what arrived before deciding what it can do.\
**Traceability**: `CWE-88` · `CWE-829` · `CAPEC-6`\
**Tooling**: `rg -n "setAsDefaultProtocolClient|open-url|CFBundleURLTypes|Exec=.*%u"`; read the argv handler, not the registration.

## §7 Local IPC and listeners

### LOC-13 Local sockets and listeners without peer or origin checks
**Where to look**
- Unix domain sockets and named pipes created by a daemon or helper; `127.0.0.1` HTTP or WebSocket servers used for OAuth callbacks, IDE integration, dev servers, or an internal control API; debug ports (`--inspect`, JDWP, remote debugging); gRPC bound to loopback.

**Vulnerable pattern** — two distinct failures. A unix socket with permissive modes and no peer credential check lets any local user drive the daemon. An HTTP listener on loopback with no `Origin` check and no token lets **any web page the user visits** drive it, because the browser will happily send the request; where the API answers to a hostname rather than to `Origin`, DNS rebinding removes even the same-origin obstacle.

**What rules it out (false positive)**
- The socket lives in a `0700` per-user directory, is `0600`, and the daemon checks peer credentials.
- The HTTP listener validates `Origin` against an allowlist, requires a high-entropy token in a header (not in the URL), binds to `127.0.0.1` on a random port, and rejects requests whose `Host` it does not recognise.
- The listener exists only during an interactive flow and closes immediately after.

Rules: FP-01, FP-04, FP-06.

**Minimal test** — while the app runs, list what it is listening on, then send one request with a foreign `Origin` header and no credentials and record the response code. Loopback only, no third party involved.\
**Traceability**: `CWE-346` · `CWE-1385` · `CWE-668` · `ASVS 5.0 V4`\
**Tooling**: `lsof -nP -iTCP -sTCP:LISTEN` or `ss -ltnp`; `curl -sS -H 'Origin: https://evil.example' http://127.0.0.1:<port>/<path> -o /dev/null -w '%{http_code}\n'`. A 200 with no token is the finding; a 403 is not proof the token check is sound.

## §8 Update and plugin loading

### LOC-14 Code that arrives at runtime without integrity verification
**Where to look**
- Self-update code and `autoUpdater` configuration (feed URL, whether code signing is enforced); installers that download and execute; documentation recommending a pipe from a download into a shell; plugin directories loaded by glob; runtime `pip install`, `npm install` or `curl` of an artifact that is then executed.

**Vulnerable pattern** — executable content is fetched or loaded at runtime and nothing verifies who produced it, or the verification exists but fails open. Sub-cases worth separating: an update channel over plain HTTP; a signature checked after the payload has already been written to a privileged path; a plugin directory writable by another local user; a pinned key that is never actually compared.

**What rules it out (false positive)**
- A signature is verified against a pinned key **before** the payload is executed or moved into place, and a verification failure aborts the update.
- The platform enforces it: OS code signing and notarization, a package manager with its own verified channel.
- The plugin directory is owned by root or by the installing user and is not writable by others, and plugins are enumerated from a fixed list rather than a glob.

Rules: FP-01, FP-06.

**Minimal test** — read the update path end to end and answer three questions: what is fetched, over what scheme, and what happens on a verification failure. Then check the mode and ownership of the plugin and install directories.\
**Traceability**: `CWE-494` · `CWE-829` · `ATT&CK T1195` · `SLSA Build L2`\
**Tooling**: `rg -n "autoUpdater|electron-updater|feedURL|http://|install.*&&.*sh"`; for the shipped artifact, verify the signature with the platform tool rather than trusting the build script.
