# Review notes for Binu’s DATA_MODEL (post on his PR)

Binu has not opened a separate DATA_MODEL PR yet. When he does, paste these as review comments (adjust line refs). These also record alignment asks against the proposed [DATA_MODEL.md](DATA_MODEL.md) in this branch.

1. **`wait_minutes` range** — API + migration reject values outside 0–180 (e.g. 500). Please document that check on `reports.wait_minutes` so the frontend and seed scripts don’t invent a different max.

2. **`confidence: none`** — Live status with zero reports in the 60-minute window must return `confidence: none` with null `crowd_level` / `estimated_wait_minutes` / `last_updated`. Confirm the TypeScript `CrowdEstimate` / RPC JSON uses `none` (not omitting the field or using `low`).

3. **No direct client inserts on `reports`** — RLS should allow SELECT for `anon`/`authenticated` but not INSERT. All writes go through `submit_report` so `user_id` is always `auth.uid()`. Call out that spoofing another user’s id via table insert is intentionally blocked.

4. **`hourly_summaries` weekday convention** — API assumes ISO-style 1=Monday … 7=Sunday and hour 0–23. Confirm timezone (UTC v1 vs campus local) before Week 2 history work.
