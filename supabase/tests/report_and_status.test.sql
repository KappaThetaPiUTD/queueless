begin;

create extension if not exists pgtap with schema extensions;
create extension if not exists pgcrypto with schema extensions;

select plan(7);

insert into auth.users (
  id,
  instance_id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at,
  raw_app_meta_data,
  raw_user_meta_data,
  is_super_admin,
  confirmation_token,
  recovery_token,
  email_change_token_new,
  email_change
)
values
  (
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'reporter_a@test.local',
    crypt('password', gen_salt('bf')),
    now(),
    now(),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{}'::jsonb,
    false,
    '',
    '',
    '',
    ''
  ),
  (
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'reporter_b@test.local',
    crypt('password', gen_salt('bf')),
    now(),
    now(),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{}'::jsonb,
    false,
    '',
    '',
    '',
    ''
  )
on conflict (id) do nothing;

insert into public.locations (id, name, category)
values
  ('11111111-1111-1111-1111-111111111111', 'Activity Center', 'gym'),
  ('99999999-9999-9999-9999-999999999999', 'Quiet Spot', 'study')
on conflict (id) do nothing;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","role":"authenticated"}',
  true
);
select set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);

-- 1) Valid report accepted
select lives_ok(
  $$select public.submit_report(
    '11111111-1111-1111-1111-111111111111'::uuid,
    'medium',
    10
  )$$,
  'valid report is accepted'
);

-- 2) Invalid crowd level and wait_minutes=500 rejected
select throws_ok(
  $$select public.submit_report(
    '11111111-1111-1111-1111-111111111111'::uuid,
    'packed',
    10
  )$$,
  'invalid_crowd_level',
  'invalid crowd levels are rejected'
);

select throws_ok(
  $$select public.submit_report(
    '11111111-1111-1111-1111-111111111111'::uuid,
    'low',
    500
  )$$,
  'invalid_wait_minutes',
  'wait_minutes = 500 is rejected'
);

-- 3) Second report within 10 minutes rejected
select throws_ok(
  $$select public.submit_report(
    '11111111-1111-1111-1111-111111111111'::uuid,
    'high',
    5
  )$$,
  'rate_limited',
  'second report within 10 minutes is rejected'
);

-- 4) Cannot insert a report as someone else (no INSERT policy + wrong user_id)
select throws_ok(
  $$insert into public.reports (location_id, user_id, crowd_level, wait_minutes)
    values (
      '11111111-1111-1111-1111-111111111111'::uuid,
      'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid,
      'low',
      1
    )$$,
  '42501',
  null,
  'user cannot insert a report as someone else'
);

-- 5) No recent reports → confidence none
select is(
  public.get_location_status('99999999-9999-9999-9999-999999999999'::uuid)->>'confidence',
  'none',
  'location with no recent reports returns confidence none'
);

-- 6) Mixed old/new reports lean toward newer
reset role;
set local role postgres;

delete from public.reports
where location_id = '11111111-1111-1111-1111-111111111111';

insert into public.reports (location_id, user_id, crowd_level, wait_minutes, created_at)
values
  (
    '11111111-1111-1111-1111-111111111111',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'low',
    30,
    now() - interval '50 minutes'
  ),
  (
    '11111111-1111-1111-1111-111111111111',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    'high',
    5,
    now() - interval '5 minutes'
  );

-- Old low (w=0.25) + fresh high (w=1.0) → avg 2.6 → high (not low)
select is(
  public.get_location_status('11111111-1111-1111-1111-111111111111'::uuid)->>'crowd_level',
  'high',
  'mixed old/new reports lean toward newer reports'
);

select * from finish();
rollback;
