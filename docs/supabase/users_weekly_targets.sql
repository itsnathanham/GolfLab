-- Weekly goal targets for Home / History streak UI (stored on `users` alongside profile).
-- Run in Supabase SQL editor (or your migration pipeline) before relying on Profile weekly pickers.

alter table public.users
  add column if not exists weekly_round_target integer;

alter table public.users
  add column if not exists weekly_practice_target integer;

comment on column public.users.weekly_round_target is 'User goal: completed rounds per local calendar week (0 = not required for streak).';
comment on column public.users.weekly_practice_target is 'User goal: practice session rows per local calendar week (0 = not required for streak).';

alter table public.users
  add column if not exists weekly_goal_target_revisions jsonb default '[]'::jsonb;

comment on column public.users.weekly_goal_target_revisions is 'Array of {effective_from, round_target, practice_target}; past streak weeks use the revision active for that week (forward-only goal changes).';
