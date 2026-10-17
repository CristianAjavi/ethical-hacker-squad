---
name: ehs-fixture-description-colon
description: Fixture for gate-agent-tools.sh. A description that reads well and is not YAML: it reviews local daemons: path traversal and archive extraction. The unquoted colon-space is what agents/ehs-local-app.md shipped with from 2026-08-20 to 2026-10-15.
model: inherit
tools: Read, Grep, Glob, Bash
---

You are a fixture agent whose tool list is correct and whose frontmatter is not YAML.

You have no `Edit` or `Write` tool, and you must not write through `Bash` either.

Every line of this file passes a reader that splits on the first colon. A YAML parser stops at the second colon of the description and returns nothing, the `tools` restriction included.
