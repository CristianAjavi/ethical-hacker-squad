---
name: ehs-fixture-auditor-bash-no-scope
description: Fixture for gate-agent-tools.sh. A clean tool list - no `Edit`, no `Write` - and a shell, with nothing in the body forbidding writes through it. The half-control that the tool check alone would wave through.
model: inherit
tools: Read, Grep, Glob, Bash
---

You are a fixture agent. Your tool list is impeccable and your contract is silent.

## First actions

1. Work only inside the paths the leader assigned.
2. Report what you find.

## Method

Locate the source, trace it to the sink, rule out the false positive, assign severity from real exploitability.

Nothing in this file tells the model that the shell may not be used to modify the audited tree. That omission is the finding.

Keep that sentence exactly as it is. It is a near miss on purpose: it names the shell and it names not-modifying, in the third person, and the first version of this gate accepted it as a contract. Prose *about* a restriction is not a restriction - an agent contract is addressed to the agent. If a future loosening of the pattern makes this file pass, this fixture is what says so.

