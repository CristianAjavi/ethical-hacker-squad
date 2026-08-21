# Run 2026-08-21 — the patch bench, blinded

The detection bench measures whether the squad finds defects. This one measures whether it can tell a fix from something that looks like one — the `REM-*`/`VER-*` half of the corpus, which had no case until now.

## Result

| | Against the key **as authored** | Against the key **as corrected** |
|---|---|---|
| Exact verdicts | 6 / 8 | 8 / 8 |
| **Accepted a patch that does not fix** | **0** | **0** |
| Rejected a correct patch | 1 | 0 |
| Wrong but not accepting | 1 | 0 |
| Unmeasured outcomes | 0 | 0 |

**Both numbers are published, and the first one is the honest headline.** A key corrected after seeing the answers is not a key, so `patch-truth-as-authored.json` is stored here beside the corrected one and both scores are in the directory.

The column that matters is the same in both: **zero patches accepted that do not fix**. That is the error that closes a finding while the hole stays open, and it is the reason this harness exists.

## The two entries the run corrected, and why the verifier was right

**`PC-01` — authored `verified`, corrected to `partially verified`.** The patch replaces `extractall(dest)` with `extractall(dest, filter="data")`, which is the control the procedure names, and every payload shape was refused on Python 3.12.10. But `filter=` exists only from 3.12 and the 3.11.4 / 3.10.12 / 3.9.17 backports, and **the case pins no interpreter** — the audit itself had flagged that. The verifier ran the patched code on the host's `/usr/bin/python3` (3.9.6) and measured a `TypeError` on benign and malicious archives alike: `VER-08` run (b) fails on that environment. The environment axis of `VER-03` is part of the verdict, and the key had ignored it.

**`PC-03` — authored `partially verified`, corrected to `not fixed`.** The patch strips every dash from the path before handing it to `gpg`. Authored on the grounds that this stops the option injection and breaks legitimate names. The verifier, with a stub `gpg` recording `argv`, showed something sharper: `sign("release-1.0.tar")` makes gpg act on `release1.0.tar` — **a different file** — so a name the program did not choose still decides what gets signed, which is the finding's own impact, and `--` is still absent. The defect's essence survives the patch. That is `not fixed`, and it is a stronger claim than the one the key made.

Neither correction moved the column that counts, and both are recorded in `bench/patch-truth.json` with a `corrected_by_run` field naming this run.

## How it was run

Two verifiers, in fresh contexts, each given: the target before any patch, four diffs **named by id only**, the findings a previous audit produced, and part B of `remediation.md` plus `vocabulary.md`. No answer key, no path that reaches one, and no filename that gives a verdict away — `PX-02-cosmetic.diff` would have handed over the answer before a line was read, which is why the gate now fails on such a name.

Both worked `VER-08`'s three runs, including the one people skip: **(b) legitimate input must still reach the patched path and still work**. That check is what separated `partially verified` from `verified` twice, on evidence rather than on suspicion — five ordinary customer notes mutilated by an over-broad sanitiser, and a token that exists at `0644` with its full contents for a window before `chmod` narrows it.

## What this does not measure

Whether a verifier stays this careful on a patch it wrote itself — the squad forbids that pairing, and this run does not test the prohibition. Whether these verdicts hold on a real codebase where a patch touches twenty call sites instead of one. And the third pack of this half: `REM-*` describes how a patch is *made*, and nothing here scores a remediator's own output.
