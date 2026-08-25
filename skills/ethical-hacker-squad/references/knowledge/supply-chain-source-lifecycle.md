# Knowledge pack — software supply chain (source integrity and component lifecycle)

> **When to load this file:** when the target owns the repository that produces the artifact — branch and tag protection, review, signature verification, binaries committed to the tree — and **always before signing off a dependency verdict as clean**, because §11 decides whether "no known vulnerabilities" is a measurement or an unmeasured state.
> **Do not load it if:** the work is confined to manifests and locks, install scripts, registry resolution, typosquatting, pipeline triggers, provenance or the raw triage of SCA output (`supply-chain.md` §1-§7), or to secrets and malicious-package indicators (`supply-chain-secrets-malware.md` §8-§9).
> **Cost:** ~165 lines. Load by section using the index. §11 is the section that changes the verdict of a report that already looked clean.

## Selective loading index
| Section | Load it if the inventory has | Procedures |
|---|---|---|
| §10 Source-side integrity and verification | a git repository whose releases you audit, any `cosign` / `slsa-verifier` / `gh attestation` / `gpg --verify` call, non-text files tracked in the tree | SUP-21, SUP-22, SUP-23 |
| §11 Support lifecycle and suppressed findings | any runtime, base image or engine with a version, any suppression or VEX file, any supplier "not affected" claim, any dependency whose name arrived as a suggestion | SUP-24, SUP-25, SUP-26 |

## How to use a procedure
First locate the files listed under **Where to look**: without that pattern the procedure does not apply and nothing gets reported. Run the **Minimal test** — local and offline unless the field says otherwise; anything reaching a remote system is marked `REQUIRES AUTHORIZATION` — and check it against **What rules it out** before writing anything. Two rules govern this file in particular. **A control you did not exercise is not a control you verified**: a `cosign verify` sitting in a script is evidence that someone wrote a command, nothing more. And **absence of findings is a measurement only when the feed that produces them covers the component**: past end of support, no feed covers it. The full contract, and the §7 triage rules that §11 extends, are in `supply-chain.md`.

## §10 Source-side integrity and verification

### SUP-21 Source-side flow control: unprotected branches, self-approval and movable release tags
**Where to look**
- Protection of the default branch and of every branch a release is built from: required approving reviews, dismissal of stale approvals, review required from `CODEOWNERS`, required status checks, `allow_force_pushes`, `allow_deletions`, and whether administrators bypass all of it.
- Tag protection: whether the tag the release workflow builds from (`on: push: tags:`) can be moved or deleted, and whether commits and tags must be signed.
- `.github/CODEOWNERS` present but with no rule making it mandatory; bot and machine accounts exempted from review; auto-merge on dependency pull requests, which makes the bot account the account to audit.
- In the tree, offline: merge commits authored and approved by the same identity, and commits in the released range whose author email belongs to no domain the project controls.

**Vulnerable pattern**
```text
main            0 required reviewers · force-push allowed · admins bypass
tags 'v*'       not protected
release.yml     on: { push: { tags: ['v*'] } }
# whoever can move the tag chooses the source code of the next signed release
```
**What rules it out (false positive)**
- The controls are enforced by an organization-level ruleset invisible from the repository. Absence of evidence in the tree is not evidence of absence of the control: request the ruleset export, and if it does not arrive report the control as `inconclusive`, never as missing.
- Single-maintainer project with no external contributors: two-party review is unreachable by construction. Report the level that *is* reachable — signed tags, protected refs, an auditable history — instead of a review requirement nobody can meet.
- The release does not build from a mutable reference: the workflow resolves the tag to a commit SHA and the provenance records that SHA, so moving the tag afterwards changes neither what was built nor what a consumer verifies.

Rules: FP-01, FP-06, FP-08.

**Minimal test**: offline, over a clone at the released tag — `git for-each-ref --format='%(refname:short) %(objecttype) %(objectname:short)' refs/tags` and `git log -1 --format='%h %an <%ae> %G? %s' <tag>` (`%G?` is the signature status; `N` means unsigned). Then reconstruct one published release as a chain: tag → commit → author → reviewer. If a single identity — person, bot or CI token — could have produced that commit and moved that tag with no second party, the finding is confirmed. Reading the protection rules themselves (`gh api repos/<owner>/<repo>/branches/<branch>/protection`) needs the network and an authorised token: `REQUIRES AUTHORIZATION`. Report the Source level the project actually meets, not "there is no branch protection".\
**Traceability**: `CWE-284` · `CWE-732` · `CWE-345` · `CWE-494` · `A03:2025` · `A08:2025` · `CICD-SEC-1` · `CICD-SEC-2` · `SLSA Source L2` · `SLSA Source L3` · `SLSA Source L4` · `SSDF PO` · `NIST 800-53 CM` · `NIST 800-53 SR` · `CCM CCC`\
**Tooling**: offline, `git log --show-signature` and `git for-each-ref` tell you what was signed and whether a tag points at a commit or at an annotated object. Everything else — protection rules, rulesets, review settings — lives outside the tree and is an **evidence request, not a scan**: read with an under-privileged token, the API answers "no protection" for a protected branch, a false positive you manufactured yourself, so record the token's scope next to the result. OpenSSF Scorecard covers this ground with `Branch-Protection` and `Code-Review` and shares that limitation, so never quote its score as a measurement of the repository. `SUP-09` already carries the proof that a git tag is a mutable pointer; the **npm maintainer-account compromises of September 2025** (`chalk`, `debug` and sibling packages, entered through a phished maintainer credential) show that one identity is enough to ship someone else's code with the release ceremony intact. `SUP-10` asks who can *trigger* the publication; this asks who can write the commit that gets published.

### SUP-22 Signature verification that accepts any signer, or that gates nothing
**Where to look**
- Every `cosign verify`, `cosign verify-attestation`, `cosign verify-blob`, `gh attestation verify`, `slsa-verifier` and `gpg --verify` call in install scripts, deployment jobs, Dockerfiles, chart hooks and documentation: does it constrain **who** signed — an identity and an issuer, or one specific key — or only **that** something signed?
- Whether the result blocks anything: verification followed by `|| true`, in a `continue-on-error` step, in a job whose failure does not fail the workflow, or run after the artifact was already pulled and executed.
- Whether the verified reference is the deployed reference: verifying a mutable tag and then deploying that same tag verifies one artifact and runs another.
- Trust root and transparency log: a custom Fulcio/Rekor instance, `--insecure-ignore-tlog`, `--insecure-ignore-sct`, an unpinned TUF root, or a GPG keyring downloaded from the same host that serves the artifact.
- Admission-time enforcement in the cluster (policy controller, Kyverno `verifyImages`, Binary Authorization) versus verification that only ever runs on a developer's laptop.

**Vulnerable pattern**
```bash
cosign verify --certificate-identity-regexp '.*' \
              --certificate-oidc-issuer-regexp '.*' \
              ghcr.io/org/app:1.4.2 || true
# any workflow in any repository on that issuer mints a certificate this accepts,
# and the '|| true' means even a hard failure does not stop the deployment
```
**What rules it out (false positive)**
- The call pins the signer identity (or the exact public key) *and* the issuer, the artifact is named by immutable digest, and the check runs where it can deny — admission control or a release gate — not as an advisory step.
- Verification is key-based against a key distributed out of band. Then the identity *is* the key, and what you audit instead is where that key lives, how it rotates and how it would be revoked.
- The permissive command is an example for a downstream consumer to adapt, and the enforced path is elsewhere. Prove that by finding the gate that denies, not by the presence of a command.

Rules: FP-01, FP-04.

**Minimal test**: `rg -n 'cosign (verify|verify-attestation|verify-blob)|slsa-verifier|gh attestation verify|gpg --verify' .` across scripts, workflows, images and docs — **the trailing path is not optional**: with no path and a non-interactive stdin, `rg` reads stdin and hangs instead of searching. For every hit answer three questions **in writing** — which identities it accepts, whether a failure stops the deployment, and whether the digest it verified is the digest that runs. Then re-run that exact command against a published artifact: verifying a public signature is reading, not intrusion, but it leaves the local machine and pulls from a registry, so it is `REQUIRES AUTHORIZATION` whenever that registry is not the client's. **Do not sign anything, do not impersonate a signing identity, and do not write to any transparency log.**\
**Traceability**: `CWE-347` · `CWE-345` · `CWE-295` · `CWE-494` · `A03:2025` · `A08:2025` · `CICD-SEC-9` · `SLSA Build L2` · `SLSA Build L3` · `SSDF PS` · `NIST 800-53 SR` · `CCM CEK`\
**Tooling**: `cosign` (Apache-2.0). **Read the major version the pipeline pins before judging the invocation**: the flags a keyless verification requires changed across major versions, so a command carried over from an older one — like any regexp matching everything — reproduces the permissive behaviour. Check the flags against that version's own documentation rather than assuming, and if you cannot, report the command as `inconclusive` instead of as safe. No scanner decides this: whether a step can deny a deployment is a property of the workflow around the command, not of the command. This is the counterpart of `SUP-12`, which finds the *missing* signature; this one finds the signature that proves nothing, and it is the more expensive of the two because the project already believes it holds the control. Write it as a failed control, not as a hardening suggestion.

### SUP-23 Binary artifacts committed to the source tree and consumed by the build
**Where to look**
- Tracked files that are not text: executables, `.jar`, `.dll`, `.so`, `.dylib`, `.wasm`, `.class`, `.pyc`, archives, and minified bundles with no corresponding source — especially under `tools/`, `scripts/`, `vendor/`, `third_party/`, `test/`, `fixtures/`.
- The build steps that read them: `java -jar tools/*.jar`, a wrapper JAR, a committed compiler plugin, an `LD_PRELOAD`, a shared object loaded by a native extension.
- The history of each blob: who added it, when, and whether that same commit also touched build machinery.

**Vulnerable pattern**
```text
tools/protoc-gen-x          ELF, added 2021, no build recipe in the repo, invoked by `make build`
tests/fixtures/payload.bin  binary "fixture" that no test reads — the Makefile does
```
**What rules it out (false positive)**
- The binary is the declared output of a recipe that lives in the same repository and you can regenerate it, or a vendored artifact pinned by digest whose upstream source you can diff.
- It is genuinely inert data — an image, a font, a fuzzing corpus, a golden file — and no build step reads it. Prove it by finding the reader, not by the file's location: `test/` is exactly where the xz object lived.
- The classifier called a text file binary: an unusual encoding, embedded control bytes, one enormous minified line. Confirm with the reader and with `git ls-files --eol`, not with the classifier alone.

Rules: FP-01, FP-09.

**Minimal test**: `git ls-files -z | xargs -0 file --mime-encoding | grep -w binary` (verified: it lists every tracked file `file` calls binary, and exits **1 with no output when there are none** — that is the clean result, not a failed command; `--mime-type` is the wrong flag here because its aligned output defeats a naive `grep` and it reports JSON and XML as `application/*`). Subtract the documented assets, and for each survivor find what reads it (`rg -n '<basename>' .` across the build path, plus `git log --diff-filter=A -- <path>` for its origin). A binary nobody reads is dead weight; a binary the build reads is unreviewable code executing inside your build. Read it as data if you must (`strings`, a disassembler); **never execute it to find out what it does.**\
**Traceability**: `CWE-506` · `CWE-494` · `CWE-829` · `CWE-1357` · `A03:2025` · `A08:2025` · `SLSA Source L2` · `SLSA Build L3` · `SSDF PS` · `NIST 800-53 SR`\
**Tooling**: `git ls-files`, `file` and `git log --diff-filter=A`, all offline. Every dependency scanner in this pack is **structurally blind** here: no manifest entry, no version to match, so a clean `osv-scanner`, `trivy` or `grype` run is the expected output over a repository full of committed binaries and proves nothing — say that explicitly instead of letting the clean run imply coverage. OpenSSF Scorecard exposes the class as `Binary-Artifacts`. This is the half of **xz utils, CVE-2024-3094** (March 2024) that `SUP-20` does not reach: `SUP-20` compares the published release against the tag, while there the precompiled malicious object sat among binary test files inside the repository.

## §11 Support lifecycle and suppressed findings

### SUP-24 Components and runtimes past their end of support
**Where to look**
- Runtime and platform majors: `engines` in `package.json`, `.nvmrc`, `python_requires`, `FROM <image>:<tag>` and the distribution release inside it, `runtime:` in serverless configuration, `<java.version>`, `TargetFramework`, and the major line of the web framework or ORM.
- Dependencies pinned to a major line the maintainer no longer patches even though a newer major exists.
- Managed services declared in IaC: database and cache engine versions past their extended-support date.
- The client's own commitment: a product shipped to customers inherits the end-of-support date of everything inside it.

**Vulnerable pattern**
```dockerfile
FROM node:<major>-alpine     # branch that stopped receiving security releases months ago
# every scanner reports "no known vulnerabilities": nobody publishes advisories
# for a branch nobody supports
```
**What rules it out (false positive)**
- The vendor or the distribution sells extended support for that branch and the project pays for it. Ask for evidence of the subscription, not for the intention.
- The version exists only in a build stage of a multi-stage build and contributes no layer to the shipped artifact.
- The branch is dead upstream but the project maintains its own patched fork and can show the backports. Then it is a maintenance-cost finding, not an unmeasured-vulnerability finding.

Rules: FP-01, FP-04, FP-08.

**Minimal test**: build the inventory offline first — `rg -n '^FROM |"engines"|python_requires|<java\.version>|TargetFramework|^\s*runtime:|engine_version' .` — then record three fields per runtime, framework, base image and engine: version in use, the vendor's declared end-of-support date, and the source of that date. **The first field is executable; the second is not** — there is no offline oracle for a support calendar, so until the date is in hand the component is `inconclusive`, not clean. Where the date has passed, **downgrade every "no known vulnerabilities" result for that component from *clean* to *unmeasured*** in the report, and say why. Distance to the latest release, which is what `SUP-02` measures, is a different question: a dependency can be perfectly up to date inside a dead branch.\
**Traceability**: `CWE-1104` · `CWE-1395` · `A03:2025` · `A06:2025` · `SSDF PW` · `SSDF RV` · `NIST 800-53 SA` · `NIST 800-53 SR` · `CCM TVM` · `CIS v8.1 Control 2`\
**Tooling**: the primary source is the vendor's own support calendar; an aggregator is secondary evidence and is named as such in the report. This is precisely where `osv-scanner`, `trivy`, `grype` and `npm audit` are silent **by design**, because advisory feeds track supported branches — their silence is not a measurement, and presenting it as one is the error that costs a client most. Two consequences to write down: for an unsupported branch **no fixed version will ever exist**, so the remediation is a migration and not an upgrade; and the staleness figures already recorded in `SUP-02` describe the population this procedure samples. S2C2F files the requirement as `SCA-3`.

### SUP-25 Suppressed CVEs and supplier "not affected" claims accepted without justification
**Where to look**
- Suppression and ignore files: `.trivyignore`, `.grype.yaml`, `osv-scanner.toml`, `audit-ci.json`, `npm audit` overrides, `pip-audit` ignore flags on the CI command line, and the OWASP dependency-check suppression XML.
- VEX documents the project publishes or consumes: OpenVEX `*.vex.json`, CSAF advisories, VEX embedded in a CycloneDX SBOM. For each entry: is there a status, a justification, an author and a date?
- Third-party SBOMs and VEX received from a supplier: whether provenance and signature are checked (`SUP-22`) before the claims are trusted.
- The CI threshold: a build that fails only above a severity level silently suppresses everything below it, and that decision lives in the workflow, not in the ignore file.

**Vulnerable pattern**
```text
.trivyignore
CVE-XXXX-NNNNN        # "false positive"
# no status, no justification, no author, no date, no expiry
# — and git blame says the line is three years old
```
**What rules it out (false positive)**
- The entry carries a status and a justification you can re-derive yourself with `SUP-13`: the vulnerable symbol is not imported, or not reachable, or the component is not in the shipped artifact. A dated, owned, expiring suppression is normal operation, not concealment.
- The supplier's claim arrives with evidence you can re-check locally against the artifact you actually consume. Record that as *verified*, naming what you checked, not as *accepted*.
- The suppressed identifier is a name collision of the kind `SUP-15` describes, not a suppressed vulnerability. Those entries are noise control and belong in the report as such.

Rules: FP-03, FP-08, FP-09.

**Minimal test**: offline and executable — `for f in .trivyignore .grype.yaml osv-scanner.toml; do [ -f "$f" ] && git blame --date=short -- "$f"; done` gives author and date per suppressed line, and an entry with neither is already the finding. (One path per `git blame`: given two, it reads the second as a revision and dies.) Then take every suppressed or "not affected" entry and re-derive the claim independently with the reachability test in `SUP-13`. Report the ones you cannot re-derive as **unverified acceptances**, with their age and their owner, and give the count and the oldest one rather than the full list. **A suppression you did not re-derive is a finding you deleted from your own report on someone else's word.**\
**Traceability**: `CWE-1395` · `CWE-1104` · `CWE-345` · `A03:2025` · `A06:2025` · `A09:2025` · `SSDF RV` · `NIST 800-53 RA` · `CCM TVM` · `CIS v8.1 Control 7`\
**Tooling**: these files are read by hand. There is no scanner for the honesty of a suppression, **by construction**: every tool in `supply-chain.md` §7 reads them in order to obey them, so running the scanner is the one action that can never surface this class. Cross-check a supplier's SBOM against `syft` output over what you actually consume. In OpenVEX a not-affected status is not complete without a justification, so an entry that carries the status alone fails the specification's own bar; verify the literal status and justification vocabulary against the specification before quoting values, because an invented justification string is worse than an empty field. S2C2F files the consumed-SBOM validation requirement as `AUD-4`, and the SLSA threat model treats tampering with the recorded expectations as a verification threat in its own right. That is the point: the attacker's cheapest move is not hiding the vulnerable component, it is getting you to write down that it does not matter.

### SUP-26 A dependency that resolves, and nothing in the project says it should be there
**Where to look**
- Every dependency whose name reached the manifest from a suggestion rather than from a decision: added in a bulk commit, named in a `README` or in an agent instruction file, or present in the manifest with no import anywhere in the code (`SUP-08` covers the mirror case, an import with no manifest entry).
- Registry metadata for each such name, four fields and no more: **first publication date**, **number of published versions**, **repository link**, **download history**. `npm view <pkg> time.created versions repository`, `pip index versions`, the registry JSON endpoint.
- The same name in the **other** ecosystem. A name that resolves in npm and not in PyPI, or the reverse, is the shape this class takes most often.
- The lock file, for what it does **not** answer: an integrity hash proves the bytes did not change between installs, never that the name belonged there.

**Vulnerable pattern** — a package that is real, installs cleanly, carries a valid integrity hash and has no advisory, because it was published **after** the code that imports it and by nobody the project has ever heard of. The registration is the attack; every earlier step in the audit is designed to pass.
```json
{ "name": "fastapi-security-utils", "created": "2026-07-30",
  "versions": ["1.0.0"], "repository": null }          // the project is two years old
```
**What rules it out (false positive)**
- The package is old, widely installed, linked to a repository whose history predates the project, and the project actually calls it. Age and reach are the exculpation here; a name list is not.
- It is a first-party package the project itself published, or an internal name resolved from a private registry — then the question moves to `SUP-05` and `SUP-06`, not away.
- The dependency exists only in a development or test scope and never enters the shipped artifact (`SUP-13` decides that, and says so in the report).
- An organisation-level registry proxy with an allowlist admits only reviewed names. **The exported policy or a written statement is required; without it the answer is `UNKNOWN`, never `HOLDS`.**

Rules: FP-04, FP-08, FP-09.

**Minimal test**: for every candidate, print the four metadata fields and set them beside two dates the repository already knows — the date of the commit that introduced the dependency, and the date of the oldest commit in the project. A package whose **first publication is later than the code that imports it** is the finding, and it needs no further argument. Then check the other ecosystem's registry for the same name. Reading public registry metadata leaves the local machine and is `REQUIRES AUTHORIZATION` when the registry is not the client's; **never install a candidate to find out what it does.**\
**Traceability**: `CWE-1357` · `CWE-829` · `CWE-1104` · `LLM04:2026` · `LLM07:2026` · `A03:2025` · `SSDF PW` · `SSDF RV` · `NIST 800-53 SR`\
**Tooling**: no scanner reports this, and the three reasons are worth stating because each one is a control the project already believes it has. **The lock file** answers byte-stability, not legitimacy. **The advisory database returns nothing**: an advisory exists only after a human reports a specific package version, and the whole value of the registration is the window before anyone does — queried on 2026-08-24, the three package names that circulate as cases of this class returned zero GitHub advisories, while `lodash`, `event-stream` and `ctx` returned records from the same query, so the null is the database's answer and not a broken lookup. **`SUP-07` under-fires by construction**: it keys on a small edit distance to a popular name, and Spracklen et al. (**USENIX Security 2025**, arXiv:2406.10279) measured that most hallucinated names are *not* close to any valid package. The same work is why a harvested blocklist is the wrong instrument: **81%** of invented names came from a single model while **58%** recurred across ten runs of that one model, so the list neither generalises nor survives the next release. Two properties do the work instead — publication date against project age, and a single version with no repository link.
