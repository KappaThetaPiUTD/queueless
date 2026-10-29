begin;

create extension if not exists pgtap with schema extensions;
create extension if not exists pgcrypto with schema extensions;

select plan(28);

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

-- Week 3 regression cases. Owner fixtures are created above; client behavior uses real roles.
reset role;
delete from public.reports where location_id = '11111111-1111-1111-1111-111111111111';
set local role authenticated;
select lives_ok($$select public.submit_report('11111111-1111-1111-1111-111111111111', 'low', 0)$$,
  'zero wait accepted');
select is(public.get_location_status('11111111-1111-1111-1111-111111111111')->>'confidence', 'low',
  'single fresh report has low confidence');
select is(public.get_location_status('11111111-1111-1111-1111-111111111111')->>'estimated_wait_minutes', '0',
  'zero wait is preserved');
select throws_ok($$select public.submit_report('99999999-9999-9999-9999-999999999999', 'low', -1)$$,
  '22023', 'invalid_wait_minutes', 'minus one rejected');
select throws_ok($$select public.submit_report('99999999-9999-9999-9999-999999999999', 'low', 121)$$,
  '22023', 'invalid_wait_minutes', '121 rejected');
select lives_ok($$select public.submit_report('99999999-9999-9999-9999-999999999999', 'high', 120)$$,
  '120 accepted at independent location');
select throws_ok($$select * from public.reports$$, '42501', null, 'authenticated cannot read raw reports');
select throws_ok($$update public.reports set wait_minutes = 1$$, '42501', null, 'authenticated cannot update raw reports');
select throws_ok($$delete from public.reports$$, '42501', null, 'authenticated cannot delete raw reports');
select set_config('request.jwt.claim.sub', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true);
select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb","role":"authenticated"}', true);
select lives_ok($$select public.submit_report('11111111-1111-1111-1111-111111111111', 'high', null)$$,
  'independent user accepted with null wait');
reset role;
insert into public.locations (id, name, category, is_active) values
  ('88888888-8888-8888-8888-888888888888', 'Inactive fixture', 'study', false),
  ('77777777-7777-7777-7777-777777777777', 'Empty fixture', 'study', true);
select throws_ok($$insert into public.reports(location_id,user_id,crowd_level,wait_minutes)
  values ('77777777-7777-7777-7777-777777777777','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','low',121)$$,
  '23514', null, 'table constraint independently rejects 121');
set local role anon;
select throws_ok($$select * from public.reports$$, '42501', null, 'anon cannot read raw reports');
select throws_ok($$select public.submit_report('11111111-1111-1111-1111-111111111111','low',null)$$,
  '42501', null, 'anon cannot execute submit RPC');
select lives_ok($$select * from public.locations$$, 'anon can read locations');
select is(jsonb_array_length(public.get_all_statuses()),
  (select count(*)::integer from public.locations where is_active), 'Home returns every active location');
select ok(not exists(select 1 from jsonb_array_elements(public.get_all_statuses()) s
  where s->>'location_id' = '88888888-8888-8888-8888-888888888888'), 'Home excludes inactive location');
select is(public.get_location_status('77777777-7777-7777-7777-777777777777'),
  '{"location_id":"77777777-7777-7777-7777-777777777777","crowd_level":null,"estimated_wait_minutes":null,"confidence":"none","last_updated":null,"report_count":0}'::jsonb,
  'no data preserves every null field');
select ok(exists(select 1 from jsonb_array_elements(public.get_all_statuses()) s
  where s->>'location_id' = '77777777-7777-7777-7777-777777777777' and s->>'confidence' = 'none'),
  'Home includes no-report location');
select throws_ok($$select public.get_location_status('88888888-8888-8888-8888-888888888888')$$,
  'P0002', 'location_not_found', 'inactive detail is missing');
select throws_ok($$select public.get_location_status('00000000-0000-0000-0000-000000000000')$$,
  'P0002', 'location_not_found', 'unknown detail is missing');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claims', '{}', true);
select throws_ok($$select public.submit_report('11111111-1111-1111-1111-111111111111','low',null)$$,
  '28000', 'not_authenticated', 'authenticated role still requires identity');
reset role;
select * from finish();
rollback;
