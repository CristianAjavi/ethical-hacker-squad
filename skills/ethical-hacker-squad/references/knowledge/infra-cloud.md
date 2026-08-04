# Knowledge pack — infrastructure, containers and CI/CD

> **When to load this file:** when the target inventory contains infrastructure as code (Terraform, Bicep, CloudFormation), Dockerfiles or images, Kubernetes/Helm manifests, or CI/CD workflows. This is the *configuration* pack, not the application-code one.
> **Do not load it if:** the target is only application code, an APK with no backend of its own, or an analysis of dependencies and repository secrets (that lives in `supply-chain.md`).
> **Cost:** ~370 lines. Load by section using the index; you almost never need all six.

## Selective loading index
| Section | Load it if the inventory has | Procedures |
|---|---|---|
| §1 IaC (Terraform and equivalents) | `*.tf`, `*.tfvars`, `main.bicep`, CFN templates | INF-01 … INF-06 |
| §2 Containers and images | `Dockerfile*`, `Containerfile`, `docker-compose.y*ml` | INF-07 … INF-09 |
| §3 Kubernetes and Helm | `*.yaml` with `kind:`, `charts/`, `kustomization.yaml` | INF-10 … INF-12 |
| §4 CI/CD and GitHub Actions | `.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile` | INF-13 … INF-16 |
| §5 Environments, state and deployment secrets | multiple environments, state backend, secret manager | INF-17 |
| §6 Network exposure and remote surface | a real cloud account or a reachable cluster | INF-18 |

## How to use a procedure
First locate the files listed under **Where to look**: if the pattern is not in the repo, the procedure does not apply and nothing gets reported. Run the **Minimal test** — always local, always non-destructive — to move from "the scanner flagged it" to "I verified it". Check it against **What rules it out**: if one of those conditions holds, the finding drops to informational or disappears. **Traceability** feeds the report matrix, and **Tooling** tells you what to read in the output and what *not* to conclude from it. Any action against a cloud account or a remote cluster is marked `REQUIRES AUTHORIZATION` and is delivered as a proposed local patch, never applied. Prioritization: Verizon's DBIR 2026 reports that **31% of breaches start with vulnerability exploitation** — for the first time in 19 years ahead of credential abuse at 13% — and that **48% involve a third party**. Google Cloud Threat Horizons H1 2026 puts third-party software vulnerabilities at **44.5% of initial access** in H2-2025 (2.9% in H1-2025). Configuration is the multiplier: `A02:2025 Security Misconfiguration`.

## §1 Infrastructure as code

### INF-01 IAM policies with a wildcard in actions, resources or principal
**Where to look**
- Terraform `**/*.tf` → `aws_iam_policy`, `aws_iam_role_policy`, `aws_iam_policy_document`; GCP `google_project_iam_member` with `roles/owner` or `roles/editor`; Azure `azurerm_role_assignment` with `Owner`/`Contributor` at subscription scope.
- Trust: `assume_role_policy` with `Principal = "*"` or an external account with no `sts:ExternalId` and no `condition`.

**Vulnerable pattern**
```hcl
statement {
  effect = "Allow"
  actions = ["*"]          # or "iam:*", "s3:*"
  resources = ["*"]        # no condition narrowing account, tag or network
}
```
**What rules it out (false positive)**
- There is a `condition` on `aws:ResourceAccount`, `aws:PrincipalTag` or `sts:ExternalId`, or an SCP/Azure Policy in the same repo that trims the effective scope: a wildcard under an organizational guardrail is not the same finding.
- The wildcard sits in an ephemeral deployment role with a short session, and another statement narrows the real ARN.

**Minimal test**: `rg -n '"\*"' --glob '*.tf'` and, for each hit, check whether the block carries a `condition {}`; with no condition and `actions=["*"]` it is confirmed on documentation alone.\
**Traceability**: `CWE-284` · `CWE-732` · `CWE-269` · `A01:2025` · `CICD-SEC-2` · `SSDF PO` · `NIST 800-53 AC` · `CCM IAM` · `CIS v8.1 Control 6` · `ATT&CK T1078`\
**Tooling**: `checkov -d . --framework terraform --skip-download --compact -o json` → the `CKV_AWS_*` IAM family. This is the noisiest scanner in the pack: it resolves neither variables nor remote modules, so `actions = var.actions` gets flagged or waved through with no real criterion, and it flags policies already compensated at another layer. Do not conclude effective permission from its output.

### INF-02 Object storage readable or writable by anyone
**Where to look**
- `aws_s3_bucket_public_access_block` missing or with all four flags at `false`; `public-read` ACL; `google_storage_bucket_iam_member` with `allUsers`/`allAuthenticatedUsers`; `azurerm_storage_account` with `allow_nested_items_to_be_public = true`.
- Bucket policies with `Principal = "*"` and no account or VPC-endpoint condition.

**Vulnerable pattern**
```hcl
resource "google_storage_bucket_iam_member" "web" {
  bucket = google_storage_bucket.assets.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"          # anonymous read over the whole bucket
}
```
**What rules it out (false positive)**
- It is a public-assets bucket by design with no regulated data; verify **what the pipeline writes there** (if it also copies `.map` files, dumps or backups, it becomes a finding again).
- Public access is served by a CDN with an origin identity and the bucket itself stays blocked.

**Minimal test**: `rg -n 'allUsers|public-read|allow_nested_items_to_be_public|block_public_acls\s*=\s*false'` and cross-reference each bucket with the resources that write to it.\
**Traceability**: `CWE-668` · `CWE-552` · `CWE-200` · `A01:2025` · `A02:2025` · `NIST 800-53 AC` · `CCM DSP` · `CIS v8.1 Control 3`\
**Tooling**: `trivy config . --skip-check-update --format sarif -o o.sarif` (prefer it over tfsec, which is superseded and whose community was redirected to Trivy). Do not conclude real exposure: the bucket may not exist yet, or it may be overridden by an organization policy.

### INF-03 Missing encryption at rest or in transit
**Where to look**
- `aws_db_instance`/`aws_rds_cluster` without `storage_encrypted`; `aws_ebs_volume` without `encrypted`; queues and topics without `kms_master_key_id`; `azurerm_storage_account` with `enable_https_traffic_only = false` or `min_tls_version` below TLS 1.2.
- Listeners on port 80 with no redirect, and buckets that do not deny `aws:SecureTransport = false`.

**Vulnerable pattern**
```hcl
resource "aws_db_instance" "main" {
  engine            = "postgres"
  storage_encrypted = false     # or simply omitted
}
```
**What rules it out (false positive)**
- The provider encrypts that service by default and the organization does not require a customer-managed key: the real finding becomes "no customer-managed key", which is lower severity.
- The cleartext listener only redirects to 443 with `HTTP_301`.

**Minimal test**: `rg -n 'storage_encrypted|kms_key_id|min_tls_version|enable_https_traffic_only' --glob '*.tf'` and list the data resources that do **not** show up.\
**Traceability**: `CWE-311` · `CWE-319` · `A04:2025` · `A02:2025` · `NIST 800-53 SC` · `CCM CEK` · `CIS v8.1 Control 3` · `PCI DSS v4.0.1 req. 4`\
**Tooling**: `checkov -d . --framework terraform --skip-download --compact -o json`. Do not conclude regulatory non-compliance: checkov does not know what data lives in the resource, and data classification is the client's call.

### INF-04 Network rules open to `0.0.0.0/0`
**Where to look**
- `aws_security_group_rule` with `cidr_blocks = ["0.0.0.0/0"]` or `::/0`; `google_compute_firewall` with `source_ranges = ["0.0.0.0/0"]`; `azurerm_network_security_rule` with prefix `*` or `Internet`.
- Ports that turn this into a critical finding: 22, 3389, 5432, 3306, 6379, 27017, 9200, 2375/2376.

**Vulnerable pattern**
```hcl
ingress {
  from_port = 0
  to_port   = 65535            # the full range, not a service
  protocol  = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}
```
**What rules it out (false positive)**
- It is the public load balancer's group on 80/443: opening it to the world is the point; the finding moves to the group of the instances behind it, which must only accept the balancer's group.
- There is a NACL or managed firewall in front **declared in the same repo**; if it is not declared, do not assume it.

**Minimal test**: `rg -n -B4 '0\.0\.0\.0/0' --glob '*.tf'` and classify by port: 80/443 goes to review, management or database ports go straight to a finding.\
**Traceability**: `CWE-1327` · `CWE-284` · `CWE-923` · `A01:2025` · `A02:2025` · `NIST 800-53 SC` · `CCM IVS` · `CIS v8.1 Control 12`\
**Tooling**: `trivy config . --skip-check-update --format sarif -o o.sarif`. Do not conclude reachability: the subnet may be private with no route to the internet, and no IaC scanner resolves the route table.

### INF-05 Long-lived static credentials instead of OIDC federation / workload identity
**Where to look**
- IaC: `aws_iam_access_key`, `google_service_account_key`, `azuread_application_password` created as resources, and any `output` that exposes the secret.
- CI: `secrets.AWS_ACCESS_KEY_ID` in workflows, absence of `permissions: id-token: write`, of `aws_iam_openid_connect_provider` for `token.actions.githubusercontent.com`, of `google_iam_workload_identity_pool`, or of federated credentials in Entra ID.

**Vulnerable pattern**
```yaml
env:
  AWS_ACCESS_KEY_ID: ${{ secrets.AWS_KEY }}        # permanent key in the pipeline
  AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET }} # correct: OIDC + role-to-assume
```
**What rules it out (false positive)**
- The target is a legacy system with no OIDC support and there is an auditable automatic rotator on a short period: ask to see it, do not accept the intent.
- The remaining variables are non-sensitive configuration and real authentication already goes through `id-token`.

**Minimal test**: `rg -n 'aws_iam_access_key|google_service_account_key|azuread_application_password'` and then `rg -n 'openid_connect|workload_identity|id-token'`; the absence of the second confirms the pattern.\
**Traceability**: `CWE-798` · `CWE-522` · `A07:2025` · `CICD-SEC-6` · `SSDF PO` · `NIST 800-53 IA` · `CCM IAM` · `CIS v8.1 Control 5` · `ATT&CK T1552`\
**Tooling**: manual review; there is no reliable scanner for "this should be OIDC". Prioritization argument (Datadog State of Cloud Security 2025): **59% of AWS IAM users, 55% of GCP service accounts and 40% of Entra ID apps have an access key older than one year**. The missing control is almost always rotation, not detection.

### INF-06 Missing audit logging, retention and alerting in the infrastructure definition
**Where to look**
- Absence of a multi-region `aws_cloudtrail` with log file integrity validation, of `aws_flow_log` on the VPC, of `azurerm_monitor_diagnostic_setting` on critical resources, of `google_logging_project_sink`, or of `log_config` on the firewalls.
- Minimal retention on `aws_cloudwatch_log_group`, a log bucket with no retention and no object lock, and no rule alerting on IAM user creation, policy changes or audit shutdown (A09:2025 covers the *alerting* failure, not only the logging one).

**Vulnerable pattern**
```hcl
# A full network module: VPC, subnets, NAT, security groups...
# and not one aws_flow_log, no audit destination, no alerting rule.
```
**What rules it out (false positive)**
- Logging is centralized in a security account managed outside this repo or by an organization policy; ask for written evidence, "the landing zone turns it on" is not evidence.
- Alerts live in the observability platform rather than in the IaC: ask for the rule definition before ruling it out.

**Minimal test**: inventory the resources holding data or network paths and diff them against `rg -n 'cloudtrail|flow_log|diagnostic_setting|logging_project_sink'`; the gap is the finding.\
**Traceability**: `CWE-778` · `A09:2025` · `CICD-SEC-10` · `SSDF PO` · `NIST 800-53 AU` · `CCM LOG` · `CIS v8.1 Control 8`\
**Tooling**: this is audited by absence, not by a scanner rule. Prioritization (Orca State of Application Security 2025-2026): **80% of organizations lack adequate logging in their IaC**. Treat it as an expected finding and argue the impact on detection time, rather than as a compliance checkbox.

## §2 Containers and images

### INF-07 Container running as root and base image not pinned by digest
**Where to look**
- `Dockerfile*` → no unprivileged `USER` in the final stage; `FROM image:latest` or a moving tag (`:3`, `:stable`, `:alpine`) instead of `image@sha256:...`.
- `docker-compose.y*ml` → missing `user:` and `image:` without a digest.

**Vulnerable pattern**
```dockerfile
FROM node:latest             # moving tag: tomorrow's build is not today's
COPY . /app
CMD ["node", "server.js"]    # no USER, so PID 1 runs as uid 0
```
**What rules it out (false positive)**
- The base image already defines a non-root user and it is not overridden afterwards (distroless `nonroot` bases, for example): check the base before reporting.
- The orchestrator enforces `runAsNonRoot: true`; then the root issue drops to defense in depth, but the digest pinning one stands.

**Minimal test**: `rg -n '^FROM|^USER' Dockerfile*`; if the final stage has no `USER` or the `FROM` carries no `@sha256:`, it is confirmed without running anything.\
**Traceability**: `CWE-250` · `CWE-1357` · `CWE-494` · `A02:2025` · `A08:2025` · `CICD-SEC-9` · `SLSA Build L2` · `CCM IVS` · `CIS v8.1 Control 4`\
**Tooling**: `hadolint --no-fail -f sarif Dockerfile` — GPL-3.0, **invoke it as an external binary and never vendor it**. Separate `DL3xxx` rules from `SC2xxx` (those come from shellcheck) and drop the style noise with no security impact: `DL3008`, `DL3059` and `DL3006` are the ones that inflate the report most. A CIS benchmark exists for Docker: cite the numeric identifier and write the criterion in your own words.

### INF-08 Secrets injected through `ARG`/`ENV` or copied into an image layer
**Where to look**
- `Dockerfile*` → `ARG NPM_TOKEN`, `ENV AWS_SECRET_ACCESS_KEY=`, `COPY .env /app/`, `COPY . .` with no `.dockerignore`; in CI, `docker build --build-arg TOKEN=...`.
- `.dockerignore` missing in a repo that contains `.env`, `.git/`, `*.pem` or `id_rsa`.

**Vulnerable pattern**
```dockerfile
ARG NPM_TOKEN
RUN echo "//registry.npmjs.org/:_authToken=${NPM_TOKEN}" > .npmrc \
 && npm ci && rm .npmrc    # the rm does not delete the earlier layer: the token ships
```
**What rules it out (false positive)**
- BuildKit's `RUN --mount=type=secret,id=...` is used: the value never lands in a layer. Verify it in the `RUN`, not in the declared intent.
- The `ARG` only carries a non-sensitive value (version, public proxy, platform).

**Minimal test**: `rg -n 'ARG .*(TOKEN|SECRET|KEY|PASSWORD)|ENV .*(TOKEN|SECRET|KEY|PASSWORD)' Dockerfile*` and confirm whether a `.dockerignore` exists.\
**Traceability**: `CWE-798` · `CWE-540` · `CWE-522` · `A02:2025` · `CICD-SEC-6` · `SSDF PS` · `NIST 800-53 IA` · `CCM CEK`\
**Tooling**: on a locally exported tar, `dockle --input image.tar -f json --exit-code 0` (the `--exit-code 0` keeps the scanner from breaking your own run). Do not conclude the image is clean if it flags nothing: dockle looks for known patterns, not entropy in arbitrary files.

### INF-09 Privileged runtime: `--privileged`, broad capabilities and a mounted Docker socket
**Where to look**
- `docker-compose.y*ml` → `privileged: true`, `cap_add: [SYS_ADMIN, NET_ADMIN, SYS_PTRACE]`, `pid: host`, `network_mode: host`, `security_opt: [seccomp:unconfined]`.
- Mounts of `/var/run/docker.sock`, `/`, `/etc`, `/proc` or `/var/lib/kubelet`, typically in CI agents that "build inside the container".

**Vulnerable pattern**
```yaml
services:
  ci-agent:
    privileged: true
    volumes: ["/var/run/docker.sock:/var/run/docker.sock"]   # equivalent to root on the host
```
**What rules it out (false positive)**
- It is a documented system container (CNI, storage driver, node agent) whose function requires those capabilities: report it as an accepted risk with an owner, not as a defect.
- The build uses an unprivileged builder (rootless BuildKit, kaniko, buildah) and the socket is no longer mounted.

**Minimal test**: `rg -n 'privileged|docker\.sock|cap_add|network_mode:\s*host|pid:\s*host'`; this is a documentary finding, and **demonstrating it with a working escape is prohibited**.\
**Traceability**: `CWE-250` · `CWE-269` · `CWE-668` · `A01:2025` · `A02:2025` · `CICD-SEC-4` · `NIST 800-53 AC` · `CCM IVS` · `ATT&CK T1610` · `ATT&CK T1611`\
**Tooling**: `trivy config .` and `checkov -d . --framework dockerfile --skip-download --compact -o json`. The valid evidence is the declared configuration, not a proof-of-concept escape.

## §3 Kubernetes

### INF-10 Missing `securityContext` and use of host namespaces
**Where to look**
- `kind: Deployment|StatefulSet|DaemonSet|Job|Pod` → `spec.template.spec.securityContext` and `containers[].securityContext`: `runAsNonRoot`, `runAsUser`, `allowPrivilegeEscalation`, `privileged`, `readOnlyRootFilesystem`, `capabilities.drop`, `seccompProfile`.
- In the same `spec`: `hostNetwork`, `hostPID`, `hostIPC`, `hostPort`, and `volumes[].hostPath` pointing at `/`, `/etc`, `/proc`, `/var/run/docker.sock` or `/var/lib/kubelet`.

**Vulnerable pattern**
```yaml
spec:
  hostPID: true
  containers:
    - { name: api, image: registry.local/api:latest }   # no securityContext at all
  volumes: [{ name: root, hostPath: { path: /, type: Directory } }]
```
**What rules it out (false positive)**
- The namespace applies Pod Security Admission in `enforce` mode at the `restricted` level, or a Kyverno/Gatekeeper policy mutates and imposes the fields; look for `pod-security.kubernetes.io/enforce` on the `Namespace` in the repo itself.
- It is an infrastructure DaemonSet (CNI, log agent) where host access is functional: demand a read-only mount and the minimal path — a log agent needs `/var/log`, not `/`.

**Minimal test**: `rg -n 'hostNetwork|hostPID|hostIPC|hostPath|hostPort' -A2` and compare the number of `securityContext` blocks against the total number of `containers:`.\
**Traceability**: `CWE-250` · `CWE-269` · `CWE-668` · `CWE-1188` · `A02:2025` · `NIST 800-53 CM` · `CCM IVS` · `CIS v8.1 Control 4` · `ATT&CK T1611`\
**Tooling**: `kubescape scan manifests/ --use-artifacts-from ~/.kubescape --format json` (**never `--submit`**, that would ship results to an external backend) and `trivy config . --skip-check-update --format sarif -o o.sarif`. Trivy's own false positive: it **scans Helm charts without rendering them** and reports literals such as `{{ .Values.securityContext.runAsUser }}` as an insecure value; render with the real `values` before accepting the finding. A CIS benchmark exists for Kubernetes: use the numeric identifier and describe the criterion in your own words.

### INF-11 RBAC with `cluster-admin` or wildcard verbs and resources
**Where to look**
- `kind: ClusterRole|Role` → `verbs: ["*"]`, `resources: ["*"]`, `apiGroups: ["*"]`; `ClusterRoleBinding` with `roleRef.name: cluster-admin` or broad subjects (`system:authenticated`, `system:serviceaccounts`).
- Dangerous verbs without a wildcard: `secrets: [get, list]`, `pods/exec`, `pods/portforward`, `escalate`, `bind`, `impersonate`, `create` on `serviceaccounts/token`.

**Vulnerable pattern**
```yaml
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "list"]    # reading every Secret means reading every credential
```
**What rules it out (false positive)**
- It is a namespaced `Role` and that namespace only holds the application itself and its secrets: the permission does not cross a trust boundary. An equivalent `ClusterRole` is never ruled out this way.
- The binding targets a controller whose whole job is managing that resource.

**Minimal test**: `rg -n -B6 'name: cluster-admin'` and list the `subjects`; every application ServiceAccount that shows up is a finding.\
**Traceability**: `CWE-284` · `CWE-862` · `CWE-863` · `CWE-269` · `A01:2025` · `NIST 800-53 AC` · `CCM IAM` · `CIS v8.1 Control 6` · `ATT&CK T1078`\
**Tooling**: `conftest test --policy ./policy manifests.yaml -o json` with your own Rego, or `opa eval` to debug the rule. Here the false positive is **yours**: a `deny` that does not filter on `input.kind` will flag a `ConfigMap` as if it were a `ClusterRole`. Always test the policy against a manifest that must pass before you trust the result.

### INF-12 Cleartext secrets in manifests and auto-mounted ServiceAccount token
**Where to look**
- `kind: Secret` with `stringData:`/`data:` committed to git; `env:` with a `value:` holding credentials instead of `valueFrom.secretKeyRef`; `values.yaml` with default passwords; `ConfigMap` with full connection strings.
- `automountServiceAccountToken` not set to `false` on pods that never call the Kubernetes API.

**Vulnerable pattern**
```yaml
kind: Secret
stringData:
  DATABASE_URL: "postgres://app:S3cr3t.@db.prod:5432/app"   # committed to the repo
```
**What rules it out (false positive)**
- The value is a template placeholder (`{{ .Values.db.password }}`, `${DB_PASSWORD}`, `CHANGEME`) or arrives encrypted through SOPS / Sealed Secrets / External Secrets with the key outside the repo.
- It is an ephemeral test environment with no real data; confirm it with the owner, do not assume it.

**Minimal test**: base64-decode the `data:` entries and assess the structure (user, host, high-entropy password). **Never test it against the service.** Cross-reference with SUP-16/SUP-17 in `supply-chain.md` to cover the git history.\
**Traceability**: `CWE-798` · `CWE-312` · `CWE-522` · `A02:2025` · `A04:2025` · `CICD-SEC-6` · `SSDF PS` · `NIST 800-53 IA` · `CCM CEK` · `ATT&CK T1552`\
**Tooling**: `trivy fs --scanners secret,misconfig --offline-scan --skip-db-update --format sarif .`. Do not conclude a Kubernetes `Secret` is protected simply by being one: it is base64 in etcd, and its real protection depends on etcd encryption, which is audited separately.

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

**Minimal test**: `rg -n 'backend "' --glob '*.tf'` and `git log --all --name-only --pretty=format: | rg 'tfstate'`. If state was ever in git, the credential is considered compromised and the deliverable is a rotation plan, not "remove it from the repo".\
**Traceability**: `CWE-312` · `CWE-200` · `CWE-668` · `A02:2025` · `A04:2025` · `CICD-SEC-1` · `CICD-SEC-7` · `NIST 800-53 CM` · `CCM DSP`\
**Tooling**: manual review plus `gitleaks dir . --report-format sarif --report-path out.sarif --redact --no-banner` (MIT, fully offline) for leaked state. Context: GitGuardian State of Secrets Sprawl 2026 measured **28.65 million new hardcoded secrets in public GitHub during 2025 (+34%)** and that **64% of the valid secrets from 2022 were still live**.

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

**Minimal test**: the part you can audit without permission is **documentary**: count namespaces carrying workloads with no `NetworkPolicy`, and list `Service` objects of type `LoadBalancer`/`NodePort` on ports other than 80/443. Any check against live infrastructure — resolving the balancer name, connecting to a port, enumerating buckets with client credentials, running `kube-bench` on a node — **REQUIRES AUTHORIZATION in writing, with scope, window and contact**, following the planning and coordination framing of `NIST SP 800-115`. Without that permission the deliverable is a proposed local patch (the default-deny `NetworkPolicy`, the switch to `ClusterIP`), never applied; and scanning third-party infrastructure, testing discovered credentials against real services, or using evasion techniques remains prohibited.\
**Traceability**: `CWE-1327` · `CWE-284` · `CWE-306` · `CWE-923` · `A01:2025` · `A02:2025` · `NIST 800-53 SC` · `NIST SP 800-115` · `CCM IVS` · `CIS v8.1 Control 12` · `CIS v8.1 Control 13`\
**Tooling**: locally, `kubescape scan manifests/ --use-artifacts-from ~/.kubescape --format json` (no `--submit`) and `conftest test --policy ./policy` with a rule of your own requiring a `NetworkPolicy` per namespace. Deliberate repetition: **`kube-bench` does not analyze a repository, it audits a running node**, and on managed clusters (EKS, GKE, AKS) it returns FAIL on control-plane checks the provider administers; presenting those FAILs as client findings invalidates the report.
