-- Analytics Events Table & RLS (idempotent)
-- Run this file in Supabase SQL Editor.

create table if not exists public.analytics_events (
  id bigserial primary key,
  created_at timestamptz not null default now(),
  user_id uuid null,
  device_id text not null,
  session_id text not null,
  event_name text not null,
  screen_name text null,
  properties jsonb not null default '{}'::jsonb,
  app_version text null,
  platform text null
);

create index if not exists analytics_events_created_at_idx on public.analytics_events (created_at desc);
create index if not exists analytics_events_event_name_idx on public.analytics_events (event_name);
create index if not exists analytics_events_user_id_idx on public.analytics_events (user_id);

alter table public.analytics_events enable row level security;

drop policy if exists "analytics_insert_authenticated" on public.analytics_events;
create policy "analytics_insert_authenticated"
on public.analytics_events
for insert
to authenticated
with check (true);

-- No select/update/delete policy defined (default deny)
drop policy if exists "analytics_no_select" on public.analytics_events;
