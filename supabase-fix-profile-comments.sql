alter table public.profiles
add column if not exists self_comment text not null default '';

alter table public.profiles
drop constraint if exists profiles_self_comment_length;

alter table public.profiles
add constraint profiles_self_comment_length
check (char_length(self_comment) <= 20);

grant select, insert, update on public.profiles to authenticated;
