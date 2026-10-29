import assert from 'node:assert/strict';
import { createClient } from '@supabase/supabase-js';
import { createQueueLessService } from '../src/services/service';
import { ServiceError } from '../src/services/errors';

// Run only against a disposable LOCAL Supabase instance. No service-role key needed.
const url = process.env.EXPO_PUBLIC_SUPABASE_URL;
const key = process.env.EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
assert(url && key, 'Set EXPO_PUBLIC_SUPABASE_URL and EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY.');
assert(['localhost', '127.0.0.1'].includes(new URL(url).hostname), 'Smoke test requires the laptop-local API; it creates real anonymous users/reports.');
const client = () => createClient(url, key, {
  auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
});
const savedSession = new Map<string, string>();
const persistentClient = () => createClient(url, key, {
  auth: {
    persistSession: true, autoRefreshToken: false, detectSessionInUrl: false,
    storageKey: 'queueless-smoke-session',
    storage: {
      getItem: (name: string) => savedSession.get(name) ?? null,
      setItem: (name: string, value: string) => { savedSession.set(name, value); },
      removeItem: (name: string) => { savedSession.delete(name); },
    },
  },
});
async function main() {
  const a = persistentClient();
  const service = createQueueLessService(a);
  await Promise.all([service.initializeSession(), service.initializeSession()]);
  const { data } = await a.auth.getSession();
  assert(data.session?.user.is_anonymous, 'Actual anonymous Auth session required');
  console.log('PASS actual anonymous sign-in (tokens and user IDs omitted)');
  const locations = await service.getLocations();
  assert(locations.length >= 2);
  const before = await service.getAllStatuses();
  assert.equal(before.length, locations.length);
  assert(before.some(status => status.confidence === 'none'), 'Run after a clean local reset for no-data coverage');
  // Two HTTP requests are dispatched concurrently using the SAME user's JWT.
  const results = await Promise.allSettled([0, 120].map(waitMinutes => service.submitReport({
    locationId: locations[0].id, crowdLevel: 'medium', waitMinutes,
  })));
  assert.equal(results.filter(result => result.status === 'fulfilled').length, 1);
  const rejected = results.find(result => result.status === 'rejected');
  assert(rejected?.status === 'rejected' && rejected.reason instanceof ServiceError && rejected.reason.code === 'rate_limited');
  console.log('PASS concurrent same-user/location: one accepted, one rate_limited');
  const restoredClient = persistentClient();
  const restoredService = createQueueLessService(restoredClient);
  await restoredService.initializeSession();
  const restored = await restoredClient.auth.getSession();
  assert.equal(restored.data.session?.user.id, data.session.user.id);
  await assert.rejects(restoredService.submitReport({ locationId: locations[0].id, crowdLevel: 'low' }),
    (error: unknown) => error instanceof ServiceError && error.code === 'rate_limited');
  console.log('PASS new client restores persisted anonymous identity and keeps the limit (in-memory storage adapter)');
  await service.submitReport({ locationId: locations[1].id, crowdLevel: 'low', waitMinutes: null });
  const other = createQueueLessService(client());
  await other.submitReport({ locationId: locations[0].id, crowdLevel: 'high', waitMinutes: 120 });
  console.log('PASS independent location and independent user');
  const detail = await service.getLocationStatus(locations[0].id);
  const home = await service.getAllStatuses();
  assert.equal(detail.reportCount, 2);
  assert.deepEqual(home.find(status => status.locationId === detail.locationId), detail);
  for (const wait of [-1, 121, 1.5]) {
    // Call the RPC directly so server validation is tested, not only the wrapper.
    const { error } = await a.rpc('submit_report', { p_location_id: locations[0].id, p_crowd_level: 'low', p_wait_minutes: wait });
    assert(error, `Server must reject wait ${wait}`);
  }
  const { error: rawError } = await a.from('reports').select('*');
  assert(rawError, 'Authenticated clients must not read raw reports');
  const { error: publicRawError } = await client().from('reports').select('*');
  assert(publicRawError, 'Unauthenticated clients must not read raw reports');
  await assert.rejects(service.getLocationStatus('00000000-0000-0000-0000-000000000000'),
    (error: unknown) => error instanceof ServiceError && error.code === 'location_not_found');
  console.log('PASS refresh, invalid waits, missing location, and raw-report privacy');
  console.log('Redacted live status:', JSON.stringify(detail));
}
main().catch(error => {
  console.error('FAIL', error instanceof ServiceError ? error.code : error instanceof Error ? error.message : 'Unknown failure');
  process.exitCode = 1;
});
