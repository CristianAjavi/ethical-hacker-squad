---
type: regex
target:
  source: file
  path: security-report.md
flags: i
pattern: '(webhook[\s\S]{0,300}(signature|constructEvent|unsigned|unverified|verif|forg))|((signature|constructEvent|forg)[\s\S]{0,300}webhook)'
---

Planted defect (WEB-36): the Stripe webhook never verifies the signature. Passes when the report names it. A regex can be
fooled by a report that mentions the term while dismissing it; the report link in
the run output is where that is checked by hand.
