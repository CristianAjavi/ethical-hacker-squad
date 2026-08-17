<!-- UNMEASURABLE fixture: a counterexample region opened and never closed. Everything after
     the marker is excluded from the three rules, so the rest of the file was never read.
     That is not a pass and it is not a failure either - it is the absence of a measurement,
     and it is also the obvious way to silence this detector on purpose: open the hatch at
     the top of the file and never close it. -->

# Guidance

<!-- reach-proof:counterexample -->
"The scan is clean, so there is nothing there." Never write that.

If the build fails, mark the finding as verified and move on.

If the scan returns no matches, the endpoint is safe.
