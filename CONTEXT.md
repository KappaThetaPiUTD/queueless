# QueueLess — Context for AI Assistants
Paste this whole file into your AI tool (ChatGPT, Gemini, Copilot, Claude, Perplexity) before asking it to write code for this project.

## What we're building
QueueLess shows how crowded UTD campus locations are (dining, gym, library, advising, study spots). Students submit quick crowd reports; the app shows Low/Medium/High status, an estimated wait time, and a history chart. Keep things simple: a working MVP beats an advanced unfinished feature.

## Stack (do not suggest alternatives)
- Expo (managed workflow) + React Native + TypeScript
- Expo Router for navigation
- Supabase: Postgres (database), Anonymous Auth, SQL database functions, scheduled jobs (`pg_cron`) as needed — free plan only
- Client: `@supabase/supabase-js`
- Python + pandas + scikit-learn for data/ML (in /data, optional)
- No Redux. Use React state/hooks. No extra UI libraries unless the team agrees.
- Supabase supersedes any older Firebase references in notes or handouts.

## Folder structure
app/                  Screens (Expo Router): index.tsx (Home), location/[id].tsx, report/[id].tsx, history/[id].tsx
src/components/       Reusable UI (e.g., CrowdStatusCard.tsx)
src/services/         Supabase client + data RPCs (Week 2)
src/utils/            Helpers (e.g., estimator.ts for wait-time logic if needed client-side)
src/types.ts          Shared data types — the single source of truth
supabase/             Local Supabase config, migrations, pgTAP tests
docs/                 API.md (RPCs + estimator), DATA_MODEL.md (tables — Binu)
data/                 Python scripts/notebooks for analysis and ML

## Conventions
- Components: PascalCase files and names (CrowdStatusCard.tsx)
- Functions/variables: camelCase in TypeScript (getRecentReports); SQL uses snake_case
- Postgres tables: lowercase plural (locations, reports, hourly_summaries)
- Always import types from src/types.ts; never redefine them
- Functional components with hooks only
- Every screen handles loading, empty, and error states
- Never commit Supabase service_role secrets; use .env for URL + anon/publishable key

## Git workflow
- Never push to main. Branch as feature/<name>-<thing> (e.g., feature/punit-supabase-init)
- Small PRs, 1 approval required, link the issue ("Closes #5")

## Data model (see src/types.ts and docs/DATA_MODEL.md)
- locations: id, name, category, latitude?, longitude?, openHours?
- reports: id, locationId, createdAt, crowdLevel, waitMinutes?, userId
- crowdLevel is 'low' | 'medium' | 'high'
- confidence includes 'none' when there are no recent reports

## Wait-time / crowd logic (MVP)
Weighted average of recent reports: newer reports count more; reports older than ~60 minutes are ignored; fewer/older reports = lower confidence; zero recent reports → confidence `none` with null crowd/wait. Exact weights live in docs/API.md and the Postgres estimator functions.
