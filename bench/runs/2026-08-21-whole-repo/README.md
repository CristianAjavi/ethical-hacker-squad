# Run 2026-08-21 — a whole repository, no pointer

The external run before this one carried an admission: the auditors received **the affected modules**, not repositories. A real engagement starts by finding the file. This run removes that help.

## Result

| | |
|---|---|
| Target | `contentful/contentful-mcp-server` at the parent of the fix commit — **286 files**, an npm/Nx TypeScript monorepo |
| What the auditor was told | that it was a third-party repository, authorized, read-only. **Nothing else.** No module, no file, no hint that a vulnerability existed |
| Published advisory in scope | `CVE-2026-53957` (`GHSA-2xhg-73j7-rrgx`) |
| **Result** | **found** — `exportSpace.ts:134`, judged `yes` by a context that saw only the advisory text and the finding text |

The finding, in the auditor's own words: *export_space and import_space forward a model-chosen host, proxy and headers together with the operator's stored CMA token*. The blind judge settled it on the mechanism — the same `{ ...args, managementToken }` spread, the same place, the same consequence — and called the extra parameters the finding names a superset on the same path, "extra exploit surface for one defect, not a different one".

**It inventoried its way there.** The coverage declaration records what it did: 286 files, an ESM monorepo publishing a stdio MCP server, a thin server package and a tools package — then routing to the packs that inventory justified, then reading the paths that carry a credential.

## What this run is not

- **One repository and one advisory.** The second target of this run — a 575-file Python application with three advisories in scope, including the one the module-level run missed — **never produced an artifact**. Its agent was killed five times by the host sleeping mid-response and by a stream stall, and it was stopped rather than resumed a sixth time. That is an aborted run, not a result, and it is written here so nobody reads the table above as the whole story.
- **A partial audit.** The artifact's own coverage declaration says so: three findings written, more paths identified and unread. The advisory happened to be on a path it reached early; a different advisory in the same repository might have sat behind the paths it never opened.
- **Still arranged by us.** We chose the repository, the commit and the pack set, and we wrote the judge's instructions. What is no longer ours: the file was found rather than handed over, and the match was decided by a context that never saw a diff.

## Files

`findings-matching-published-advisory.json` holds the finding the judge matched. `withheld-summary.json` lists the other two by class and severity only — third-party findings with no published advisory, held pending a disclosure decision. `judgements.json` is the verdict with its reasoning.
