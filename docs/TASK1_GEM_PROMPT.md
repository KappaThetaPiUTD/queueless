# Task 1 — Gemini Gem prompt and expected answer

Use this after you create a Gem named **QueueLess** and upload `CONTEXT.md`, the handout PDF, and your Week 1 task list.

## Correction to tell the Gem first

> Supabase supersedes the Firebase references in CONTEXT.md. Stack is Expo + React Native + TypeScript with `@supabase/supabase-js`, Supabase Auth (anonymous), Postgres, SQL database functions, and scheduled jobs (pg_cron). Free plan only. Do not suggest Firebase.

## Ask

> Based on my files, explain QueueLess, what the backend is responsible for, and what my tasks are this week.

## Expected answer (sanity-check / screenshot target)

**What QueueLess is:** An app for UTD students that shows how crowded a campus spot is before they walk there. Each location shows Low/Medium/High crowd level, estimated wait time, and freshness. Students submit crowd reports (optional wait). History shows usual busy times by weekday/hour. Research candidates include Activity Center, JSOM, McDermott Library, Starbucks, and popular study spots. Dec 3 demo: list locations → live status → submit report → see estimate change → view History.

**Backend responsibilities (Supabase/Postgres):**
- Store and protect reports (RLS + auth)
- Validate and rate-limit submissions (10 minutes per user per location)
- Compute recent crowd estimates (ignore reports older than ~60 minutes)
- Aggregate history by weekday/hour
- Seed realistic demo data
- Expose RPCs the Expo app calls via `@supabase/supabase-js`

**My Week 1 tasks (Punit):**
1. AI context chat (Copilot + QueueLess Gem) and post screenshot
2. Install tools, accept Supabase org invite, `supabase init` / `start`, PR the `supabase/` folder
3. Design `docs/API.md` (all RPCs + estimator with worked examples); review Binu’s `DATA_MODEL.md`
4. Local prototype: Postgres functions `submit_report` and `get_location_status` + six pgTAP tests
5. Coordinate CONTEXT/types migration from Firebase → Supabase with Binu (`confidence: none` when no recent reports)

**Not Week 1 implementation:** hosted deploy, `get_all_statuses`, `get_location_history`, hourly job, and `src/services/` wrappers (design this week, build next week).

## Evidence

Screenshot the Gem’s answer and post it on your GitHub issue with a short note that Supabase replaced Firebase.
