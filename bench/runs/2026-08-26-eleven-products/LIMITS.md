# Two defects in the harness, found before any arm was scored

Both were found by exercising the scoring path on synthetic artifacts built from the key, not
by looking at an arm's report. They are recorded here because either one, unnoticed, would have
produced a published number that was wrong.

## 1. The scorer would have reported every arm at 0% recall

`scripts/bench/score.py` counts a finding only when its `status` is `confirmed`, `probable` or
`hardening`. This round's prompt asked each arm for `{title, location, class, severity,
evidence, impact, recommendation}` and never mentioned `status`.

Scored raw, an arm with 53 well-formed findings reads as **recall 0%** — a harness defect that
looks exactly like a devastating result, for every arm at once.

[`adapt.py`](adapt.py) sets `status` to `confirmed` where an arm did not set one, and changes
nothing else. Proved on a synthetic report: findings in equals findings out, titles and
locations byte-identical, a declared `status` respected rather than overwritten.

**It has no per-arm branch.** One file, one behaviour, run over every report in the round —
which is the only thing that makes the comparison fair, and is why it is a separate file
instead of a flag inside the scoring step.

End to end on artifacts built from the key: a report naming all 54 planted defects scores
**54/54**; a report naming all 50 decoys scores **50 decoys reported**.

## 2. One planted defect can be "detected" by reporting a decoy

The all-decoys artifact scores **1/54**, not 0. The one it hits is **`P-12` (`INF-02`,
`aws_s3_bucket_public_access_block` in `terraform-platform`)**: a decoy sits close enough to it
that the matching rule — same file, then symbol or line window — resolves to the planted defect.

There is no exact `(case, path, symbol)` collision in `bench/ground-truth.json`; the looseness
is in the match, not in the key.

**Effect:** any arm that reports that decoy is credited with one detection it did not earn,
inflating recall by up to 1/54 ≈ 2 points. It applies identically to every arm, so it does not
bias the comparison — but it does mean **every absolute recall number in this round is up to
two points high**, and that is stated here rather than discovered by someone re-running it.

It is not fixed mid-round: changing the matching rule after the arms have run is the thing
these pages exist to refuse. It is filed to be fixed before the next round that uses this key.
