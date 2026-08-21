# Run 2026-08-21 — third-party code, ground truth from someone else

Every other run in this directory scores the squad against a bench **this project wrote**, and each of their READMEs says so. This one is the answer to that objection: the target is code nobody here has touched, and the answer key belongs to somebody else.

## The target and the key

Three advisories from the **GitHub Advisory Database**, reviewed, high severity, each carrying the upstream commit that fixed it in [`Netflix/lemur`](https://github.com/Netflix/lemur). The audited files are the **parent** of that commit — the vulnerable state — fetched through the GitHub API. Provenance and the exact commands are in [`../../external/lemur-2026.json`](../../external/lemur-2026.json).

| Advisory | Class | In scope of |
|---|---|---|
| `GHSA-cfh6-pv5c-38jv` / `CVE-2026-71308` | unchecked `replaces[]` silences notifications on certificates the caller does not own | case A |
| `GHSA-pxmc-2ffp-8j67` / `CVE-2026-71417` | arbitrary certificate revocation at the CA via a duplicate row | case A |
| `GHSA-6c8m-q6g9-vrw3` / `CVE-2026-71307` | authenticated low-privilege users read plaintext destination credentials | case B |

Two specialists, fresh contexts, given only the affected modules and the packs. **Neither was told a vulnerability existed**, neither was allowed to use the network, and neither was told what the project was.

## Result

| | |
|---|---|
| Published advisories in scope | 3 |
| **Found blind** | **2** |
| Missed | 1 |
| Additional findings not matching any published advisory | 7 |

**`CVE-2026-71308` — found.** The specialist traced `replacements` from three write schemas, through `service.upload/create/update`, to the SQLAlchemy append event that sets `notify = False` on the *appended* certificate — a row belonging to someone else — and noted that every other operation on a foreign certificate is guarded by `CertificatePermission` in eight places while this one is not. The upstream fix added exactly that authorization. It was reported `probable`, not `confirmed`, for one named reason: the schema that resolves the id lives outside the files it was given.

**`CVE-2026-71307` — found.** The specialist reported `DestinationOutputSchema` dumping the stored `options` blob verbatim and copying it again into the nested plugin object, with the SFTP plugin's `password` and `privateKeyPass` declared as ordinary string options — and separately reported that the read handlers carry only `AuthenticatedResource` while the write handlers on the same resources carry `admin_permission`. The upstream fix touched those three files: the schema, the views and the plugin.

**`CVE-2026-71417` — missed.** Two findings landed on the same upload endpoint the fix touched — an authorization gap on the owner field and a skipped validation hook — but neither describes the chain the advisory names: upload a certificate that duplicates an existing row, then revoke it, and the revocation reaches the CA. Adjacent is not the same as found, and this column says missed.

## What is published here, and what is not

`findings-matching-published-advisories.json` holds the three findings that correspond to advisories **already public and already fixed upstream**.

The other seven are **withheld** — `withheld-summary.json` records their class and severity and nothing else. They are defects in a third party's code that may still be live; publishing their location or mechanism in this repository would be disclosure by us, which the safety contract forbids without the maintainer's involvement. What happens to them is the maintainer's decision to make, through the project's own channel, and this file exists so that the decision is visible rather than quietly skipped.

## The limits, stated as plainly as the result

- **The auditors received the affected modules, not the whole repository.** A real engagement starts by finding the file; this one handed it over. That makes the task easier than the engagement it stands for.
- **Recall is measured against advisories that exist.** A defect nobody has published counts as neither a hit nor a miss, which is why the seven extra findings sit in their own row rather than inflating the score.
- **The ground truth is external; the comparison is ours.** Nobody outside this project checked that finding X answers advisory Y. The artifacts are here so that anyone can disagree.
- **Three advisories is three.** It is the first measurement of this kind in this repository, not a benchmark.
