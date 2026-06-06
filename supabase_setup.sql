-- Run this in Supabase SQL Editor (Dashboard > SQL Editor > New Query)

-- 1. User Profiles
create table if not exists user_profiles (
  id uuid references auth.users on delete cascade primary key,
  weight_kg double precision not null default 70,
  height_cm double precision not null default 170,
  age int not null default 25,
  gender text not null default 'male',
  calorie_goal int not null default 2000,
  water_goal_ml int not null default 3000,
  weekly_calorie_goal int not null default 14000,
  weight_goal text not null default 'maintain',
  dob_string text not null default '',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 2. Daily Metrics
create table if not exists daily_metrics (
  id bigint generated always as identity primary key,
  user_id uuid references auth.users on delete cascade not null,
  date_key text not null,
  total_calories int not null default 0,
  water_ml int not null default 0,
  weight double precision,
  fasting_start_epoch bigint,
  fasting_duration_minutes int not null default 960,
  calorie_entries jsonb not null default '[]',
  steps int not null default 0,
  calories_burned int not null default 0,
  activities jsonb not null default '[]',
  sleep_minutes int not null default 0,
  sleep_bedtime text not null default '',
  sleep_wake_time text not null default '',
  protein_grams int not null default 0,
  carbs_grams int not null default 0,
  fat_grams int not null default 0,
  fiber_grams int not null default 0,
  sugar_grams int not null default 0,
  nutrition_entries jsonb not null default '[]',
  fasting_reminder_minutes int not null default 60,
  fasting_reminder_enabled boolean not null default true,
  fasting_last_reminder_epoch bigint,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(user_id, date_key)
);

-- Existing projects can run these safely after the table already exists.
alter table daily_metrics add column if not exists protein_grams int not null default 0;
alter table daily_metrics add column if not exists carbs_grams int not null default 0;
alter table daily_metrics add column if not exists fat_grams int not null default 0;
alter table daily_metrics add column if not exists fiber_grams int not null default 0;
alter table daily_metrics add column if not exists sugar_grams int not null default 0;
alter table daily_metrics add column if not exists nutrition_entries jsonb not null default '[]';
alter table daily_metrics add column if not exists fasting_reminder_minutes int not null default 60;
alter table daily_metrics add column if not exists fasting_reminder_enabled boolean not null default true;
alter table daily_metrics add column if not exists fasting_last_reminder_epoch bigint;

-- 3. Weight Entries
create table if not exists weight_entries (
  id bigint generated always as identity primary key,
  user_id uuid references auth.users on delete cascade not null,
  date_key text not null,
  weight double precision not null,
  created_at timestamptz default now(),
  unique(user_id, date_key)
);

-- 4. App Settings
create table if not exists app_settings (
  id bigint generated always as identity primary key,
  user_id uuid references auth.users on delete cascade not null,
  setting_key text not null,
  setting_value jsonb,
  updated_at timestamptz default now(),
  unique(user_id, setting_key)
);

-- 4. Enable Row Level Security
alter table user_profiles enable row level security;
alter table daily_metrics enable row level security;
alter table weight_entries enable row level security;
alter table app_settings enable row level security;

-- 5. RLS Policies - users can only access their own data
drop policy if exists "Users can view own profile" on user_profiles;
drop policy if exists "Users can insert own profile" on user_profiles;
drop policy if exists "Users can update own profile" on user_profiles;

drop policy if exists "Users can view own metrics" on daily_metrics;
drop policy if exists "Users can insert own metrics" on daily_metrics;
drop policy if exists "Users can update own metrics" on daily_metrics;

drop policy if exists "Users can view own weight" on weight_entries;
drop policy if exists "Users can insert own weight" on weight_entries;
drop policy if exists "Users can update own weight" on weight_entries;

drop policy if exists "Users can view own settings" on app_settings;
drop policy if exists "Users can insert own settings" on app_settings;
drop policy if exists "Users can update own settings" on app_settings;

create policy "Users can view own profile"
  on user_profiles for select using (auth.uid() = id);
create policy "Users can insert own profile"
  on user_profiles for insert with check (auth.uid() = id);
create policy "Users can update own profile"
  on user_profiles for update using (auth.uid() = id);

create policy "Users can view own metrics"
  on daily_metrics for select using (auth.uid() = user_id);
create policy "Users can insert own metrics"
  on daily_metrics for insert with check (auth.uid() = user_id);
create policy "Users can update own metrics"
  on daily_metrics for update using (auth.uid() = user_id);

create policy "Users can view own weight"
  on weight_entries for select using (auth.uid() = user_id);
create policy "Users can insert own weight"
  on weight_entries for insert with check (auth.uid() = user_id);
create policy "Users can update own weight"
  on weight_entries for update using (auth.uid() = user_id);

create policy "Users can view own settings"
  on app_settings for select using (auth.uid() = user_id);
create policy "Users can insert own settings"
  on app_settings for insert with check (auth.uid() = user_id);
create policy "Users can update own settings"
  on app_settings for update using (auth.uid() = user_id);

-- 6. Auto-update updated_at timestamp
create or replace function update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists user_profiles_updated_at on user_profiles;
drop trigger if exists daily_metrics_updated_at on daily_metrics;
drop trigger if exists weight_entries_updated_at on weight_entries;
drop trigger if exists app_settings_updated_at on app_settings;

create trigger user_profiles_updated_at before update on user_profiles
  for each row execute function update_updated_at();
create trigger daily_metrics_updated_at before update on daily_metrics
  for each row execute function update_updated_at();
create trigger weight_entries_updated_at before update on weight_entries
  for each row execute function update_updated_at();
create trigger app_settings_updated_at before update on app_settings
  for each row execute function update_updated_at();
