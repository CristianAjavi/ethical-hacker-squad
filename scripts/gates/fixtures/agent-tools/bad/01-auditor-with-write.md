---
name: ehs-fixture-auditor-with-write
description: Fixture for gate-agent-tools.sh. An auditor that also lists `Write`. This is the G1 violation in the shape it would really arrive - a specialist that grew a write tool during a refactor while its prose still says it has none.
model: inherit
tools: Read, Grep, Glob, Bash, Write
---

You are a fixture agent. You exist so that the gate can be seen failing.

## Safety contract

- **You have no `Edit` or `Write` tool, and you must not write through `Bash` either.**

That sentence is the lie this fixture exists to catch: the body promises a restriction the frontmatter contradicts. The gate must believe the tool list, never the prose, because the harness grants tools from the list.
