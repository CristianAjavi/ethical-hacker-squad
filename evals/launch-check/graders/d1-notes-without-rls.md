---
type: regex
target:
  source: file
  path: security-report.md
flags: i
pattern: '(\bnotes\b[\s\S]{0,200}\b(no|not|without|missing|disabled|never|lacks?|off|absent)\b[\s\S]{0,40}(RLS|row[- ]level security))|(\b(no|not|without|missing|disabled|never|lacks?|off|absent)\b[\s\S]{0,40}(RLS|row[- ]level security)[\s\S]{0,200}\bnotes\b)|((RLS|row[- ]level security)[\s\S]{0,40}\b(no|not|without|missing|disabled|never|lacks?|off|absent)\b[\s\S]{0,200}\bnotes\b)|(\bnotes\b[\s\S]{0,200}(RLS|row[- ]level security)[\s\S]{0,40}\b(no|not|without|missing|disabled|never|lacks?|off|absent)\b)'
---

Planted defect (WEB-29): the `notes` table never enables row-level security. Passes when the report names it. A regex can be
fooled by a report that mentions the term while dismissing it; the report link in
the run output is where that is checked by hand.
