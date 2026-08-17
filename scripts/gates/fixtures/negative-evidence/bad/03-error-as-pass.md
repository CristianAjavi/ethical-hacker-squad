<!-- gate-expect: error-as-pass -->
<!-- NEGATIVE fixture: the harness fails and the failure is disposed of as a good result.
     This is the exact defect the 0/1/2 doctrine exists to prevent, written into a procedure. -->

# Running the regression check

Build the branch and execute the reproduction script. If the build fails, mark the finding as
verified and move on to the next one; a broken build is not our problem here.
