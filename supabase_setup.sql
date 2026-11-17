-- FitGo manual SQL fallback.
--
-- Canonical schema: supabase/migrations/20261117110000_initial_schema.sql
-- Prefer the CLI: supabase link --project-ref jqvfqjegodjcjngdvlkd
--                 supabase db push
-- You can also paste this whole file into Dashboard -> SQL Editor.
--
-- This file mirrors the baseline migration and is safe to run on an existing
-- FitGo project. It adds the 3.0 goal-plan columns and fixes the
-- weight_entries updated_at trigger.
-- FitGo 3.0 baseline schema and repair migration.
--
-- Safe to apply to an existing project: tables, columns, policies, and
-- triggers are created only when missing, and existing rows are preserved.
--
-- Apply with:
--   supabase link --project-ref jqvfqjegodjcjngdvlkd
--   supabase db push
--
-- Or run this file in Supabase Dashboard -> SQL Editor.

-- â”€â”€â”€ 1. User profiles â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

create table if not exists public.user_profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  weight_kg double precision not null default 70,
  height_cm double precision not null default 170,
  age integer not null default 25,
  gender text not null default 'male',
  calorie_goal integer not null default 2000,
  water_goal_ml integer not null default 3000,
  weekly_calorie_goal integer not null default 14000,
  weight_goal text not null default 'maintain',
  dob_string text not null default '',
  activity_level text not null default 'light',
  target_weight_kg double precision not null default 0,
  goal_target_date text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Goal-plan fields added in 3.0. Existing rows receive safe defaults.
alter table public.user_profiles
  add column if not exists activity_level text not null default 'light',
  add column if not exists target_weight_kg double precision not null default 0,
  add column if not exists goal_target_date text not null default '';

-- â”€â”€â”€ 2. Daily metrics â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

create table if not exists public.daily_metrics (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  date_key text not null,
  total_calories integer not null default 0,
  water_ml integer not null default 0,
  weight double precision,
  fasting_start_epoch bigint,
  fasting_duration_minutes integer not null default 960,
  calorie_entries jsonb not null default '[]'::jsonb,
  steps integer not null default 0,
  calories_burned integer not null default 0,
  activities jsonb not null default '[]'::jsonb,
  sleep_minutes integer not null default 0,
  sleep_bedtime text not null default '',
  sleep_wake_time text not null default '',
  protein_grams integer not null default 0,
  carbs_grams integer not null default 0,
  fat_grams integer not null default 0,
  fiber_grams integer not null default 0,
  sugar_grams integer not null default 0,
  nutrition_entries jsonb not null default '[]'::jsonb,
  fasting_reminder_minutes integer not null default 60,
  fasting_reminder_enabled boolean not null default true,
  fasting_last_reminder_epoch bigint,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, date_key)
);

alter table public.daily_metrics
  add column if not exists protein_grams integer not null default 0,
  add column if not exists carbs_grams integer not null default 0,
  add column if not exists fat_grams integer not null default 0,
  add column if not exists fiber_grams integer not null default 0,
  add column if not exists sugar_grams integer not null default 0,
  add column if not exists nutrition_entries jsonb not null default '[]'::jsonb,
  add column if not exists fasting_reminder_minutes integer not null default 60,
  add column if not exists fasting_reminder_enabled boolean not null default true,
  add column if not exists fasting_last_reminder_epoch bigint;

-- â”€â”€â”€ 3. Weight entries â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

create table if not exists public.weight_entries (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  date_key text not null,
  weight double precision not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, date_key)
);

-- The old setup attached an updated_at trigger without this column, which
-- made upserts on an existing date fail. Add it for existing projects.
alter table public.weight_entries
  add column if not exists updated_at timestamptz not null default now();

-- â”€â”€â”€ 4. App settings â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

create table if not exists public.app_settings (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  setting_key text not null,
  setting_value jsonb,
  updated_at timestamptz not null default now(),
  unique (user_id, setting_key)
);

-- â”€â”€â”€ 5. Row Level Security â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

alter table public.user_profiles enable row level security;
alter table public.daily_metrics enable row level security;
alter table public.weight_entries enable row level security;
alter table public.app_settings enable row level security;

drop policy if exists "Users can view own profile" on public.user_profiles;
drop policy if exists "Users can insert own profile" on public.user_profiles;
drop policy if exists "Users can update own profile" on public.user_profiles;
drop policy if exists "Users can delete own profile" on public.user_profiles;

drop policy if exists "Users can view own metrics" on public.daily_metrics;
drop policy if exists "Users can insert own metrics" on public.daily_metrics;
drop policy if exists "Users can update own metrics" on public.daily_metrics;
drop policy if exists "Users can delete own metrics" on public.daily_metrics;

drop policy if exists "Users can view own weight" on public.weight_entries;
drop policy if exists "Users can insert own weight" on public.weight_entries;
drop policy if exists "Users can update own weight" on public.weight_entries;
drop policy if exists "Users can delete own weight" on public.weight_entries;

drop policy if exists "Users can view own settings" on public.app_settings;
drop policy if exists "Users can insert own settings" on public.app_settings;
drop policy if exists "Users can update own settings" on public.app_settings;
drop policy if exists "Users can delete own settings" on public.app_settings;

create policy "Users can view own profile"
  on public.user_profiles for select to authenticated
  using ((select auth.uid()) = id);
create policy "Users can insert own profile"
  on public.user_profiles for insert to authenticated
  with check ((select auth.uid()) = id);
create policy "Users can update own profile"
  on public.user_profiles for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);
create policy "Users can delete own profile"
  on public.user_profiles for delete to authenticated
  using ((select auth.uid()) = id);

create policy "Users can view own metrics"
  on public.daily_metrics for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Users can insert own metrics"
  on public.daily_metrics for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "Users can update own metrics"
  on public.daily_metrics for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "Users can delete own metrics"
  on public.daily_metrics for delete to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can view own weight"
  on public.weight_entries for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Users can insert own weight"
  on public.weight_entries for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "Users can update own weight"
  on public.weight_entries for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "Users can delete own weight"
  on public.weight_entries for delete to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can view own settings"
  on public.app_settings for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Users can insert own settings"
  on public.app_settings for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "Users can update own settings"
  on public.app_settings for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "Users can delete own settings"
  on public.app_settings for delete to authenticated
  using ((select auth.uid()) = user_id);

-- â”€â”€â”€ 6. Privileges â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

grant usage on schema public to authenticated;
grant select, insert, update, delete
  on public.user_profiles, public.daily_metrics,
     public.weight_entries, public.app_settings
  to authenticated;

grant usage, select
  on sequence public.daily_metrics_id_seq,
              public.weight_entries_id_seq,
              public.app_settings_id_seq
  to authenticated;

-- Edge Functions use the service role for account deletion; keep its access
-- explicit even though it bypasses RLS.
grant all
  on public.user_profiles, public.daily_metrics,
     public.weight_entries, public.app_settings
  to service_role;
grant usage, select
  on sequence public.daily_metrics_id_seq,
              public.weight_entries_id_seq,
              public.app_settings_id_seq
  to service_role;

-- â”€â”€â”€ 7. updated_at maintenance â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

create or replace function public.update_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at = pg_catalog.now();
  return new;
end;
$$;

drop trigger if exists user_profiles_updated_at on public.user_profiles;
drop trigger if exists daily_metrics_updated_at on public.daily_metrics;
drop trigger if exists weight_entries_updated_at on public.weight_entries;
drop trigger if exists app_settings_updated_at on public.app_settings;

create trigger user_profiles_updated_at
  before update on public.user_profiles
  for each row execute function public.update_updated_at();
create trigger daily_metrics_updated_at
  before update on public.daily_metrics
  for each row execute function public.update_updated_at();
create trigger weight_entries_updated_at
  before update on public.weight_entries
  for each row execute function public.update_updated_at();
create trigger app_settings_updated_at
  before update on public.app_settings
  for each row execute function public.update_updated_at();
