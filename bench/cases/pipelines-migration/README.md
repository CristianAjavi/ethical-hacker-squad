# pipelines-migration

Bench case. A billing service part-way through moving its builds off Jenkins:
the GitLab pipeline is the new one, the `Jenkinsfile` still publishes the npm
package, Azure Pipelines builds the Windows agent and CircleCI mirrors the
open-source SDK. The runner configuration and an export of the platform
settings are in the tree. Written to be read.
