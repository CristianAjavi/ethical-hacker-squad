# Knowledge pack — software supply chain

> **When to load this file:** when the target has third-party dependencies, a package registry, an artifact publishing flow, or when you need to triage the output of a software composition analysis (SCA) scanner and hunt for secrets in the repository and its history.
> **Do not load it if:** the audit only covers infrastructure or network configuration (use `infra-cloud.md`) or application logic with no relevant external dependencies.
> **Cost:** ~333 lines. Load by section using the index; §7 changes the report the most.
> **Second file of this pack:** `supply-chain-secrets-malware.md` holds §8-§9 and `SUP-16`..`SUP-20` — secrets in the working tree, in git history and outside the repository, plus behavioural indicators of a malicious package. §8 applies to every git repository, so that file is opened on almost every engagement; it carries its own index.
> **Third file of this pack:** `supply-chain-source-lifecycle.md` holds §10-§11 and `SUP-21`..`SUP-26` — who can write and tag the code that gets published, signature verification that accepts any signer or gates nothing, binaries committed to the tree, components past end of support, suppressed CVEs, and the dependency that resolves although nothing in the project asked for it. Open it whenever you audit the repository that produces the artifact, and **always before closing a §7 verdict as clean**: `SUP-24` is what separates *clean* from *unmeasured*. It carries its own index.

## Selective loading index
| Section | Load it if the inventory has | Procedures |
|---|---|---|
| §1 Manifests and locks | `package.json`, `requirements.txt`, `go.mod`, `Cargo.toml`, `pom.xml` | SUP-01, SUP-02 |
| §2 Install scripts | `package.json` with `scripts`, `setup.py`, `build.rs`, gradle | SUP-03, SUP-04 |
| §3 Dependency confusion and registries | `.npmrc`, `pip.conf`, `settings.xml`, a private registry | SUP-05, SUP-06 |
| §4 Typosquatting and slopsquatting | new dependencies, LLM-assisted code | SUP-07, SUP-08 (+ `SUP-26`) |
| §5 CI/CD and publishing integrity | `.github/workflows/`, `release.yml`, registry tokens | SUP-09, SUP-10 |
| §6 Provenance, SBOM and signing | SLSA requirements, SBOM, binary distribution | SUP-11, SUP-12 |
| §7 Dependency vulnerability triage | any SCA output (always) | SUP-13, SUP-14, SUP-15 |

Sections §8 and §9 (`SUP-16`..`SUP-20`) are in `supply-chain-secrets-malware.md`. Sections §10 and §11 (`SUP-21`..`SUP-25`) are in `supply-chain-source-lifecycle.md`: §10 when you audit the repository that produces the artifact or any signature-verification command, §11 whenever you are about to call a dependency result clean.

## How to use a procedure
First locate the files listed under **Where to look**: without that pattern the procedure does not apply and nothing gets reported. Run the **Minimal test** — local, no network unless stated, and never touching third-party systems — to move from "the scanner flagged it" to "I verified it". Check it against **What rules it out** before writing anything; in this discipline most raw findings die right there. **Traceability** feeds the report matrix and **Tooling** states what to read and what *not* to conclude. Two cross-cutting rules for §7: **an SCA finding with no evidence of an import or a call to the vulnerable symbol drops to informational**, and you say so in the report; and **before writing that a component is clean, close `SUP-24` and `SUP-25`** (§11, in `supply-chain-source-lifecycle.md`) — past end of support the scanner's silence is not a measurement, and a suppression you did not re-derive is a finding you deleted from your own report.

Prioritization: Verizon's DBIR 2026 reports that **31% of breaches start with vulnerability exploitation** and that **48% involve a third party**; Google Cloud Threat Horizons H1 2026 measures third-party software vulnerabilities rising from 2.9% to **44.5% of initial access** between H1 and H2 of 2025. OWASP promoted this to its own category in 2025: `A03:2025 Software Supply Chain Failures`.

## §1 Manifests and lock files

### SUP-01 Lock missing, out of sync, or unused by the pipeline
**Where to look**
- Presence and freshness of `package-lock.json`/`pnpm-lock.yaml`/`yarn.lock`, `poetry.lock`/`uv.lock`, `Cargo.lock`, `go.sum`, `Gemfile.lock`, `composer.lock` against their manifest.
- CI commands: `npm install` instead of `npm ci`, `pip install -r requirements.txt` with no hashes, `bundle install` without `--deployment`, or a `.gitignore` that excludes the lock.

**Vulnerable pattern**
```yaml
- run: npm install          # re-resolves; the lock stops being the source of truth
- run: pip install -r requirements.txt   # no --require-hashes: any artifact will do
```
**What rules it out (false positive)**
- It is a publishable library, not an application: there the lock is not committed by design and resolution happens on the consumer side; the finding moves to the test matrix.
- There is a proxy or internal registry freezing versions and serving the exact artifact; ask for evidence that the pipeline points there.

Rules: FP-08, FP-09.

**Minimal test**: check that every direct dependency in the manifest appears in the lock with an exact version and, where the ecosystem supports it, an integrity hash; then find the real install command in CI.\
**Traceability**: `CWE-1357` · `CWE-494` · `CWE-345` · `A03:2025` · `A08:2025` · `CICD-SEC-3` · `SLSA Build L1` · `SSDF PW` · `NIST 800-53 SR`\
**Tooling**: `osv-scanner scan source -r --offline-vulnerabilities --format json .` reads the lock directly; with no lock, the scanner analyzes ranges and its output no longer describes what gets deployed. Say so explicitly in the report instead of reporting versions that may never have been installed.

### SUP-02 Floating ranges and outdated or unmaintained dependencies
**Where to look**
- Manifests with `^`, `~`, `*`, `latest`, `>=` with no ceiling; in Go, a `replace` pointing at a branch; in containers, dependencies installed with no version.
- Dependencies whose last release is old, whose repository is archived, or which depend on a single maintainer.

**Vulnerable pattern**
```json
"dependencies": { "utility-x": "*", "http-client": "^2.1.0" }
```
**What rules it out (false positive)**
- The floating range is bounded by a committed lock and by `npm ci` in the pipeline: resolution is deterministic and the finding drops to informational about the manifest.
- The dependency has had no release in years because it is functionally complete and small; assess issue activity and CVE response, not just the date.

Rules: FP-01, FP-10.

**Minimal test**: for every direct dependency, compare the version resolved in the lock against the latest published one and record the distance; flag the ones no longer maintained. **Boundary:** this measures distance to the latest release, not support status — a dependency can be perfectly up to date inside a branch nobody patches any more. That question is `SUP-24`.\
**Traceability**: `CWE-1104` · `CWE-1395` · `A03:2025` · `A06:2025` · `SSDF PW` · `NIST 800-53 SR` · `CCM TVM` · `CIS v8.1 Control 7`\
**Tooling**: `cargo audit --file Cargo.lock --no-fetch --json` helps here, but it **mixes `unmaintained`, `unsound` and `yanked` advisories with real vulnerabilities**: separate them in the report, they are not exploitable on their own. Context (Datadog State of DevSecOps 2026): the median dependency is **278 days out of date** and **42% of services use unmaintained libraries**; Endor Labs also measures a **32% chance that updating to the latest version introduces other known vulnerabilities**, so "update everything" is not a valid recommendation without measurement.

## §2 Code execution at install and build time

### SUP-03 Package manager lifecycle scripts
**Where to look**
- `package.json` → `scripts.preinstall`, `install`, `postinstall`, `prepare`; also inside the **dependencies**, not just your project (`node_modules/*/package.json`).
- Python: `setup.py` with logic in the module body or in `cmdclass`; Ruby: `extconf.rb`; Rust: `build.rs`.

**Vulnerable pattern**
```json
"scripts": { "preinstall": "node ./setup_helper.js" }
```
**What rules it out (false positive)**
- The script compiles a native binding or downloads a binary from the project's official domain with hash verification. Legitimate, but record it as surface: it still executes code before any test runs.
- The project installs with `npm ci --ignore-scripts` in every environment and CI enforces it.

Rules: FP-01, FP-05.

**Minimal test**: enumerate lifecycle scripts across the whole resolved tree and **read** the ones you do not recognize, without running them. If the file is obfuscated or minified, treat it under SUP-19.\
**Traceability**: `CWE-94` · `CWE-506` · `CWE-829` · `A03:2025` · `A08:2025` · `CICD-SEC-3` · `SSDF PW` · `NIST 800-53 SR`\
**Tooling**: guided manual inspection; no SCA covers this. Prioritization argument: Ohm et al., *Backstabber's Knife Collection* (DIMVA 2020), across 174 real malicious packages, measured that **56% trigger the malicious behavior at install time** and that data exfiltration is the goal in **55%**. **Shai-Hulud 2.0** (21-23 November 2025) executed at `preinstall` (`setup_bun.js` → obfuscated `bun_environment.js`), and **ua-parser-js** (October 2021) delivered a miner from a `postinstall` hook.

### SUP-04 Arbitrary code on the build path
**Where to look**
- `Makefile`, `configure.ac`, `*.m4`, `Makefile.am`, `CMakeLists.txt`, `build.gradle` with a remote `apply from:`, `pom.xml` with plugins that run scripts, `build.rs`, `conanfile.py`.
- Any download at build time: `curl ... | sh`, `wget` with no signature or hash verification.

**Vulnerable pattern**
```makefile
prepare:
	curl -sL https://cdn.example.net/toolchain.sh | sh   # no hash, no signature, no pin
```
**What rules it out (false positive)**
- The download points at an artifact pinned by digest and is verified with `sha256sum -c` or a signature before it executes.
- The step only runs in a documented local development environment and is not part of the reproducible build that produces the published artifact.

Rules: FP-01, FP-04.

**Minimal test**: `rg -n 'curl .*\|\s*(sh|bash)|wget .*\|\s*sh|apply from:.*http'` across the whole build path, and compare the release tarball against the git tree at the same tag (see SUP-20).\
**Traceability**: `CWE-494` · `CWE-829` · `CWE-427` · `A03:2025` · `A08:2025` · `CICD-SEC-4` · `SLSA Build L2` · `SSDF PW`\
**Tooling**: manual inspection. This is exactly the vector of **xz utils, CVE-2024-3094** (March 2024): the backdoor was not in git, it lived in a `build-to-host.m4` present only in the release tarball, plus a precompiled object hidden among binary test files.

## §3 Dependency confusion and registry resolution

### SUP-05 Internal package names anyone can publish
**Where to look**
- `package.json` with internal dependencies **without a scope** (`payments-utils` instead of `@company/payments-utils`); `requirements.txt` with generic internal names; `pom.xml` with a `groupId` you do not control.
- `.npmrc` with no `@scope:registry=https://internal.registry/`; no defensive reservation of the name in the public registry.

**Vulnerable pattern**
```json
"dependencies": { "core-auth-lib": "1.4.2" }   // internal name, unscoped, free publicly
```
**What rules it out (false positive)**
- The name is already reserved by the organization in the public registry (a read-only check against the registry, publishing nothing).
- The package is consumed by file path, workspace or submodule, not by name resolution from a registry.

Rules: FP-01, FP-09.

**Minimal test**: list the dependencies that do **not** exist in the public registry and also have no scope of their own; that set is the exact confusion surface.\
**Traceability**: `CWE-427` · `CWE-829` · `CWE-1357` · `A03:2025` · `A08:2025` · `CICD-SEC-3` · `SSDF PW` · `NIST 800-53 SR` · `ATT&CK T1195`\
**Tooling**: an existence check against the registry (read-only). Founding case: **Alex Birsan, 9 February 2021**, compromised **35 companies** by publishing packages in public registries under the names of internal packages, exploiting the fact that the build prefers the higher version.

### SUP-06 Multi-registry resolution where the higher version wins
**Where to look**
- `pip.conf`/`pip.ini`/`PIP_EXTRA_INDEX_URL` with `extra-index-url` pointing at the internal registry: pip queries **both** indexes and picks the higher version regardless of origin. The correct setup is `index-url` at the internal proxy, which already replaces the public one.
- `.npmrc` with a public `registry=` and no per-scope mapping; Maven `settings.xml` with an incomplete `mirrorOf`; `NuGet.config` with no `packageSourceMapping`.

**Vulnerable pattern**
```ini
[global]
index-url = https://pypi.org/simple
extra-index-url = https://pypi.internal/simple   # the public one can win with 99.0.0
```
**What rules it out (false positive)**
- The internal registry is a **proxy** that also serves public packages and is the only configured index: then there is no version competition.
- There is explicit mapping by scope or by name prefix toward the internal registry.

Rules: FP-01.

**Minimal test**: reconstruct the pipeline's effective index list (environment variables included) and check whether any internal name is resolvable from the public one.\
**Traceability**: `CWE-427` · `CWE-829` · `A03:2025` · `A08:2025` · `CICD-SEC-3` · `CICD-SEC-8` · `SSDF PW` · `CCM STA`\
**Tooling**: configuration review; no scanner detects this reliably, because the configuration usually lives in runner environment variables rather than in the repo. Ask for them as evidence, and write it down if you do not get them.

## §4 Typosquatting and slopsquatting

### SUP-07 Packages named almost identically to a legitimate one
**Where to look**
- Recently added dependencies whose name differs from a popular one by a character, a hyphen, a plural, a prefix (`python-`, `node-`) or a homoglyph.
- New transitive dependencies appearing in the lock diff, which is where nobody looks.

**Vulnerable pattern**
```diff
+ "requets": "2.31.0"      // versus "requests"; plus 3 new transitives in the lock
```
**What rules it out (false positive)**
- The package is a recognized official fork or port, with a long history, a maintainer matching the original project, and consistent download volume.
- The similar name predates the popular one; check the dates before accusing anyone.

Rules: FP-09.

**Minimal test**: for every suspicious dependency, query the registry for **four signals**: existence, age of the first publication (under 90 days is a strong signal), download volume, and whether the maintainer matches the declared repository. No single one of the four is enough on its own.\
**Traceability**: `CWE-1357` · `CWE-829` · `CWE-506` · `A03:2025` · `A08:2025` · `SSDF PW` · `NIST 800-53 SR` · `ATT&CK T1195`\
**Tooling**: lock-diff review plus a read-only registry query. Scale of the problem (Sonatype 2026 State of the Software Supply Chain): **454,600 new malicious packages in 2025**, 1.233 million cumulative, OSS malware **+75%**, and **more than 99% of OSS malware occurs in npm**. ReversingLabs 2026 measures +73% year over year, with PyPI down 43% and NuGet down 60%: the shift toward npm is real and should weigh in your per-ecosystem prioritization.

### SUP-08 Slopsquatting: dependencies and versions hallucinated by an LLM
**Where to look**
- Imports of packages absent from every manifest; dependencies added in AI-assisted commits; specific versions cited in documentation or comments that do not exist in the registry.
- Install instructions in a `README` or in an agent context file naming packages without verification.

**Vulnerable pattern**
```python
import fastapi_security_utils          # the LLM proposed it; it does not exist... until someone publishes it
```
**What rules it out (false positive)**
- The package exists, is old, and is the one the project actually uses: the hallucination was the reviewer's, not the code's. **Existing is not enough on its own** — a name someone registered *after* the code that imports it also exists, and that case is `SUP-26`.
- The import resolves to an internal module of the repository by path.

Rules: FP-09.

**Minimal test**: extract every top-level import and subtract those resolving to local modules or declared dependencies; each leftover is verified **against the real registry** before you accept it or write it into any deliverable. The same rule binds you: every dependency or version you suggest gets checked before you write it down.\
**Traceability**: `CWE-1357` · `CWE-829` · `LLM07:2026` · `LLM04:2026` · `A03:2025` · `A06:2025` · `SSDF PW` · `NIST 800-53 SR`\
**Tooling**: your own import-extraction script plus an existence query. Evidence: Spracklen et al., **USENIX Security 2025** (arXiv:2406.10279), across 576,000 samples and 16 models, measured **5.2% hallucinated packages in commercial models and 21.7% in open ones**, with **205,474 unique** invented names; Sonatype reports GPT-5 hallucinated **27.8% of recommended versions**. A hallucinated, repeatable name is a name an attacker can register.

## §5 CI/CD and publishing integrity

### SUP-09 Mutable references to pipeline dependencies
**Where to look**
- `uses: owner/action@v4` or `@main` under `.github/workflows/`; `container:`/`services:` images by tag; GitLab templates with `ref: main`; Jenkins plugins with no version.
- Artifacts passed between jobs with no hash or attestation verification.

**Vulnerable pattern**
```yaml
- uses: tj-actions/changed-files@v45     # a git tag is a MUTABLE pointer
```
**What rules it out (false positive)**
- The reference points at a resource under the same `owner` and access-control perimeter. It is still pending hardening, not a third-party risk.
- There is a policy blocking merges without pinning and a bot updating the SHAs; the finding becomes one of coverage.

Rules: FP-01, FP-06, FP-10.

**Minimal test**: count references pinned by 40-character SHA against the total and report the percentage, not a 200-line list.\
**Traceability**: `CWE-829` · `CWE-494` · `CWE-345` · `A03:2025` · `A08:2025` · `CICD-SEC-3` · `CICD-SEC-9` · `SLSA Build L2` · `SSDF PW`\
**Tooling**: `zizmor --offline --format sarif .github/workflows/` (`--offline` is mandatory; with `--gh-token` or `GH_TOKEN` it switches to online mode). Proof that a tag is mutable: in **tj-actions/changed-files, CVE-2025-30066** (14-15 March 2025), a compromised PAT allowed **every tag from v1 through v45.0.7 to be repointed at the same malicious commit**, which dumped runner secrets into the log; more than 23,000 repositories affected, fixed in v46.0.1, with a sibling incident in reviewdog/action-setup (CVE-2025-30154). Datadog 2026: **only 4% of organizations pin all their public GitHub Actions by commit SHA**.

### SUP-10 Publishing with long-lived credentials and no flow control
**Where to look**
- `NPM_TOKEN`, `PYPI_API_TOKEN`, `CARGO_REGISTRY_TOKEN`, container registry credentials stored as permanent repository secrets; release workflows triggerable from unprotected branches or by any collaborator.
- Absence of `permissions: id-token: write` (OIDC Trusted Publishing), of `environment` approval, of branch protection over the release tag, and of mandatory review of the publishing workflow.

**Vulnerable pattern**
```yaml
on: workflow_dispatch          # anyone with write can launch it
  - run: npm publish
    env: { NODE_AUTH_TOKEN: "${{ secrets.NPM_TOKEN }}" }   # permanent token
```
**What rules it out (false positive)**
- The registry does not support OIDC and the token is minimally scoped, short-lived and rotated by an auditable process; ask to see the process, not the intent.
- Publishing requires two-person approval through an `environment` with reviewers.

Rules: FP-01, FP-08.

**Minimal test**: trace who can trigger the publishing workflow and with which credential it signs; if a single collaborator can publish without review, that is a flow-control finding.\
**Traceability**: `CWE-798` · `CWE-522` · `CWE-284` · `A03:2025` · `A07:2025` · `CICD-SEC-1` · `CICD-SEC-2` · `CICD-SEC-5` · `CICD-SEC-6` · `SLSA Build L2` · `SLSA Source L4` · `SSDF PO`\
**Tooling**: manual workflow review. Verified current state: **npm classic tokens were revoked on 9 December 2025** and granular write tokens were capped at 90 days; the correct approach today is **OIDC Trusted Publishing** with `id-token: write`, not a stored `NPM_TOKEN`. In SLSA v1.2, the Source track (L1 versioning, L2 history and provenance, L3 continuous technical controls, L4 two-party review) is the reference for source flow control, and the Build track for the artifact.

## §6 Provenance, SBOM and signing

### SUP-11 SBOM missing, stale, or generated from the wrong place
**Where to look**
- Presence of `sbom.json`/`*.cdx.json`/`*.spdx.json` among the release artifacts; the pipeline step that generates it; whether it is generated from the **source** or from the **final image** (they must match, and often do not).
- Whether the SBOM is published alongside the artifact or lost inside the runner.

**Vulnerable pattern**
```yaml
# The release publishes the binary and the container,
# but no step generates or attaches an SBOM of what is actually distributed.
```
**What rules it out (false positive)**
- The SBOM is generated and attached as a signed attestation of the final artifact; check that the referenced digest is the one published.
- The project distributes no artifacts (it is an internal application deployed as an image already inventoried downstream).

Rules: FP-01, FP-06.

**Minimal test**: run `syft dir:. -o cyclonedx-json=sbom.json` over the source and compare the component count against the official release SBOM; a large gap means the SBOM describes something else.\
**Traceability**: `CWE-1357` · `A03:2025` · `A08:2025` · `CICD-SEC-9` · `SLSA Build L1` · `SSDF PS` · `NIST 800-53 SR` · `CCM STA`\
**Tooling**: `syft dir:. -o cyclonedx-json=sbom.json` (offline over the local tree). Do not conclude full coverage: syft sees what the manifests declare, so vendored dependencies or static binaries show up incomplete or not at all.

### SUP-12 Artifacts with no signature and no provenance attestation
**Where to look**
- Releases with binaries and no `.sig`, no `.intoto.jsonl` and no signed checksums; container images with no cosign signature; install instructions that download over HTTPS and nothing more.
- No step emitting provenance (who built it, from which commit, with which builder).

**Vulnerable pattern**
```yaml
- run: gh release upload "$TAG" dist/*.tar.gz     # no signature and no attestation
```
**What rules it out (false positive)**
- The registry already stores provenance attestations from the hosted builder and the consumer verifies them; then the finding is documentation, not control.
- The artifact is consumed only internally, by immutable digest, from an access-controlled registry.

Rules: FP-01, FP-06.

**Minimal test**: for an existing release, check whether a signature and an attestation are published and whether the referenced commit and builder match the tag. Verifying a public signature is reading, not intrusion.\
**Traceability**: `CWE-347` · `CWE-345` · `CWE-494` · `A08:2025` · `CICD-SEC-9` · `SLSA Build L2` · `SLSA Build L3` · `SSDF PS` · `NIST 800-53 SR`\
**Tooling**: `cosign` for signing and verification (sigstore). Framing: in **SLSA v1.2** (approved 24 November 2025) the Build track runs from L0 (no guarantees) to L1 (provenance exists), L2 (hosted build platform with signed provenance) and L3 (hardened builds). Name the target level and the current one; "does not meet SLSA" is not a finding, "it sits at L1 and the client requirement is L3" is.

## §7 Honest triage of dependency vulnerabilities

### SUP-13 Reachability: a finding with no call evidence drops to informational
**Where to look**
- The SCA output: for each CVE, whether the vulnerable symbol is imported and called from application code, and whether it is a direct or a transitive dependency.
- Whether the package is used only in tests or development tooling (`devDependencies`, test extras).

**Vulnerable pattern**
```text
CRITICAL  package-x 1.2.0  CVE-XXXX-NNNN  insecure deserialization
→ but the project only imports package-x/format, which never invokes the deserializer
```
**What rules it out (false positive)**
- There is no import of the affected module on any executable path, or the vulnerable function requires a configuration the project does not use. Document the reasoning with the file and line, not with an assertion.
- The dependency is development-only and never ships in the deployed artifact.

Rules: FP-03, FP-04.

**Minimal test**: locate the import and the call to the affected symbol; without both, the severity is explicitly downgraded in the report.\
**Traceability**: `CWE-1395` · `CWE-1104` · `A03:2025` · `A06:2025` · `SSDF RV` · `NIST 800-53 RA` · `CCM TVM` · `CIS v8.1 Control 7`\
**Tooling**: **`govulncheck -mode source -format sarif ./...` is the only tool in this pack with a real call graph and, by far, the lowest false-positive rate**; if the target is Go, start there and use the rest as a complement. Evidence for the bias you are correcting: Endor Labs measures that **fewer than 9.5% of vulnerabilities have a real call path from the application to the vulnerable function** and that **95% live in transitive dependencies**; Datadog 2026 measures that **only 18% of "critical" vulnerabilities stay critical once runtime context is applied**. Reporting the scanner's raw list is a methodological error, not extra diligence.

### SUP-14 Prioritizing by real exploitation: KEV and EPSS before CVSS
**Where to look**
- For each CVE that survived SUP-13: whether it is in the CISA KEV catalog, its EPSS score, and only then its CVSS.
- Whether a fixed version exists and how far the update is.

**Vulnerable pattern**
```text
Client policy: "patch everything with CVSS >= 7".
Measured result: covers 82.1% of what gets exploited at 6.5% efficiency.
```
**What rules it out (false positive)**
- A low EPSS and absence from KEV do **not** rule out a CVE with a confirmed call path in an exposed service: EPSS estimates the probability of exploitation observed over 30 days, not impact in your context. Use it to order, never as the sole closing criterion.

Rules: FP-10.

**Minimal test**: query EPSS with `GET https://api.first.org/data/v1/epss?cve=CVE-2021-44228` (it accepts batches via `?cve=a,b`; verified response for Log4Shell: `{"epss":"0.999990000","percentile":"1.000000000"}`) or download the daily CSV from `https://epss.empiricalsecurity.com/epss_scores-current.csv.gz`; the current model version is **EPSS v5**, identifier `v2026.06.15`, published by FIRST.org. For KEV, use `https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json`, whose per-entry fields are `cveID, vendorProject, product, vulnerabilityName, dateAdded, shortDescription, requiredAction, dueDate, knownRansomwareCampaignUse, notes, cwes`; **`knownRansomwareCampaignUse == "Known"` escalates automatically**.\
**Traceability**: `CWE-1395` · `A03:2025` · `A06:2025` · `SSDF RV` · `RV.1.1` · `NIST 800-53 RA` · `CCM TVM` · `CIS v8.1 Control 7`\
**Tooling**: the correct threshold has been measured. Jacobs et al. (2023), across 192,035 CVEs from July 2016 to December 2022, found that **only 6.4% were exploited**; the "CVSS v3 >= 7" strategy reaches 82.1% coverage at **6.5% efficiency**, whereas **EPSS at a 0.088 threshold reaches 82% coverage at 78.5% efficiency and one eighth of the effort**. Propose that threshold and back it with these numbers. Urgency context (DBIR 2026): a **43-day** median time to patch and **only 26% of the KEV catalog patched**.

### SUP-15 Data-source noise: unscored CVEs and scanners that invent matches
**Where to look**
- CVEs with no CVSS assigned by the NVD, advisories that exist only in the ecosystem feed (GHSA, RUSTSEC, PYSEC), and findings matched on artifact name rather than hash.
- Duplicates across scanners: the same defect reported three times under three identifiers.

**Vulnerable pattern**
```text
dependency-check: "commons-collections 3.2.1" -> CPE of another product with the same name
(shaded JAR: the name matches, the component does not)
```
**What rules it out (false positive)**
- The identifier has no advisory in the package's own ecosystem and no reference to the real repository: it is a name collision.
- A reviewed, justified suppression entry already exists; maintaining it is normal operation, not concealment, as long as it carries a date and a reason.

Rules: FP-08, FP-09.

**Minimal test**: cross-check each finding against the ecosystem's own database and discard those that appear only through CPE matching.\
**Traceability**: `CWE-1395` · `A03:2025` · `A09:2025` · `SSDF RV` · `NIST 800-53 RA` · `CCM TVM`\
**Tooling**: `osv-scanner scan source -r --offline-vulnerabilities --format json .`, `trivy fs --scanners vuln,secret,misconfig --offline-scan --skip-db-update --format sarif .`, `GRYPE_DB_AUTO_UPDATE=false grype dir:. -o json`, `npm audit --package-lock-only --omit=dev --json` (**never `npm audit fix`**; it needs network and ships the dependency tree to the registry), `pip-audit -r requirements.txt --no-deps -f json` (never `--fix`). **OWASP dependency-check has the worst false-positive profile** in this pack because of its heuristic CPE matching against the name: JARs with relocated classes ("shaded") match unrelated CPEs, and maintaining a suppression file is part of operating it normally. Data framing the noise: Sonatype 2026 measures that **nearly 65% of open source CVEs have no CVSS assigned by the NVD**, with a median of **41 days** to score them, and that **95% of vulnerable downloads already had a fix available**. On the accepted-risk side, Datadog 2026 measures that **87% of organizations have at least one exploitable vulnerability deployed**, and Orca that **more than 77% leave critical container vulnerabilities unpatched for over 90 days**.
