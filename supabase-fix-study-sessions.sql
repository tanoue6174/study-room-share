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

alter table public.study_sessions enable row level security;

drop policy if exists "Students can read own study sessions" on public.study_sessions;
drop policy if exists "Students can read friends active study sessions" on public.study_sessions;
drop policy if exists "Students can create own study sessions" on public.study_sessions;
drop policy if exists "Students can update own study sessions" on public.study_sessions;

create policy "Students can read own study sessions"
on public.study_sessions
for select
to authenticated
using (user_id = auth.uid());

create policy "Students can read friends active study sessions"
on public.study_sessions
for select
to authenticated
using (
  active = true
  and exists (
    select 1
    from public.student_friends
    where (
      student_friends.user_id = auth.uid()
      and student_friends.friend_id = study_sessions.user_id
    )
    or (
      student_friends.friend_id = auth.uid()
      and student_friends.user_id = study_sessions.user_id
    )
  )
);

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

grant select, insert, update on public.study_sessions to authenticated;

do $$
begin
  if to_regclass('public.study_sessions_id_seq') is not null then
    grant usage, select on sequence public.study_sessions_id_seq to authenticated;
  end if;
end $$;

notify pgrst, 'reload schema';
