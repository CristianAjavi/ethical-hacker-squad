# Knowledge pack — Web and API AppSec (backend-as-a-service)

> **When to load this file:** the inventory has a backend-as-a-service the browser or the mobile client reaches directly: a Supabase client (`@supabase/supabase-js`, `supabase/migrations/`, `supabase/config.toml`) or a Firebase client SDK with `firebase.json`, `firestore.rules`, `storage.rules` or `database.rules.json`.
> **Do not load it if:** every query goes through a server you can read and the client never holds a key that reaches the data store. Then the authorization lives in that server, and `web-api.md` §2 is the place.
> **Cost:** ~84 lines. Fourth file of the `web-api` pack. The entry point, `web-api.md`, holds §0-§5; `web-api-clientside-logic.md` holds §6-§10; `web-api-logging.md` holds §11. A secret that reached the browser through a public build prefix is `SUP-27`, in the `supply-chain` pack.

## Selective loading index

| Section | Load it if the inventory has | Procedures |
|---|---|---|
| §12 The database answers the browser | a Supabase or Firebase client, its migrations, its rules files | WEB-29, WEB-30 |

## How to use a procedure

The six fields are the same contract as in `web-api.md`. One difference changes how you read this file: **there may be no server code at all.** The browser holds the project URL and a key that is public by design, and talks to Postgres through the Data API or to Firestore directly. The authorization layer is SQL policies or a rules file, and it is the code you audit. A filter in the frontend (`.eq('user_id', user.id)`, `where('owner', '==', uid)`) is a request parameter the caller chooses, never a control.

## §12 The database answers the browser

### WEB-29 Row-level security is the only authorization in front of Postgres (Supabase)

**Where to look**
- `supabase/migrations/*.sql`, `supabase/seed.sql`, any schema dump, and ORM migrations (Prisma, Drizzle) that target a Supabase database: every `create table` in an exposed schema (`public` by default; `[api] schemas` in `supabase/config.toml`) and whether `alter table … enable row level security` follows it. Tables created from the dashboard get RLS by default; tables created from SQL or another tool do not.
- `create policy` bodies: `using (true)`, `with check (true)`, `auth.uid() is not null`, and policies that read `user_metadata` / `raw_user_meta_data`, which the signed-in user can edit.
- `create view` without `with (security_invoker = true)`, and `security definer` functions in an exposed schema, reachable as `/rest/v1/rpc/<name>`.
- `grant … to anon` / `to authenticated` on tables, and Storage: buckets declared public, policies on `storage.objects`.
- Client code calling `createClient(url, key)`: which key it carries, and whether the code relies on its own filters for isolation.

**Vulnerable pattern** — the table is reachable with the publishable key and nothing in the database ties a row to the caller. Authentication exists; ownership is decided by the frontend.

```sql
create table public.invoices (id bigint primary key, user_id uuid, amount numeric);
-- no "alter table public.invoices enable row level security;"
create policy "read" on public.notes for select to authenticated using (auth.uid() is not null);
-- every signed-in user reads every note
```

**What rules it out (false positive)**
- RLS is enabled and each command the role is granted (`select`, `insert`, `update`, `delete`) has a policy that binds the row to the caller, typically `auth.uid() = user_id`, with `with check` on writes. RLS enabled with no policy denies everything: that is closed, not a finding.
- The role holds no grant on the table, so the request fails with `42501` before RLS is consulted. Supabase stopped granting `anon` and `authenticated` on new `public` tables by default (new projects from 2026-05-30, existing projects from 2026-10-30); tables that existed before keep their grants. Read the grants; do not infer them from the date.
- The schema is not exposed through the Data API, or the data is public by design and writes are closed.
- A view sets `security_invoker = true` (Postgres 15+); a `security definer` function's owner lacks `bypassrls` or the table forces RLS — on Supabase the default owner, `postgres`, has it.

Rules: FP-01, FP-05, FP-07, FP-08.

**Minimal test** — local: `supabase start` (API on `http://127.0.0.1:54321`), apply the migrations, create two synthetic users, then with the local publishable key and user A's token request user B's rows: `curl -s "http://127.0.0.1:54321/rest/v1/invoices?select=*" -H "apikey: $LOCAL_KEY" -H "Authorization: Bearer $USER_A_JWT"`. It must return nothing of B's, on read **and** on write; repeat with no user token. Against the hosted project: **REQUIRES AUTHORIZATION** — it reads real users' rows.

**Traceability**: `CWE-862` · `CWE-639` · `CWE-284` · `WSTG-ATHZ-*` · `ASVS 5.0 V8` · `A01:2025` · `API1:2023`
**Tooling**: `supabase db advisors --local --type security --fail-on warn` runs the security lints against the local stack; the ones that matter here are `0013_rls_disabled_in_public`, `0007_policy_exists_rls_disabled`, `0010_security_definer_view`, `0015_rls_references_user_metadata`, `0024_rls_policy_always_true` and `0028_anon_security_definer_function_executable`. With `--local` it bundles a subset and lacks `0025` onward; `--linked` asks the hosted project and **REQUIRES AUTHORIZATION**. `supabase db lint` is a different tool (`plpgsql_check`) and says nothing about RLS. A clean advisor run proves only that the lints passed: a policy of `auth.uid() is not null` passes every one of them and still lets each user read every row.

### WEB-30 Security Rules are the only authorization in front of Firestore, Realtime Database and Storage (Firebase)

**Where to look**
- `firebase.json`: the `firestore`, `database` and `storage` keys and the `rules` file each one points at — conventionally `firestore.rules`, `database.rules.json`, `storage.rules`.
- In those files: `allow read, write: if true`, `if request.time < timestamp.date(…)`, `if request.auth != null`, a `match /{document=**}` that grants anything, and in Realtime Database `".read": true` / `".write": true`.
- Rules that authorize from data the caller writes: a role or owner field the same user can set in `request.resource.data`, or in a profile document their own rules let them update.
- Client code calling `initializeApp(config)`, `getFirestore`, `collection(`, `ref(`: what it reads and writes directly.

**Vulnerable pattern** — the starter rules never replaced, or replaced by "signed in" instead of "owner":

```
match /databases/{database}/documents {
  match /{document=**} {
    allow read, write: if request.time < timestamp.date(2026, 11, 11);  // anyone, until the date
  }
  match /orders/{orderId} {
    allow read: if request.auth != null;  // any account, anonymous sign-in included
  }
}
```

`firebase init` writes the first form with a date thirty days out. The second is the usual "fix", and it opens the data to every account the project accepts.

**What rules it out (false positive)**
- Each `match` binds access to the owner — `request.auth.uid == userId`, `resource.data.owner == request.auth.uid` — with reads and writes stated separately, and writes validate `request.resource.data`.
- The collection is public by design and writes are closed. The Storage starter template denies everything (`if false`).
- Rules are not filters: a query the rules would reject fails as a whole. A client query that filters by owner proves nothing about the rule, and a scoped rule does not leak through an unfiltered query.
- The rules in the repository are not what is deployed, and the deployed version arrived as evidence. Without that evidence the answer is `UNKNOWN`. App Check limits which app calls; it does not decide whose document a caller reads.

Rules: FP-01, FP-05, FP-07, FP-08.

**Minimal test** — local: `firebase emulators:exec --only firestore "npm test"`, with `@firebase/rules-unit-testing` loading the rules file. `authenticatedContext('alice')` reading Bob's document must `assertFails`; `unauthenticatedContext()` must `assertFails` on every private path; the owner must `assertSucceeds`, or the test proves nothing. Against the deployed project: **REQUIRES AUTHORIZATION**.

**Traceability**: `CWE-862` · `CWE-639` · `CWE-284` · `WSTG-ATHZ-*` · `ASVS 5.0 V8` · `A01:2025` · `API1:2023`
**Tooling**: `rg -n "if (true|request\.auth != null|request\.time <)" firestore.rules storage.rules` and `rg -n '"\.(read|write)": *true' database.rules.json` locate candidates; each still needs the owner check above. A secret scanner's match on the web `apiKey` (`AIza…`) is not a finding by itself: Firebase documents that key as safe to ship, and access is decided by the rules. What turns the key into a finding is its API restrictions — another Google API enabled on the same key, a Gemini key above all, is a real exposure.
