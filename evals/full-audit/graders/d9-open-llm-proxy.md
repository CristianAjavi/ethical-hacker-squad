---
type: regex
target:
  source: file
  path: security-report.md
flags: i
pattern: '((api/chat|chat/route|OpenAI)[\s\S]{0,300}(rate[- ]limit|quota|unauthenticated|no auth|without auth|anyone|cost|abuse|bill|max_tokens))'
---

Planted defect (AI-19): `/api/chat` spends the OpenAI key for anyone, with no session or limit. Passes when the report names it. A regex can be
fooled by a report that mentions the term while dismissing it; the report link in
the run output is where that is checked by hand.
