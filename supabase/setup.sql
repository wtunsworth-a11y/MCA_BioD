-- Melanesian Camera Trap ID: database setup
-- Run once in Supabase: SQL Editor -> New query -> paste all of this -> Run.
-- Safe to run again: it only creates what is missing and replaces functions.

-------------------------------------------------------------------------------
-- 1. People
-------------------------------------------------------------------------------
-- One row per signed-in person. Email addresses stay in Supabase's private
-- auth tables and are never exposed to the website.
create table if not exists public.profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  display_name  text not null check (char_length(display_name) between 2 and 60),
  affiliation   text check (char_length(affiliation) <= 120),
  expertise     text[] not null default '{}',
  status        text not null default 'pending' check (status in ('pending', 'approved', 'blocked')),
  is_moderator  boolean not null default false,
  created_at    timestamptz not null default now()
);

-- Emails that become moderators (and are approved) the first time they sign in.
create table if not exists public.moderator_emails (
  email text primary key
);
insert into public.moderator_emails (email) values ('w.unsworth@landscapealliance.org')
  on conflict do nothing;

create or replace function public.is_moderator() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select is_moderator from public.profiles where id = auth.uid()), false);
$$;

create or replace function public.my_status() returns text
language sql stable security definer set search_path = public as $$
  select status from public.profiles where id = auth.uid();
$$;

-- New profiles start as pending members; moderators listed above start approved.
-- Only moderators can change status or moderator rights.
create or replace function public.guard_profile() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  mod_email boolean;
begin
  if tg_op = 'INSERT' then
    if new.id is distinct from auth.uid() then
      raise exception 'You can only create your own profile.';
    end if;
    select exists (
      select 1 from public.moderator_emails m join auth.users u on lower(u.email) = lower(m.email)
      where u.id = new.id) into mod_email;
    new.is_moderator := mod_email;
    new.status := case when mod_email then 'approved' else 'pending' end;
    new.created_at := now();
  elsif tg_op = 'UPDATE' and not public.is_moderator() then
    new.status := old.status;
    new.is_moderator := old.is_moderator;
    new.created_at := old.created_at;
  end if;
  if new.display_name ~* '(https?://|www\.)' or coalesce(new.affiliation, '') ~* '(https?://|www\.)' then
    raise exception 'Links are not allowed in names.';
  end if;
  return new;
end $$;

drop trigger if exists profiles_guard on public.profiles;
create trigger profiles_guard before insert or update on public.profiles
  for each row execute function public.guard_profile();

-------------------------------------------------------------------------------
-- 2. Identifications (one per person per sighting) and comments
-------------------------------------------------------------------------------
create table if not exists public.identifications (
  id           bigint generated always as identity primary key,
  sighting_id  text not null check (sighting_id ~ '^[A-Za-z_]+_[0-9]{3}$'),
  user_id      uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  family       text check (char_length(family) <= 60),
  genus        text check (char_length(genus) <= 60),
  species      text check (char_length(species) <= 60),
  provisional  text check (char_length(provisional) <= 80),
  unid         boolean not null default false,
  flag_range   boolean not null default false,
  flag_newsp   boolean not null default false,
  flag_review  boolean not null default false,
  confidence   text check (confidence in ('Sure', 'Likely', 'Best guess')),
  local_name   text check (char_length(local_name) <= 80),
  note         text check (char_length(note) <= 1500),
  hidden       boolean not null default false,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (sighting_id, user_id)
);

create table if not exists public.comments (
  id           bigint generated always as identity primary key,
  sighting_id  text not null check (sighting_id ~ '^[A-Za-z_]+_[0-9]{3}$'),
  user_id      uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  body         text not null check (char_length(body) between 1 and 1500),
  hidden       boolean not null default false,
  created_at   timestamptz not null default now()
);

-- Every change to an identification is kept here (moderators only).
create table if not exists public.identification_history (
  id                 bigint generated always as identity primary key,
  identification_id  bigint not null,
  changed_by         uuid,
  change             text not null,
  old_row            jsonb not null,
  changed_at         timestamptz not null default now()
);

-- Rules applied to every new or changed identification or comment:
-- your own rows only, no links (no ads), a limit of 60 entries an hour,
-- blocked members can't post, and only moderators can hide or unhide.
create or replace function public.guard_entry() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  txt text;
  recent int;
begin
  if public.my_status() is null then
    raise exception 'Please finish signing in before submitting.';
  end if;
  if public.my_status() = 'blocked' then
    raise exception 'This account cannot submit entries.';
  end if;
  if tg_table_name = 'identifications' then
    txt := concat_ws(' ', new.note, new.local_name, new.provisional, new.family, new.genus, new.species);
  else
    txt := new.body;
  end if;
  if txt ~* '(https?://|www\.|\.(com|net|org)\y)' then
    raise exception 'Links and web addresses are not allowed in notes or comments.';
  end if;
  if tg_op = 'INSERT' then
    if new.user_id is distinct from auth.uid() then
      raise exception 'You can only add your own entries.';
    end if;
    if not public.is_moderator() then new.hidden := false; end if;
    execute format('select count(*) from public.%I where user_id = $1 and created_at > now() - interval ''1 hour''', tg_table_name)
      into recent using auth.uid();
    if recent >= 60 then
      raise exception 'Too many entries in the last hour. Please try again later.';
    end if;
    new.created_at := now();
  else  -- UPDATE
    if not public.is_moderator() then
      new.hidden := old.hidden;
      new.user_id := old.user_id;
      new.sighting_id := old.sighting_id;
    end if;
    new.created_at := old.created_at;
  end if;
  if tg_table_name = 'identifications' then
    new.updated_at := now();
  end if;
  return new;
end $$;

drop trigger if exists identifications_guard on public.identifications;
create trigger identifications_guard before insert or update on public.identifications
  for each row execute function public.guard_entry();
drop trigger if exists comments_guard on public.comments;
create trigger comments_guard before insert or update on public.comments
  for each row execute function public.guard_entry();

create or replace function public.log_identification() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.identification_history (identification_id, changed_by, change, old_row)
  values (old.id, auth.uid(), lower(tg_op), to_jsonb(old));
  return coalesce(new, old);
end $$;

drop trigger if exists identifications_history on public.identifications;
create trigger identifications_history after update or delete on public.identifications
  for each row execute function public.log_identification();

-------------------------------------------------------------------------------
-- 3. Who can read and write what (row-level security)
-------------------------------------------------------------------------------
alter table public.profiles               enable row level security;
alter table public.moderator_emails       enable row level security;
alter table public.identifications        enable row level security;
alter table public.comments               enable row level security;
alter table public.identification_history enable row level security;

-- profiles: names are public; you edit your own; moderators edit anyone's status
drop policy if exists "profiles readable" on public.profiles;
create policy "profiles readable" on public.profiles for select using (true);
drop policy if exists "create own profile" on public.profiles;
create policy "create own profile" on public.profiles for insert to authenticated with check (id = auth.uid());
drop policy if exists "edit own profile or moderate" on public.profiles;
create policy "edit own profile or moderate" on public.profiles for update to authenticated
  using (id = auth.uid() or public.is_moderator()) with check (id = auth.uid() or public.is_moderator());

-- identifications: everyone sees visible ones; you add, edit and withdraw your own;
-- moderators see and hide anything
drop policy if exists "identifications readable" on public.identifications;
create policy "identifications readable" on public.identifications for select
  using (not hidden or user_id = auth.uid() or public.is_moderator());
drop policy if exists "add own identification" on public.identifications;
create policy "add own identification" on public.identifications for insert to authenticated
  with check (user_id = auth.uid());
drop policy if exists "edit own identification or moderate" on public.identifications;
create policy "edit own identification or moderate" on public.identifications for update to authenticated
  using (user_id = auth.uid() or public.is_moderator()) with check (user_id = auth.uid() or public.is_moderator());
drop policy if exists "withdraw own identification" on public.identifications;
create policy "withdraw own identification" on public.identifications for delete to authenticated
  using (user_id = auth.uid() or public.is_moderator());

-- comments: same pattern
drop policy if exists "comments readable" on public.comments;
create policy "comments readable" on public.comments for select
  using (not hidden or user_id = auth.uid() or public.is_moderator());
drop policy if exists "add own comment" on public.comments;
create policy "add own comment" on public.comments for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "edit own comment or moderate" on public.comments;
create policy "edit own comment or moderate" on public.comments for update to authenticated
  using (user_id = auth.uid() or public.is_moderator()) with check (user_id = auth.uid() or public.is_moderator());
drop policy if exists "delete own comment or moderate" on public.comments;
create policy "delete own comment or moderate" on public.comments for delete to authenticated
  using (user_id = auth.uid() or public.is_moderator());

-- history and moderator list: moderators only
drop policy if exists "history for moderators" on public.identification_history;
create policy "history for moderators" on public.identification_history for select to authenticated
  using (public.is_moderator());
drop policy if exists "moderator list for moderators" on public.moderator_emails;
create policy "moderator list for moderators" on public.moderator_emails for all to authenticated
  using (public.is_moderator()) with check (public.is_moderator());

-- The website reaches tables only through these grants (automatic access is off).
grant usage on schema public to anon, authenticated;
grant select on public.profiles, public.identifications, public.comments to anon, authenticated;
grant insert, update on public.profiles to authenticated;
grant insert, update, delete on public.identifications, public.comments to authenticated;
grant select on public.identification_history to authenticated;
grant select, insert, delete on public.moderator_emails to authenticated;
grant execute on function public.is_moderator(), public.my_status() to anon, authenticated;

-- Done. You should see "Success. No rows returned".
