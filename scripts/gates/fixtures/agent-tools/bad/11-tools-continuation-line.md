---
name: ehs-fixture-tools-continuation-line
description: Fixture for gate-agent-tools.sh. The tool list wraps onto a second, indented line. YAML folds that line into the same value; a reader that takes only the line holding the key never sees it.
model: inherit
tools: Read, Grep, Glob,
  Write
---

You are a fixture agent whose tool list says one thing to a line reader and another to a YAML parser.

You must not write through `Bash`.

A line reader certifies `Read, Grep, Glob`. YAML reads `Read, Grep, Glob, Write`, and the harness is the one that uses YAML.
