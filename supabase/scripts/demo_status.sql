insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  created_at, updated_at, raw_app_meta_data, raw_user_meta_data, is_super_admin,
  confirmation_token, recovery_token, email_change_token_new, email_change
) values (
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  '00000000-0000-0000-0000-000000000000',
  'authenticated',
  'authenticated',
  'demo@test.local',
  crypt('x', gen_salt('bf')),
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
) on conflict (id) do nothing;

delete from public.reports where user_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc';

insert into public.reports (location_id, user_id, crowd_level, wait_minutes, created_at) values
  ('11111111-1111-1111-1111-111111111111', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'low', 30, now() - interval '50 minutes'),
  ('11111111-1111-1111-1111-111111111111', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'high', 8, now() - interval '5 minutes');

select public.get_location_status('11111111-1111-1111-1111-111111111111'::uuid);
