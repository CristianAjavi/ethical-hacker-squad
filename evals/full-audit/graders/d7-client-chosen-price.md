---
type: regex
target:
  source: file
  path: security-report.md
flags: i
pattern: '((unit_amount|price|amount)[\s\S]{0,250}(client|request body|req\.json|from the body|tamper|manipulat|attacker|user[- ]controlled|choose|any amount))|((client|attacker|user)[\s\S]{0,120}(sets?|chooses?|controls?) (the )?(price|amount))'
---

Planted defect (WEB-36): the checkout price comes from the request body. Passes when the report names it. A regex can be
fooled by a report that mentions the term while dismissing it; the report link in
the run output is where that is checked by hand.
