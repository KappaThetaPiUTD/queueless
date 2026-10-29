# Week 3 evidence — Punit

Recorded October 29, 2026. This is a current update, not a claim that the October 23 checkpoint was met.

Draft follow-up: [PR #13](https://github.com/KappaThetaPiUTD/queueless/pull/13), branch `feature/punit-week3-integration`, based on the existing [PR #8](https://github.com/KappaThetaPiUTD/queueless/pull/8) branch. Merge/review the follow-up into #8 before #8 goes to main. Neither PR was merged during this work.

## Done

- Enabled local anonymous sign-ins.
- Added a follow-up migration for 0–120/null waits, low confidence for a single report, per-user/location concurrency protection, restricted raw reports, and active-location Home statuses.
- Kept the five fixed UUID location IDs. Added provisional nullable building/floor fields and `is_active` for coordination with Binu's #11 contract.
- Added persistent anonymous Expo client setup, shared service methods, typed errors, snake_case mapping, deterministic mocks, placeholder-only environment example and LAN instructions.
- Added SQL regressions and a real-client smoke script. This checkout has service code and tests; frontend screens are not present.
- `npm run typecheck`: PASS.
- `npm test`: PASS, 5/5 tests. These are unit/mock/client-wrapper tests, not a phone demo.
- Dependency install: 0 reported vulnerabilities.

## Database/client validation

Environment: Node v26.11.1, pinned Supabase CLI 2.122.0, local Postgres image 17.11.0.006.

| Command/check | Result |
| --- | --- |
| `npx supabase db reset --local` | PASS twice; both migrations and five fixed location seeds applied without manual SQL |
| `npx supabase test db` | PASS, Files=1, Tests=28, Result: PASS |
| `npm run typecheck` | PASS |
| `npm test` | PASS, 5 tests, 0 failures |
| `npm run test:live` | PASS against actual local Auth + REST + Postgres |
| `npx supabase db advisors --local --type security --fail-on warn` | PASS: No issues found, empty results |
| `npx supabase migration list --local` | Both `20261009013000` and `20261029165249` applied |
| `git diff --check` | PASS |

Redacted actual client output:

```text
PASS actual anonymous sign-in (tokens and user IDs omitted)
PASS concurrent same-user/location: one accepted, one rate_limited
PASS new client restores persisted anonymous identity and keeps the limit (in-memory storage adapter)
PASS independent location and independent user
PASS refresh, invalid waits, missing location, and raw-report privacy
```

Actual mapped status sample (no credentials or user identity):

```json
{
  "locationId": "11111111-1111-1111-1111-111111111111",
  "crowdLevel": "high",
  "estimatedWaitMinutes": 60,
  "confidence": "medium",
  "lastUpdated": "2026-10-29T17:08:46.621124+00:00",
  "reportCount": 2
}
```

The first smoke attempt correctly exposed an old Auth container with anonymous sign-ins disabled. Stopping/starting the local stack loaded `enable_anonymous_sign_ins = true`; a fresh reset and full tests then passed. The advisor's original helper-function search-path warning was also fixed and the final scan is clean.

The currently running local services are database, Auth, REST/API gateway and mail. Optional Studio/storage/realtime/analytics services were excluded to avoid unrelated image downloads during backend verification. `.env` is ignored by Git and contains only the local URL/public key. No service-role key was written into the app.

Session restoration was checked using a new real Supabase client sharing a test storage adapter. Native AsyncStorage persistence, UI error states and the phone demo still require the Expo app integration; this evidence does not claim those were tested.

## Next / needs teammates

- Binu: substantive review of PR #8/follow-up, independently reproduce reset + pgTAP, reconcile his schema/access changes and own the final data-model wording and synthetic seed work.
- Harsha/Krish: reconcile service dependency versions with their Expo manifest and connect Home/detail/submit screens, then pair on a real phone flow and session persistence check.
- Record live versus mocked demo steps and attach a recording after the screen integration exists.
- Confirm Sai's location/estimator agreement; confirm hosted invitation acceptance separately.
- Update the board to In Review once the team is reviewing; keep #6/#12 open until their complete acceptance criteria are met.

## Blocked / not claimed

- No Binu approval or independent teammate reproduction is claimed.
- No live frontend/Expo phone demo is claimed. No screens exist in this checkout.
- The connected hosted QueueLess project was reported INACTIVE. No hosted restore, schema deployment, test-user upload, or hosted Auth change was performed.
- Hosted project visibility through the connector does not prove the user's invitation acceptance/browser membership.
- Teammate messages, issue updates and board changes have not been sent/performed. Suggested messages are in `PUNIT_WEEK3_GUIDE.md`.
- History RPC/chart and hourly cron remain outside this checkpoint.

## Copyable progress update

**Done:** review fixes and typed service handoff implemented; clean local resets, 28 SQL tests, five service tests, TypeScript, real anonymous-client/concurrency/session-restore smoke checks and the database security scan all pass. See this evidence file for redacted output.

**Next:** Binu review/reproduction; Harsha/Krish screen integration and live phone demo.

**Blocked:** independent review and live screen integration require teammates; hosted project is inactive and invitation acceptance is not verified.

Refs #6, #11, #12. This incremental work does not close their entire checklists.
