# Sample deliverable — false-positive control for gate-report-contract.sh

This file is a fixture, not a real report. It exists so the secret scanner has a
**positive control for silence**: it is deliberately full of the text a correct
security deliverable contains — token prefixes, redaction placeholders, hashes,
identifiers and near-miss strings — and the gate must stay quiet on all of it.

If a future change to the patterns starts firing here, the gate has become the
kind of noisy check that gets switched off, and it fails before it can do that.

---

## Executive summary

Review of an authorized repository, static mode, at the depth reached: three
findings, one of them a credential in the history. Nothing here supports a claim
that the system is secure.

## Findings

### F-01 — Credential committed to the repository

- status: `confirmed` · severity: `high` · confidence: `high`
- location: `config/deploy.rb:41`, first introduced in commit `a1b2c3d`
- evidence: `[REDACTED:secret]` — a classic GitHub token (`ghp_` prefix, 40
  characters, checksum validating offline). The value is not reproduced here,
  not even truncated; the location and the format class are what rotation needs.
- fix: rotate the token at the provider, then purge the object from history.
  Treat it as compromised regardless of repository visibility.
- traceability: `SUP-11`, CWE-798

### F-02 — Personal data written to the application log

- status: `confirmed` · severity: `medium` · confidence: `high`
- location: `app/services/checkout.rb:88`
- evidence: the `email` and `national_id` columns reach the info-level log on
  every checkout; order of magnitude, tens of thousands of records per day.
  Sample values are `[REDACTED:pii]`.
- traceability: `PRI-04`

### F-03 — Administrative interface reachable from the build network

- status: `probable` · severity: `medium` · confidence: `medium`
- location: `[REDACTED:internal-host]` (`host-A`, the internal build runner)
- evidence: the deploy job reaches `host-A` with no network policy between the
  runner and the administrative port. The inferred link, named as required: the
  production network topology was described to us and not observed.
- traceability: `INF-09`

## What was ruled out, and what resisted

Tested, and it did not appear:

- SQL injection in the checkout flow — `WEB-07`, `refuted`. Traced from the
  three HTTP entry points that reach the order module; every query goes through
  the ORM's parameter binding, read end to end. Bound: the two admin-only
  reporting endpoints were out of scope and are not covered by this entry.
- Insecure deserialization of the job payload — `WEB-19`, `refuted`. The worker
  accepts JSON only, with a schema check before the object is built.

What actively resisted:

- The forged-token attempt against `POST /api/v2/orders` was rejected by the
  signature check in `app/auth/token_verifier.rb:23`. The attempt used
  `[REDACTED:payload]` — parameter `token`, sink `verify!`, class: signature
  stripping. The working string is in the evidence annex, item A-2.
- The pipeline blocked an action pinned to a mutable tag, in
  `.github/workflows/deploy.yml`.

How to keep it:

- Regression test for the signature check: send a token whose `alg` header is
  emptied and whose signature segment is dropped, and assert HTTP 401 plus no
  entry in the orders table. Belongs in `spec/requests/auth_spec.rb`.
- Regression test for the pipeline rule: a workflow file referencing an action
  by tag must fail the existing hardening job.

## Coverage declaration

Exercised: session management, authorization, injection, dependency exposure.
Not exercised: cryptography at rest (no key material in scope), and the mobile
client (no artifact provided). The dynamic checks against the staging host are
`blocked`: no authorization was granted for that host, and a written scope
covering `host-A` would unblock them.

---

## Near-miss strings the scanner must NOT flag

These are the shapes that a naive detector fires on. They are legitimate text in
a security deliverable and every one of them must pass.

- Prefixes taught in the corpus, with nothing after them: `ghp_`, `gho_`,
  `ghu_`, `ghs_`, `ghr_`, `AKIA`, `sk-ant-`, `xoxb-`, `AIza`, `glpat-`.
- A body one character short of a token: `ghp_EhsFixtureNotARealToken00000x`.
- An `alg:none` teaching example, whose third segment is empty:
  `eyJhbGciOiJub25lIn0.eyJzdWIiOiJmaXh0dXJlIn0.`
- A commit SHA: `da39a3ee5e6b4b0d3255bfef95601890afd80709`.
- A UUID: `8f14e45f-ea2c-4c07-8b1a-4b0c2f9d1e77`.
- The words password, secret, api_key, token and credential, in prose, because a
  security report is *about* them — which is why this gate keys on formats and
  not on those words.
