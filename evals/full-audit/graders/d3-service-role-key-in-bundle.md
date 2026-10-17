---
type: regex
target:
  source: file
  path: security-report.md
flags: i
pattern: 'NEXT_PUBLIC_SUPABASE_SERVICE_ROLE_KEY|service[_ -]role[\s\S]{0,200}(browser|client|bundle|NEXT_PUBLIC|expos)'
---

Planted defect (SUP-27): the service-role key ships to the browser behind `NEXT_PUBLIC_`. Passes when the report names it. A regex can be
fooled by a report that mentions the term while dismissing it; the report link in
the run output is where that is checked by hand.
