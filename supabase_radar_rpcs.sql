-- RPC for joining a radar (Thread-safe array append)
create or replace function join_radar(radar_id uuid, user_id uuid)
returns void
language plpgsql
security definer
as $$
begin
  update radars
  set participants = array_append(participants, user_id)
  where id = radar_id
  and not (participants @> array[user_id]); -- Prevent duplicates
end;
$$;

-- ==========================================================
-- Chat RLS Helpers & Policies (Radar + Social Chat)
-- ==========================================================

-- Helper: check if a user is a member of a chat (bypass RLS via definer).
create or replace function public.is_chat_member(p_chat_id uuid, p_user_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  exists_member boolean;
begin
  begin
    execute
      'select exists (select 1 from public.chat_members where chat_id = $1 and user_id = $2)'
      into exists_member
      using p_chat_id, p_user_id;
  exception when undefined_column then
    execute
      'select exists (select 1 from public.chat_members where room_id = $1 and user_id = $2)'
      into exists_member
      using p_chat_id, p_user_id;
  end;

  return coalesce(exists_member, false);
end;
$$;

-- Helper: ensure a user is recorded as a chat member (supports chat_id or room_id column).
create or replace function public.ensure_chat_member(p_chat_id uuid, p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  begin
    insert into public.chat_members (chat_id, user_id)
    values (p_chat_id, p_user_id)
    on conflict (chat_id, user_id) do nothing;
  exception when undefined_column then
    insert into public.chat_members (room_id, user_id)
    values (p_chat_id, p_user_id)
    on conflict (room_id, user_id) do nothing;
  end;
end;
$$;

-- Ensure RLS is enabled
alter table public.chat_members enable row level security;
alter table public.chat_messages enable row level security;
alter table public.chat_rooms enable row level security;

-- chat_members policies
drop policy if exists "chat_members_select" on public.chat_members;
create policy "chat_members_select" on public.chat_members
for select to authenticated
using (public.is_chat_member(chat_members.chat_id, auth.uid()));

drop policy if exists "chat_members_insert_self" on public.chat_members;
create policy "chat_members_insert_self" on public.chat_members
for insert to authenticated
with check (user_id = auth.uid());

drop policy if exists "chat_members_update_self" on public.chat_members;
create policy "chat_members_update_self" on public.chat_members
for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "chat_members_delete_self" on public.chat_members;
create policy "chat_members_delete_self" on public.chat_members
for delete to authenticated
using (user_id = auth.uid());

-- chat_messages policies (room_id is the canonical link)
drop policy if exists "chat_messages_select_member" on public.chat_messages;
create policy "chat_messages_select_member" on public.chat_messages
for select to authenticated
using (public.is_chat_member(chat_messages.room_id, auth.uid()));

drop policy if exists "chat_messages_insert_member" on public.chat_messages;
create policy "chat_messages_insert_member" on public.chat_messages
for insert to authenticated
with check (
  sender_id = auth.uid()
  and public.is_chat_member(chat_messages.room_id, auth.uid())
);

drop policy if exists "chat_messages_update_member" on public.chat_messages;
create policy "chat_messages_update_member" on public.chat_messages
for update to authenticated
using (public.is_chat_member(chat_messages.room_id, auth.uid()))
with check (public.is_chat_member(chat_messages.room_id, auth.uid()));

drop policy if exists "chat_messages_delete_own" on public.chat_messages;
create policy "chat_messages_delete_own" on public.chat_messages
for delete to authenticated
using (sender_id = auth.uid());

-- chat_rooms policies (readable by members only)
drop policy if exists "chat_rooms_select_member" on public.chat_rooms;
create policy "chat_rooms_select_member" on public.chat_rooms
for select to authenticated
using (public.is_chat_member(chat_rooms.id, auth.uid()));

-- RPC for leaving a radar (Thread-safe array remove)
create or replace function leave_radar(radar_id uuid, user_id uuid)
returns void
language plpgsql
security definer
as $$
begin
  update radars
  set participants = array_remove(participants, user_id)
  where id = radar_id;
end;
$$;

-- ==========================================================
-- Radar Misa V2 (radar_events) RPCs
-- ==========================================================

-- Join radar with rule checks (status, time, quota, approval).
-- Returns status (JOINED/PENDING) and chat_room_id if joined.
create or replace function join_radar_event(p_radar_id uuid, p_user_id uuid)
returns table(status text, chat_room_id uuid)
language plpgsql
security definer
as $$
declare
  v_event record;
  v_existing record;
  v_joined_count int;
  v_new_status text;
begin
  select *
  into v_event
  from radar_events
  where id = p_radar_id;

  if not found then
    raise exception 'Radar tidak ditemukan';
  end if;

  if v_event.status not in ('PUBLISHED', 'UPDATED') then
    raise exception 'Radar tidak aktif';
  end if;

  if v_event.event_time < now() then
    raise exception 'Radar sudah lewat';
  end if;

  if v_event.max_participants is not null and v_event.max_participants > 0 then
    select count(*) into v_joined_count
    from radar_participants
    where radar_id = p_radar_id and status = 'JOINED';

    if v_joined_count >= v_event.max_participants then
      raise exception 'Kuota penuh';
    end if;
  end if;

  select * into v_existing
  from radar_participants
  where radar_id = p_radar_id and user_id = p_user_id
  limit 1;

  if found then
    if v_existing.status = 'JOINED' then
      return query select 'JOINED', v_event.chat_room_id;
    elsif v_existing.status = 'PENDING' then
      return query select 'PENDING', null;
    end if;
  end if;

  if v_event.require_host_approval then
    v_new_status := 'PENDING';
  else
    v_new_status := 'JOINED';
  end if;

  insert into radar_participants (radar_id, user_id, status, role)
  values (p_radar_id, p_user_id, v_new_status, 'MEMBER')
  on conflict (radar_id, user_id) do update
  set status = excluded.status, role = excluded.role;

  insert into radar_change_logs (radar_id, changed_by, change_type, description)
  values (
    p_radar_id,
    p_user_id,
    case when v_new_status = 'PENDING' then 'REQUEST_JOIN' else 'JOIN' end,
    case when v_new_status = 'PENDING' then 'Mengajukan permintaan join' else 'Bergabung ke Radar' end
  );

  if v_new_status = 'JOINED' and v_event.chat_room_id is not null then
    insert into chat_members (chat_id, user_id)
    values (v_event.chat_room_id, p_user_id)
    on conflict (chat_id, user_id) do nothing;

    return query select 'JOINED', v_event.chat_room_id;
  end if;

  return query select 'PENDING', null;
end;
$$;

-- Leave radar: mark LEFT, remove chat member, log.
create or replace function leave_radar_event(p_radar_id uuid, p_user_id uuid)
returns void
language plpgsql
security definer
as $$
declare
  v_chat_room_id uuid;
begin
  update radar_participants
  set status = 'LEFT'
  where radar_id = p_radar_id and user_id = p_user_id;

  select chat_room_id into v_chat_room_id
  from radar_events
  where id = p_radar_id;

  if v_chat_room_id is not null then
    delete from chat_members
    where chat_id = v_chat_room_id and user_id = p_user_id;
  end if;

  insert into radar_change_logs (radar_id, changed_by, change_type, description)
  values (p_radar_id, p_user_id, 'LEAVE', 'Keluar dari Radar');
end;
$$;

-- Kick participant: host only, mark KICKED, remove chat member, log.
create or replace function kick_radar_participant(
  p_radar_id uuid,
  p_user_id uuid,
  p_actor_id uuid
)
returns void
language plpgsql
security definer
as $$
declare
  v_creator_id uuid;
  v_chat_room_id uuid;
begin
  select creator_id, chat_room_id into v_creator_id, v_chat_room_id
  from radar_events
  where id = p_radar_id;

  if v_creator_id is null or v_creator_id != p_actor_id then
    raise exception 'Hanya host yang boleh mengeluarkan peserta';
  end if;

  update radar_participants
  set status = 'KICKED'
  where radar_id = p_radar_id and user_id = p_user_id;

  if v_chat_room_id is not null then
    delete from chat_members
    where chat_id = v_chat_room_id and user_id = p_user_id;
  end if;

  insert into radar_change_logs (radar_id, changed_by, change_type, description)
  values (p_radar_id, p_actor_id, 'KICK', 'Mengeluarkan peserta');
end;
$$;

-- Respond to invite: accept/decline atomically.
create or replace function respond_radar_invite(
  p_invite_id uuid,
  p_accept boolean,
  p_user_id uuid
)
returns text
language plpgsql
security definer
as $$
declare
  v_invite record;
  v_chat_room_id uuid;
begin
  select * into v_invite
  from radar_invites
  where id = p_invite_id and invitee_id = p_user_id;

  if not found then
    raise exception 'Undangan tidak ditemukan';
  end if;

  if v_invite.status <> 'PENDING' then
    return v_invite.status;
  end if;

  if p_accept then
    update radar_invites set status = 'ACCEPTED' where id = p_invite_id;

    insert into radar_participants (radar_id, user_id, status, role)
    values (v_invite.radar_id, p_user_id, 'JOINED', 'MEMBER')
    on conflict (radar_id, user_id) do update
    set status = excluded.status, role = excluded.role;

    select chat_room_id into v_chat_room_id
    from radar_events
    where id = v_invite.radar_id;

    if v_chat_room_id is not null then
      insert into chat_members (chat_id, user_id)
      values (v_chat_room_id, p_user_id)
      on conflict (chat_id, user_id) do nothing;
    end if;

    insert into radar_change_logs (radar_id, changed_by, change_type, description)
    values (v_invite.radar_id, p_user_id, 'INVITE_ACCEPTED', 'Menerima undangan');

    return 'ACCEPTED';
  else
    update radar_invites set status = 'DECLINED' where id = p_invite_id;

    insert into radar_change_logs (radar_id, changed_by, change_type, description)
    values (v_invite.radar_id, p_user_id, 'INVITE_DECLINED', 'Menolak undangan');

    return 'DECLINED';
  end if;
end;
$$;
