# Knowledge pack — Web and API AppSec (backend-as-a-service)

> **When to load this file:** the inventory has a backend-as-a-service the browser or the mobile client reaches directly: a Supabase client (`@supabase/supabase-js`, `supabase/migrations/`, `supabase/config.toml`, `supabase/functions/`) or a Firebase client SDK with `firebase.json`, `firestore.rules`, `storage.rules` or `database.rules.json`.
> **Do not load it if:** every query goes through a server you can read and the client never holds a key that reaches the data store. Then the authorization lives in that server, and `web-api.md` §2 is the place.
> **Cost:** ~148 lines. Fourth file of the `web-api` pack. The entry point, `web-api.md`, holds §0-§5; `web-api-clientside-logic.md` holds §6-§10; `web-api-logging.md` holds §11; `web-api-fullstack.md` holds §13-§14 (Server Actions, the proxy, scheduled jobs, payments). A secret that reached the browser through a public build prefix is `SUP-27`, in the `supply-chain` pack.

## Selective loading index

| Section | Load it if the inventory has | Procedures |
|---|---|---|
| §12 The database answers the browser | a Supabase or Firebase client, its migrations, its rules files, Supabase Edge Functions | WEB-29, WEB-30, WEB-31, WEB-32 |

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
- Anonymous sign-ins: `enable_anonymous_sign_ins = true` under `[auth]` in `supabase/config.toml`, or `signInAnonymously()` in the client. Anonymous users get the `authenticated` role, so every `to authenticated` policy admits them; one meant for real accounts adds `(select (auth.jwt()->>'is_anonymous')::boolean) is false`, as a restrictive policy beside a permissive one (a restrictive policy alone admits nothing).
- Realtime: `postgres_changes` follows the table's RLS, except that RLS is not applied to `DELETE` events. Broadcast and Presence obey policies on `realtime.messages` only for channels opened with `private: true` **and** with the project's "Allow public access" setting off; it is on by default, and then anyone holding the publishable key subscribes and broadcasts on every public channel.

**Vulnerable pattern** — the table is reachable with the publishable key and nothing in the database ties a row to the caller. Authentication exists; ownership is decided by the frontend.

```sql
-- 1. RLS never enabled: with the grants the table still has, the publishable key reads and writes every row
create table public.notes (id bigint primary key, user_id uuid, body text);

-- 2. RLS enabled, but the policy asks whether a caller exists, not whether the row is theirs
alter table public.invoices enable row level security;
create policy "read own" on public.invoices for select to authenticated
  using (auth.uid() is not null);   -- every signed-in user, anonymous ones included, reads every invoice
```

**What rules it out (false positive)**
- RLS is enabled and each command the role is granted (`select`, `insert`, `update`, `delete`) has a policy that binds the row to the caller, typically `auth.uid() = user_id`, with `with check` on writes. RLS enabled with no policy denies everything: that is closed, not a finding.
- The role holds no grant on the table, so the request fails with `42501` before RLS is consulted. Supabase stopped granting `anon` and `authenticated` on new `public` tables by default (new projects from 2026-05-30, existing projects from 2026-10-30); tables that existed before keep their grants. Read the grants; do not infer them from the date.
- The schema is not exposed through the Data API, or the data is public by design and writes are closed.
- A view sets `security_invoker = true` (Postgres 15+); a `security definer` function's owner lacks `bypassrls` or the table forces RLS — on Supabase the default owner, `postgres`, has it.
- Anonymous sign-ins are off (the default), or every policy that matters carries the `is_anonymous` check. A Realtime channel is private and public access is disabled, with the setting as evidence (`FP-08`).

Rules: FP-01, FP-05, FP-07, FP-08.

**Minimal test** — local: `supabase start` (API on `http://127.0.0.1:54321`) needs Docker and pulls images over the network, so it is the runtime pass of `team.md`: name what will run and wait for the user's go-ahead; without it, the evidence is the migrations and the policies. Apply the migrations, create two synthetic users, then with the local publishable key and user A's token request user B's rows: `curl -s "http://127.0.0.1:54321/rest/v1/invoices?select=*" -H "apikey: $LOCAL_KEY" -H "Authorization: Bearer $USER_A_JWT"`. It must return nothing of B's, on read **and** on write; repeat with no user token. Against the hosted project: **REQUIRES AUTHORIZATION** — it reads real users' rows.

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

### WEB-31 A user can write the column that decides their own privileges (Supabase)

**Where to look**
- `for update` and `for all` policies on tables that hold a privilege: `profiles`, `users`, `accounts`, `members` with a `role`, `is_admin`, `plan`, `tier`, `credits`, `verified` or `org_id` column.
- The grants on those tables: `grant update on table … to authenticated` (Supabase's default on `public` tables until the change dated in `WEB-29`; older tables keep it), and `information_schema.column_privileges` for column-level grants.
- Authorization that reads `raw_user_meta_data` / `user_metadata` — the user writes it with `supabase.auth.updateUser()`; `raw_app_meta_data` they cannot. Advisor lint `0015_rls_references_user_metadata` flags policies that read it.
- Client code calling `.from('profiles').update(…)` or `.upsert(…)` with an object built from a form.

**Vulnerable pattern** — the row is the user's own, so the policy lets them update it, and nothing restricts **which columns** they update. `with check` cannot fix this: Postgres evaluates it against the proposed new row, not the original, so it cannot say "this column is unchanged".

```sql
create policy "update own profile" on public.profiles for update to authenticated
  using ((select auth.uid()) = id) with check ((select auth.uid()) = id);
-- PATCH /rest/v1/profiles?id=eq.<me>  {"role": "admin", "plan": "pro"}  succeeds
```

**What rules it out (false positive)**
- Privilege columns live in a table `authenticated` cannot write — Supabase's own RBAC guide puts roles in a `user_roles` table with every privilege revoked and surfaces them through a custom access token hook.
- Table-level `update` is revoked and granted back only on harmless columns (`revoke update on table public.profiles from authenticated; grant update (display_name, avatar_url) …`). Revoking the column alone does nothing while the table-level grant exists.
- A `before update` trigger raises when a privilege column changes for a non-service caller.
- The column holds nothing an authorization decision reads.

Rules: FP-01, FP-07.

**Minimal test** — local stack (runtime pass, user's go-ahead): as a synthetic user, `PATCH` your own row with `{"role":"admin"}` through `/rest/v1/profiles` with the publishable key and your token; it must fail or leave the column unchanged. Read `information_schema.column_privileges` to explain why.

**Traceability**: `CWE-269` · `CWE-915` · `WSTG-ATHZ-03` · `ASVS 5.0 V8` · `A01:2025` · `API3:2023`
**Tooling**: no advisor lint covers a column the owner may write. `rg -n "for (update|all)" supabase/migrations` lists the policies; for each table, compare its writable columns against what any policy, function or app check reads as a privilege.

### WEB-32 An Edge Function that takes the platform's check for its own (Supabase)

**Where to look**
- `supabase/functions/*/index.ts`, and `[functions.<name>] verify_jwt = false` in `supabase/config.toml` or `--no-verify-jwt` in deploy scripts and CI.
- `withSupabase` from `@supabase/server`: the `auth` mode (`'user'`, `'secret'`, `'publishable'`, `'none'`) and any use of `ctx.supabaseAdmin`, which bypasses RLS.
- A client built with `SUPABASE_SERVICE_ROLE_KEY` or `SUPABASE_SECRET_KEYS` inside the function, and whether the function reads the caller (`supabase.auth.getUser()`, `getClaims()`, a JWKS check) before querying with it.

**Vulnerable pattern** — the function runs with a key that bypasses RLS on behalf of whoever called it. `verify_jwt` defaults to `true`, but Supabase documents that the check alone does not authenticate a caller who sends only an API key — the publishable key passes it — and its signing-keys guide tells projects that rotate keys to turn the check off and verify in code instead. Supabase also warns that `auth: 'none'` disables every credential check, and that turning verification off to clear a 401 during development removes the platform's check.

```ts
Deno.serve(async (req) => {
  const { userId } = await req.json();
  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  return Response.json(await admin.from("invoices").select("*").eq("user_id", userId));  // any caller, any user
});
```

**What rules it out (false positive)**
- The function derives the user from a verified token (`getClaims()`, `getUser()`, JWKS) and scopes every admin query to that user, or queries with a client that carries the user's token — a secret key bypasses RLS only when the request carries no user token.
- It is a webhook verified by signature (`WEB-36` for payments) or a scheduled job checking a secret that fails closed (`WEB-35`).
- What it returns is public by design.

Rules: FP-01, FP-05.

**Minimal test** — local: `supabase functions serve` (runtime pass, user's go-ahead), then call the function with only the publishable key, and as user A for user B's data; both must be refused. A deployed function: **REQUIRES AUTHORIZATION**.

**Traceability**: `CWE-306` · `CWE-862` · `CWE-639` · `WSTG-ATHZ-02` · `ASVS 5.0 V8` · `A01:2025` · `API1:2023`
**Tooling**: `rg -n "verify_jwt *= *false|--no-verify-jwt|SERVICE_ROLE|SECRET_KEYS|supabaseAdmin|auth: *'none'" supabase/` locates the candidates; each still needs the caller-and-owner reading by hand.
