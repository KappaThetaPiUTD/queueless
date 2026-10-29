import type { ServiceErrorCode, SubmitReportInput } from '../types';

export class ServiceError extends Error {
  constructor(public readonly code: ServiceErrorCode, message: string) {
    super(message);
    this.name = 'ServiceError';
  }
}

export function normalizeError(error: unknown): ServiceError {
  if (error instanceof ServiceError) return error;
  const e = error as { code?: string; message?: string; status?: number } | null;
  const message = e?.message ?? 'Unexpected service failure';
  if (e?.code === 'anonymous_provider_disabled') return new ServiceError('configuration', 'Enable anonymous sign-ins and restart local Supabase.');
  if (message.includes('rate_limited')) return new ServiceError('rate_limited', 'Wait 10 minutes before reporting here again.');
  if (message.includes('location_not_found')) return new ServiceError('location_not_found', 'Location was not found or is inactive.');
  if (['22023', '22P02', '23514'].includes(e?.code ?? '') || message.startsWith('invalid_')) return new ServiceError('invalid_input', 'Check the location, crowd level, and wait (0–120 or null).');
  if (e?.code === '28000' || e?.status === 401 || message.includes('not_authenticated')) return new ServiceError('not_authenticated', 'Could not initialize your session.');
  if (error instanceof TypeError || e?.status === 0 || /fetch|network|connection|timeout/i.test(message)) return new ServiceError('network', 'Cannot reach QueueLess. Check your connection and try again.');
  return new ServiceError('unexpected', 'QueueLess could not complete the request.');
}

export function validateLocationId(id: string): void {
  if (typeof id !== 'string' || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id)) {
    throw new ServiceError('invalid_input', 'Location must be a UUID.');
  }
}

export function validateReport(input: SubmitReportInput): void {
  validateLocationId(input.locationId);
  if (!['low', 'medium', 'high'].includes(input.crowdLevel)
    || (input.waitMinutes != null && (!Number.isInteger(input.waitMinutes) || input.waitMinutes < 0 || input.waitMinutes > 120))) {
    throw new ServiceError('invalid_input', 'Choose low/medium/high and an integer wait from 0 through 120, or null.');
  }
}
