---
name: ehs-fixture-wildcard-tools
description: Fixture for gate-agent-tools.sh. A wildcard tool list. It names no write tool and grants every one of them, which is exactly why a gate matching the three forbidden names and nothing else would pass this file.
model: inherit
tools: *
---

You are a fixture agent with an unbounded tool list.

## Safety contract

- **You have no `Edit` or `Write` tool, and you must not write through `Bash` either.**

The sentence is false and the frontmatter is what decides. An enumeration that says "everything" has to be read as containing the forbidden entries.
