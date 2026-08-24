# The ordering of pre-registration and result, on a clock that is not ours

A blind auditor of this repository confirmed the six-question rubric answers and then named the limitation that mattered: **every timestamp it checked was a git committer date, which the author supplies.** Ordering verified against the author's own clock is worth what the author's honesty is worth.

So it is verified again against GitHub's.

A workflow run records `created_at` on GitHub's servers when the push arrives. That value is not in the commit object and cannot be set by whoever wrote it.

| | commit | GitHub received it | evidence |
|---|---|---|---|
| **pre-registration** of the critic-stage round | `b4f3648` | **by 2026-08-22T01:18:20Z** | it is an ancestor of `66002fa`, whose CI run GitHub created at that time |
| **result** of the same round | `91abbc0` | **2026-08-22T02:01:50Z** | its own CI run, and it is *not* an ancestor of `66002fa` |

**Forty-three minutes, on a clock nobody here controls, in that order.** Reproduce it with:

```
gh run list --branch pack/ci-platforms --json createdAt,headSha
git merge-base --is-ancestor <prereg-sha> <sha-of-a-run-that-predates-the-result>
```

## What this still does not prove

- It establishes that the pre-registration **existed and was published** before the result was. It cannot establish that the result was not already known to the author when the pre-registration was written — nothing outside a trusted third party can.
- It covers the rounds that were pushed to a branch CI runs on. Rounds committed and pushed together in one push share a receipt time and are ordered only by the commit graph.
- The remaining defence is the one the rubric is built on: **the refutation criterion is written into the pre-registration**, so a reader can check whether the published result respects it. Two rounds in `bench/` were published as worthless *because* they did.
