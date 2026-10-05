# QueueLess — Context for AI Assistants
Paste this whole file into your AI tool (ChatGPT, Gemini, Copilot, Claude, Perplexity) before asking it to write code for this project.

## What we're building
QueueLess shows how crowded UTD campus locations are (dining, gym, library, advising, study spots). Students submit quick crowd reports; the app shows Low/Medium/High status, an estimated wait time, and a history chart. Keep things simple: a working MVP beats an advanced unfinished feature.

## Stack (do not suggest alternatives)
- Expo (managed workflow) + React Native + TypeScript
- Expo Router for navigation
- Firebase: Firestore (database), Anonymous Auth, Cloud Functions only if needed
- Python + pandas + scikit-learn for data/ML (in /data, optional)
- No Redux. Use React state/hooks. No extra UI libraries unless the team agrees.

## Folder structure
app/                  Screens (Expo Router): index.tsx (Home), location/[id].tsx, report/[id].tsx, history/[id].tsx
src/components/       Reusable UI (e.g., CrowdStatusCard.tsx)
src/services/         Firebase setup + data functions (firebase.ts, locations.ts, reports.ts)
src/utils/            Helpers (e.g., estimator.ts for wait-time logic)
src/types.ts          Shared data types — the single source of truth
data/                 Python scripts/notebooks for analysis and ML

## Conventions
- Components: PascalCase files and names (CrowdStatusCard.tsx)
- Functions/variables: camelCase (getRecentReports)
- Firestore collections: lowercase plural (locations, reports)
- Always import types from src/types.ts; never redefine them
- Functional components with hooks only
- Every screen handles loading, empty, and error states
- Never commit Firebase config secrets; use .env

## Git workflow
- Never push to main. Branch as feature/<name>-<thing> (e.g., feature/krish-status-card)
- Small PRs, 1 approval required, link the issue ("Closes #5")

## Data model (see src/types.ts)
- locations: id, name, category, latitude?, longitude?, openHours?
- reports: id, locationId, timestamp, crowdLevel, estimatedWaitMinutes?, userId
- crowdLevel is 'low' | 'medium' | 'high'

## Wait-time logic (MVP)
Weighted average of recent reports: newer reports count more; reports older than ~60 minutes are ignored; fewer/older reports = lower confidence.
