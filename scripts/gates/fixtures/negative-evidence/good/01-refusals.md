<!-- POSITIVE fixture: every one of these lines is CORRECT text, and every one of them is
     built out of exactly the words the detector hunts for. They are lifted, in substance,
     from README.md, SKILL.md, tooling.md, report.md, remediation.md and web-api.md, which
     is why the detector needs the refusal cues: this repository argues against the
     inference on nearly every page. If it fires here, it fires on the corpus. -->

# What a clean run means

A clean scan is not evidence of absence, because measured per-tool recall on real
vulnerabilities runs well under half.

"The tests pass" is not the same as "the vulnerability does not reproduce". State which one
you actually established.

Empty output = no matches against its rules; nothing more.

Report a clean scan as a fact about the tool, never as evidence that a class of bug is absent.

Treating the fix as verified because the test suite is green is a mistake: the suite checks
what somebody thought of checking.

A clean scan is not evidence of a benign artifact, and a hit does not prove compromise.

We cannot say the endpoint is safe just because the scan returned no matches.

The tests pass and the vulnerability still reproduces, which is the interesting case.
