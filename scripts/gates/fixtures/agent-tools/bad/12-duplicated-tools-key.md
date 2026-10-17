---
name: ehs-fixture-duplicated-tools-key
description: Fixture for gate-agent-tools.sh. Two `tools` keys. Which one wins depends on the parser - the last for a line reader that overwrites, an error or the first for others - so the file declares two restrictions and none.
model: inherit
tools: Read, Grep, Glob, Write
tools: Read, Grep, Glob
---

You are a fixture agent with two answers to the question of which tools you hold.

You must not write through `Bash`.
