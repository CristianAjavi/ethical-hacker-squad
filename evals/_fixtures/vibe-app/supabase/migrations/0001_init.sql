-- Profiles: one row per user, created by a trigger on sign-up.
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  role text not null default 'user',      -- 'user' | 'admin'
  plan text not null default 'free',      -- 'free' | 'pro'
  created_at timestamptz default now()
);
alter table public.profiles enable row level security;
create policy "read own profile" on public.profiles for select to authenticated
  using ((select auth.uid()) = id);
create policy "update own profile" on public.profiles for update to authenticated
  using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

-- Notes.
create table public.notes (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id),
  title text,
  body text,
  created_at timestamptz default now()
);

-- Invoices, written by the Stripe webhook.
create table public.invoices (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id),
  amount_cents integer not null,
  created_at timestamptz default now()
);
alter table public.invoices enable row level security;
create policy "read own invoices" on public.invoices for select to authenticated
  using ((select auth.uid()) = user_id);
