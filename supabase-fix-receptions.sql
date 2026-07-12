create table if not exists public.study_receptions (
  id bigint generated always as identity primary key,
  room_option_id bigint not null references public.study_room_options(id) on delete cascade,
  room_name text not null,
  reception_date date not null,
  created_by uuid not null references auth.users(id) on delete cascade,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.study_reception_votes (
  id bigint generated always as identity primary key,
  reception_id bigint not null references public.study_receptions(id) on delete cascade,
  student_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (reception_id, student_id)
);

alter table public.study_receptions enable row level security;
alter table public.study_reception_votes enable row level security;

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

drop policy if exists "Authenticated users can read active receptions" on public.study_receptions;
drop policy if exists "Teachers can create own receptions" on public.study_receptions;
drop policy if exists "Teachers can delete own receptions" on public.study_receptions;
drop policy if exists "Authenticated users can read reception votes" on public.study_reception_votes;
drop policy if exists "Students can vote once" on public.study_reception_votes;

create policy "Authenticated users can read active receptions"
on public.study_receptions for select to authenticated
using (
  active = true
  and reception_date >= current_date
);

create policy "Teachers can create own receptions"
on public.study_receptions for insert to authenticated
with check (
  created_by = auth.uid()
  and exists (select 1 from public.profiles where id = auth.uid() and role = 'teacher')
  and exists (
    select 1 from public.study_room_options
    where study_room_options.id = room_option_id
      and study_room_options.created_by = auth.uid()
      and study_room_options.accepts_requests = true
  )
  and reception_date >= current_date
);

create policy "Teachers can delete own receptions"
on public.study_receptions for delete to authenticated
using (
  created_by = auth.uid()
  and exists (select 1 from public.profiles where id = auth.uid() and role = 'teacher')
);

create policy "Authenticated users can read reception votes"
on public.study_reception_votes for select to authenticated
using (
  student_id = auth.uid()
  or exists (
    select 1
    from public.study_receptions
    where study_receptions.id = reception_id
      and study_receptions.created_by = auth.uid()
      and exists (
        select 1 from public.profiles
        where profiles.id = auth.uid() and profiles.role = 'teacher'
      )
  )
);

create policy "Students can vote once"
on public.study_reception_votes for insert to authenticated
with check (
  student_id = auth.uid()
  and exists (select 1 from public.profiles where id = auth.uid() and role = 'student')
  and exists (
    select 1 from public.study_receptions
    where study_receptions.id = reception_id
      and study_receptions.active = true
      and study_receptions.reception_date >= current_date
  )
);

grant select, insert, delete on public.study_receptions to authenticated;
grant select, insert on public.study_reception_votes to authenticated;
grant usage, select on all sequences in schema public to authenticated;

notify pgrst, 'reload schema';
