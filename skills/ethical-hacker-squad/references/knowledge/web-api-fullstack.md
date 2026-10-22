# Knowledge pack — Web and API AppSec (full-stack frameworks, payments, scheduled jobs)

> **When to load this file:** the server code lives in the same repository as the pages, inside a full-stack framework — Next.js (`app/**/route.ts`, `pages/api/`, files with `"use server"`, `middleware.ts` or `proxy.ts`), Remix, SvelteKit, Nuxt — or the app takes payments (Stripe webhooks, Checkout), runs scheduled jobs (`crons` in `vercel.json`), or delegates sign-in to Clerk or Auth.js. This is the usual shape of an app generated with an AI coding tool.
> **Do not load it if:** the backend is a separate codebase you can read on its own; then `web-api.md` §2 is the place.
> **Cost:** ~137 lines. Fifth file of the `web-api` pack. `web-api.md` holds §0-§5; `web-api-clientside-logic.md` §6-§10; `web-api-logging.md` §11; `web-api-baas.md` §12. An LLM endpoint that anyone can call on your key is `AI-19`, in the `ai-safety` pack.

## Selective loading index

| Section | Load it if the inventory has | Procedures |
|---|---|---|
| §13 The server boundary of a full-stack app | Server Actions or Server Functions, Route Handlers, `middleware.ts` / `proxy.ts`, Clerk or Auth.js, `crons` in `vercel.json` | WEB-33, WEB-34, WEB-35 |
| §14 Payments | a Stripe SDK, a webhook route, a Checkout Session or PaymentIntent created by the app | WEB-36 |

## How to use a procedure

Same six fields as `web-api.md`. One thing changes how you read this code: **the framework decides what is an endpoint, not the file you are reading.** A function exported from a `"use server"` file is a public `POST` endpoint whether or not any page imports it, and a route the proxy matcher skips is still served. Read the boundary from the framework's rules and the build, never from which links the UI renders.

## §13 The server boundary of a full-stack app

### WEB-33 A Server Action or Route Handler that trusts the page in front of it

**Where to look**
- Files and functions marked `"use server"`, and every function they export; `app/**/route.ts` / `route.js` (`GET`, `POST`, `PUT`, `PATCH`, `DELETE`); `pages/api/**`.
- In each one, the first lines: is there a session read (`auth()`, `getServerSession`, `currentUser()`, `supabase.auth.getUser()`, `getClaims()`), and is the object it touches checked against that session — `where: { id, userId: session.user.id }`, not `where: { id }`?
- Arguments: everything a Server Action receives comes from the client, including ids, amounts, roles and `formData` fields the form never rendered.
- Return values: whatever an action returns is serialized to the browser, including fields the page never displays.

**Vulnerable pattern** — the page checks the session and the action it calls does not. Next.js documents both halves: an exported Server Action "is reachable via a direct POST request, not just through your application's UI", and a page-level check "does not extend to the Server Actions defined within it" (Data Security guide, revised 2026-10-06).

```ts
"use server";
export async function deleteProject(id: string) {
  await db.project.delete({ where: { id } });   // no session, no owner: any caller deletes any project
}
```

**What rules it out (false positive)**
- The function reads the session itself and scopes the object to it, or calls a data-access layer that does and fails closed.
- The action is not exported from a `"use server"` module and is not passed to a client component — then the framework never registers it. Dead-code elimination also drops unused actions; decide it from the build, not the source.
- What it does is public by design (a newsletter sign-up) and rate-limited.
- Encrypted action ids and closed-over variables are not this rule: Next.js says not to rely on encryption alone, and they do not authenticate the caller.

Rules: FP-01, FP-04, FP-05.

**Minimal test** — local and only after the user agrees to run the app (`team.md`, runtime pass): sign in as synthetic user A, then call user B's action or route directly — `fetch` from a script or `curl` with A's cookie, the action id taken from the built page — and confirm it fails, on read **and** on write. With no running app, the evidence is the code path from the export to the query with no session read on it.

**Traceability**: `CWE-862` · `CWE-285` · `CWE-639` · `WSTG-ATHZ-02` · `ASVS 5.0 V8` · `A01:2025` · `API1:2023` · `API5:2023`
**Tooling**: `rg -n '"use server"' -g '!node_modules'` and `rg --files -g '**/route.{ts,js}' -g '**/pages/api/**'` enumerate the endpoints; each one still needs the session-and-owner reading by hand. Clerk ships an ESLint rule, `@clerk/next/require-auth-protection` (App Router only), that flags pages, Route Handlers and Server Functions without `auth.protect()`.

### WEB-34 Authorization that lives only in middleware or the proxy

**Where to look**
- `middleware.ts` or, from Next.js 16.0.0 on, `proxy.ts` (16.0.0 deprecated the middleware file and renamed it): what it checks, and its `config.matcher`. The matchers in Next.js and Auth.js documentation exclude `api` (`'/((?!api|_next/static|_next/image|favicon.ico).*)'`), so copied verbatim they leave every API route unchecked.
- Clerk: `clerkMiddleware()` with `createRouteMatcher()` — deprecated in `@clerk/nextjs` 7.5.14 (2026-07-07) in favour of `auth.protect()` inside each page, Route Handler and Server Function. Clerk's own reference now says middleware is not the best place to protect routes.
- Auth.js: `export { auth as middleware }` with no `auth()` inside the API handlers; `AUTH_SECRET` (the one strictly required variable); `trustHost` / `AUTH_TRUST_HOST` behind a proxy that does not set `Host` safely; a `session` callback returning tokens or roles — its return value is sent to the client.
- The Next.js version in the lockfile, and how it is deployed (`next start`, `output: 'standalone'`, a container, or Vercel).

**Vulnerable pattern** — the only check sits in a layer the request can miss: a matcher that skips the path, a Server Function invoked by id rather than by route, or a self-hosted Next.js still affected by CVE-2025-29927, where a request carrying `x-middleware-subrequest` skipped middleware entirely.

```ts
export const config = { matcher: ["/((?!api|_next/static|_next/image).*)"] };
// /dashboard redirects anonymous users; /api/admin/users answers them
```

CVE-2025-29927 (CVSS 9.1, published 2025-03-21) is fixed in 12.3.5, 13.5.9, 14.2.25 and 15.2.3. Deployments hosted on Vercel were not affected; self-hosted `next start` and `standalone` builds were.

**What rules it out (false positive)**
- Every protected resource checks the session itself (`WEB-33` passes); the proxy only redirects for convenience. Both Next.js ("should not be your only line of defense") and Clerk recommend exactly that.
- The matcher covers the route and the version is patched — for the CVE, a fixed release, a Vercel deployment, or a front proxy that strips `x-middleware-subrequest` from outside requests, with that configuration as evidence.

Rules: FP-01, FP-08.

**Minimal test** — read the matcher against the route list; with Next.js 15.1 or later, `unstable_doesProxyMatch` from `next/experimental/testing/server` answers it in a unit test. Against the local app (runtime pass, with the user's go-ahead): request a protected API route with no session, and, on an affected version, a protected page with `x-middleware-subrequest` set. Never against a deployment without authorization.

**Traceability**: `CWE-288` · `CWE-862` · `WSTG-ATHN-04` · `WSTG-ATHZ-02` · `ASVS 5.0 V8` · `A01:2025` · `A07:2025` · `API5:2023`
**Tooling**: the lockfile answers the CVE (`npm ls next`, or `next` in `package-lock.json` / `pnpm-lock.yaml`); `npm audit` reports it with the advisory id. Nothing reads a matcher for you: list the routes, list what the matcher excludes, and intersect them by hand.

### WEB-35 A scheduled or internal endpoint anyone on the internet can trigger

**Where to look**
- `crons` in `vercel.json` and the routes they call; `CRON_SECRET` and how the handler compares it.
- Routes named `cron`, `jobs`, `tasks`, `internal`, `admin`, `revalidate`, `seed`, `migrate`, `backfill`, `sync`; webhooks from services other than payments (`WEB-36`).
- Checks built on headers anyone can send: `user-agent` containing `vercel-cron`, `x-vercel-cron-schedule`, an `x-internal` flag, a `?key=` compared against a hard-coded string.

**Vulnerable pattern** — the job runs for whoever calls it. Vercel sends `Authorization: Bearer <CRON_SECRET>` and documents a check that fails closed: `if (!cronSecret || authHeader !== \`Bearer ${cronSecret}\`)`. Without the first clause, an unset variable makes the expected value `Bearer undefined`, which any caller can send.

```ts
export async function GET(req: Request) {
  if (req.headers.get("authorization") !== `Bearer ${process.env.CRON_SECRET}`) return new Response(null, { status: 401 });
  await chargeAllSubscriptions();   // CRON_SECRET unset in preview: "Bearer undefined" runs billing
}
```

**What rules it out (false positive)**
- The handler fails closed on a missing secret and compares a value of at least 16 random characters. A constant-time comparison is better still.
- The work is harmless and idempotent when triggered twice — Vercel itself may deliver a cron twice and never retries a failed one — and costs nothing to run.
- Deployment Protection is not this rule for production: its default for new projects since 2026-01-13, Standard Protection, protects previews and generated URLs, not production domains.

Rules: FP-01, FP-05.

**Minimal test** — local: call the route with no `Authorization`, with `Bearer undefined`, and with the cron `user-agent`; each must be refused. Calling the deployed route runs the real job: **REQUIRES AUTHORIZATION**.

**Traceability**: `CWE-306` · `CWE-288` · `WSTG-ATHN-04` · `ASVS 5.0 V8` · `A01:2025` · `API5:2023`
**Tooling**: `rg -n "CRON_SECRET|vercel-cron|x-vercel-cron" -g '!node_modules'`, then read each comparison. A route with no check at all matches nothing, so start from `vercel.json`.

## §14 Payments

### WEB-36 A payment the app believes without verifying it

**Where to look**
- The webhook route: `stripe.webhooks.constructEvent` / `constructEventAsync` and what reaches it. The signature is computed over the **raw** body: App Router `await req.text()`, Pages Router with `bodyParser: false`, Express with `express.raw()` mounted before `express.json()`. In Deno (Supabase Edge Functions) the synchronous call fails; the async one with `SubtleCryptoProvider` is the supported form.
- Guards around the verification: `if (endpointSecret) { … }` — the shape of Stripe's own snapshot sample — skips it whenever the variable is missing; a `tolerance` of `0` disables the recency check.
- Fulfilment: what grants the product — the webhook, or the `success_url` page reading `session_id` from the query string. Stripe states that webhooks are required for fulfilment, because a customer is not guaranteed to reach the landing page.
- Amounts: `unit_amount`, `amount`, `price` or a quantity read from the request body when creating a Checkout Session or PaymentIntent.
- Idempotency: processed `event.id`s recorded; fulfilment safe to run twice and concurrently.

**Vulnerable pattern** — the event, the payment or the price comes from the caller.

```ts
export async function POST(req: Request) {
  const event = await req.json();                       // never verified: anyone POSTs "checkout.session.completed"
  if (event.type === "checkout.session.completed") await grantPro(event.data.object.client_reference_id);
}
// and at checkout: price_data: { unit_amount: body.amount }   // the buyer sets the price
```

**What rules it out (false positive)**
- The raw body is verified against the `whsec_` secret with the library's default tolerance (five minutes), the call fails closed when the secret is unset, and fulfilment retrieves the Session server-side and checks `payment_status` before granting anything — which also makes a forged `session_id` harmless.
- Prices come from server-side ids (`price: "price_…"` looked up on the server), never from the request.
- Duplicates are absorbed: Stripe retries for up to three days in live mode and may send two events for one object; dedupe on `event.id`, and on the object id plus type.

Rules: FP-01, FP-02.

**Minimal test** — local, test mode only: `stripe listen --forward-to localhost:3000/api/webhooks` and `stripe trigger checkout.session.completed` prove the happy path; then POST the same JSON **unsigned** to the route — it must be rejected — and replay a signed event to see that nothing is granted twice. For the price, create a session with a tampered amount against test keys. Never with live keys.

**Traceability**: `CWE-345` · `CWE-347` · `CWE-602` · `WSTG-BUSL-01` · `WSTG-BUSL-02` · `ASVS 5.0 V2` · `A08:2025` · `A06:2025`
**Tooling**: `rg -n "constructEvent|webhooks\\.|req\\.json\\(\\)|unit_amount|success_url|client_reference_id" -g '!node_modules'`; the Stripe CLI drives the local test. No scanner decides whether fulfilment waits for the webhook: read the code that grants the product.
