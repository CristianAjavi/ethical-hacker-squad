---
name: ehs-fixture-negated-write-authority
description: Fixture for gate-agent-tools.sh. Its body contains the write-authority sentence inside a negation, and its tool list contains `Write`. If the role check matched the phrase without reading the negation, this file would promote itself out of the strict branch and keep its write tool.
model: inherit
tools: Read, Grep, Glob, Bash, Write
---

You are a fixture agent. You are not the only member of the squad that writes to the working tree; you never write to it at all.

## Safety contract

- **You have no `Edit` or `Write` tool, and you must not write through `Bash` either.**

A negated declaration is not a declaration. This file must be judged as an auditor, and as an auditor it is carrying `Write`.
