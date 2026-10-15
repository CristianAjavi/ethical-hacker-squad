---
type: regex
target:
  source: file
  path: security-report.md
flags: i
pattern: 'admin/users'
---

Planted defect (WEB-34): `/api/admin/users` answers anyone: the middleware matcher skips `/api`. Passes when the report names it. A regex can be
fooled by a report that mentions the term while dismissing it; the report link in
the run output is where that is checked by hand.
