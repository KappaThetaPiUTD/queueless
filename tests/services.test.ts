import test from 'node:test';
import assert from 'node:assert/strict';
import type { SupabaseClient } from '@supabase/supabase-js';
import { createMockService } from '../src/services/mock';
import { ServiceError, normalizeError } from '../src/services/errors';
import { createQueueLessService, mapStatus } from '../src/services/service';

test('mock supports unknown → submit → Home/detail refresh → repeat rejected', async () => {
  const service = createMockService();
  const [location] = await service.getLocations();
  assert.equal((await service.getLocationStatus(location.id)).confidence, 'none');
  await service.submitReport({ locationId: location.id, crowdLevel: 'high', waitMinutes: 0 });
  const detail = await service.getLocationStatus(location.id);
  assert.equal(detail.confidence, 'low');
  assert.equal(detail.estimatedWaitMinutes, 0);
  assert.deepEqual((await service.getAllStatuses()).find(row => row.locationId === location.id), detail);
  await assert.rejects(service.submitReport({ locationId: location.id, crowdLevel: 'low' }),
    (error: unknown) => error instanceof ServiceError && error.code === 'rate_limited');
});

test('wait boundaries, null, missing location, offline, and ten-minute expiry', async () => {
  let now = Date.parse('2026-10-23T17:00:00Z');
  const service = createMockService({ now: () => now });
  const [location] = await service.getLocations();
  for (const waitMinutes of [-1, 121, 1.5, NaN]) {
    await assert.rejects(service.submitReport({ locationId: location.id, crowdLevel: 'low', waitMinutes }),
      (error: unknown) => error instanceof ServiceError && error.code === 'invalid_input');
  }
  await service.submitReport({ locationId: location.id, crowdLevel: 'low', waitMinutes: 120 });
  now += 10 * 60_000;
  await service.submitReport({ locationId: location.id, crowdLevel: 'low', waitMinutes: null });
  assert.equal((await service.getLocationStatus(location.id)).estimatedWaitMinutes, null);
  await assert.rejects(service.getLocationStatus('00000000-0000-0000-0000-000000000000'),
    (error: unknown) => error instanceof ServiceError && error.code === 'location_not_found');
  await assert.rejects(createMockService({ offline: true }).getLocations(),
    (error: unknown) => error instanceof ServiceError && error.code === 'network');
});

test('concurrent initialization signs in once and retries after an auth failure', async () => {
  let calls = 0;
  let fail = true;
  let session: object | null = null;
  const client = { auth: {
    getSession: async () => ({ data: { session }, error: null }),
    signInAnonymously: async () => {
      calls++;
      if (fail) return { error: new TypeError('Failed to fetch') };
      session = {};
      return { error: null };
    },
  } } as unknown as SupabaseClient;
  const service = createQueueLessService(client);
  const failed = await Promise.allSettled([service.initializeSession(), service.initializeSession()]);
  assert(failed.every(result => result.status === 'rejected'));
  assert.equal(calls, 1);
  fail = false;
  await Promise.all([service.initializeSession(), service.initializeSession()]);
  assert.equal(calls, 2);
  await service.initializeSession();
  assert.equal(calls, 2);
});

test('mapping preserves null and zero; server/network errors have stable codes', () => {
  assert.deepEqual(mapStatus({ location_id: 'id', crowd_level: null, estimated_wait_minutes: null,
    confidence: 'none', last_updated: null, report_count: 0 }), {
    locationId: 'id', crowdLevel: null, estimatedWaitMinutes: null,
    confidence: 'none', lastUpdated: null, reportCount: 0,
  });
  assert.equal(mapStatus({ location_id: 'id', crowd_level: 'low', estimated_wait_minutes: 0,
    confidence: 'low', last_updated: null, report_count: 1 }).estimatedWaitMinutes, 0);
  assert.equal(normalizeError({ code: '22P02', message: 'invalid UUID' }).code, 'invalid_input');
  assert.equal(normalizeError({ code: 'anonymous_provider_disabled' }).code, 'configuration');
  assert.equal(normalizeError({ message: 'rate_limited' }).code, 'rate_limited');
  assert.equal(normalizeError(new TypeError('Failed to fetch')).code, 'network');
});

test('live wrappers use one Home RPC, map server results, and preserve typed rejections', async () => {
  const calls: Array<{ name: string; args: unknown }> = [];
  const row = { location_id: '11111111-1111-1111-1111-111111111111', crowd_level: 'low',
    estimated_wait_minutes: 0, confidence: 'low', last_updated: '2026-10-23T17:00:00Z', report_count: 1 };
  let error: object | null = null;
  const client = { rpc: async (name: string, args?: unknown) => {
    calls.push({ name, args });
    return { data: name === 'get_all_statuses' ? [row] : row, error };
  } } as unknown as SupabaseClient;
  const service = createQueueLessService(client);
  assert.equal((await service.getAllStatuses())[0].estimatedWaitMinutes, 0);
  assert.deepEqual(calls, [{ name: 'get_all_statuses', args: undefined }]);
  assert.equal((await service.getLocationStatus(row.location_id)).locationId, row.location_id);
  error = { code: 'P0002', message: 'location_not_found' };
  await assert.rejects(service.getLocationStatus(row.location_id),
    (error: unknown) => error instanceof ServiceError && error.code === 'location_not_found');
});
