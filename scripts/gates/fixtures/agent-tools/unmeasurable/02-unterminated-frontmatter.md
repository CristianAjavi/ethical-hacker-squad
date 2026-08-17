---
name: ehs-fixture-unterminated-frontmatter
description: Fixture for gate-agent-tools.sh. The frontmatter is never closed, so there is no telling where the declaration ends and the contract begins. Not a pass and not a failure - an absence of measurement.
model: inherit
tools: Read, Grep, Glob, Bash

You are a fixture agent whose body was swallowed by its own frontmatter.

Everything under here may be YAML that failed to parse or prose that was never reached. Guessing which would mean guessing whether this agent can write.
