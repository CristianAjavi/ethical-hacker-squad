# The prompts both arms received

`without-join.md` is the composition round's prompt, used by the four stored runs.
`with-join.md` is this round's, used by the four new ones.

**They are byte-identical.** That is the point of keeping them: the only difference between the
arms is the corpus the prompt points at — one where `path_coverage.py` ships and the roles cite
it, one from before it existed. Nothing in the wording changed, and a reader can check that
rather than take it on trust.

## Outside information

Both prompts carry the same clause: *"Report only what you establish by reading this tree."*
Neither arm was given a framework hint the other lacked, and the target's stacks are named
identically in both launch instructions.

This disclosure exists because `gate-bench-integrity.sh` refused the round without it, and it
was right to: **this bench has measured prompt wording at 21 points.** A comparison that does
not keep its prompts cannot tell the arms apart from the sentences.
