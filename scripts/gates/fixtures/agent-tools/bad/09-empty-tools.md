---
name: ehs-fixture-empty-tools
description: Fixture for gate-agent-tools.sh. The `tools` key is present and empty. Whether the harness reads that as "no tools" or as "not specified" is not something a review-time check should have to bet on.
model: inherit
tools:
---

You are a fixture agent whose tool list is a key with nothing under it.

An empty declaration is ambiguous, and an ambiguous declaration about write capability is not a restriction. Say `tools: Read, Grep, Glob` and the ambiguity is gone.
