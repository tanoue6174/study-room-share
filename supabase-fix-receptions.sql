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

drop policy if exists "Authenticated users can read active receptions" on public.study_receptions;
drop policy if exists "Teachers can create own receptions" on public.study_receptions;
drop policy if exists "Teachers can delete own receptions" on public.study_receptions;
drop policy if exists "Authenticated users can read reception votes" on public.study_reception_votes;
drop policy if exists "Students can vote once" on public.study_reception_votes;

create policy "Authenticated users can read active receptions"
on public.study_receptions for select to authenticated
using (active = true);

create policy "Teachers can create own receptions"
on public.study_receptions for insert to authenticated
with check (
  created_by = auth.uid()
  and exists (select 1 from public.profiles where id = auth.uid() and role = 'teacher')
);

create policy "Teachers can delete own receptions"
on public.study_receptions for delete to authenticated
using (
  created_by = auth.uid()
  and exists (select 1 from public.profiles where id = auth.uid() and role = 'teacher')
);

create policy "Authenticated users can read reception votes"
on public.study_reception_votes for select to authenticated
using (true);

create policy "Students can vote once"
on public.study_reception_votes for insert to authenticated
with check (
  student_id = auth.uid()
  and exists (select 1 from public.profiles where id = auth.uid() and role = 'student')
);

grant select, insert, delete on public.study_receptions to authenticated;
grant select, insert on public.study_reception_votes to authenticated;
grant usage, select on all sequences in schema public to authenticated;

notify pgrst, 'reload schema';
