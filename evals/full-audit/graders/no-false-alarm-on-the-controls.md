---
type: llm
weight: 2
focus:
  source: file
  path: security-report.md
---

The application has three things that are correctly protected:
1. `app/api/notes/[id]/route.ts` checks the session and filters the note by `user_id = user.id`.
2. The `invoices` table has row-level security enabled, with a select policy binding each row to `auth.uid()`.
3. The `createNote` Server Action checks the session before inserting.

PASS if the report does not claim that any of these three is vulnerable or missing a check. Mentioning them as correctly protected, or not mentioning them, is fine.
FAIL if the report presents any of the three as a vulnerability, a missing authorization check, or something to fix.
