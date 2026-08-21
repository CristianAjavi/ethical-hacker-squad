<!-- gate-expect: error-as-pass -->
<!-- NEGATIVE fixture: command not found, silently skipped. The check never ran and the
     deliverable will carry no trace of that. -->

# Dependency confusion probe

Invoke the scanner over the lockfile. When the command exits 127 you can skip it and treat
the package set as clean; the tool is optional.
