---
name: ehs-fixture-auditor-no-shell
description: Fixture for gate-agent-tools.sh, green path. An auditor with no shell at all. It carries no scope block and must still pass - the block is required of agents that hold the instrument, not of every file under agents/.
model: inherit
tools: Read, Grep, Glob
---

You are a fixture agent without a shell.

## Method

You read files and you report. There is no instrument here to restrict, and demanding the sentence anyway would teach authors to paste a contract they do not need - which is how a safety block turns into decoration.
