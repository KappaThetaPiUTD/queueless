import type { SupabaseClient } from '@supabase/supabase-js';
import type { LocationStatusRow, QueueLessService } from '../types';
import { normalizeError, validateLocationId, validateReport } from './errors';

export function mapStatus(row: LocationStatusRow) {
  return {
    locationId: row.location_id, crowdLevel: row.crowd_level,
    estimatedWaitMinutes: row.estimated_wait_minutes, confidence: row.confidence,
    lastUpdated: row.last_updated, reportCount: row.report_count,
  };
}

/** Injectable client allows the same wrappers to run in Expo and the live smoke test. */
export function createQueueLessService(client: SupabaseClient): QueueLessService {
  let pendingSession: Promise<void> | undefined;
  async function initializeSession(): Promise<void> {
    if (!pendingSession) {
      pendingSession = (async () => {
        const { data, error } = await client.auth.getSession();
        if (error) throw error;
        if (!data.session) {
          const result = await client.auth.signInAnonymously();
          if (result.error) throw result.error;
        }
      })().catch(error => { throw normalizeError(error); }).finally(() => { pendingSession = undefined; });
    }
    return pendingSession;
  }
  async function request<T>(action: () => Promise<T>): Promise<T> {
    try { return await action(); } catch (error) { throw normalizeError(error); }
  }
  return {
    initializeSession,
    getLocations: () => request(async () => {
      const { data, error } = await client.from('locations')
        .select('id,name,category,latitude,longitude,open_hours,building,floor_or_area,is_active')
        .eq('is_active', true).order('name');
      if (error) throw error;
      return (data ?? []).map(row => ({
        id: row.id, name: row.name, category: row.category,
        latitude: row.latitude ?? undefined, longitude: row.longitude ?? undefined,
        openHours: row.open_hours ?? undefined, building: row.building,
        floorOrArea: row.floor_or_area, isActive: row.is_active,
      }));
    }),
    getAllStatuses: () => request(async () => {
      const { data, error } = await client.rpc('get_all_statuses');
      if (error) throw error;
      return ((data ?? []) as LocationStatusRow[]).map(mapStatus);
    }),
    getLocationStatus: locationId => request(async () => {
      validateLocationId(locationId);
      const { data, error } = await client.rpc('get_location_status', { p_location_id: locationId });
      if (error) throw error;
      return mapStatus(data as LocationStatusRow);
    }),
    submitReport: input => request(async () => {
      validateReport(input);
      await initializeSession();
      const { data, error } = await client.rpc('submit_report', {
        p_location_id: input.locationId, p_crowd_level: input.crowdLevel,
        p_wait_minutes: input.waitMinutes ?? null,
      });
      if (error) throw error;
      return { id: data.report_id, locationId: data.location_id, crowdLevel: data.crowd_level,
        waitMinutes: data.wait_minutes, createdAt: data.created_at };
    }),
  };
}
