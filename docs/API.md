# QueueLess Backend API

Postgres RPCs exposed through Supabase (`supabase.rpc(...)`).  
Stack: Supabase Auth (anonymous), Postgres, SQL functions, `pg_cron` (Week 2). Free plan only.

Aligned proposed tables: `locations`, `reports`, `hourly_summaries` (see `docs/DATA_MODEL.md` — Binu).  
Column conventions: `location_id`, `crowd_level`, `wait_minutes`, `user_id`, `created_at`.

**Week 1 implement:** `submit_report`, `get_location_status`  
**Week 1 design / Week 2 implement:** `get_all_statuses`, `get_location_history`, `refresh_hourly_summaries`

---

## Estimator design

Numeric map: `low = 1`, `medium = 2`, `high = 3`.

### Freshness window

Reports older than **60 minutes** are ignored for live status.

| Age of report (minutes) | Weight |
| --- | ---: |
| 0 ≤ age < 15 | 1.00 |
| 15 ≤ age < 30 | 0.75 |
| 30 ≤ age < 45 | 0.50 |
| 45 ≤ age < 60 | 0.25 |
| age ≥ 60 | ignored |

### Crowd level from weighted average

\[
\bar{s} = \frac{\sum_i w_i \cdot s_i}{\sum_i w_i}
\]

Map back:

| \(\bar{s}\) | Crowd level |
| --- | --- |
| \(\bar{s} < 1.5\) | `low` |
| \(1.5 \le \bar{s} < 2.5\) | `medium` |
| \(\bar{s} \ge 2.5\) | `high` |

### Estimated wait

Same weights on non-null `wait_minutes`. If no report in the window has a wait, `estimated_wait_minutes` is `null`.

### Confidence

| Condition | `confidence` |
| --- | --- |
| Zero reports in the last 60 minutes | `none` |
| ≥ 3 reports **and** mean weight ≥ 0.75 | `high` |
| ≥ 2 reports **or** mean weight ≥ 0.5 | `medium` |
| Otherwise | `low` |

Mean weight = \(\frac{\sum w_i}{n}\). When `confidence` is `none`, `crowd_level`, `estimated_wait_minutes`, and `last_updated` are `null`; `report_count` is `0`.

Coordinate these assumptions with Sai’s wait-time estimator MVP (#7).

### Worked examples

**Example 1 — single fresh report**  
One report, age 5 min, `high`, wait 12.

- Weight 1.0 → \(\bar{s} = 3\) → `high`
- Wait = 12
- Mean weight = 1.0, n = 1 → confidence `low` (only one report)

**Example 2 — mixed ages lean newer**  
Reports:

| Age | Level | Score | Weight |
| --- | --- | ---: | ---: |
| 5 min | high | 3 | 1.00 |
| 20 min | medium | 2 | 0.75 |
| 50 min | low | 1 | 0.25 |

- \(\sum w s = 3\cdot1 + 2\cdot0.75 + 1\cdot0.25 = 4.75\)
- \(\sum w = 2.0\)
- \(\bar{s} = 2.375\) → `medium` (newer high + medium pull above 1.5; not yet high)
- Mean weight = \(2.0 / 3 \approx 0.667\) → confidence `medium` (≥ 2 reports)

If the 5-minute report were ignored (hypothetically equal old weights), the average would sit lower — freshness is why the new `high` matters.

**Example 3 — no recent reports**  
Only reports from 90+ minutes ago → all ignored →

```json
{
  "location_id": "…",
  "crowd_level": null,
  "estimated_wait_minutes": null,
  "confidence": "none",
  "last_updated": null,
  "report_count": 0
}
```

---

## Shared types (JSON)

```ts
type CrowdLevel = 'low' | 'medium' | 'high';
type Confidence = 'none' | 'low' | 'medium' | 'high';

type LocationStatus = {
  location_id: string; // uuid
  crowd_level: CrowdLevel | null;
  estimated_wait_minutes: number | null;
  confidence: Confidence;
  last_updated: string | null; // ISO timestamptz
  report_count: number;
};
```

Errors from RPCs surface as Postgres `raise exception` with `ERRCODE` / message; the JS client sees `error.code` / `error.message`.

---

## `submit_report`

Validates input, enforces a **10-minute** per-user / per-location limit, inserts a row into `reports`, returns the new report id.

### Authorized callers

- Role: `authenticated` (anonymous Supabase Auth session required)
- `user_id` is always `auth.uid()` — never accepted from the client

### Inputs

| Name | Type | Required | Rules |
| --- | --- | --- | --- |
| `p_location_id` | `uuid` | yes | Must exist in `locations` |
| `p_crowd_level` | `text` | yes | One of `low`, `medium`, `high` |
| `p_wait_minutes` | `integer` | no | If present: integer 0–180 inclusive |

### Success output (example)

```json
{
  "report_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "location_id": "11111111-2222-3333-4444-555555555555",
  "crowd_level": "medium",
  "wait_minutes": 8,
  "created_at": "2026-10-09T01:00:00+00:00"
}
```

### Errors

| Condition | Message (stable) | HTTP-ish |
| --- | --- | --- |
| Not signed in | `not_authenticated` | 401 |
| Unknown location | `location_not_found` | 404 |
| Invalid `crowd_level` | `invalid_crowd_level` | 400 |
| `wait_minutes` out of range (e.g. 500) | `invalid_wait_minutes` | 400 |
| Report to same location within 10 minutes | `rate_limited` | 429 |

### Call example

```ts
const { data, error } = await supabase.rpc('submit_report', {
  p_location_id: locationId,
  p_crowd_level: 'medium',
  p_wait_minutes: 8,
});
```

---

## `get_location_status`

Returns the live estimate for one location using the estimator above.

### Authorized callers

- Roles: `anon`, `authenticated`

### Inputs

| Name | Type | Required |
| --- | --- | --- |
| `p_location_id` | `uuid` | yes |

### Success output — with recent reports (example)

```json
{
  "location_id": "11111111-2222-3333-4444-555555555555",
  "crowd_level": "medium",
  "estimated_wait_minutes": 10,
  "confidence": "medium",
  "last_updated": "2026-10-09T00:55:00+00:00",
  "report_count": 3
}
```

### Success output — no recent reports

```json
{
  "location_id": "11111111-2222-3333-4444-555555555555",
  "crowd_level": null,
  "estimated_wait_minutes": null,
  "confidence": "none",
  "last_updated": null,
  "report_count": 0
}
```

### Errors

| Condition | Message |
| --- | --- |
| Unknown location | `location_not_found` |

---

## `get_all_statuses` (design — Week 2 implement)

Returns statuses for **every** location in one call for Home. Do **not** call `get_location_status` once per card.

### Authorized callers

- Roles: `anon`, `authenticated`

### Inputs

None.

### Success output (example)

```json
[
  {
    "location_id": "11111111-2222-3333-4444-555555555555",
    "crowd_level": "low",
    "estimated_wait_minutes": 2,
    "confidence": "high",
    "last_updated": "2026-10-09T00:58:00+00:00",
    "report_count": 5
  },
  {
    "location_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
    "crowd_level": null,
    "estimated_wait_minutes": null,
    "confidence": "none",
    "last_updated": null,
    "report_count": 0
  }
]
```

### Errors

None expected under normal conditions (empty array if no locations seeded).

---

## `get_location_history` (design — Week 2 implement)

Returns **7 days × 24 hours** of average busyness from `hourly_summaries`.

### Authorized callers

- Roles: `anon`, `authenticated`

### Inputs

| Name | Type | Required |
| --- | --- | --- |
| `p_location_id` | `uuid` | yes |

### Success output (example)

Grid is dense: one cell per `(weekday, hour)`. Missing cells use `null` average and `sample_count: 0`.

```json
{
  "location_id": "11111111-2222-3333-4444-555555555555",
  "cells": [
    {
      "weekday": 1,
      "hour": 0,
      "avg_crowd_score": 1.2,
      "avg_crowd_level": "low",
      "sample_count": 14
    },
    {
      "weekday": 1,
      "hour": 1,
      "avg_crowd_score": null,
      "avg_crowd_level": null,
      "sample_count": 0
    }
  ]
}
```

`weekday`: ISO-style **1 = Monday … 7 = Sunday**.  
`hour`: 0–23 (UTC for v1; document timezone with Binu if campus-local is preferred).

### Errors

| Condition | Message |
| --- | --- |
| Unknown location | `location_not_found` |

---

## `refresh_hourly_summaries` (design — Week 2 implement)

Hourly `pg_cron` job that rebuilds `hourly_summaries` from `reports` (aggregate by location, weekday, hour).

### Authorized callers

- `service_role` / database cron only — **not** exposed to `anon` or `authenticated`

### Inputs

None (reads all reports needed for the rolling window agreed in DATA_MODEL).

### Success output (example)

```json
{
  "rows_upserted": 840,
  "ran_at": "2026-10-09T01:00:00+00:00"
}
```

### Errors

| Condition | Message |
| --- | --- |
| Called by non-privileged role | `not_authorized` |

### Cron (Week 2)

```sql
select cron.schedule(
  'refresh-hourly-summaries',
  '0 * * * *',
  $$ select public.refresh_hourly_summaries(); $$
);
```

---

## Security notes

1. Enable RLS on `locations`, `reports`, `hourly_summaries`.
2. Clients insert reports **only** through `submit_report` (no direct insert of arbitrary `user_id`).
3. Prefer `SECURITY DEFINER` functions with `set search_path = public` (or empty + qualified names), then `revoke execute from public` and grant to intended roles.
4. Never ship the `service_role` key in the Expo app.

---

## Client call shape (Week 2 `src/services/`)

```ts
await supabase.rpc('get_location_status', { p_location_id: id });
await supabase.rpc('submit_report', {
  p_location_id: id,
  p_crowd_level: level,
  p_wait_minutes: wait,
});
```
