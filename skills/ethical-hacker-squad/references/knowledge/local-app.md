# Knowledge pack — Local applications: CLI, desktop and libraries

> **When to load this file:** the inventory has a command-line tool, a desktop application (Electron, Tauri, native shell), a published library or SDK, an installer or updater, a local daemon, or any program whose attack surface is the machine it runs on rather than an HTTP route.
> **Do not load it if:** the scope is only a web backend with no local artifact, only IaC and containers, or only dependency manifests.
> **Cost:** ~274 lines. Load by section using the index; **§0 first**, because on a local surface the hard part is naming the attacker, not finding the pattern.
> **Second file of this pack:** `local-app-desktop-ipc.md` holds §6-§8 and `LOC-11`..`LOC-14` — Electron and WebView renderer isolation, protocol handlers and deep links, local IPC and loopback listeners, and code that arrives at runtime. Open it as soon as the inventory has a desktop shell, a socket or a self-updater; it carries its own index. **§0 stays here and governs it too.**

## Selective loading index

| Section | Load it if the inventory has | Procedures |
|---|---|---|
| §0 Who the attacker is here | always, before reporting | — |
| §1 Filesystem surface | file arguments, archive extraction, recursive delete or copy | LOC-01..LOC-02 |
| §2 Temporary files and races | `/tmp` use, lock files, check-then-open patterns | LOC-03..LOC-04 |
| §3 Process surface | subprocess calls, `PATH`, plugins, config discovery | LOC-05..LOC-07 |
| §4 Privileges and permissions | files created at runtime, setuid, sudo helpers, services | LOC-08..LOC-09 |
| §5 Published library defaults | a package other people import | LOC-10 |
| §6-§8 → `local-app-desktop-ipc.md` | a desktop or WebView shell, a socket or loopback listener, a self-updater or a plugin directory | LOC-11..LOC-14 |
| §9 Secrets at rest | token caches, config files, logs, crash reports | LOC-15 |
| §10 The encoding boundary | a walk over a tree somebody else can write into, batch scanning, log ingestion | LOC-16 |

Injection, deserialization and file-content handling do **not** live here: they transfer from `web-api.md` §3 and §5 (`WEB-07`..`WEB-12`) and apply unchanged to a local process. Dependencies and publishing are `supply-chain.md`. Container and CI packaging is `infra-cloud.md`. `LOC-16` is about undecodable bytes breaking the tool that reads them; invisible characters smuggled *into a model's context* are `AI-20` in `ai-safety-data-output.md`, a different victim.

## §0 Who the attacker is here

A local surface has no anonymous internet attacker, and reporting as if it did is the fastest way to manufacture a false positive. Before writing a finding, name which of these you mean:

- **Another user on the same machine** — the classic multi-user or shared-CI case. This is who wins a symlink race, reads a world-readable token, or plants a binary earlier in `PATH`.
- **A file the tool is pointed at** — an archive, a project directory, a config file, a document. The victim runs the tool; the attacker wrote the input.
- **A hostile working directory** — the tool is run inside a repository or download folder someone else produced. Anything discovered relative to `cwd` is attacker-controlled.
- **Remote content rendered by the app** — a page, a deep link, a web origin reaching a local listener. This is the one that turns a desktop app into a remote surface.
- **A consumer of the library** — for a published package, the "victim" is the application that imports it and inherits an unsafe default.

Two rules that prevent most of the noise in this pack:

1. **The user is not an attacker against themselves.** A single-user tool that lets its owner edit their own config, read their own token file, or pass their own dangerous flag is not a vulnerability. It becomes one when a *second* principal appears: another local account, a file the owner did not write, a page the owner merely visited.
2. **State the crossing.** Every finding here must say which boundary is crossed — user to user, file to process, web origin to local process, library to consumer. A finding that cannot name it is a hardening note, not a vulnerability.

**Out of scope of this pack, and of every pack in this corpus:** memory-safety and binary exploitation in native code, kernel drivers, firmware, embedded and industrial control, and smart contracts. Say so instead of stretching a procedure over them.

## §1 Filesystem surface

### LOC-01 Path traversal in file arguments and archive extraction
**Where to look**
- Python: `zipfile.ZipFile.extractall`, `tarfile.open(...).extractall` without `filter="data"`, `os.path.join(dest, name)` on an entry name; Node: `adm-zip`, `tar`, `unzipper`, `path.join(dest, entry.fileName)`; Java: `ZipInputStream.getNextEntry` with `new File(dir, entry.getName())`; Go: `archive/zip` with `filepath.Join`.
- Any command that takes a destination and a name from outside: `--output`, `--extract-to`, import and restore flows, plugin and template installers, "download this attachment" helpers.

**Vulnerable pattern** — an entry name from the archive, or a path from an argument, is joined to a destination and used without canonicalizing the result and re-checking that it is still inside. The name may carry `..` segments, an absolute path, a Windows drive letter, a backslash separator on a case-insensitive filesystem, or a trailing NTFS stream. Example: `zf.extractall(dest)` where the archive contains `../../.ssh/authorized_keys`.

**What rules it out (false positive)**
- Extraction goes through a filter that rejects traversal and absolute names (Python 3.12+ `filter="data"`), or every resolved path is compared against the canonicalized destination prefix **after** resolving symlinks, and a mismatch aborts.
- The archive is produced by the same program in the same run and never leaves a private directory.
- The destination is a fresh directory created for this operation and the process cannot write anywhere interesting anyway — argue it, do not assume it.

Rules: FP-01, FP-02, FP-06.

**Minimal test** — in a temporary directory, build an archive whose entry name is `../evidence-<random>.txt`, run the application's extraction function against a subdirectory, and check whether the file landed outside. Local, non-destructive, no privileges.\
**Traceability**: `CWE-22` · `CWE-23` · `CAPEC-126` · `ASVS 5.0 V5`\
**Tooling**: `rg -n "extractall|ZipInputStream|adm-zip|archive/zip|filepath.Join"` → it tells you where to read. A match proves nothing until you see whether the joined path is re-checked after canonicalization.

### LOC-02 Symlink following on write, delete or permission change
**Where to look**
- Recursive operations on paths the process did not create: `shutil.rmtree`, `shutil.copytree`, `os.remove`, `os.chmod`/`os.chown`, `fs.rm({recursive:true})`, `rm -rf` in a shell wrapper, cache and log cleanup, uninstall routines.
- Extraction code that recreates entries of type symlink, then writes further entries through them.

**Vulnerable pattern** — the program writes to, deletes, or changes the mode of a path that another local user can replace with a symlink, and the operation follows it. The cleanup of a shared temporary directory is the textbook case; so is an installer that `chmod`s a tree it does not own.

**What rules it out (false positive)**
- The operation is confined to a directory the process created in this run, owned by it, mode `0700`, inside a per-user location.
- File descriptors are opened with `O_NOFOLLOW` or resolved relative to a directory handle (`dir_fd`, `openat`), so the name cannot be swapped underneath.
- Only one principal exists on the machine by design — a single-user desktop, a container with one account — and you can say so concretely.

Rules: FP-01, FP-06.

**Minimal test** — in a temporary sandbox, place a symlink where the program expects a regular file or directory, point it at a canary file outside, run the operation and inspect the canary. Never run this against a real path.\
**Traceability**: `CWE-59` · `CWE-61` · `CAPEC-27` · `ASVS 5.0 V5`\
**Tooling**: `rg -n "rmtree|copytree|os.remove|unlink|chmod|chown"` plus `ls -l` on the directories involved; the finding is the combination of an unowned path and a following operation.

## §2 Temporary files and races

### LOC-03 Predictable temporary files in a shared directory
**Where to look**
- `tempfile.mktemp`, `os.tmpnam`, string concatenation onto `/tmp` or `os.tmpdir()`, names built from the pid, the timestamp or a weak random, shell redirections such as `> /tmp/tool.$$`.
- Lock files, sockets, editor swap files, downloaded update payloads staged before verification.

**Vulnerable pattern** — the path is guessable and the directory is shared, so another user pre-creates it as a file or a symlink before the program opens it. The program then writes through the attacker's handle, or reads content the attacker planted.

**What rules it out (false positive)**
- Creation is atomic and exclusive: `mkstemp`, `NamedTemporaryFile`, `O_CREAT|O_EXCL`, `mkdtemp` for a whole working directory.
- `TMPDIR` resolves to a per-user directory that the OS creates `0700` — true on macOS by default, not on a bare Linux `/tmp`.
- The content is public, has no integrity requirement, and nothing later trusts it — state which, rather than assuming all three.

Rules: FP-01, FP-06, FP-07.

**Minimal test** — run the tool twice and compare the names it creates; if they are predictable, pre-create the next one in a sandbox and observe whether the program opens it instead of failing.\
**Traceability**: `CWE-377` · `CWE-378` · `CWE-379` · `ASVS 5.0 V5`\
**Tooling**: `rg -n "mktemp|tmpnam|/tmp/|os.tmpdir"` and `ls -ld` on the directory actually used at runtime.

### LOC-04 Time-of-check to time-of-use on a path
**Where to look**
- `os.path.exists` / `os.access` / `stat` followed by `open`; `if not exists: create`; validating a path and reopening it **by name**; `test -f` in a wrapper script before acting.
- Any sequence where the security decision and the operation are two syscalls on the same name.

**Vulnerable pattern** — between the check and the use, another local user replaces the name. The check passed on a benign object; the operation lands on a different one. `os.access` before `open` is the canonical example: it answers a question about the past.

**What rules it out (false positive)**
- The operation itself is atomic and carries the check: `O_CREAT|O_EXCL`, `renameat`, opening first and validating the *file descriptor* with `fstat` rather than the path.
- Every path in the sequence lives inside a private directory the process created and owns.
- The check is advisory — a nicer error message — and the code is correct when it loses the race. Read the failure branch before deciding this.

Rules: FP-01, FP-06, FP-10.

**Minimal test** — reason it out from the two syscalls and the ownership of the directory; a race is a property of the code, not something a single run demonstrates. If a demonstration is needed, run a bounded loop in a sandbox that swaps the name while the operation runs, with a fixed iteration cap, and report the win rate observed.\
**Traceability**: `CWE-367` · `CAPEC-29` · `ASVS 5.0 V5`\
**Tooling**: `rg -n -B2 -A4 "os.access|path.exists|lstat|stat\("` and read what happens immediately after the check.

## §3 Process surface

### LOC-05 Argument injection into a subprocess
**Where to look**
- A user-controlled value placed into an argument vector: wrappers around `git`, `ssh`, `curl`, `tar`, `rsync`, `find`, `ffmpeg`, package managers; `subprocess.run([...])`, `child_process.spawn`, `exec.Command`, `Runtime.getRuntime().exec`.
- Any place a filename, branch, URL or identifier reaches a command without a `--` terminator.

**Vulnerable pattern** — the value starts with `-` (or contains `=` for a `--flag=value` form) and is read as an option rather than as data. Passing a list instead of a shell string prevents shell metacharacters, **not** this. The high-value options are the ones that execute or write: `ssh -o ProxyCommand=`, `git -c core.pager=`, `curl -o`, `tar --to-command`, `find -exec`.

**What rules it out (false positive)**
- The command line contains an explicit `--` before positional values, and the value is not consumed as an option after it.
- The value is validated against an allowlist, or resolved to a path that must already exist inside a known directory.
- The value is a literal in the source and nothing external can reach it.

Rules: FP-01, FP-02.

**Minimal test** — call the entry point with a value beginning with `-` (for example `-o/tmp/canary-<random>`) in a sandbox and observe whether the child's behaviour changes or the canary appears.\
**Traceability**: `CWE-88` · `CWE-78` · `CAPEC-6` · `ASVS 5.0 V1` · `ASVS 5.0 V2`\
**Tooling**: `rg -n "subprocess|spawn\(|exec\(|os.system|Runtime.getRuntime"` → read each call site for a `--` and for where the value came from.

### LOC-06 Untrusted search path for executables and libraries
**Where to look**
- Bare command names in a subprocess call (`"git"`, `"python"`) resolved through the inherited `PATH`; `PATH` assembled from environment or config; `LD_PRELOAD`, `LD_LIBRARY_PATH`, `DYLD_INSERT_LIBRARIES` honoured while privileged; Windows DLL search order; `rpath` containing `$ORIGIN` or a writable directory.
- Interpreter path effects: `python` with the current directory on `sys.path`, Node resolving `require` from `cwd`, a plugin directory added by glob.

**Vulnerable pattern** — the program resolves an executable or a shared library **by name**, and the resolution can reach a directory another user can write: the current directory, a shared temporary directory, an install path with loose permissions.

**What rules it out (false positive)**
- Executables are invoked by absolute path, or the resolved path is verified and its ownership checked before use.
- The privileged component scrubs the environment (`env -i`, explicit allowlist) before spawning anything.
- Every directory on the search path is owned by root or by the running user and is not group- or world-writable — check with `ls -ld`, do not assume.

Rules: FP-01, FP-06.

**Minimal test** — in a sandbox directory, place an executable with the same bare name earlier in `PATH`, run the tool from there, and see which one runs.\
**Traceability**: `CWE-426` · `CWE-427` · `CAPEC-38` · `CAPEC-471` · `ATT&CK T1574`\
**Tooling**: `rg -n "\"(git|sh|bash|python|node|npm|docker)\""` at call sites; `otool -l` or `readelf -d` for `rpath` on a shipped binary.

### LOC-07 Configuration and code discovered from the working directory
**Where to look**
- Config discovery that walks up from `cwd`: `.toolrc`, `*.yml`, `.env`, `pyproject.toml`, `package.json` scripts, `Makefile`, `conftest.py`, editor and linter configs, VCS hooks, plugin autoload directories.
- Agent-facing instruction files — `CLAUDE.md`, `AGENTS.md`, `.cursor/rules/` — when the local tool feeds them to a model. That case is `ai-safety.md` §1 and §8; cite it there and cross-reference.

**Vulnerable pattern** — running the tool inside a directory produced by someone else (a cloned repository, an unpacked archive, a downloaded sample) makes it read configuration that selects an executable, adds a plugin path, disables verification, or defines a hook that runs. The victim's only action was `cd`.

**What rules it out (false positive)**
- Repository-level configuration is data only: it can never name a binary, a plugin path, a hook, or a flag that disables a security control.
- Behaviour-changing configuration is only accepted from a per-user location, or requires an explicit opt-in flag on the command line each time.
- The tool refuses configuration files not owned by the invoking user, and says so when it does.

Rules: FP-01, FP-06.

**Minimal test** — build a directory containing a hostile configuration that flips one security-relevant setting (certificate verification off, a plugin path added), run the tool inside it, and check whether the setting took effect.\
**Traceability**: `CWE-426` · `CWE-829` · `CAPEC-38` · `ASVS 5.0 V13`\
**Tooling**: `rg -n "cwd|getcwd|walk_up|find_up|parent.parent"` around config loading; read the precedence order and ask which layer a stranger can write.

## §4 Privileges and permissions

### LOC-08 Files and directories created with permissive modes
**Where to look**
- Everything the program creates at runtime: token and session caches, sqlite databases, logs, sockets, downloaded payloads, `os.makedirs` without a mode, `open(path, "w")` for a credential file, an explicit `chmod 0o777`, a `umask` the program never sets.

**Vulnerable pattern** — a file holding credentials or state is readable by other local users, or a file the program later trusts is writable by them. The second is worse: a writable state file is an execution path controlled by someone else.

**What rules it out (false positive)**
- The file sits inside a per-user directory that is itself `0700`, and the platform enforces it (a Windows profile directory with inherited ACLs, a macOS per-user `TMPDIR`).
- The content is public and nothing downstream trusts it for a security decision.

Rules: FP-06, FP-07.

**Minimal test** — run the tool with a fake credential, then `stat` every path it created. Report the mode, the owner and what the file contains, redacted.\
**Traceability**: `CWE-276` · `CWE-732` · `CWE-668` · `ASVS 5.0 V14`\
**Tooling**: `find <data-dir> -type f -perm -o+r` and `-perm -o+w`; `stat -c '%A %U %n'` on Linux, `stat -f '%Sp %Su %N'` on macOS.

### LOC-09 Privileged helpers and elevated execution
**Where to look**
- setuid or setgid binaries shipped by the application; `sudo` invoked from the tool; install scripts run with elevation; `launchd` plists, `systemd` units, Windows services created at install time; an updater daemon.

**Vulnerable pattern** — a privileged component accepts input from an unprivileged one — a path, an argument, an environment variable, a socket message — and acts on it without validating it or dropping privileges. Or the whole program runs elevated when only one step needs it.

**What rules it out (false positive)**
- The privileged step takes no external input: a fixed operation, no arguments, no environment inheritance.
- The helper authenticates the calling user, validates every path against a fixed allowlist, and scrubs the environment.
- Elevation is requested interactively by the OS for that one action, and the action is described to the user.

Rules: FP-01, FP-02, FP-05.

**Minimal test** — read the unit or plist, then check ownership and mode of every file and directory it references. Do not run privileged operations to demonstrate this; the configuration is the evidence. Anything beyond reading is **REQUIRES AUTHORIZATION**.\
**Traceability**: `CWE-250` · `CWE-269` · `CWE-732` · `ASVS 5.0 V15`\
**Tooling**: read the packaging scripts; `ls -l@` on the install directory. Scope any `find -perm -4000` to the application's own paths, never the whole filesystem.

## §5 Published library defaults

### LOC-10 Insecure-by-default parameters in a public API
**Where to look**
- Default argument values in the exported surface: `verify=False`, `check_hostname=False`, `autoescape=False`, `allow_pickle=True`, `strict=False`, `insecure=True`, a default signing key, a permissive default CORS in an embedded server, a default that disables certificate pinning.
- Constructors that accept a callable, a deserializer, or a template loader, and default it to the permissive option.

**Vulnerable pattern** — the safe behaviour requires the consumer to pass an argument. Every consumer that reads only the quickstart is insecure, and the finding lands in *their* CVE, not yours. The defect is the default, not the option's existence.

**What rules it out (false positive)**
- The insecure mode requires an explicit argument whose name says what it does, and the documentation says when it is acceptable.
- The library is internal, with one known consumer whose call sites you can read.
- The default is safe and the permissive path is reachable only under a flag that also warns.

Rules: FP-01, FP-02, FP-06.

**Minimal test** — write a scratch script that calls the public API with the minimum arguments from the README, then assert which control is active: is the certificate verified, is the template escaped, is the payload parsed without executing.\
**Traceability**: `CWE-1188` · `CWE-665` · `ASVS 5.0 V15`\
**Tooling**: read the exported signatures directly (`rg -n "^def |^class |export function|pub fn"`); a scanner will not tell you which default is the dangerous one.

## §9 Secrets at rest

### LOC-15 Credentials and personal data left on the machine
**Where to look**
- Token and session caches under the application's data directory, sqlite databases, `.netrc`-style files, logs, crash reports and telemetry payloads, shell history, and the argument vector itself.

**Vulnerable pattern** — three distinct shapes. A credential stored in cleartext in a file with permissive modes. A credential passed as a **command-line argument**, which every other user on the machine can read from the process table. A credential or personal datum written into logs or a crash report that is then uploaded off the machine.

**What rules it out (false positive)**
- The OS keystore holds the secret: Keychain, libsecret or the Windows credential manager, with the file on disk holding only a handle.
- The file is `0600` inside a `0700` per-user directory and the threat model explicitly accepts a local attacker with the user's own privileges — say that out loud rather than implying it.
- Secrets are accepted from an environment variable, standard input or a file path, never from `argv`, and log writers pass values through a redactor with a test proving it.

Rules: FP-01, FP-06.

**Minimal test** — run a command with a distinctive fake token, then search the data directory, the log files and `ps -eo args` output for that string. Report where it appeared, never the real value.\
**Traceability**: `CWE-312` · `CWE-522` · `CWE-532` · `CWE-214` · `ASVS 5.0 V14`\
**Tooling**: `rg -n --hidden "<canary>" ~/.config/<app> ~/.cache/<app>` in a scratch profile, plus `ps -eo args` captured while the command runs. Never run a repository-wide secret scan against paths outside the authorized scope.

## §10 The encoding boundary

### LOC-16 Bytes that break the analyser: non-UTF-8 paths and undecodable content
**Where to look**
- Any walk over a tree the program does not own, followed by serialization of what it found: Python `os.walk`/`os.listdir`/`Path.rglob` feeding `json.dumps`, a Pydantic model or a log record; Go `filepath.WalkDir` with `encoding/json`; Node `fs.readdir` without `{ encoding: "buffer" }`; Java `Files.walk` decoded with the platform charset.
- Every read of target content that names an error handler: `errors="ignore"`, `errors="replace"`, `errors="surrogateescape"`, `new String(bytes, Charset.defaultCharset())`, `strings.ToValidUTF8`.
- Jobs whose unit of work is a whole directory somebody else can write into: secret scanners and SAST steps in CI, SBOM generators, indexers, backup and sync agents, log shippers, upload processors, archive extractors.

**Vulnerable pattern** — three shapes, failing in opposite directions.
1. **Abort.** A POSIX filename is bytes, not text. Python decodes an invalid one with `surrogateescape`, producing lone surrogates in `U+DC80`-`U+DCFF` (inside the low-surrogate block `U+DC00`-`U+DFFF`) that no JSON encoder will emit: the first `json.dumps` raises `UnicodeEncodeError` and the run dies. Whoever can create a filename in the scanned tree stops the scan, and everything the walk had not reached is never examined — while the job reads as an infrastructure flake, not as a disabled control. Tencent shipped `strip_surrogates` for exactly this in `AI-Infra-Guard` on 2026-09-01.
2. **Silent drop.** `errors="ignore"` deletes the undecodable bytes *before* the matcher sees them, so the pattern that would have matched no longer exists; a consumer downstream that decodes the raw bytes differently gets the payload back. A filter bypass whose symptom is a clean report.
3. **Skipped and undeclared.** The decode error is caught, the file is skipped, and the summary reports zero findings without reporting zero files read. A control that cannot say what it did not cover is publishing `not measured` as `OK`.

**What rules it out (false positive)**
- The walk carries bytes end to end (`os.scandir` on a `bytes` path, `fs.readdir` with `encoding: "buffer"`, `[]byte`) and converts only at the edge, through a lossless transport such as hex or base64 for the name.
- Undecodable input is normalized at one declared choke point before serialization **and a test feeds it a lone surrogate** — the test is the evidence; the existence of a sanitizer function is not.
- A skipped file is counted and named in the output, so the report separates "read and clean" from "not read".
- Nothing but the principal that runs the tool can write into the tree: no upload, no extracted archive, no clone, no contributor. Name that principal — §0 of this pack.

Rules: FP-02, FP-06, FP-09.

**Minimal test** — in a scratch directory, plant one file whose *name* is not valid UTF-8 and whose *content* is not either, then run the tool over that directory:
```
mkdir -p /tmp/ehs-probe && python3 -c 'open(b"/tmp/ehs-probe/bad\xff.txt","wb").write(b"canary\xffvalue")'
```
Three outcomes, three verdicts: it crashes → shape 1; it finishes and never mentions the file → shape 3; it finishes, mentions the file, and the canary is missing from the evidence → shape 2. Local, non-destructive, no privileges.\
**Traceability**: `CWE-176` · `CWE-248` · `CAPEC-267` · `ASVS 5.0 V1`\
**Tooling**: `rg -n 'errors\s*=\s*.(ignore|replace|surrogateescape)|os\.walk|filepath\.WalkDir|Files\.walk'` → it tells you where to read; whether the walk and the serializer agree on what a name is shows only in the test above. Plant the byte with `printf` or Python, never by typing it: an editor normalizes it away before it reaches disk.
