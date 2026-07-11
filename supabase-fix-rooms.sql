create table if not exists public.study_rooms (
  id bigint generated always as identity primary key,
  room_name text not null,
  location text not null,
  available_date date not null,
  start_time time not null,
  end_time time not null,
  capacity integer not null check (capacity between 1 and 200),
  note text default '',
  accepts_requests boolean not null default true,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  check (start_time < end_time)
);

create table if not exists public.study_room_options (
  id bigint generated always as identity primary key,
  room_name text not null,
  location text not null,
  accepts_requests boolean not null default true,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (created_by, room_name)
);

alter table public.study_rooms
add column if not exists accepts_requests boolean not null default true;

alter table public.study_room_options
add column if not exists accepts_requests boolean not null default true;

alter table public.study_rooms enable row level security;
alter table public.study_room_options enable row level security;

drop policy if exists "Logged in users can read study rooms" on public.study_rooms;
drop policy if exists "Teachers can create study rooms" on public.study_rooms;
drop policy if exists "Teachers can update own study rooms" on public.study_rooms;
drop policy if exists "Teachers can delete own study rooms" on public.study_rooms;
drop policy if exists "Logged in users can read room options" on public.study_room_options;
drop policy if exists "Teachers can create room options" on public.study_room_options;
drop policy if exists "Teachers can update own room options" on public.study_room_options;
drop policy if exists "Teachers can delete own room options" on public.study_room_options;

create policy "Logged in users can read study rooms"
on public.study_rooms
for select
to authenticated
using (true);

create policy "Teachers can create study rooms"
on public.study_rooms
for insert
to authenticated
with check (created_by = auth.uid());

create policy "Teachers can update own study rooms"
on public.study_rooms
for update
to authenticated
using (created_by = auth.uid())
with check (created_by = auth.uid());

create policy "Teachers can delete own study rooms"
on public.study_rooms
for delete
to authenticated
using (created_by = auth.uid());

create policy "Logged in users can read room options"
on public.study_room_options
for select
to authenticated
using (true);

create policy "Teachers can create room options"
on public.study_room_options
for insert
to authenticated
with check (created_by = auth.uid());

create policy "Teachers can update own room options"
on public.study_room_options
for update
to authenticated
using (created_by = auth.uid())
with check (created_by = auth.uid());

create policy "Teachers can delete own room options"
on public.study_room_options
for delete
to authenticated
using (created_by = auth.uid());
