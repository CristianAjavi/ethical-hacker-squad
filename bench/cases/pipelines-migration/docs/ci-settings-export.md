# CI platform settings — export of 2026-08-14

Exported by the platform team for the quarterly review. Everything below comes
from the provider consoles, not from this repository.

## GitLab (project `billing/service`)

| Variable | Protected | Masked | Environment scope |
|---|---|---|---|
| `STAGING_API` | no | no | `*` |
| `STAGING_DEPLOY_TOKEN` | no | yes | `*` |
| `PRODUCTION_DEPLOY_TOKEN` | yes | yes | `production` |
| `NPM_PUBLISH_TOKEN` | yes | yes | `*` |

- Merge-request pipelines: enabled for all contributors, including forks.
- Job token permissions: allowlist enabled; the allowlist contains
  `billing/service` and `platform/ci-templates`.
- Protected branches: `main` and `release/*`. Protected tags: `v*`.
- `platform/ci-templates`: maintained by the platform team; the whole
  engineering group has push access to its default branch.

## Jenkins (controller `ci.internal.example`)

- Credential `npm-publish-token`: stored at the **folder** scope
  `billing/`, usable by the jobs in that folder.
- Agents: static VMs, label `build-linux`, workspace reused between builds.
- Builds on the built-in node: disabled (0 executors).

## Azure DevOps (project `Agent`)

- Variable group `windows-signing`: linked to the `Agent` pipeline only.
- *Make secrets available to builds of fork pull requests*: **off**.
- Agent pool: Microsoft-hosted (`windows-2022`).

## CircleCI (project `billing/sdk`)

- Context `sdk-npm-publish`: restricted to the `release-managers` security
  group; a job requesting it fails for anyone else.
- *Build forked pull requests*: on.
- *Pass secrets to builds from forked pull requests*: **off**.
