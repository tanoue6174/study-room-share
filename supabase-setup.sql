create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  login_id text unique,
  display_name text not null,
  role text not null check (role in ('teacher', 'student')),
  created_at timestamptz not null default now()
);

alter table public.profiles
add column if not exists login_id text unique;

create table if not exists public.study_rooms (
  id bigint generated always as identity primary key,
  room_name text not null,
  location text not null,
  available_date date not null,
  start_time time not null,
  end_time time not null,
  capacity integer not null check (capacity between 1 and 200),
  note text default '',
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  check (start_time < end_time)
);

alter table public.profiles enable row level security;
alter table public.study_rooms enable row level security;

drop policy if exists "Users can read profiles" on public.profiles;
drop policy if exists "Users can create own profile" on public.profiles;
drop policy if exists "Users can update own profile" on public.profiles;
drop policy if exists "Logged in users can read study rooms" on public.study_rooms;
drop policy if exists "Teachers can create study rooms" on public.study_rooms;
drop policy if exists "Teachers can update own study rooms" on public.study_rooms;
drop policy if exists "Teachers can delete own study rooms" on public.study_rooms;

create policy "Users can read profiles"
on public.profiles
for select
to authenticated
using (true);

create policy "Users can create own profile"
on public.profiles
for insert
to authenticated
with check (id = auth.uid());

create policy "Users can update own profile"
on public.profiles
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

create policy "Logged in users can read study rooms"
on public.study_rooms
for select
to authenticated
using (true);

create policy "Teachers can create study rooms"
on public.study_rooms
for insert
to authenticated
with check (
  created_by = auth.uid()
  and exists (
    select 1
    from public.profiles
    where profiles.id = auth.uid()
      and profiles.role = 'teacher'
  )
);

create policy "Teachers can update own study rooms"
on public.study_rooms
for update
to authenticated
using (
  created_by = auth.uid()
  and exists (
    select 1
    from public.profiles
    where profiles.id = auth.uid()
      and profiles.role = 'teacher'
  )
)
with check (
  created_by = auth.uid()
  and exists (
    select 1
    from public.profiles
    where profiles.id = auth.uid()
      and profiles.role = 'teacher'
  )
);

create policy "Teachers can delete own study rooms"
on public.study_rooms
for delete
to authenticated
using (
  created_by = auth.uid()
  and exists (
    select 1
    from public.profiles
    where profiles.id = auth.uid()
      and profiles.role = 'teacher'
  )
);
