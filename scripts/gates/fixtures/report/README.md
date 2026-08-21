# Fixtures for `gate-report-contract.sh`

## `good/` — the false-positive control, committed

`good/01-clean-deliverable.md` is inside the gate's default scan path. It is a
conforming sample deliverable stuffed with the strings that make naive secret
scanners fire: token prefixes with nothing after them, a body one character too
short, an `alg:none` JWT with an empty signature segment, a commit SHA, a UUID,
and the words *password*, *secret* and *token* in ordinary prose.

Its job is to fail the day the patterns lose precision. A gate that cries wolf
on correct text is a gate somebody deletes from CI, so the control runs on every
invocation rather than living in a document as an intention.

## `bad/` — deliberately absent

There is no negative fixture directory here, and that is the point.

A negative fixture for this gate would have to be a string that every secret
scanner in the world is built to recognise: a token with a valid checksum, an
AWS access key id, a PEM private key block. Committing one would mean
(a) pushing a credential-shaped literal into a public repository whose own
corpus records that 81% of secrets committed to public repositories are never
removed, (b) tripping push protection and the scanners of everyone who clones
us, and (c) teaching, by example, the exact habit this gate exists to break.

So the positive controls are **generated at run time**, in a temporary
directory, by the battery inside `gate-report-contract.sh`: a fictitious
40-character GitHub token whose checksum validates under our own CRC32/Base62
reconstruction, the same token with the checksum deliberately broken, and an
access-key-shaped literal. The battery asserts that each one is caught **and
classified correctly**, and that a clean copy stays green. It runs on every
invocation; `GATE_SELFTEST=0` skips it and forfeits the `0`.

The evidence that the gate fails when it should is therefore reproducible with
one command, and nothing secret-shaped ever enters the history:

```
scripts/gates/gate-report-contract.sh --self-test
```
