# Run 2026-08-21 — third-party code, ground truth from someone else

Every other run in this directory scores the squad against a bench **this project wrote**, and each of their READMEs says so. This one is the answer to that objection: the target is code nobody here has touched, and the answer key belongs to somebody else.

## The target and the key

Five advisories from the **GitHub Advisory Database**, reviewed, high severity, each carrying the upstream commit that fixed it — three in [`Netflix/lemur`](https://github.com/Netflix/lemur), one in [`contentful/contentful-mcp-server`](https://github.com/contentful/contentful-mcp-server) and one in [`ether/etherpad`](https://github.com/ether/etherpad). The audited files are the **parent** of that commit — the vulnerable state — fetched through the GitHub API. Provenance and the exact commands are in [`../../external/lemur-2026.json`](../../external/lemur-2026.json).

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

**`CVE-2026-53957` — found.** On an MCP server: the specialist reported that `exportSpace` and `importSpace` declare `host`, `hostDelivery`, `proxy`, `rawProxy` and `headers` as ordinary model-supplied parameters and then spread them into the client config beside the management token, so **the model, not the operator, chooses the endpoint the credential is presented to** — while the operator's pinned `CONTENTFUL_HOST` is never read by either tool. The blind judge called it the same defect, naming the extra parameters a superset on the same path rather than a different one.

**`CVE-2026-55090` — found.** On an HTML exporter: the specialist reported four unescaped sinks and the judge matched the one the advisory names — hook-supplied tag and data-attribute values concatenated into markup — at the same line. It rated the other three (author colour into a `<style>` block, author class name, list type name) as *neighbouring* sinks, not the same defect.

**`CVE-2026-71417` — missed.** Two findings landed on the same upload endpoint the fix touched — an authorization gap on the owner field and a skipped validation hook — but neither describes the chain the advisory names: upload a certificate that duplicates an existing row, then revoke it, and the revocation reaches the CA. Adjacent is not the same as found, and this column says missed.

## What is published here, and what is not

`findings-matching-published-advisories.json` holds the three findings that correspond to advisories **already public and already fixed upstream**.

The other seven are **withheld** — `withheld-summary.json` records their class and severity and nothing else. They are defects in a third party's code that may still be live; publishing their location or mechanism in this repository would be disclosure by us, which the safety contract forbids without the maintainer's involvement. What happens to them is the maintainer's decision to make, through the project's own channel, and this file exists so that the decision is visible rather than quietly skipped.

## The comparison was taken out of our hands

The first version of this record scored the run by **reading the upstream diff ourselves**. That is a hand on the scale, and the objection is fair, so it was removed:

- **File level, deterministic.** `scripts/bench/score-external.py` will only consider a finding for an advisory if `location.path` is one of the files that advisory's fix commit touched. The file list comes from the commit, not from us.
- **Class level, judged blind.** Every file-level candidate pair went to a separate context that saw **the advisory text and the finding text and nothing else** — not the repository, not who wrote either, not this project, and not which answer anybody hoped for. It answered `yes`, `partial` or `no`, with the rule that adjacent is `partial`.

**The judge returned 2 `yes`, 8 `partial`, 2 `no`** — the same two hits and the same miss this record already claimed, reached by a party that never saw a diff. `judgements.json` holds every verdict with its reason; `score.txt` is the scorer's output. Without a judgements file the scorer refuses to call anything a hit and says so.

Eight `partial` verdicts are worth reading on their own: four findings sit on the same file as `CVE-2026-71417` and the judge called every one of them a different defect. That is the shape of a near miss, and it is why the miss column says missed.

## The limits, stated as plainly as the result

- **The auditors received the affected modules, not the whole repository.** A real engagement starts by finding the file; this one handed it over. That makes the task easier than the engagement it stands for.
- **Recall is measured against advisories that exist.** A defect nobody has published counts as neither a hit nor a miss, which is why the seven extra findings sit in their own row rather than inflating the score.
- **The ground truth is external and the comparison is now blind**, but both were arranged by this project: we chose the advisories, we scoped the files, and we wrote the judge's instructions. The artifacts and the judgements are here so anyone can disagree with any of it.
- **Five advisories is five.** Three projects, two ecosystems, four surfaces — and still a sample, not a benchmark. What it does rule out is the objection that one repository or one language flattered the result.
- **The two clean sweeps are the small ones.** The MCP and exporter cases had one advisory each in a small file set; `lemur` had three advisories in ~4,400 lines and one of them was missed. Difficulty is not constant across this table and the table does not pretend it is.
