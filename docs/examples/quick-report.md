# Example: what a quick audit hands back

> **This is an illustration of the format, written by hand.** It is not the output of a run, and no model produced it. It describes the synthetic app in [`evals/_fixtures/vibe-app`](../../evals/_fixtures/vibe-app) — nine planted defects — so a reader can see what the deliverable of a `quick` audit looks like before spending anything on one. A real report is written in the user's language; this one is in English to match the repository.

---

## Executive summary

Scope: the repository `notes-saas` (Next.js 15 App Router, Supabase, Stripe Checkout, OpenAI), read locally, nothing executed. Mode: **quick** — the leader alone, the checklist of `coverage.md` § Quick audit for this stack, capped at twelve procedures. Result: the app is **not ready to launch**: anyone on the internet can read every note, make themselves an administrator or a Pro customer for free, and spend your OpenAI and Supabase budget.

### Fix these first

1. **Anyone can read and change every user's notes.**
   - Where: `supabase/migrations/0001_init.sql` — the `notes` table never turns on row-level security, and `lib/supabase/admin.ts` uses the service-role key, which skips it anyway.
   - Change: `alter table public.notes enable row level security;` plus a policy `using ((select auth.uid()) = user_id)` for select, insert, update and delete; and stop using `supabaseAdmin` in code the browser loads (item 2).
   - Check: with two test accounts, account A must not see account B's notes.
2. **Your Supabase master key is in every visitor's browser.**
   - Where: `.env.local` names it `NEXT_PUBLIC_SUPABASE_SERVICE_ROLE_KEY`, and `app/dashboard/NotesClient.tsx` (a client component) imports the client built with it.
   - Change: rename it without `NEXT_PUBLIC_`, use it only in server code, and **rotate the key in the Supabase dashboard** — it has already been shipped.
   - Check: build the app and search `.next/static` for the key's first characters: no match.
3. **Any signed-in user can make themselves an admin or a Pro customer.**
   - Where: the `update own profile` policy in `supabase/migrations/0001_init.sql` lets a user write every column of their own row, `role` and `plan` included.
   - Change: `revoke update on table public.profiles from authenticated; grant update (display_name) on table public.profiles to authenticated;`
   - Check: as a test user, `PATCH /rest/v1/profiles?id=eq.<you>` with `{"role":"admin"}` must fail.
4. **Anyone can mark themselves as paid.**
   - Where: `app/api/stripe/webhook/route.ts` accepts any JSON as a Stripe event, and `app/api/checkout/route.ts` charges the `amount` the browser sends.
   - Change: verify the webhook with `stripe.webhooks.constructEvent(await req.text(), signature, STRIPE_WEBHOOK_SECRET)`; build the Checkout Session from a `price_…` id chosen on the server.
   - Check: posting the same JSON without a signature returns 400 and grants nothing.
5. **Anyone can call your admin API, your nightly job and your AI assistant.**
   - Where: `middleware.ts` skips `/api`, so `app/api/admin/users/route.ts`, `app/api/cron/charge-trials/route.ts` and `app/api/chat/route.ts` check nobody; the `deleteNote` Server Action in `app/actions.ts` checks nobody either.
   - Change: read the session inside each route and action and check the owner; compare `CRON_SECRET` only after checking it is set; give `/api/chat` a session check and a per-user limit.
   - Check: each route called with no session returns 401.

## Checklist run

| # | Procedure | Result |
|---|---|---|
| 1 | `SUP-16`, `SUP-17` secrets in the tree and history | checked — nothing found at this depth |
| 2 | `SUP-27` server secret behind a public prefix | checked — item 2 |
| 3 | `WEB-29` row-level security | checked — item 1 |
| 5 | `WEB-31` privilege columns | checked — item 3 |
| 6 | `WEB-33` Server Actions and routes | checked — item 5 |
| 7 | `WEB-34` authorization only in the proxy | checked — item 5; `next` 15.1.7 is inside CVE-2025-29927's range, which did not affect apps hosted on Vercel, where this one runs |
| 8 | `WEB-04` user A reads user B's object | checked — `app/api/notes/[id]/route.ts` checks the session and the owner: correct |
| 10 | `WEB-36` payments | checked — item 4 |
| 12 | `WEB-35` cron routes | checked — item 5 |
| 13 | `AI-19` the LLM key | checked — item 5 |
| 4, 9, 11, 14 | `WEB-30`, `WEB-05`, `WEB-32`, `AI-05` | not applicable to this stack |

Nothing above was demonstrated against a running app: every item is `confirmed` from the code or `probable` with what would settle it, as `findings.json` records. A full audit — specialists, an independent verifier, the runtime pass if you allow it — is the next step, and `scripts/ehs cost` will tell you what this one spent before you decide.
