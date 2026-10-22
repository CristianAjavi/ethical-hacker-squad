---
type: regex
target:
  source: file
  path: security-report.md
flags: i
pattern: 'deleteNote'
---

Planted defect (WEB-33): the `deleteNote` Server Action checks neither the session nor the owner. Passes when the report names it. A regex can be
fooled by a report that mentions the term while dismissing it; the report link in
the run output is where that is checked by hand.
