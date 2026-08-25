# Knowledge pack — infrastructure, containers and CI/CD (pipelines, environments and exposure)

> **When to load this file:** the inventory contains CI/CD workflows (`.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`), several deployment environments, a Terraform state backend or a secret manager, or a live host or cluster named in scope.
> **Do not load it if:** the work is confined to infrastructure as code, container images or Kubernetes manifests — those are `infra-cloud.md` §1-§3.
> **Cost:** ~180 lines. Load by section using the index. The rest of the pack: `infra-cloud.md` holds §1-§3 and `INF-01`..`INF-12`; `infra-cloud-cicd-platforms.md` holds §7 and `INF-19`..`INF-23`, the same classes on GitLab CI, Jenkins, Azure Pipelines, CircleCI and Bitbucket.

## Selective loading index
| Section | Load it if the inventory has | Procedures |
|---|---|---|
| §4 CI/CD and GitHub Actions | `.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile` | INF-13 … INF-16 |
| §5 Environments, state and deployment secrets | multiple environments, state backend, secret manager, any configuration read with a fallback | INF-17, INF-24 |
| §6 Network exposure and remote surface | a real cloud account or a reachable cluster | INF-18 |

## How to use a procedure
First locate the files listed under **Where to look**: if the pattern is not in the repo, the procedure does not apply and nothing gets reported. Run the **Minimal test** — always local, always non-destructive — and then check it against **What rules it out**: if one of those conditions holds, the finding drops to informational or disappears. **Traceability** feeds the report matrix, and **Tooling** tells you what to read in the output and what *not* to conclude from it. Any action against a cloud account or a remote cluster is marked `REQUIRES AUTHORIZATION` and is delivered as a proposed local patch, never applied. The full statement of the contract and the prioritization note are in `infra-cloud.md`.

## §4 CI/CD and GitHub Actions

### INF-13 `pull_request_target` combined with a checkout of the PR code
**Where to look**
- `.github/workflows/*.yml` → `on: pull_request_target` (also `issue_comment`, `workflow_run`) alongside `actions/checkout` with `ref: ${{ github.event.pull_request.head.sha }}` or `head.ref`.
- Any later step that executes the downloaded code: `npm ci`, `make`, `./gradlew`, `pytest`, or a composite action from the checkout itself.

**Vulnerable pattern**
```yaml
on: pull_request_target                    # runs with secrets and a write token
  - uses: actions/checkout@v4
    with: { ref: "${{ github.event.pull_request.head.sha }}" }   # attacker's code
  - run: npm ci && npm test                # their scripts run with those secrets
```
**What rules it out (false positive)**
- The workflow uses `pull_request_target` but does **not** check out the PR code: it only reads metadata to label or comment. That is the legitimate use of the trigger.
- The job sits behind an `environment:` with required reviewers, so an external PR cannot run without human approval.

Rules: FP-01, FP-09.

**Minimal test**: for every workflow with `pull_request_target`, find `actions/checkout` and inspect the `ref`: with no explicit `ref` it checks out the base (safe); with `head.*` the finding is confirmed.\
**Traceability**: `CWE-94` · `CWE-829` · `A03:2025` · `A08:2025` · `CICD-SEC-4` · `SSDF PW` · `SLSA Build L2` · `NIST 800-53 SA`\
**Tooling**: `zizmor --offline --format sarif .github/workflows/` — **`--offline` is mandatory**: passing `--gh-token` or having `GH_TOKEN` in the environment switches it to online mode and queries the GitHub API, which is already traffic against a third party. Complement it with `actionlint -format '{{json .}}' .github/workflows/*.yml`.

### INF-14 Template expression injection inside a `run:` block
**Where to look**
- `${{ ... }}` interpolations inside `run:` or `script:` whose value is controlled by whoever opens the PR or issue: `github.event.pull_request.title`, `.body`, `.head.ref`, `github.event.comment.body`, `github.event.issue.title`, `github.head_ref`.

**Vulnerable pattern**
```yaml
- run: |
    echo "Reviewing: ${{ github.event.pull_request.title }}"
    # a title with quotes and a semicolon closes the echo and chains another command
```
**What rules it out (false positive)**
- The value goes through `env:` and the script references it quoted as a shell variable (`"$TITLE"`): the content is no longer interpolated into the script text.
- The field is not externally controlled (`github.sha`, `github.run_id`, `github.repository`).

Rules: FP-01, FP-02.

**Minimal test**: `rg -n 'run:' -A15 .github/workflows/ | rg '\$\{\{\s*github\.event'`; every hit that does not go through `env:` is a finding. Since 2026-06-18 `actions/checkout` fails on the most common unsafe patterns, but that covers the checkout, not your `run:` blocks.\
**Traceability**: `CWE-94` · `CWE-78` · `CWE-77` · `A05:2025` · `CICD-SEC-4` · `SSDF PW` · `NIST 800-53 SI`\
**Tooling**: `zizmor --offline --format sarif .github/workflows/` and `actionlint`. Do not conclude exploitability without looking at the trigger: the same interpolation in a workflow that only runs on `push` to a protected branch faces a very different attacker.

### INF-15 Missing or excessive `permissions:` and secrets reachable from a fork
**Where to look**
- No `permissions:` block at all (it inherits the repository default, which may be read+write) or `permissions: write-all`.
- `secrets: inherit` in a `workflow_call`; use of `${{ secrets.* }}` in jobs reachable from a fork; `pull_request` with `types: [labeled]` used as a trust gate without restricting who may label.

**Vulnerable pattern**
```yaml
permissions: write-all       # or the block simply does not exist
jobs:
  release:
    steps: [{ run: ./publish.sh, env: { TOKEN: "${{ secrets.REGISTRY_TOKEN }}" } }]
```
**What rules it out (false positive)**
- The organization pins the default `GITHUB_TOKEN` permission to read-only: then the missing block does not imply write. Check it, because it is configuration outside the repo and you cannot assume it in either direction.
- The job holding secrets only triggers on `push` to `main` or on `release`, unreachable from a fork.

Rules: FP-06, FP-08.

**Minimal test**: list the workflows without `permissions:` and cross-reference them with those referencing `secrets.`; least privilege applies per job, not per workflow.\
**Traceability**: `CWE-284` · `CWE-732` · `CWE-522` · `A01:2025` · `CICD-SEC-2` · `CICD-SEC-5` · `SSDF PO` · `NIST 800-53 AC` · `CCM IAM`\
**Tooling**: `zizmor --offline` flags excessive permissions; `actionlint` validates syntax but does **not** judge the permission, so a workflow that is clean to actionlint can still be `write-all`.

### INF-16 Third-party actions not pinned by SHA and exposed self-hosted runners
**Where to look**
- `uses: owner/action@v4`, `@main`, `@master`: only `@<40-character sha>` is immutable. This also applies to `container:`/`services:` with a moving tag and to `uses:` inside your own `action.yml`.
- `runs-on: [self-hosted, ...]` in public repositories or in workflows triggerable by outsiders; organization runners without a restricted group; cache or `~/.docker/config.json` shared across jobs.

**Vulnerable pattern**
```yaml
on: pull_request                       # anyone opens a PR
jobs:
  test:
    runs-on: [self-hosted, linux]      # persistent machine on the internal network
    steps: [{ uses: tj-actions/changed-files@v45 }]   # a tag is a MUTABLE pointer
```
**What rules it out (false positive)**
- The action belongs to the same `owner` and access-control perimeter: pinning it is still good practice, but it is not a third-party risk.
- The runner is ephemeral (one job per machine, destroyed afterwards) in a private repository, with no cloud credentials mounted.

Rules: FP-06, FP-10.

**Minimal test**: count SHA-pinned actions against the total under `.github/workflows/` and report the percentage; cross-reference `runs-on` with repository visibility and workflow triggers.\
**Traceability**: `CWE-829` · `CWE-494` · `CWE-345` · `A03:2025` · `A08:2025` · `CICD-SEC-3` · `CICD-SEC-9` · `CICD-SEC-7` · `SLSA Build L2` · `SLSA Build L3` · `SSDF PW`\
**Tooling**: `zizmor --offline --format sarif .github/workflows/` (`unpinned-uses` and `artipacked` rules). Do not take its severity at face value: it flags `unpinned-uses` even where it is hardening rather than an exploitable finding today. Argue with the real case instead: in **tj-actions/changed-files (CVE-2025-30066, 14-15 March 2025)** the bot's PAT was compromised and **every tag from v1 through v45.0.7 was repointed to a malicious commit** that dumped runner secrets into the log; more than 23,000 repositories were affected, fixed in v46.0.1, with a sibling incident in reviewdog/action-setup (CVE-2025-30154). Datadog State of DevSecOps 2026: **only 4% of organizations pin all their public GitHub Actions by commit SHA**. The **Shai-Hulud 2.0** worm (21-23 November 2025) used GitHub Actions and self-hosted runners as its persistence mechanism.

## §5 Environment separation, state and deployment secrets

### INF-17 Environments not separated and unprotected Terraform state
**Where to look**
- A single workspace, backend or account for dev/staging/prod; `terraform.tfvars` with production values committed; no `backend` block in a root directory (local state, accidentally committable).
- A backend without encryption, versioning or locking; `terraform.tfstate`/`*.tfstate.backup` in the working tree or in git history — state stores sensitive attributes in cleartext, including generated database passwords.

**Vulnerable pattern**
```hcl
terraform {
  # no backend block: state lives on disk and ends up in git
}
```
**What rules it out (false positive)**
- The directory is a reusable module, not a root: modules do not declare a backend and that is correct. Check whether there is a `provider`/`backend` or only `variables` and `outputs`.
- Remote state exists and the local `.tfstate` is an artifact of a trial run, already ignored by `.gitignore` and absent from history.

Rules: FP-04, FP-09.

**Minimal test**: `rg -n 'backend "' --glob '*.tf'` and `git log --all --name-only --pretty=format: | rg 'tfstate'`. If state was ever in git, the credential is considered compromised and the deliverable is a rotation plan, not "remove it from the repo".\
**Traceability**: `CWE-312` · `CWE-200` · `CWE-668` · `A02:2025` · `A04:2025` · `CICD-SEC-1` · `CICD-SEC-7` · `NIST 800-53 CM` · `CCM DSP`\
**Tooling**: manual review plus `gitleaks dir . --report-format sarif --report-path out.sarif --redact --no-banner` (MIT, fully offline) for leaked state. Context: GitGuardian State of Secrets Sprawl 2026 measured **28.65 million new hardcoded secrets in public GitHub during 2025 (+34%)** and that **64% of the valid secrets from 2022 were still live**.

### INF-24 A configuration name the code reads and nothing in the project defines

`WEB-23` finds a name that is **declared and nobody reads**. This is the mirror image: a name that is **read and nobody declares**. Both are joins across files, both survive every analyser, and this one ends somewhere worse — because the idiom that reads configuration safely is the same idiom that turns an absent value into silence.

**Where to look**
- Every read of a configuration name **with a fallback**: `os.environ.get("X", ...)`, `os.getenv("X", ...)`, `process.env.X || ...`, `System.getenv("X")` followed by a null branch, `viper.GetString`, `config.get("x", ...)`, `env("X", ...)` in a settings module.
- The definition side, all of it, or the subtraction is worthless: `.env`, `.env.example`, `docker-compose*.y*ml` `environment:`, `Dockerfile` `ENV`, Kubernetes `env:` and `envFrom:`, Helm `values.yaml`, Terraform variables and task definitions, the CI `env:` blocks, and the deployment documentation.
- The same shape one level out: a feature flag the code queries and no flag file defines; an internal route or job name a caller builds by string and no route table registers; a template or migration referenced by a name that resolves to nothing.
- **Highest yield where the default is itself the control**: a secret, a signing key, an issuer, an allowlist, a mode selector, a `*_ENABLED` flag guarding a check.

**Vulnerable pattern** — the program starts, nothing fails, and the fallback is the security decision:
```python
SECRET = os.environ.get("JWT_SECRET", "dev-secret")     # nothing in the repo sets JWT_SECRET
STRICT = os.environ.get("VERIFY_AUDIENCE", "false")     # ... and the check is off by default
```
This is the shape generated code produces most reliably, because the model writes against a deployment it cannot see: it invents a plausible variable name and, being careful, gives it a default.

**What rules it out (false positive)**
- The value is injected by something outside the repository — a secret manager, a platform variable, an operator-managed configuration. **The exported variable list or a written statement is required; without it the answer is `UNKNOWN`, never `HOLDS`.** This is the normal case for this class and it is precisely why the finding gets written down rather than dropped.
- The name is consumed by a mechanism a symbol search cannot see: a prefix-based loader, a struct with environment tags read wholesale, a chart that templates the whole block. Prove it by naming the consumer, as `WEB-23` requires.
- The default is not a security decision: a page size, a log level, a display string. Say which, and move on.
- **`FP-02` does not exculpate this class, and answering it wrongly is the standard mistake.** A placeholder such as `changeme` or `dev-secret` is indeed not attacker-controlled — and that is not why it is a finding. It is a finding because the value is *known*, identical in every deployment that forgot the variable, and readable in this repository.

Rules: FP-02, FP-04, FP-08, FP-09.

**Minimal test**: build the two lists and subtract them, in that order. Read every name with `rg -n --no-heading 'environ\.get\(|getenv\(|process\.env\.|env\(' .` over the source — **the trailing path is not optional**, since with none and a non-interactive stdin `rg` reads stdin and hangs — and every name defined with `rg -n -e '^\s*[A-Z0-9_]+\s*[:=]' .env* docker-compose*.y*ml` plus the chart and the manifests. For each leftover, print **the default that stays in force** and answer one question in writing: does that default decide a security property? A name whose absence turns a check off is the finding; a name whose absence changes a page size is a note. Then do the same subtraction for feature flags and for internal route names.\
**Traceability**: `CWE-1188` · `CWE-453` · `CWE-665` · `A05:2025` · `ASVS 5.0 V14` · `SSDF PW` · `NIST 800-53 CM`
**Tooling**: `rg` and the subtraction. No scanner reports it, for the same reason no scanner reports `WEB-23`: the code is well formed, the read is idiomatic and the default is syntactically ordinary — the defect is the **absence of a definition in a different file**, and absence is not a pattern. A secret scanner does not fire either: `dev-secret` has no distinctive format. Report the count and the ones whose default is load-bearing, not the whole list, and when the definitions live in the platform say so and ask for them rather than calling the surface clean.

## §6 Network exposure and remote surface

### INF-18 Verifying effective exposure against real infrastructure `REQUIRES AUTHORIZATION`
**Where to look**
- Resources with a public IP (`associate_public_ip_address`, `aws_eip`, `azurerm_public_ip`); `kind: Service` with `type: LoadBalancer`/`NodePort`; `Ingress` without TLS or with annotations that disable checks; published management panels (Kubernetes dashboard, Grafana, `kubelet` on 10250).
- Absence of `NetworkPolicy`: Kubernetes allows all pod-to-pod traffic by default, so a namespace carrying workloads with no policy at all is a flat network; also check that a default-deny exists for **egress**, not only ingress.

**Vulnerable pattern**
```yaml
kind: Service
spec:
  type: LoadBalancer                      # public IP
  ports: [{ port: 6379, targetPort: 6379 }]   # unauthenticated datastore, exposed
```
**What rules it out (false positive)**
- The load balancer is internal through a provider annotation and never gets a public IP.
- A service mesh with strict mTLS and an authorization policy fulfills the `NetworkPolicy` role: report the overlap, not the absence.

Rules: FP-01, FP-10.

**Minimal test**: the part you can audit without permission is **documentary**: count namespaces carrying workloads with no `NetworkPolicy`, and list `Service` objects of type `LoadBalancer`/`NodePort` on ports other than 80/443. Any check against live infrastructure — resolving the balancer name, connecting to a port, enumerating buckets with client credentials, running `kube-bench` on a node — **REQUIRES AUTHORIZATION in writing, with scope, window and contact**, following the planning and coordination framing of `NIST SP 800-115`. Without that permission the deliverable is a proposed local patch (the default-deny `NetworkPolicy`, the switch to `ClusterIP`), never applied; and scanning third-party infrastructure, testing discovered credentials against real services, or using evasion techniques remains prohibited.\
**Traceability**: `CWE-1327` · `CWE-284` · `CWE-306` · `CWE-923` · `A01:2025` · `A02:2025` · `NIST 800-53 SC` · `NIST SP 800-115` · `CCM IVS` · `CIS v8.1 Control 12` · `CIS v8.1 Control 13`\
**Tooling**: locally, `kubescape scan manifests/ --use-artifacts-from ~/.kubescape --format json` (no `--submit`) and `conftest test --policy ./policy` with a rule of your own requiring a `NetworkPolicy` per namespace. Deliberate repetition: **`kube-bench` does not analyze a repository, it audits a running node**, and on managed clusters (EKS, GKE, AKS) it returns FAIL on control-plane checks the provider administers; presenting those FAILs as client findings invalidates the report.
