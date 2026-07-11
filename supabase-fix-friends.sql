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

alter table public.student_friends enable row level security;

drop policy if exists "Students can search student profiles" on public.profiles;
drop policy if exists "Students can read own friends" on public.student_friends;
drop policy if exists "Students can create own friends" on public.student_friends;
drop policy if exists "Students can delete own friends" on public.student_friends;

create policy "Students can search student profiles"
on public.profiles
for select
to authenticated
using (
  id = auth.uid()
  or role = 'student'
);

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

grant select on public.profiles to authenticated;
grant select, insert, delete on public.student_friends to authenticated;

do $$
begin
  if to_regclass('public.student_friends_id_seq') is not null then
    grant usage, select on sequence public.student_friends_id_seq to authenticated;
  end if;
end $$;
