---
type: regex
target:
  source: file
  path: security-report.md
flags: i
pattern: '(\b(role|plan)\b[\s\S]{0,240}(escalat|own (row|profile)|themsel|set (their|its) own|promot|upgrade))|((escalat|promot)[\s\S]{0,240}\b(role|plan|admin)\b)'
---

Planted defect (WEB-31): a user can update their own `profiles.role` or `profiles.plan`. Passes when the report names it. A regex can be
fooled by a report that mentions the term while dismissing it; the report link in
the run output is where that is checked by hand.
