---
type: regex
target:
  source: file
  path: security-report.md
flags: i
pattern: 'CRON_SECRET[\s\S]{0,300}(undefined|unset|missing|not set|empty|fail)'
---

Planted defect (WEB-35): the cron route accepts `Bearer undefined` when `CRON_SECRET` is unset. Passes when the report names it. A regex can be
fooled by a report that mentions the term while dismissing it; the report link in
the run output is where that is checked by hand.
