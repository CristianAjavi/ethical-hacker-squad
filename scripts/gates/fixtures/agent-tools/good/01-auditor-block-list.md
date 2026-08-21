---
name: ehs-fixture-auditor-block-list
description: Fixture for gate-agent-tools.sh, green path. Tools as a YAML block list rather than an inline one, a scoped `Bash(git:*)` entry, and two tool names built to trip a substring match - `TodoWrite` writes a task list and `NotebookRead` only reads. None of them may be reported as a write tool.
model: inherit
tools:
  - Read
  - Grep
  - Glob
  - NotebookRead
  - TodoWrite
  - Bash(git:*)
---

You are a fixture agent. Everything about this file conforms.

## Safety contract

- **You have no `Edit` or `Write` tool, and you must not write through `Bash` either.** Leave the working tree exactly as you found it.
- Never print a full secret or personal data.

## Method

Read, measure, report. A false positive here is a gate somebody switches off within the week, so this file is part of the check as much as the failing ones are.
