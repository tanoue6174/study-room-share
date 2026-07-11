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

create table if not exists public.study_requests (
  id bigint generated always as identity primary key,
  room_id bigint references public.study_rooms(id) on delete cascade,
  room_option_id bigint references public.study_room_options(id) on delete cascade,
  room_location text not null,
  request_date date not null,
  request_time text not null,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.student_friends (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  friend_id uuid not null references public.profiles(id) on delete cascade,
  friend_name text not null,
  created_at timestamptz not null default now(),
  unique (user_id, friend_id),
  check (user_id <> friend_id)
);

create unique index if not exists student_friends_user_friend_idx
on public.student_friends (user_id, friend_id);

create table if not exists public.study_room_plans (
  id bigint generated always as identity primary key,
  room_id bigint not null references public.study_rooms(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (room_id, user_id)
);

create unique index if not exists study_room_plans_room_user_idx
on public.study_room_plans (room_id, user_id);

create table if not exists public.study_sessions (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  room_id bigint references public.study_rooms(id) on delete set null,
  room_name text not null,
  location text default '',
  ends_at text,
  active boolean not null default true,
  started_at timestamptz not null default now()
);

alter table public.study_rooms
add column if not exists accepts_requests boolean not null default true;

alter table public.study_room_options
add column if not exists accepts_requests boolean not null default true;

alter table public.study_requests
alter column room_id drop not null;

alter table public.study_requests
add column if not exists room_option_id bigint references public.study_room_options(id) on delete cascade;

alter table public.study_requests
add column if not exists room_location text;

alter table public.study_requests
add column if not exists request_date date;

alter table public.study_requests
add column if not exists request_time text;

alter table public.study_requests
add column if not exists created_by uuid references auth.users(id) on delete cascade;

update public.study_requests
set room_location = coalesce(
  room_location,
  (
    select study_room_options.location
    from public.study_room_options
    where study_room_options.id = study_requests.room_option_id
  ),
  (
    select study_rooms.location
    from public.study_rooms
    where study_rooms.id = study_requests.room_id
  ),
  '場所未設定'
)
where room_location is null;

alter table public.profiles enable row level security;
alter table public.study_rooms enable row level security;
alter table public.study_room_options enable row level security;
alter table public.study_requests enable row level security;
alter table public.student_friends enable row level security;
alter table public.study_room_plans enable row level security;
alter table public.study_sessions enable row level security;

drop policy if exists "Users can read profiles" on public.profiles;
drop policy if exists "Users can create own profile" on public.profiles;
drop policy if exists "Users can update own profile" on public.profiles;
drop policy if exists "Teachers can read profiles" on public.profiles;
drop policy if exists "Logged in users can read study rooms" on public.study_rooms;
drop policy if exists "Teachers can create study rooms" on public.study_rooms;
drop policy if exists "Teachers can update own study rooms" on public.study_rooms;
drop policy if exists "Teachers can delete own study rooms" on public.study_rooms;
drop policy if exists "Logged in users can read room options" on public.study_room_options;
drop policy if exists "Teachers can create room options" on public.study_room_options;
drop policy if exists "Teachers can update own room options" on public.study_room_options;
drop policy if exists "Teachers can delete own room options" on public.study_room_options;
drop policy if exists "Logged in users can read study requests" on public.study_requests;
drop policy if exists "Logged in users can create study requests" on public.study_requests;
drop policy if exists "Students can search student profiles" on public.profiles;
drop policy if exists "Students can read own friends" on public.student_friends;
drop policy if exists "Students can create own friends" on public.student_friends;
drop policy if exists "Students can delete own friends" on public.student_friends;
drop policy if exists "Logged in users can read room plans" on public.study_room_plans;
drop policy if exists "Students can create own room plans" on public.study_room_plans;
drop policy if exists "Students can delete own room plans" on public.study_room_plans;
drop policy if exists "Students can read own study sessions" on public.study_sessions;
drop policy if exists "Students can create own study sessions" on public.study_sessions;
drop policy if exists "Students can update own study sessions" on public.study_sessions;

create policy "Users can read profiles"
on public.profiles
for select
to authenticated
using (id = auth.uid());

create policy "Users can create own profile"
on public.profiles
for insert
to authenticated
with check (
  id = auth.uid()
  and role in ('teacher', 'student')
);

create policy "Users can update own profile"
on public.profiles
for update
to authenticated
using (id = auth.uid())
with check (
  id = auth.uid()
  and role in ('teacher', 'student')
);

create policy "Students can search student profiles"
on public.profiles
for select
to authenticated
using (
  id = auth.uid()
  or role = 'student'
);

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

create policy "Logged in users can read room options"
on public.study_room_options
for select
to authenticated
using (true);

create policy "Teachers can create room options"
on public.study_room_options
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

create policy "Teachers can update own room options"
on public.study_room_options
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

create policy "Teachers can delete own room options"
on public.study_room_options
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

create policy "Logged in users can read study requests"
on public.study_requests
for select
to authenticated
using (true);

create policy "Logged in users can create study requests"
on public.study_requests
for insert
to authenticated
with check (created_by = auth.uid());

create policy "Students can read own friends"
on public.student_friends
for select
to authenticated
using (user_id = auth.uid());

create policy "Students can create own friends"
on public.student_friends
for insert
to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1
    from public.profiles
    where profiles.id = auth.uid()
      and profiles.role = 'student'
  )
  and exists (
    select 1
    from public.profiles friend_profile
    where friend_profile.id = friend_id
      and friend_profile.role = 'student'
  )
);

create policy "Students can delete own friends"
on public.student_friends
for delete
to authenticated
using (user_id = auth.uid());

create policy "Logged in users can read room plans"
on public.study_room_plans
for select
to authenticated
using (true);

create policy "Students can create own room plans"
on public.study_room_plans
for insert
to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1
    from public.profiles
    where profiles.id = auth.uid()
      and profiles.role = 'student'
  )
);

create policy "Students can delete own room plans"
on public.study_room_plans
for delete
to authenticated
using (user_id = auth.uid());

create policy "Students can read own study sessions"
on public.study_sessions
for select
to authenticated
using (user_id = auth.uid());

create policy "Students can create own study sessions"
on public.study_sessions
for insert
to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1
    from public.profiles
    where profiles.id = auth.uid()
      and profiles.role = 'student'
  )
);

create policy "Students can update own study sessions"
on public.study_sessions
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

grant select on public.profiles to authenticated;
grant select, insert, delete on public.student_friends to authenticated;
grant select, insert, delete on public.study_room_plans to authenticated;

do $$
begin
  if to_regclass('public.student_friends_id_seq') is not null then
    grant usage, select on sequence public.student_friends_id_seq to authenticated;
  end if;
  if to_regclass('public.study_room_plans_id_seq') is not null then
    grant usage, select on sequence public.study_room_plans_id_seq to authenticated;
  end if;
end $$;
