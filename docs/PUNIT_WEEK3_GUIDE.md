# Punit's Week 3 task, explained

Your job is to make the existing backend safe to use, then give Harsha and Krish simple TypeScript functions for their screens. You do not need to build the whole app. The pasted issue's October 23 checkpoint has already passed as of October 29; report current progress and blockers honestly.

## The words in the assignment

- **Backend:** the database, login, and rules behind the app.
- **Migration:** a versioned SQL file that changes the database. The new migration builds on PR #8.
- **RPC:** a database function the app calls. `submit_report` saves a report; status functions calculate crowd estimates.
- **Anonymous sign-in:** Supabase creates an identity without asking for email/password. The phone keeps that session so reopening the app keeps the same identity.
- **RLS/permissions:** rules controlling which database data clients can access. Raw reports contain user IDs; the app only receives aggregate statuses.
- **Service layer:** the `src/services/` functions your teammates import instead of writing database queries in each screen.
- **Mock:** predictable fake data for frontend development. A mock demo is not evidence that the database works.
- **pgTAP:** SQL tests that check database behavior.
- **PR/review/merge:** proposed code changes, a teammate checking them, and accepting them into `main`.

## What you can do alone (and the code prepared here)

| Work | What it means | Where |
| --- | --- | --- |
| Enable anonymous login locally | Let the real client create an identity | `supabase/config.toml` |
| Fix waits/confidence/concurrency | Wait must be an integer 0–120 or null; one report has low confidence; simultaneous duplicates cannot both save | Follow-up Week 3 migration |
| Restrict raw-report reads | App users get estimates rather than other users' report rows | Same migration + role tests |
| Return Home statuses in one request | Include every active location, including empty ones | `get_all_statuses()` |
| Provide frontend functions | Session, locations, statuses, submit, field mapping, typed errors | `src/services/` |
| Let frontend work before backend setup | Deterministic mock with the same interface | `createMockService()` |
| Collect reproducible evidence | Run reset, SQL tests, client tests, real auth/concurrent requests | Commands below |

## What needs someone else

| Person | Concrete thing to do together | Why you cannot finish it alone |
| --- | --- | --- |
| Binu | Review PR #8 and the follow-up migration; agree location fields/access rules; run reset/tests on his laptop | Independent review/reproduction must come from another person |
| Binu | Finalize the data-model wording and two-week synthetic seed fixtures from #11 | These are his assigned deliverables; coordinate the overlapping schema changes |
| Harsha | Import the service into Home; fetch `getLocations()` and `getAllStatuses()`; refresh Home after submission | His Home screens are absent from this checkout |
| Krish | Import detail/submit services; handle null waits, invalid input and `rate_limited`; refresh detail on return | His screens are absent from this checkout |
| Harsha + Krish | Demo Home → detail → submit → refreshed detail/Home on a phone | Requires their screens, Expo setup, and a reachable API |
| Binu/project owner | Confirm your hosted organization membership/invitation; restore/configure hosted project when the team is ready | Seeing the project through a connector does not prove your browser/account invitation was accepted |
| Sai | Confirm provisional campus locations and estimator agreement | Product decisions belong to the team |

An AI can prepare code, tests and a review checklist. It cannot honestly supply Binu's independent approval, claim a teammate reproduced tests, or claim a phone demo occurred. History charts, cron jobs and hosted deployment are later work, not required for this checkpoint.

## Run the backend checks

Use a terminal in the repository. Start Docker Desktop first. These commands use only the disposable local database; `db reset --local` deletes its existing local data.

If you already had Supabase containers from the original branch, run `npx supabase stop` before `start` so the anonymous-auth config is reloaded. A database reset alone does not update the existing Auth container's environment.

```powershell
npm ci
npx supabase start
npx supabase db reset --local
npx supabase test db
npm run typecheck
npm test
```

For the actual client test, copy `.env.example` to `.env`, then set the local API URL and ONLY the publishable (or legacy anon) key from `npx supabase status`. Do not paste the full status output into issues: it also contains secrets. The smoke script creates local anonymous users and reports.

```powershell
npm run test:live
```

It checks actual anonymous Auth, concurrent submissions (one succeeds, one is limited), separate user/location submissions, Home/detail refresh, invalid waits and raw-report access restrictions. Run after a reset for a known no-data state. To repeat from scratch, reset locally again first. Tests using SQL-injected claims alone do not prove Auth works.

The client follows the [official Supabase React Native session guidance](https://supabase.com/docs/guides/auth/quickstarts/react-native) and [anonymous Auth documentation](https://supabase.com/docs/guides/auth/auth-anonymous). Database locking uses a [PostgreSQL transaction advisory lock](https://www.postgresql.org/docs/current/explicit-locking.html#ADVISORY-LOCKS).

## Frontend handoff

`package.json` provides a service/test workspace, not a runnable Expo application. Harsha owns the Expo foundation. When combining branches, use Expo-compatible React, React Native and AsyncStorage versions via `npx expo install`; reconcile manifests/lockfiles rather than overwriting Harsha's app manifest. The dependencies here allow service development and type checking in this checkout.

Live imports in Expo:

```ts
import { queueLessService as service, ServiceError } from '../src/services';
await service.initializeSession(); // at startup; submit also initializes it
const [locations, statuses] = await Promise.all([
  service.getLocations(), service.getAllStatuses(),
]);
const detail = await service.getLocationStatus(locations[0].id);
try {
  await service.submitReport({ locationId: detail.locationId, crowdLevel: 'medium', waitMinutes: null });
  // Re-fetch detail and getAllStatuses() after success / when Home regains focus.
} catch (error) {
  if (error instanceof ServiceError) console.log(error.code);
}
```

For mocks, replace the import with `const service = createMockService()` from `src/services/mock.ts`. Keep one mock instance for the demo so its state survives navigation. A new instance resets it. `createMockService({ offline: true })` provides the network-error state. The mock is a screen fixture, not another weighted estimator.

Methods return the shared camelCase types in `src/types.ts`. `waitMinutes: 0` means zero wait; `null`/omitted means not supplied. A no-data estimate has confidence `none`, count 0, and null crowd/wait/freshness. Error codes: `network`, `location_not_found`, `invalid_input`, `rate_limited`, `not_authenticated`, `configuration`, `unexpected`.

For Expo Go, `localhost` points to the phone itself. Set `EXPO_PUBLIC_SUPABASE_URL` to `http://<laptop-LAN-IPv4>:54321`, keep phone/laptop on the same reachable network, and allow the local API through the laptop firewall if needed. Use `ipconfig` to find the Wi-Fi IPv4 address. Restart Expo after changing `.env`. An Expo tunnel does not tunnel your Supabase API. Hosted use needs the team's active project URL/public key and anonymous auth enabled there separately. Never put a database password, secret or service-role key in the app.

## Short pairing checklist

1. Show Home and open one detail screen with no reports: show an unknown/no-data state, not zero crowd.
2. Submit `medium` with a null wait as an anonymous user; refresh detail and Home.
3. Try an immediate repeat at the same location: show the `rate_limited` message.
4. Submit at a different location: allowed. Test 0 and 120; reject -1, 121 and fractions.
5. Restart the app and confirm the session persists; the limit must still apply.
6. Disconnect the API and confirm loading resolves into an error with retry.
7. Record whether each step used real Supabase or mocks. Add a short recording once the live phone demo happens.

## Messages you can send (drafts, not sent)

**To Binu:** “My Week 3 follow-up adds the 0–120 limits, low confidence for one report, concurrent submission protection, aggregate Home RPC, and raw-report restrictions. It also adds building/floor_or_area/is_active as a provisional contract for your #11 changes. Please review those overlaps, run a local reset + full pgTAP suite independently, and confirm hosted invite status. We still need your substantive review before merging.”

**To Harsha and Krish:** “The shared interface is in src/types.ts and services are in src/services. Home uses one getAllStatuses call; detail uses getLocationStatus; submitReport handles anonymous login. Null is unknown/unsupplied, zero is a real zero wait. Mocks use the same interface. Let's pair for Home → detail → submit → refreshed Home/detail, repeat rejection and no-data states.”

Use `docs/WEEK3_EVIDENCE.md` for an accurate Done / Next / Blocked update. Do not close #6 or mark #12 done until its full requirements and reviews are complete.
