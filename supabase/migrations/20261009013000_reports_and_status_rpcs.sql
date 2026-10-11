-- QueueLess Week 1: locations/reports schema + submit_report + get_location_status

create extension if not exists pgcrypto with schema extensions;

create type public.crowd_level as enum ('low', 'medium', 'high');
create type public.confidence_level as enum ('none', 'low', 'medium', 'high');
create type public.location_category as enum ('dining', 'gym', 'library', 'advising', 'study');

create table public.locations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category public.location_category not null,
  latitude double precision,
  longitude double precision,
  open_hours text,
  created_at timestamptz not null default now()
);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  location_id uuid not null references public.locations (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  crowd_level public.crowd_level not null,
  wait_minutes integer check (
    wait_minutes is null
    or (wait_minutes >= 0 and wait_minutes <= 180)
  ),
  created_at timestamptz not null default now()
);

create index reports_location_created_at_idx
  on public.reports (location_id, created_at desc);

create index reports_user_location_created_at_idx
  on public.reports (user_id, location_id, created_at desc);

create table public.hourly_summaries (
  location_id uuid not null references public.locations (id) on delete cascade,
  weekday smallint not null check (weekday between 1 and 7),
  hour smallint not null check (hour between 0 and 23),
  avg_crowd_score numeric(6, 3),
  sample_count integer not null default 0,
  updated_at timestamptz not null default now(),
  primary key (location_id, weekday, hour)
);

alter table public.locations enable row level security;
alter table public.reports enable row level security;
alter table public.hourly_summaries enable row level security;

create policy "locations_select_all"
  on public.locations for select
  to anon, authenticated
  using (true);

create policy "reports_select_authenticated"
  on public.reports for select
  to authenticated
  using (true);

create policy "reports_select_anon"
  on public.reports for select
  to anon
  using (true);

-- No direct inserts into reports; use submit_report RPC.
create policy "hourly_summaries_select_all"
  on public.hourly_summaries for select
  to anon, authenticated
  using (true);

-- Freshness weight helper
create or replace function public.report_freshness_weight(p_age_minutes numeric)
returns numeric
language sql
immutable
as $$
  select case
    when p_age_minutes < 0 then 0
    when p_age_minutes < 15 then 1.0
    when p_age_minutes < 30 then 0.75
    when p_age_minutes < 45 then 0.50
    when p_age_minutes < 60 then 0.25
    else 0
  end;
$$;

create or replace function public.submit_report(
  p_location_id uuid,
  p_crowd_level text,
  p_wait_minutes integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_level public.crowd_level;
  v_row public.reports%rowtype;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  if not exists (select 1 from public.locations l where l.id = p_location_id) then
    raise exception 'location_not_found' using errcode = 'P0002';
  end if;

  if p_crowd_level is null or p_crowd_level not in ('low', 'medium', 'high') then
    raise exception 'invalid_crowd_level' using errcode = '22023';
  end if;
  v_level := p_crowd_level::public.crowd_level;

  if p_wait_minutes is not null and (p_wait_minutes < 0 or p_wait_minutes > 180) then
    raise exception 'invalid_wait_minutes' using errcode = '22023';
  end if;

  if exists (
    select 1
    from public.reports r
    where r.user_id = v_uid
      and r.location_id = p_location_id
      and r.created_at > now() - interval '10 minutes'
  ) then
    raise exception 'rate_limited' using errcode = 'P0001';
  end if;

  insert into public.reports (location_id, user_id, crowd_level, wait_minutes)
  values (p_location_id, v_uid, v_level, p_wait_minutes)
  returning * into v_row;

  return jsonb_build_object(
    'report_id', v_row.id,
    'location_id', v_row.location_id,
    'crowd_level', v_row.crowd_level,
    'wait_minutes', v_row.wait_minutes,
    'created_at', v_row.created_at
  );
end;
$$;

create or replace function public.get_location_status(p_location_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_score_sum numeric := 0;
  v_weight_sum numeric := 0;
  v_wait_sum numeric := 0;
  v_wait_weight_sum numeric := 0;
  v_count integer := 0;
  v_mean_weight numeric;
  v_avg numeric;
  v_crowd text;
  v_wait numeric;
  v_confidence text;
  v_last timestamptz;
  r record;
  v_age numeric;
  v_w numeric;
  v_score numeric;
begin
  if not exists (select 1 from public.locations l where l.id = p_location_id) then
    raise exception 'location_not_found' using errcode = 'P0002';
  end if;

  for r in
    select crowd_level, wait_minutes, created_at
    from public.reports
    where location_id = p_location_id
      and created_at > now() - interval '60 minutes'
  loop
    v_age := extract(epoch from (now() - r.created_at)) / 60.0;
    v_w := public.report_freshness_weight(v_age);
    if v_w <= 0 then
      continue;
    end if;

    v_score := case r.crowd_level
      when 'low' then 1
      when 'medium' then 2
      when 'high' then 3
    end;

    v_score_sum := v_score_sum + v_w * v_score;
    v_weight_sum := v_weight_sum + v_w;
    v_count := v_count + 1;

    if r.wait_minutes is not null then
      v_wait_sum := v_wait_sum + v_w * r.wait_minutes;
      v_wait_weight_sum := v_wait_weight_sum + v_w;
    end if;

    if v_last is null or r.created_at > v_last then
      v_last := r.created_at;
    end if;
  end loop;

  if v_count = 0 or v_weight_sum = 0 then
    return jsonb_build_object(
      'location_id', p_location_id,
      'crowd_level', null,
      'estimated_wait_minutes', null,
      'confidence', 'none',
      'last_updated', null,
      'report_count', 0
    );
  end if;

  v_avg := v_score_sum / v_weight_sum;
  v_crowd := case
    when v_avg < 1.5 then 'low'
    when v_avg < 2.5 then 'medium'
    else 'high'
  end;

  if v_wait_weight_sum > 0 then
    v_wait := round(v_wait_sum / v_wait_weight_sum);
  else
    v_wait := null;
  end if;

  v_mean_weight := v_weight_sum / v_count;
  if v_count >= 3 and v_mean_weight >= 0.75 then
    v_confidence := 'high';
  elsif v_count >= 2 or v_mean_weight >= 0.5 then
    v_confidence := 'medium';
  else
    v_confidence := 'low';
  end if;

  return jsonb_build_object(
    'location_id', p_location_id,
    'crowd_level', v_crowd,
    'estimated_wait_minutes', v_wait,
    'confidence', v_confidence,
    'last_updated', v_last,
    'report_count', v_count
  );
end;
$$;

revoke all on function public.submit_report(uuid, text, integer) from public;
revoke all on function public.get_location_status(uuid) from public;
revoke all on function public.report_freshness_weight(numeric) from public;

grant execute on function public.submit_report(uuid, text, integer) to authenticated;
grant execute on function public.get_location_status(uuid) to anon, authenticated;
grant execute on function public.report_freshness_weight(numeric) to anon, authenticated;
