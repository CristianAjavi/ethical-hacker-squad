# The check that did not flag the shape it is named for

Measured during this round, on this round's corpus, and moved here from the tool's own docstring
when the served tree hit its blast-radius limit: the tool ships to users and needs the numbers, the
history of how they were learned belongs in the bench.

## What was found

Two independent auditors, in two different components of `corpus-v10`, reported that
`writer_parity.py` did not flag a writer asymmetry they had found by reading. One of them is the
check's own headline shape — an entity written by three functions where two call a validator and
one does not:

- `quarrystore/quarrystore/repository.py` — `create_note` and `redact_note` call
  `policy.assert_can_write`; `update_note` calls nothing and mutates `body`, `category` and
  `billable_minutes`.
- `tallyflow-consumer/src/ledger.js` — `applyPosting` carries a solvency branch, a ceiling and a
  row lock; `adjustBalance` writes the same `balances` row with none of the three.

Run directly afterwards against the whole corpus: **five known asymmetries, zero flagged.** Two of
the six services are TypeScript and yielded no entities at all.

## Why

`WRITE` matches **calls** — `add(`, `save(`, `insert(`. An ORM write is frequently an attribute
assignment on an already-loaded instance:

```python
note.body = body
db.flush()
```

There is no call to match. The check was not mistuned; it was looking for the wrong shape.

## What was published first, and in the wrong order

This tool's **precision** was published carefully a day earlier — how a declared-entity filter cut
it from five flags to one, and why the earlier 100% was an artefact of a ±40-line window on
sixty-line files. Its **recall was never measured**, so the summary line *"0 with one writer checked
and another not"* read as *"no asymmetry exists"*. That is the failure this project spends its
rounds hunting in other people's code, inside its own instrument.

## The fix, and both numbers

A Python-only AST pass: assignment to an attribute of a name, inside a function that also flushes
or commits, where the name resolves — parameter annotation first, then its own spelling — to an
entity the tree declares. The declared-entity filter is the same one that fixed the precision
problem; without it `config.debug = True` beside a commit becomes a writer.

| | before | after |
|---|---|---|
| Python asymmetries found (of 2 known) | 0 | **2** |
| TypeScript/JavaScript (of 3 known) | 0 | 0 — pass not written |
| flags landing on a decoy | 0 | **0** |

Scored against the key, both ways, because one of them flatters:

- **By symbol: 2 of 2.** Both flags name a function that carries a planted defect
  (`update_note` → `AA-28`, `restore_over_redacted` → `AA-27`).
- **By line: 0 of 2 within five lines, 2 of 2 within ten.** The flag anchors on the `def`; the key
  anchors on the offending statement, eight and ten lines inside.

The symbol number is the honest one for a function-level finding, and the line numbers are printed
beside it rather than instead of it. **Two flags is a small sample and this is not a precision
claim.**

## What did not change

The three JavaScript and TypeScript asymmetries are still invisible, and the summary now says so on
every run — clean or not. A clean run of this check remains a fact about the check.

## Why the check exists at all

Moved here from the tool's docstring in the same trim.

```
WHY IT ASKS THAT
    Across the composition corpus this is the densest shape there is - the
    competitor's own run named four instances of it in six services, and two of
    them are defects this project never found in any run:

      ledger-flow  services/postings.py calls posting.clean() before writing;
                   services/importer.py:82 calls bulk_insert_mappings(Posting)
                   and calls nothing.
      atlas-sync   UpsertRecord pins owner_id to the caller the handler
                   resolved; BulkInsertRecords takes it from the payload.

    Both files are defensible. `bulk_insert_mappings` is the documented way to
    load a lot of rows fast, and skipping the ORM lifecycle is the reason it
    exists. The defect is that the invariant lives on the path nobody took.
```
