-- Demo locations for local development (UUIDs fixed for tests/docs).
insert into public.locations (id, name, category, open_hours) values
  ('11111111-1111-1111-1111-111111111111', 'Activity Center', 'gym', '6am–11pm'),
  ('22222222-2222-2222-2222-222222222222', 'JSOM Cafe', 'dining', '8am–6pm'),
  ('33333333-3333-3333-3333-333333333333', 'McDermott Library', 'library', '7am–2am'),
  ('44444444-4444-4444-4444-444444444444', 'Starbucks (SU)', 'dining', '7am–9pm'),
  ('55555555-5555-5555-5555-555555555555', 'ECS Study Commons', 'study', '24h');
