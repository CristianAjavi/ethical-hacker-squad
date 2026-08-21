# Tooling layer

Load this before invoking any scanner. It answers three questions per tool: how to run it without touching anything, whether it needs the network, and what its output does **not** mean.

## Three rules that override any tool output

1. **A match is a candidate, not a finding.** Trace source, transformation and sink, look for compensating controls, then decide. The packs' `What rules it out` field exists for this.
2. **A clean run is not evidence of absence.** Measured on 27 real projects and 192 CVE-confirmed vulnerabilities, individual static analyzers missed between 47% and 80% of them; combining several left 30% to 69% still missed (Lipp et al., ISSTA 2022). On a Java benchmark, four well-known SAST tools detected 11%-27% each and 38.8% combined, with deserialization, input validation and XSS the least detected (Bennett et al., EASE 2024). Report a clean scan as a fact about the tool.
3. **Licence and network posture are part of the invocation.** Some tools may be executed but not redistributed; some phone home by default; some verify a discovered credential by using it against the real provider, which is an action against a third party.

## Network posture

- **Fully offline:** gitleaks, detect-secrets, syft, bandit, njsscan, hadolint, conftest/OPA, actionlint, `zizmor --offline`, apktool, jadx, aapt2, apksigner, semgrep with local rules.
- **Network once, then air-gapped:** osv-scanner, trivy, grype, cargo-audit, govulncheck, dependency-check, kubescape.
- **Network always:** `npm audit`, `pip-audit`, `gh`, TruffleHog when verifying, any SCA service API.

Anything in the last group leaves the machine. Say so in the report's methodology section.

## Secrets

| Tool | Licence | Non-destructive invocation | Typical false positive |
|---|---|---|---|
| gitleaks | MIT | `gitleaks dir . --report-format sarif --report-path out.sarif --redact --no-banner` | Roughly one in two hits is false. Fixture keys, documentation examples, `.env.example`, base64 assets, UUIDs. Measured precision around 46% with recall around 88% on the SecretBench corpus (Basak et al., ESEM 2023). |
| TruffleHog | **AGPL-3.0** | `trufflehog filesystem . --no-verification --json` | `--no-verification` is mandatory: by default it verifies a found credential by calling the real provider API, which is an action against a third party. Worst measured precision of the group. Invoke as a subprocess; never import it into MIT code. |
| detect-secrets | Apache-2.0 | `detect-secrets scan --all-files --no-verify . > .secrets.baseline` | Very high by design; its workflow is scan, audit, baseline. |

Detection order that actually works: **distinctive format first, entropy second.** Format-specific patterns reached above 99% precision where entropy alone did not (Meli et al., NDSS 2019). GitHub tokens (`ghp_`, `gho_`, `ghu_`, `ghs_`, `ghr_`) carry a CRC32 checksum in their last six characters that can be validated offline — a valid checksum is a critical finding without triage. That an AWS, Anthropic, Slack or Google key carries a published checksum is **not verified**: those are high-precision by prefix, not self-verifying.

Two facts worth acting on: 81% of secrets committed to public repositories are never removed (Meli et al.), and 64% of credentials found valid in 2022 were still valid in early 2026 (GitGuardian, 2026). "It was rotated later" is usually false. MCP configuration files are now a measured secret surface in their own right.

## Dependencies and SBOM

| Tool | Licence | Invocation | Note |
|---|---|---|---|
| govulncheck | BSD-3-Clause | `govulncheck -mode source -format sarif ./...` | The only one with a real call graph. Lowest false-positive rate. `-mode binary` does produce them. |
| osv-scanner | Apache-2.0 | `osv-scanner scan source -r --offline-vulnerabilities --format json .` | Version matching, no reachability. |
| trivy | Apache-2.0 | `trivy fs --scanners vuln,secret,misconfig --offline-scan --skip-db-update --format sarif -o o.sarif .` | Flags CVEs already fixed by distribution backports. |
| grype | Apache-2.0 | `GRYPE_DB_AUTO_UPDATE=false grype dir:. -o json` | Go binaries matched by module, not by used symbol. |
| syft | Apache-2.0 | `syft dir:. -o cyclonedx-json=sbom.json` | Produces no findings; its inventory errors propagate downstream. |
| npm audit | Artistic-2.0 | `npm audit --package-lock-only --omit=dev --json` | Never `audit fix`. Requires network; sends the tree to the registry. Inflates dev-only build tooling. |
| pip-audit | Apache-2.0 | `pip-audit -r requirements.txt --no-deps -f json` | Never `--fix`. Requires network. |
| cargo-audit | Apache-2.0 OR MIT | `cargo audit --file Cargo.lock --no-fetch --json` | Mixes `unmaintained`, `unsound` and `yanked` advisories, which are not exploitable vulnerabilities. |
| OWASP dependency-check | Apache-2.0 | `dependency-check.sh --scan . --format SARIF --noupdate --disableOssIndex` | Worst profile: heuristic CPE name matching, shaded JARs match unrelated CPEs. A suppression file is normal operation, not a workaround. |

**Triage before reporting.** Fewer than 9.5% of dependency vulnerabilities have a real call path from the application to the vulnerable function, and 95% sit in transitive dependencies (Endor Labs). Applying runtime context, only 18% of CVSS-critical findings stay critical (Datadog, 2026). Of 192,035 CVEs observed over six and a half years, 6.4% were ever exploited; prioritizing by CVSS ≥ 7 gives 82% coverage at 6.5% efficiency, while EPSS at threshold **0.088** gives 82% coverage at 78.5% efficiency for an eighth of the effort (Jacobs et al., 2023).

So the priority order is: reachable, then in the KEV catalog, then EPSS above threshold, then CVSS. Two free lookups:

- KEV: `https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json`; `knownRansomwareCampaignUse == "Known"` escalates automatically.
- EPSS v5 (`v2026.06.15`, FIRST.org): `https://api.first.org/data/v1/epss?cve=CVE-a,CVE-b` in one batched call.

Also note that roughly 65% of open-source CVEs carry no NVD CVSS score at all, with a 41-day median to score the rest. "No CVSS" is not "no risk".

## Static analysis

| Tool | Licence trap | Invocation |
|---|---|---|
| semgrep | Engine LGPL-2.1, **rules under a proprietary licence that forbids redistribution**. Run it; never vendor its ruleset. | `semgrep scan --config ./rules/ --metrics=off --disable-version-check --json -o out.json .` |
| CodeQL | Queries MIT, **CLI terms permit open-source codebases only**; analyzing a private or commercial repository without GitHub Advanced Security violates them. | `codeql database create db --language=X --source-root=.` then `codeql database analyze` |
| brakeman | **Not OSI**; commercial use requires a paid licence. | `brakeman --no-pager -f json -o out.json --no-exit-on-warn .` |
| bandit | Apache-2.0 | `bandit -r . -f json -o out.json -ll` |
| gosec | Apache-2.0 | `GOFLAGS=-mod=vendor GOPROXY=off gosec -fmt=sarif -out=o.sarif -no-fail ./...` |
| njsscan | LGPL-3.0 | `njsscan --json -o out.json .` |

`semgrep --config auto` contacts semgrep.dev and enables metrics, transmitting a hash of the project URL, rule hashes and finding counts — not source code. Disable it. Typical bandit noise: `B101` in test directories, `B404`/`B603` on subprocess calls with fixed arguments and no shell, `B105` on the literal string `password`, `B311` on non-cryptographic randomness.

## IaC, containers and CI

`checkov -d . --framework terraform kubernetes dockerfile --skip-download --compact -o json` is the noisiest of the group: it does not resolve variables or modules, so a variable with a safe default still reports, and it flags controls compensated at another layer. `trivy config . --skip-check-update` is the successor to tfsec, whose maintainers redirected their community to Trivy; it scans Helm without rendering, so template literals appear as insecure values. `hadolint --no-fail -f sarif Dockerfile` is GPL-3.0 — invoke it, never vendor it — and most of its noise is style with no security impact. `kube-bench` audits a node, not a repository, and fails control-plane checks that the provider manages on EKS, GKE and AKS. `conftest`/`opa` false positives are yours: a `deny` rule that does not filter on `input.kind` fires across the whole YAML stream.

For workflows, `actionlint -format '{{json .}}' .github/workflows/*.yml` and `zizmor --offline --format sarif .github/workflows/` are pure static checks. `--offline` matters: supplying `--gh-token` or `GH_TOKEN` switches zizmor to online mode. Its `unpinned-uses` finding is hardening rather than an exploitable issue in repositories that never expose a writable token — but note that only about 4% of organizations pin all public actions by commit SHA, and a tag is mutable: in March 2025 every tag of a widely used action from `v1` through `v45.0.7` was repointed at a malicious commit that dumped runner secrets into the workflow log.

## Mobile, static and local only

`apktool d app.apk -o out/ --no-src`, `jadx -d out/ --no-res --no-debug-info app.apk`, `aapt2 dump badging app.apk`, `apksigner verify --print-certs --verbose app.apk`, `apkleaks -f app.apk --json`, and MobSF in local static mode.

How each one lies: jadx emits decompiled code that can be corrupt, so grepping its output for secrets yields phantom findings; apkleaks is pure regex and marks any 32-40 character base64 or hex string as a key, including public Maps keys that are not secrets; MobSF flags every `exported` component without checking reachability or `android:permission`, and reports weak crypto from a dead library.

**frida and objection are excluded from the automated pipeline.** Their function is to disable a running application's security controls and inject code into its process. They modify state, are therefore not non-destructive, require a rooted device you own, and need written authorization. They are not part of this skill's tooling.

## Local application surfaces

There is no scanner for most of this pack, and that is the point: whether a temporary directory is world-writable, whether a plugin path is owned by another user, or whether a loopback listener answers a foreign `Origin` are facts about the running machine, not patterns in the source. The method is to read the code for the call site and then **check ownership and modes at runtime**.

| What you need | Non-destructive invocation | What it does not prove |
|---|---|---|
| Modes and owners of what the app creates | `stat -c '%A %U %n' <path>` (Linux), `stat -f '%Sp %Su %N' <path>` (macOS), `find <dir> -perm -o+w` | Nothing about *when* the file was created, or about the umask of a different user's session. |
| What is listening, and to whom | `lsof -nP -iTCP -sTCP:LISTEN` or `ss -ltnp` | A loopback bind is not safety: the question is whether the listener checks `Origin` and a token. Test that with one `curl` carrying a foreign `Origin`, against your own process only. |
| What a protocol handler receives | run the app with the argv it gets printed, invoked through `open`/`xdg-open` with your own crafted URL | That the handler is safe for *other* schemes or for the second instance path. |
| Library defaults | read the exported signatures (`rg -n "^def |^class |export function|pub fn"`) | A signature does not show which default the runtime actually applies after config merging; call it in a scratch script. |
| Search path and linkage of a shipped binary | `otool -l` (macOS), `readelf -d` (Linux) for `rpath` and `runpath` | Nothing about what the loader will do with an inherited `LD_PRELOAD` while privileged. |

Generic static analysis does reach part of this surface — Semgrep and CodeQL both ship rules for `tempfile.mktemp`, `extractall` and `shell=True` — with the recall caveat that applies to every tool here. Two invocation rules specific to this pack: every test writes **only** inside a temporary directory created for the run, and a symlink or race test is never pointed at a path the tool did not create. A demonstration that destroys the user's file is not evidence, it is damage.

## Privacy surfaces

There is no scanner for this. Personal-data mapping is done by reading schemas, models, migrations, DTOs, serializers, log statements and analytics event definitions, and the useful tools are the generic ones: `grep` over field names that denote personal data in the project's own vocabulary, the ORM's own schema dump, and the migration history to find fields added and never removed.

Two cautions. Field-name matching is a starting point, not an inventory — personal data hides in free-text columns, JSON blobs and third-party identifiers that no name pattern catches, so report the method's limits alongside its output. And never sample production data to find out what a field contains; infer from the schema and the code that writes it.

## Remote and dynamic — REQUIRES AUTHORIZATION

Everything here sends traffic to a host. None of it runs without explicit, scoped authorization from the owner of that host.

`zap-baseline.py -t https://target -J r.json -m 1` is passive (spider plus passive rules); `zap-full-scan.py` is active and is a different decision. It over-reports missing headers that a CDN or WAF supplies, and a one-minute spider does not cover a single-page application, so its silence means little. `nuclei -u https://target -t ./templates/ -ni -duc -jsonl` with `-ni` disables out-of-band callbacks to third-party infrastructure; exclude the `intrusive`, `dos` and `fuzz` tags; its version- and banner-based templates report CVEs without confirming exploitability. `nikto` is actively intrusive, trips WAF and IDS, and has the worst signal-to-noise ratio of the set: banner-derived "outdated server" findings are routinely wrong because distributions backport fixes. `testssl.sh --ids-friendly` and `sslyze` (AGPL — subprocess only) report facts rather than judgements; the letter grade is not a vulnerability.

Rule of thumb across all of them: discard by default any finding derived solely from a version banner.

## LLM and agent testing — REQUIRES AUTHORIZATION AND A BUDGET

garak (Apache-2.0), promptfoo (MIT), **microsoft/PyRIT** (MIT; the `Azure/PyRIT` repository was archived on 2026-03-25) and deepteam (Apache-2.0) are active attacks against a live endpoint, not static analysis. They require documented authorization from the endpoint owner — often a third-party API whose terms forbid adversarial testing — they consume paid tokens, they write harmful content to disk, and they can trip abuse detection and get an API key suspended. Never run them unattended; always cap the number of probes.

Two interpretation rules. A successful injection **in a test harness does not prove a vulnerability in production**, because production usually has a system prompt, a tool permission layer and an output filter that the harness bypasses by construction. And promptfoo and deepteam verdicts are produced by an LLM judge: a FAIL is an opinion with variance, not a reproduced exploit.

## Reference material we link but never copy

PayloadsAllTheThings (MIT), SecLists (MIT), nuclei-templates (MIT) and LOLDrivers (Apache-2.0) permit reuse with attribution. HackTricks restricts commercial use, GTFOBins and LOLBAS are GPL-3.0, the OWASP guides are CC BY-SA 4.0, and the semgrep ruleset is proprietary. For all of those: link and describe, never paste. `NOTICE.md` records the full determination.
