# The prompt both arms received

One template. The arms differ only in which corpus the launch instruction points at and in
the mantis arm being asked to map its own review constraints onto `FP-nn` labels.

**Both arms were required to carry `scope`.** The field is this project's, and exempting the
competitor from it would have measured our discipline against its absence. If the field makes
an auditor think better it has to do that for both, and whatever lead survives is real.

## What this directory does NOT contain

The per-arm **launch call**. Every `mantis` launch in this round carried *run the stages
inline rather than spawning sub-agents*, and no `ours` launch carried anything like it —
so the sentence above, that the arms differ only in which corpus the launch points at, is
**wrong**, and it names the smaller difference while omitting the larger.

A `prompts/` directory that ships the shared template and not the launch call is a
directory that can be complete and still mislead. `gate-bench-integrity.sh` checked that
prompts exist; it could not check that they were all of it.
See [`../../CORRECTION-inline-constraint.md`](../../CORRECTION-inline-constraint.md).
