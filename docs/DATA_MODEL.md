# QueueLess Data Model (proposed — Binu leads)

This file proposes table/column names so `docs/API.md` and migrations can stay aligned. **Binu owns final wording**; update this doc when the review PR lands.

## Tables

### `locations`
| Column | Type | Notes |
| --- | --- | --- |
| `id` | `uuid` PK | |
| `name` | `text` | |
| `category` | enum `dining\|gym\|library\|advising\|study` | |
| `latitude` | `float8` nullable | |
| `longitude` | `float8` nullable | |
| `open_hours` | `text` nullable | |
| `created_at` | `timestamptz` | |

### `reports`
| Column | Type | Notes |
| --- | --- | --- |
| `id` | `uuid` PK | |
| `location_id` | `uuid` FK → locations | |
| `user_id` | `uuid` FK → auth.users | Always from `auth.uid()` via RPC |
| `crowd_level` | enum `low\|medium\|high` | |
| `wait_minutes` | `int` nullable | 0–180 if present |
| `created_at` | `timestamptz` | |

### `hourly_summaries`
| Column | Type | Notes |
| --- | --- | --- |
| `location_id` | `uuid` FK | |
| `weekday` | `smallint` | 1=Mon … 7=Sun |
| `hour` | `smallint` | 0–23 |
| `avg_crowd_score` | `numeric` nullable | 1–3 scale |
| `sample_count` | `int` | |
| `updated_at` | `timestamptz` | |
| PK | `(location_id, weekday, hour)` | |

## RLS summary
- `locations`, `hourly_summaries`: public read
- `reports`: public read; **no client INSERT/UPDATE/DELETE** — only `submit_report`
- Writes to summaries: `refresh_hourly_summaries` (service/cron) in Week 2

## Confidence
Live status uses `confidence: none | low | medium | high`. `none` means no reports in the last ~60 minutes (see `docs/API.md`).
