<!-- POSITIVE fixture: correct verdict prose, and the near-misses that a lazier detector
     would flag. The vocabulary tables legitimately put an absence term and a conclusive
     term on the same line; `Secure` is a cookie attribute, not a claim; and `not verified`
     is one token, not a sighting of `verified`. Each line here broke an earlier version of
     the detector or of a neighbouring gate. -->

# Verdict prose that must not be flagged

| Term | Meaning |
|---|---|
| `refuted` | the check ran and established the opposite of the claim; use `inconclusive` when it settles nothing |
| `blocked` | a named external condition stopped it; say what would unblock it |

Drift already present: `not executed` versus `not verified`, and `withdrawn` missing from the
report specification.

The cookie carries `Secure` and the setting is `SESSION_COOKIE_SECURE`; neither is a verdict.

An `inconclusive` outcome is not a weaker `verified`: nothing may be concluded from it.

Recording that as a pass is the failure this dimension exists to prevent.

The finding was `refuted` after the request log showed the nonce reaching the handler, which
is the reach proof this outcome required.
