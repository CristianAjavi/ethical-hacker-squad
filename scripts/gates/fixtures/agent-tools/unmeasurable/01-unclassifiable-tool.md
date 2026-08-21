---
name: ehs-fixture-unclassifiable-tool
description: Fixture for gate-agent-tools.sh. Lists a third-party MCP tool. Nothing in the name says whether it writes, and a gate that assumes the harmless reading of an unknown capability is a gate that will one day pass the thing it was written to stop.
model: inherit
tools: Read, Grep, Glob, Bash, mcp__acme__apply_change
---

You are a fixture agent holding a tool this repository has never seen.

## Safety contract

- **You have no `Edit` or `Write` tool, and you must not write through `Bash` either.**

The correct verdict here is "could not measure", not "conforms". Somebody has to look at what that tool does and record the answer.
