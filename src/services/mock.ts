import type { CrowdEstimate, Location, QueueLessService, SubmittedReport } from '../types';
import { ServiceError, validateLocationId, validateReport } from './errors';

const fixtureTime = '2026-10-23T17:00:00.000Z';
const locations: Location[] = [
  ['11111111-1111-1111-1111-111111111111', 'Activity Center', 'gym'],
  ['22222222-2222-2222-2222-222222222222', 'JSOM Cafe', 'dining'],
  ['33333333-3333-3333-3333-333333333333', 'McDermott Library', 'library'],
  ['44444444-4444-4444-4444-444444444444', 'Starbucks (SU)', 'dining'],
  ['55555555-5555-5555-5555-555555555555', 'ECS Study Commons', 'study'],
].map(([id, name, category]) => ({ id, name, category: category as Location['category'],
  building: null, floorOrArea: null, isActive: true }));

/** Deterministic screen fixture, not an implementation of the production estimator.
 * A fresh factory resets the fake session and its report limit. */
export function createMockService(options: { now?: () => number; offline?: boolean } = {}): QueueLessService {
  const now = options.now ?? (() => Date.parse(fixtureTime));
  const submitted = new Map<string, { at: number; report: SubmittedReport }>();
  const check = (id?: string) => {
    if (options.offline) throw new ServiceError('network', 'Mock connection is offline.');
    if (id !== undefined) {
      validateLocationId(id);
      if (!locations.some(location => location.id === id)) throw new ServiceError('location_not_found', 'Unknown location.');
    }
  };
  const status = (id: string): CrowdEstimate => {
    check(id);
    const item = submitted.get(id);
    if (item && now() - item.at < 60 * 60_000) {
      return { locationId: id, crowdLevel: item.report.crowdLevel,
        estimatedWaitMinutes: item.report.waitMinutes, confidence: 'low',
        reportCount: 1, lastUpdated: item.report.createdAt };
    }
    return { locationId: id, crowdLevel: null, estimatedWaitMinutes: null,
      confidence: 'none', reportCount: 0, lastUpdated: null };
  };
  return {
    initializeSession: async () => { check(); },
    getLocations: async () => { check(); return locations.map(location => ({ ...location })); },
    getAllStatuses: async () => { check(); return locations.map(location => status(location.id)); },
    getLocationStatus: async id => status(id),
    submitReport: async input => {
      check(input.locationId);
      validateReport(input);
      const at = now();
      const previous = submitted.get(input.locationId);
      if (previous && at - previous.at < 10 * 60_000) throw new ServiceError('rate_limited', 'Wait 10 minutes before reporting here again.');
      const report: SubmittedReport = { id: `mock-report-${submitted.size + 1}`, locationId: input.locationId,
        crowdLevel: input.crowdLevel, waitMinutes: input.waitMinutes ?? null, createdAt: new Date(at).toISOString() };
      submitted.set(input.locationId, { at, report });
      return { ...report };
    },
  };
}
