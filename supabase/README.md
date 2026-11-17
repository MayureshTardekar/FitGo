# FitGo Supabase

The database is versioned in `supabase/migrations/`. The root
`supabase_setup.sql` is a manual fallback that mirrors the baseline migration
for pasting into the Dashboard SQL Editor.

## Tables

- `user_profiles` — one row per auth user, including target weight and goal date.
- `daily_metrics` — one row per user/day (calories, fasting, water, sleep,
  activity, nutrition).
- `weight_entries` — one row per user/day weight.
- `app_settings` — per-user key/value settings such as saved meals.

Every table has RLS enabled and policies scoped to `auth.uid()`. The AI key and
chat history are intentionally **not** stored in Supabase; they remain on-device.

## Local development

```bash
supabase start
supabase db reset      # applies every migration from scratch
supabase stop
```

Local API: `http://127.0.0.1:54321` (the app still points at the hosted project).
Local Studio: `http://127.0.0.1:54323`.

## Hosted project

Project ref: `jqvfqjegodjcjngdvlkd`.

> **Status (17 Nov 2026):** `20261117110000_initial_schema.sql` is applied to
> the hosted project. Local and remote migration history match. The
> `user_profiles` goal-plan columns and `weight_entries.updated_at` are present.

```bash
supabase login
supabase link --project-ref jqvfqjegodjcjngdvlkd
supabase db push
```

`supabase link` and `db push` ask for the database password once. The password
is not stored in this repo. If you cannot run the CLI, paste
`supabase_setup.sql` into **Dashboard → SQL Editor** instead.

After pushing, verify in the dashboard that `user_profiles` has
`activity_level`, `target_weight_kg`, and `goal_target_date`, and that
`weight_entries` has `updated_at`.

## Account deletion

Row deletion cascades from `auth.users`. The remaining work is the
`delete-account` Edge Function that uses the service-role key, deletes the auth
user, and revokes the Apple refresh token. Do not expose the service-role key
to the Flutter app.
