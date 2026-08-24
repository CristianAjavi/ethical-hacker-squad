# Run 2026-08-21 — `WEB-26`, written from the loss it should have prevented

The whole-repository round ended 0/2 for the corpus against 1/2 for an unaided engineer. The corpus arm had the right file open and reported the neighbouring defect; the class it missed had been named as uncovered **by one of our own arms, in writing, earlier the same day**, and the write-up was deferred so it could not contaminate a round then in flight.

This is the write-up, and its measurement.

## Result

| | |
|---|---|
| planted instances detected | **2 of 2** — the unbounded allocation and the uncapped parser recursion |
| decoys reported | **0 of 2** |
| findings the key never planted | 0 |

Two findings, two planted defects, nothing else. The specialist reported both as `probable`, not `confirmed`, because the callers that would settle reachability were outside the target — the ceiling written down rather than assumed.

## The decoys are the procedure

Both imitate the finding at the line where a reader meets it, and telling them apart needs the exculpation clause rather than the pattern:

- **`readText`** has the identical shape to the planted `readBlob` — a declared length sizing an array — and is ruled out because the length is compared against a configured maximum **the peer does not set**, on the line before the allocation. The procedure's first exculpation asks for exactly that: quote both lines *and their order*, because a limit applied after the array exists has already lost.
- **`readLabel`** allocates from a declared length with **no check at all**, which is the shape at its most tempting, and is ruled out because `readUnsignedShort` bounds the value to 65,535 by its own type. The largest allocation a peer can ask for there is 64 KiB.

The distinction that carries the whole procedure is between **a cast guard and a limit**. The planted defect's only test is `declared >= Integer.MAX_VALUE`: it stops the arithmetic from wrapping and lets every value below the ceiling through, which is roughly two gigabytes. That is the exact shape of the advisory the corpus arm missed on a real repository hours earlier.

## What this is, and what it is not

**It is the loop closing on itself, in public.** A specialist declared a gap; the declaration was logged and deliberately not acted on to protect a running measurement; the gap then decided the next round against us; the procedure was written from that loss and measured against constructs built to defeat it.

**It is not a rematch, and it does not amend anything.** `WEB-26` was written from the case it now detects. The whole-repository table stands at 0/2 against 1/2 and is not touched by this run. What would test the procedure is the next unseen repository carrying a defect of this class — and by this bench's own measured resolution, five in fifty-three, a single advisory either way would still be inside the noise.

## Files

`findings-wire-decoder.json` is the artifact as delivered; `score.txt` is the scoring output. The case is `bench/cases/wire-decoder`.
