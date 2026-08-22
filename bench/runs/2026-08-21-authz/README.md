# Run 2026-08-21 — `WEB-24` and `WEB-25`, the two procedures the parity produced

Six rule-picked advisories, three arms, 3/6 each. The tie came from two shared misses, and neither was a coverage gap — both defects were **in the files every arm was given**. They were procedure gaps, and this directory measures the two procedures written to close them.

| Procedure | The miss it comes from |
|---|---|
| `WEB-24` a gate one sibling handler enforces and another does not | `CVE-2026-71417`: `AuthorityPermission` imported and enforced in the create handler at `views.py:529`, absent from the upload handler at `:558`. `WEB-05` did not fire, because it is written around administrative routes and missing decorators and this was neither — both handlers are authenticated and the difference is two lines of ordinary application code. Eight findings across the three arms landed `partial` on that route without joining it. |
| `WEB-25` authorization checked on the object in the path, not on the objects in the body | `CVE-2026-71308`: `replaces[]` resolved into live rows with no permission on the rows referenced, and an append listener flipping `notify = False` on the victim. **35 findings from three independent methods returned 0 `yes` and 0 `partial`** — not one looked at what naming another row did to it. |

## Result

| | |
|---|---|
| planted instances detected | **2 of 2** |
| decoys reported | **0 of 2** |
| findings the key never planted | 1, not counted against the run |

The two decoys are the point, because both imitate the finding exactly where a reader meets it:

- `CertificatesStats` has a gated `post` and an ungated `get` — the shape `WEB-24` is written around. The specialist ruled it out on `FP-09` with the reason the procedure asks for: *`counts_by_month()` acts on no authority and the route carries no id, so it is not the twin of the gated `recompute`.* Not the same effect, therefore not the finding.
- `tags[]` names other rows in the body, one line below `supersedes[]` in the same resolver — the shape `WEB-25` is written around. Ruled out on `FP-02`, because that resolver iterates the caller's own tags and keeps the intersection, so an id the caller does not own resolves to nothing.

Getting both right requires the exculpation clauses to do real work, not the pattern match.

The unlabelled finding is worth reading: `CertificateTags.post` authorizes the tags in the body — a check that cannot fail, since the schema already reduced that list to the caller's own — and never authorizes the `certificate_id` in the path. The bench did not plant it. It is a defect, and the case author put it there without noticing.

## What this is and is not

**It is not a rematch.** These procedures were written *from* the advisories they now describe, so this run shows the lessons are encoded and survive contact with constructs built to defeat them. It does not show they generalise, and the 3/6 tie in `../2026-08-21-round2/` is not amended by anything here.

**What would settle it** is the next rule-picked round, on cases nobody here has seen, with `WEB-24` and `WEB-25` already in the corpus before anyone knows the cases exist. That is the third round, and it does not exist yet. The pattern is now explicit and worth stating plainly: each rule-picked round has ended level and produced procedures from what everyone missed. Whether that compounds into a lead is an empirical question with two data points and no answer.

## Files

`findings-certs-authz.json` is the artifact as delivered; `score.txt` is the scoring output. The case is `bench/cases/certs-authz`.
