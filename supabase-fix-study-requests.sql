create table if not exists public.study_requests (
  id bigint generated always as identity primary key,
  room_id bigint references public.study_rooms(id) on delete cascade,
  room_option_id bigint references public.study_room_options(id) on delete cascade,
  room_location text,
  request_date date,
  request_time text,
  created_by uuid references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.study_requests
add column if not exists room_id bigint references public.study_rooms(id) on delete cascade;

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

alter table public.study_requests
add column if not exists created_at timestamptz not null default now();

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

alter table public.study_requests enable row level security;

drop policy if exists "Logged in users can read study requests" on public.study_requests;
drop policy if exists "Logged in users can create study requests" on public.study_requests;

create policy "Logged in users can read study requests"
on public.study_requests
for select
to authenticated
using (created_by = auth.uid());

create policy "Logged in users can create study requests"
on public.study_requests
for insert
to authenticated
with check (
  created_by = auth.uid()
  and exists (
    select 1 from public.profiles
    where profiles.id = auth.uid() and profiles.role = 'student'
  )
);
