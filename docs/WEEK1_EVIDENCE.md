# Week 1 evidence notes (Punit)

Post screenshots + PR links on the GitHub issue. This file is a checklist.

## Task 1 — AI context
- [ ] Copilot enabled in VS Code (student account)
- [ ] Gemini Gem **QueueLess** created; files uploaded
- [ ] Screenshot of Gem answer (use [TASK1_GEM_PROMPT.md](TASK1_GEM_PROMPT.md))

## Task 2 — Tools + local Supabase
Verified locally after reboot:

| Tool | Version |
| --- | --- |
| Node | v26.11.1 |
| Docker | 29.8.2 |
| Supabase CLI | 2.120.0 |
| Studio | http://127.0.0.1:54323 |

- [ ] Accept Binu’s Supabase org invite (browser — cannot automate)
- [ ] Screenshot terminal versions + Studio dashboard
- Branch: `feature/punit-supabase-init`

## Task 3 — API design
- [docs/API.md](API.md) — all RPCs, errors, estimator, 3 examples
- [docs/DATA_MODEL.md](DATA_MODEL.md) — proposed names for Binu to own/edit
- [ ] ≥3 review comments on Binu’s DATA_MODEL PR when it opens
- [ ] Ping Sai on estimator vs issue #7

## Task 4 — Functions + tests
```
npx supabase test db
→ All tests successful. Files=1, Tests=7, Result: PASS
```

Scenarios covered: valid accept; invalid crowd; wait 500; 10-min rate limit; spoof insert blocked; confidence none; mixed ages lean newer.

### Sample `get_location_status` (computed)

Activity Center after old `low` (50 min) + fresh `high` (5 min, wait 8):

```json
{
  "confidence": "medium",
  "crowd_level": "high",
  "location_id": "11111111-1111-1111-1111-111111111111",
  "last_updated": "2026-10-09T01:46:21.491454+00:00",
  "report_count": 2,
  "estimated_wait_minutes": 12
}
```

Studio: http://127.0.0.1:54323 — post table screenshots with Binu.
