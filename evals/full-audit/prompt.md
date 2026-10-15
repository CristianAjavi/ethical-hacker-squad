---
description: A full security audit of the same app, asked for in a reviewer's words.
tags: [vibe-app, full]
runs: 3
max_turns: 200
timeout_seconds: 3000
allowed_tools: [Read, Glob, Grep, Skill, Agent, TodoWrite, Write, Bash]
---

Run a full security audit of this repository. I own it and you are authorized to review it locally; do not contact any external service. Report what an attacker could exploit, with the file and the evidence for each finding, and write the report to `security-report.md` in this folder.
