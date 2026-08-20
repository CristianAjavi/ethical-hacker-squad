# Security policy

This repository ships a security skill that runs inside other people's projects, with tool access, on code the user did not write. A defect here does not stay here.

## Reporting a vulnerability

**Do not open a public issue.** Use GitHub's private reporting: **Security → Advisories → Report a vulnerability** on <https://github.com/CristianAjavi/ethical-hacker-squad>. It reaches the maintainer privately and keeps the discussion attached to the repository.

Include what you would want to receive: the file and line, what an attacker controls, what they get, and the smallest reproduction that shows it. If the finding is a procedure that misleads rather than a mechanical flaw, say which procedure and what a reader would do wrong because of it.

Expect an acknowledgement within a few days. There is no bounty and no service-level agreement; this is a maintained personal project, and saying so is more useful than promising a response time nobody is on call for.

## What counts as a vulnerability here

The interesting classes are specific to what this repository is:

- **Injected instructions in the corpus or in an agent definition.** Text that a specialist would follow as an order rather than read as knowledge. This is the highest-severity class: it would execute inside the security agent of everyone who installed the plugin.
- **A procedure that widens the safety contract**, explicitly or by implication — anything that would lead a specialist to test a target outside the authorized scope, run a destructive action, exfiltrate data, or spend an unbounded budget.
- **A tool grant that breaks the audit/remediate split**, such as an auditor that can write, or an agent whose declared tools do not match what its prompt asks it to do.
- **A supply-chain flaw in this repository's own machinery**: an unpinned or mutable action, a privileged workflow trigger, an over-permissioned token, a gate that can be made to pass without measuring.
- **A leaked credential** in the tree or in history.

## What belongs in a public issue instead

A wrong or missing procedure is a quality defect, not a vulnerability, and it is handled in the open where other users can see it: `false-positive` (the squad reported something unexploitable) and `false-negative` (the squad missed something real). Both are first-class issue types — see `CONTRIBUTING.md`. Closing one requires the fix **plus** the check that stops it recurring.

## Scope

This policy covers the contents of this repository: the skill, the corpus, the agent definitions, the plugin manifest, the gates and the workflows.

It does not cover Claude Code itself, the model, or any third-party tool the corpus names. Report those to their own maintainers. Findings your own audit produced about **your** systems are yours; nothing in this repository asks you to send them anywhere.
