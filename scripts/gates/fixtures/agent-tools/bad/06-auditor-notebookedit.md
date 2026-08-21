---
name: ehs-fixture-auditor-notebookedit
description: Fixture for gate-agent-tools.sh. An auditor carrying `NotebookEdit`, the write tool people forget when they think of write tools. It also proves the entry is matched whole - a gate that greps for "Edit" as a substring would report the wrong name here.
model: inherit
tools: Read, Grep, Glob, Bash, NotebookEdit
---

You are a fixture agent auditing notebooks.

## Safety contract

- **You have no `Edit` or `Write` tool, and you must not write through `Bash` either.**

A notebook is a file. Being able to edit it is being able to write.
