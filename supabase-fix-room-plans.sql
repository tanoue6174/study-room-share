create table if not exists public.study_room_plans (
  id bigint generated always as identity primary key,
  room_id bigint not null references public.study_rooms(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (room_id, user_id)
);

create unique index if not exists study_room_plans_room_user_idx
on public.study_room_plans (room_id, user_id);

alter table public.study_room_plans enable row level security;

drop policy if exists "Logged in users can read room plans" on public.study_room_plans;
drop policy if exists "Students can create own room plans" on public.study_room_plans;
drop policy if exists "Students can delete own room plans" on public.study_room_plans;

create policy "Logged in users can read room plans"
on public.study_room_plans
for select
to authenticated
using (
  user_id = auth.uid()
  or exists (
    select 1
    from public.student_friends
    where (
      student_friends.user_id = auth.uid()
      and student_friends.friend_id = study_room_plans.user_id
    )
    or (
      student_friends.friend_id = auth.uid()
      and student_friends.user_id = study_room_plans.user_id
    )
  )
);

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

grant select, insert, delete on public.study_room_plans to authenticated;

create or replace function public.get_study_room_plan_counts()
returns table (room_id bigint, planned_count bigint)
language sql
stable
security definer
set search_path = public
as $$
  select plans.room_id, count(*)::bigint
  from public.study_room_plans plans
  where auth.uid() is not null
  group by plans.room_id;
$$;

revoke all on function public.get_study_room_plan_counts() from public;
grant execute on function public.get_study_room_plan_counts() to authenticated;

do $$
begin
  if to_regclass('public.study_room_plans_id_seq') is not null then
    grant usage, select on sequence public.study_room_plans_id_seq to authenticated;
  end if;
end $$;
