# Security policy

This repository contains a Claude Code plugin that instructs a squad of **ethical**
offensive security subagents. Its instruction files run as context inside the agent of
every person who installs it, so a defect here is not just a bug: it is a change in the
behavior of a security tool on someone else's machine. It is treated accordingly.

## Supported versions

| Channel | Branch | Support |
|---|---|---|
| `stable` | `stable` | Yes. Receives security fixes. |
| `latest` | `main` | Yes, at the tip. Fixed forward only. |
| Hand-installed copies | — | No. Reinstall from the marketplace. |

Only the latest published version of each channel is supported. There are no backports to
earlier versions.

## How to report a vulnerability

**Do not open a public issue.** The issues in this repository are public from the first
second and the report would be disclosed before a fix exists.

Single channel:

- **GitHub private security advisory:**
  <https://github.com/CristianAjavi/ethical-hacker-squad/security/advisories/new>

That form is used instead of an email address on purpose: it is private, it leaves a
trail, it allows discussing the patch with the reporter before publishing, and it allows
requesting a CVE at publication time. No email address is published for security reports,
so that they do not arrive over unencrypted channels.

Include in the report:

1. What the defect does and what the impact is for someone with the plugin installed.
2. Plugin version (`version` in `.claude-plugin/plugin.json`) and channel (`latest` or `stable`).
3. Minimal reproduction steps, with synthetic data and redacted secrets.
4. If it applies, the standard identifier (CWE, OWASP) that corresponds.

## Response timelines

| Milestone | Commitment |
|---|---|
| Acknowledgement of receipt | 3 calendar days |
| Triage and initial verdict (applies / does not apply / missing information) | 10 calendar days |
| Fix published on the `latest` channel | 30 calendar days for high or critical severity |
| Coordinated disclosure of the public advisory | 90 days from the report, or earlier if a fix is already published |

If the 90-day deadline is going to be missed, the reporter is notified and an extension is
agreed. The reporter is credited in the advisory unless they prefer to stay anonymous.

## What is in scope

- Code execution, context leakage or permission escalation caused by installing or using
  the plugin.
- **Indirect prompt injection through the knowledge corpus**: content in `skills/**` that
  induces the user's agent to act outside what the skill declares. This is the main vector
  of this tool, because there is an automated loop that reads public sources and proposes
  changes to the corpus.
- Publication chain: any path by which a third party can get content into the `latest` or
  `stable` channels without going through the gates.
- Workflows of this repository: secret handling, token permissions, actions not pinned by
  SHA, triggers that process untrusted content.
- Instructions that make the squad act outside the scope authorized by its user (for
  example, touching targets it was not pointed at).

## What is NOT in scope

- **False positives and false negatives of the analysis.** They are quality defects, not
  vulnerabilities: they go through public issues
  ([false positive](https://github.com/CristianAjavi/ethical-hacker-squad/issues/new?template=1-false-positive.yml),
  [false negative](https://github.com/CristianAjavi/ethical-hacker-squad/issues/new?template=2-false-negative.yml)).
- Vulnerabilities in third-party software discovered using this tool. Disclose them
  coordinately with the affected vendor; this repository is neither their reporting channel
  nor an intermediary.
- Vulnerabilities of the Claude Code platform or of Anthropic. Report those through their
  own channels.
- Raw scanner output against this repository with no exploitability analysis in context.

## Ethical use scope

The plugin exists to audit, harden and verify systems that are **your own or explicitly
authorized**. The security contract lives in
`skills/ethical-hacker-squad/SKILL.md` and is part of the product, not a decorative
warning.

Conditions of use and of contribution:

1. **Prior, verifiable authorization.** Using it against third-party systems, accounts,
   domains or data without explicit permission is illegal in most jurisdictions and falls
   outside any support.
2. **Contributions that weaponize attacks are not accepted.** No working exploits, no
   ready-to-use payloads, no persistence, exfiltration, stealth evasion, denial of service
   or lateral movement techniques. What enters the corpus is detection and remediation
   capability.
3. **Unpatched 0-days are not accepted** as a contribution to the corpus. Coordinated
   disclosure with the vendor comes first; the corpus is updated once the information is
   already public.
4. **No real data.** Cases, examples and tests use synthetic data. Secrets, credentials and
   personal data are always redacted.
5. **The MIT license does not grant authorization.** Being able to run the tool does not
   mean you may run it against a system you do not control.

Anyone contributing material that violates these points will have the contribution
rejected and, if it is deliberate, their access blocked.
