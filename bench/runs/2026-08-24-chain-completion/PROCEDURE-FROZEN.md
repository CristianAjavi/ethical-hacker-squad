# Frozen candidate — `VER-10 The finding that landed next to the defect`

Frozen before the first run of this round, per `PREREGISTRATION.md`.

**This text is NOT in the corpus and does not ship.** It moves into
`references/knowledge/remediation-verification.md` only if the round's
pre-registered criteria are met. If they are not, this file stays here as the
record of a hypothesis that was tested and refused.

---

### VER-10 The finding that landed next to the defect

**Where to look**
- Every finding you are about to report that is **true, and smaller than the file
  it lives in**. Before it is written down, ask one question of it: *what is the
  next step from here that I have not taken?*
- Three shapes this repository has measured, all with the right file already open:
  - **A sibling the same helper does not cover.** One attribute is escaped by a
    helper that exists in the file; the attribute beside it is not. Report the
    escaped one and the real sink is nine lines away.
  - **A neighbour of the same family.** A recursion with no depth counter is
    reported; the allocation two lines below, sized from the same untrusted
    length, is not.
  - **A reachable state transition.** An authorization gap on a field is
    reported; what the field lets the caller *do next* — duplicate a row, then
    revoke it, and the revocation reaches a signing authority — is not.
- The move is the same in all three: from the finding, enumerate what the same
  input, the same helper or the same principal reaches **one step further**, and
  look there before writing.

**Vulnerable pattern**
```
finding:  "unescaped author value reaches class= in export()"      ← true, reported
sink:     "the same value reaches the plugin-hook data- attribute" ← 9 lines away, not reported
helper:   esc_attr() exists in this file and is applied to neither
```
The report is accurate. The advisory is about the line it does not name.

**What rules it out (false positive)**
- The next step is **enumerated and empty**: the sibling attributes are escaped,
  the neighbours of the family carry their guard, the transition is blocked at a
  line you quote. Write that line down — an enumeration with no citation is not
  an enumeration.
- The step leaves the trust domain the engagement covers, and the coverage
  declaration already says so.
- The step is the same defect under another name. Report it once; two ids for one
  chain is padding, and `FP-08` covers what to do when the evidence is outside
  the repository.

Rules: FP-01, FP-06, FP-08.

**Minimal test**: for each finding, write one line — *the next step I took from
here, and what I found*. A finding whose line is empty has not been finished. On
a target with an advisory, the pass is scored on whether the chain the advisory
names appears in some finding, not on whether some finding touches the same file.

**Traceability**: `internal process` — this is a review move, not a defect class,
and carries no external identifier.\
**Tooling**: none. A taint tracker follows the flow it was pointed at; this is
about the flow nobody pointed at.

---

## Why this text and not more knowledge

Three measured instances, each with the right file open and something true
reported:

| Round | Reported | Missed |
|---|---|---|
| `../2026-08-21-whole-repo-3arm/` | the neighbouring recursion | the allocation sized from the same length |
| `../2026-08-22-second-target/` | authorization gap on the owner field | the duplicate-then-revoke chain reaching the CA |
| `../2026-08-22-third-competitor/` | unescaped value at `class=` | the same value at the `data-` attribute |

`WEB-26` was written from the first of those and closed it as a **knowledge**
gap: an allocation pattern the corpus did not carry. The other two are not
knowledge gaps. Nothing in a pack would have named the duplicate-then-revoke
chain, and the exporter's helper was already in the file.

That is the whole hypothesis, and it is falsifiable: the failure is not *what
the reviewer knows*, it is *stopping at the first true thing*. If forcing one
more step does not move recall by the pre-registered band, the failure was
something else and this text is deleted.
