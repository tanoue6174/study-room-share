begin;

create or replace function public.current_user_has_role(required_role text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and role = required_role
  );
$$;

revoke all on function public.current_user_has_role(text) from public;
grant execute on function public.current_user_has_role(text) to authenticated;

create or replace function public.prevent_profile_identity_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() = old.id then
    if new.role is distinct from old.role then
      raise exception 'profile role cannot be changed';
    end if;
    if new.login_id is distinct from old.login_id then
      raise exception 'profile login_id cannot be changed';
    end if;
  end if;
  return new;
end;
$$;

revoke all on function public.prevent_profile_identity_change() from public;
drop trigger if exists prevent_profile_identity_change on public.profiles;
create trigger prevent_profile_identity_change
before update on public.profiles
for each row execute function public.prevent_profile_identity_change();

drop policy if exists "Users can create own profile" on public.profiles;
drop policy if exists "Users can update own profile" on public.profiles;
drop policy if exists "Users can create own student profile" on public.profiles;
drop policy if exists "Users can update own profile without changing identity" on public.profiles;

create policy "Users can create own student profile"
on public.profiles
for insert
to authenticated
with check (
  id = auth.uid()
  and role = 'student'
);

create policy "Users can update own profile without changing identity"
on public.profiles
for update
to authenticated
using (id = auth.uid())
with check (
  id = auth.uid()
  and role in ('teacher', 'student')
);

drop policy if exists "Teachers can create study rooms" on public.study_rooms;
drop policy if exists "Teachers can update own study rooms" on public.study_rooms;
drop policy if exists "Teachers can delete own study rooms" on public.study_rooms;

create policy "Teachers can create study rooms"
on public.study_rooms
for insert
to authenticated
with check (
  created_by = auth.uid()
  and public.current_user_has_role('teacher')
);

create policy "Teachers can update own study rooms"
on public.study_rooms
for update
to authenticated
using (
  created_by = auth.uid()
  and public.current_user_has_role('teacher')
)
with check (
  created_by = auth.uid()
  and public.current_user_has_role('teacher')
);

create policy "Teachers can delete own study rooms"
on public.study_rooms
for delete
to authenticated
using (
  created_by = auth.uid()
  and public.current_user_has_role('teacher')
);

drop policy if exists "Teachers can create room options" on public.study_room_options;
drop policy if exists "Teachers can update own room options" on public.study_room_options;
drop policy if exists "Teachers can delete own room options" on public.study_room_options;

create policy "Teachers can create room options"
on public.study_room_options
for insert
to authenticated
with check (
  created_by = auth.uid()
  and public.current_user_has_role('teacher')
);

create policy "Teachers can update own room options"
on public.study_room_options
for update
to authenticated
using (
  created_by = auth.uid()
  and public.current_user_has_role('teacher')
)
with check (
  created_by = auth.uid()
  and public.current_user_has_role('teacher')
);

create policy "Teachers can delete own room options"
on public.study_room_options
for delete
to authenticated
using (
  created_by = auth.uid()
  and public.current_user_has_role('teacher')
);

drop policy if exists "Logged in users can read study requests" on public.study_requests;
drop policy if exists "Logged in users can create study requests" on public.study_requests;
drop policy if exists "Users can read own study requests" on public.study_requests;
drop policy if exists "Students can create own study requests" on public.study_requests;

create policy "Users can read own study requests"
on public.study_requests
for select
to authenticated
using (created_by = auth.uid());

create policy "Students can create own study requests"
on public.study_requests
for insert
to authenticated
with check (
  created_by = auth.uid()
  and public.current_user_has_role('student')
);

drop policy if exists "Logged in users can read room plans" on public.study_room_plans;
drop policy if exists "Users can read own and friends room plans" on public.study_room_plans;

create policy "Users can read own and friends room plans"
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

create or replace function public.get_study_room_plan_counts()
returns table (room_id bigint, planned_count bigint)
language sql
stable
security definer
set search_path = public
as $$
  select plans.room_id, count(*)::bigint as planned_count
  from public.study_room_plans plans
  where auth.uid() is not null
  group by plans.room_id;
$$;

revoke all on function public.get_study_room_plan_counts() from public;
grant execute on function public.get_study_room_plan_counts() to authenticated;

drop policy if exists "Authenticated users can read active receptions" on public.study_receptions;
drop policy if exists "Teachers can create own receptions" on public.study_receptions;
drop policy if exists "Teachers can delete own receptions" on public.study_receptions;
drop policy if exists "Authenticated users can read reception votes" on public.study_reception_votes;
drop policy if exists "Students can vote once" on public.study_reception_votes;
drop policy if exists "Authenticated users can read current receptions" on public.study_receptions;
drop policy if exists "Users can read permitted reception votes" on public.study_reception_votes;
drop policy if exists "Students can vote on current receptions" on public.study_reception_votes;

with ranked_receptions as (
  select
    id,
    row_number() over (
      partition by created_by, room_option_id, reception_date
      order by created_at desc, id desc
    ) as duplicate_number
  from public.study_receptions
  where active = true
)
update public.study_receptions receptions
set active = false
from ranked_receptions ranked
where receptions.id = ranked.id
  and ranked.duplicate_number > 1;

create unique index if not exists study_receptions_one_active_date_idx
on public.study_receptions (created_by, room_option_id, reception_date)
where active = true;

create policy "Authenticated users can read current receptions"
on public.study_receptions
for select
to authenticated
using (
  active = true
  and reception_date >= current_date
);

create policy "Teachers can create own receptions"
on public.study_receptions
for insert
to authenticated
with check (
  created_by = auth.uid()
  and active = true
  and reception_date >= current_date
  and public.current_user_has_role('teacher')
  and exists (
    select 1
    from public.study_room_options options
    where options.id = room_option_id
      and options.created_by = auth.uid()
      and options.accepts_requests = true
  )
);

create policy "Teachers can delete own receptions"
on public.study_receptions
for delete
to authenticated
using (
  created_by = auth.uid()
  and public.current_user_has_role('teacher')
);

create policy "Users can read permitted reception votes"
on public.study_reception_votes
for select
to authenticated
using (
  student_id = auth.uid()
  or (
    public.current_user_has_role('teacher')
    and exists (
      select 1
      from public.study_receptions receptions
      where receptions.id = reception_id
        and receptions.created_by = auth.uid()
    )
  )
);

create policy "Students can vote on current receptions"
on public.study_reception_votes
for insert
to authenticated
with check (
  student_id = auth.uid()
  and public.current_user_has_role('student')
  and exists (
    select 1
    from public.study_receptions receptions
    where receptions.id = reception_id
      and receptions.active = true
      and receptions.reception_date >= current_date
  )
);

alter table public.study_sessions
add column if not exists ended_at timestamptz;

update public.study_sessions
set ends_at = null
where ends_at is not null
  and ends_at !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$|^24:00$';

alter table public.study_sessions
drop constraint if exists study_sessions_ends_at_format;

alter table public.study_sessions
add constraint study_sessions_ends_at_format
check (
  ends_at is null
  or ends_at ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$|^24:00$'
);

with ranked_sessions as (
  select
    id,
    row_number() over (
      partition by user_id
      order by started_at desc, id desc
    ) as duplicate_number
  from public.study_sessions
  where active = true
)
update public.study_sessions sessions
set active = false,
    ended_at = coalesce(sessions.ended_at, now())
from ranked_sessions ranked
where sessions.id = ranked.id
  and ranked.duplicate_number > 1;

create unique index if not exists study_sessions_one_active_user_idx
on public.study_sessions (user_id)
where active = true;

drop policy if exists "Students can create own study sessions" on public.study_sessions;
drop policy if exists "Students can update own study sessions" on public.study_sessions;
drop policy if exists "Students can delete ended study sessions" on public.study_sessions;
drop policy if exists "Students can delete own ended study sessions" on public.study_sessions;

create policy "Students can create own study sessions"
on public.study_sessions
for insert
to authenticated
with check (
  user_id = auth.uid()
  and public.current_user_has_role('student')
);

create policy "Students can update own study sessions"
on public.study_sessions
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "Students can delete own ended study sessions"
on public.study_sessions
for delete
to authenticated
using (
  user_id = auth.uid()
  and active = false
);

notify pgrst, 'reload schema';

commit;
