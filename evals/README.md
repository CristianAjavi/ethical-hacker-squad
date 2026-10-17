# Product evals: does the installed plugin beat the model alone?

`bench/` measures the **corpus**: in 13 of the 17 rounds under `bench/runs/` that kept their prompts, those prompts tell the model "Do not delegate to subagents", so the thing a user installs — the leader, its subagents, the packs they load — was never scored, and never against the two things a user would otherwise do: ask the model with no plugin, or run Claude Code's built-in `/security-review`. This suite measures the product, with `claude plugin eval` (Claude Code 2.1.269 or later), which runs every case **with** the plugin and **without** it and reports the difference.

## What it runs

One synthetic app, the shape an AI coding tool produces in a weekend: Next.js 15 App Router on Vercel, Supabase, Stripe Checkout, an OpenAI assistant (`_fixtures/vibe-app/`, seeded into each run's empty workspace by `_fixtures/seed-vibe-app.sh`). It carries nine planted defects and three things done right.

| Grader | Defect | Where | Procedure |
|---|---|---|---|
| `d1` | `notes` never enables row-level security | `supabase/migrations/0001_init.sql` | `WEB-29` |
| `d2` | a user can set their own `role` or `plan` | same file, `update own profile` | `WEB-31` |
| `d3` | the service-role key ships to the browser behind `NEXT_PUBLIC_` | `lib/supabase/admin.ts`, imported by `app/dashboard/NotesClient.tsx` | `SUP-27` |
| `d4` | `deleteNote` checks neither session nor owner | `app/actions.ts` | `WEB-33` |
| `d5` | `/api/admin/users` answers anyone; the matcher skips `/api` | `middleware.ts`, `app/api/admin/users/route.ts` | `WEB-34` |
| `d6` | the Stripe webhook never verifies the signature | `app/api/stripe/webhook/route.ts` | `WEB-36` |
| `d7` | the checkout price comes from the request body | `app/api/checkout/route.ts` | `WEB-36` |
| `d8` | the cron route accepts `Bearer undefined` when `CRON_SECRET` is unset | `app/api/cron/charge-trials/route.ts` | `WEB-35` |
| `d9` | `/api/chat` spends the OpenAI key for anyone, without a limit | `app/api/chat/route.ts` | `AI-19` |
| controls | `app/api/notes/[id]/route.ts`, the `invoices` policy and `createNote` are correct; reporting any of them is a false alarm | — | — |

`next` is pinned to 15.1.7, inside the CVE-2025-29927 range, and the README says the app is deployed on Vercel, where that CVE did not apply. No grader rewards either answer; the report is where to read how each arm handled it.

| Case | Prompt | What its two arms measure |
|---|---|---|
| `launch-check` | a non-expert: "Is it safe? … write what you find to `security-report.md`, most urgent first" | the plugin's `quick` path against the model alone |
| `full-audit` | a reviewer: "Run a full security audit … write the report to `security-report.md`" | the full squad against the model alone |
| `security-review-builtin` | `/security-review`, with the app as the pending change of a branch | read its **W/OUT** arm: the built-in command with no plugin. Its with-arm adds the plugin to the built-in, which is not a comparison anyone asked for |

Each defect grader is a free regex over the report (`security-report.md`, or the final message for `/security-review`). The control grader is an `llm` judge with weight 2. `skill-fired` records whether the skill was invoked and never counts toward the score.

## Running it costs money, so it is never run by default

Rule 9 of the skill applies to its own evaluation: a run spends model credits and needs an explicit cap and the maintainer's approval. Every case runs three times per arm by default, and a full squad dispatches several subagents per run, so cost is dominated by `full-audit`.

```bash
# from the repository root; the scaffold seeds each workspace, Write lets the
# run produce its report, Bash runs inside Claude Code's sandbox (no network)
claude plugin eval . \
  --scaffold --allow-tools Write Bash \
  --model <pinned model> --judge-model <pinned judge> \
  --max-cost-usd 30 --no-publish
```

- Cheapest first look: `--case launch-check --runs 1` (two runs, one per arm).
- `--max-cost-usd` is checked before each run starts; once spent, nothing new starts and the command exits 2 with partial results, which do not belong in any comparison.
- Pin both models. A change of default model is not a change of plugin.
- Results land in `evals/results/<timestamp>/` (git-ignored): `report.html` and `aggregate-result.json`.

## How to read it

- `launch-check` and `full-audit`: `WITH` is the plugin, `W/OUT` the same model with no plugin, `Δ` what the plugin added. A `Δ` near zero means the plugin is ceremony on this target; negative means it cost recall or precision.
- The built-in: compare `security-review-builtin` **W/OUT** against `full-audit` **WITH**. The prompts differ by design — each tool is asked the way a user would ask it — so this is a comparison of products, not of prompts.
- Read `report.html` for every claim a regex scored: a report that names a term while dismissing it still passes a regex, and only the run's text tells.

## What this suite does not prove

- **One app, written by the same author as the procedures it tests.** It checks that the product finds what the corpus claims to cover; it cannot say how the product does on code nobody here designed. That needs external repositories with defects labelled by someone else, which this suite is the harness for, not a substitute of.
- **Regex graders are coarse.** They are free and stable, and they can be fooled both ways; the `llm` control grader and the report are the cross-check.
- **One run so far, and it found no difference.** [`measured/2026-10-17-sonnet-5-5`](measured/2026-10-17-sonnet-5-5/): with Sonnet 5.5, the plugin scored the same as the model alone on `full-audit` and `launch-check` (Δ 0.00) at about a fifth more cost; `/security-review` could not run inside the macOS eval sandbox. Results are claimed only from a committed `aggregate-result.json` beside the run's model, judge, Claude Code version and cost.
