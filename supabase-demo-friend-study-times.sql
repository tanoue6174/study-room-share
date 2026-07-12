-- 発表用デモデータ
-- tanoue を中心に、Aさん・Bさん・Cさんを友達にして今週の勉強時間を追加します。

with center_user as (
  select id
  from public.profiles
  where role = 'student'
    and (display_name = 'tanoue' or login_id = 'tanoue')
  limit 1
),
demo_friends as (
  select id, display_name
  from public.profiles
  where role = 'student'
    and display_name in ('Aさん', 'Bさん', 'Cさん')
)
insert into public.student_friends (user_id, friend_id, friend_name)
select center_user.id, demo_friends.id, demo_friends.display_name
from center_user
cross join demo_friends
on conflict (user_id, friend_id) do update
set friend_name = excluded.friend_name;

with demo_friends as (
  select id
  from public.profiles
  where role = 'student'
    and display_name in ('Aさん', 'Bさん', 'Cさん')
)
delete from public.study_sessions
using demo_friends
where study_sessions.user_id = demo_friends.id
  and study_sessions.room_name = '発表用デモ'
  and study_sessions.started_at >= date_trunc('week', now());

with demo_plans(name, day_offset, start_time, minutes) as (
  values
    ('Aさん', 0, time '16:00', 120),
    ('Aさん', 1, time '17:00', 150),
    ('Aさん', 2, time '16:30', 120),
    ('Bさん', 0, time '15:30', 90),
    ('Bさん', 3, time '17:00', 150),
    ('Cさん', 1, time '16:00', 180),
    ('Cさん', 2, time '15:30', 150),
    ('Cさん', 4, time '16:30', 165)
),
demo_sessions as (
  select
    profiles.id as user_id,
    date_trunc('week', now())
      + (demo_plans.day_offset || ' days')::interval
      + (demo_plans.start_time - time '00:00') as started_at,
    demo_plans.minutes
  from demo_plans
  join public.profiles on profiles.display_name = demo_plans.name
  where profiles.role = 'student'
)
insert into public.study_sessions (
  user_id,
  room_id,
  room_name,
  location,
  ends_at,
  active,
  started_at,
  ended_at
)
select
  user_id,
  null,
  '発表用デモ',
  '',
  null,
  false,
  started_at,
  started_at + make_interval(mins => minutes)
from demo_sessions;
