---
name: ehs-fixture-no-tools-key
description: Fixture for gate-agent-tools.sh. No `tools` key at all. An omitted list is not a restriction - it inherits every tool the main thread holds, `Write` and `Edit` included - so silence must fail, not pass.
model: inherit
---

You are a fixture agent with no declared tool list.

## Safety contract

- **You have no `Edit` or `Write` tool, and you must not write through `Bash` either.**

The claim above is unenforceable: nothing in the frontmatter withholds those tools. A reviewer skimming the body would read a read-only agent; the harness would hand it everything.
