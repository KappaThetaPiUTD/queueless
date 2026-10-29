export type CrowdLevel = 'low' | 'medium' | 'high';

export type Confidence = 'none' | 'low' | 'medium' | 'high';

export type LocationCategory = 'dining' | 'gym' | 'library' | 'advising' | 'study';

export interface Location {
  id: string;
  name: string;
  category: LocationCategory;
  latitude?: number;
  longitude?: number;
  openHours?: string;
  building: string | null;
  floorOrArea: string | null;
  isActive: boolean;
}

export interface Report {
  id: string;
  locationId: string;
  /** ISO timestamptz from Postgres, or ms since epoch if normalized client-side */
  createdAt: string | number;
  crowdLevel: CrowdLevel;
  /** Optional integer from 0 through 120; null means no wait supplied. */
  waitMinutes?: number | null;
  userId: string; // Supabase Auth anonymous uid
}

export interface CrowdEstimate {
  locationId: string;
  crowdLevel: CrowdLevel | null; // null when no recent reports
  estimatedWaitMinutes: number | null;
  lastUpdated: string | number | null;
  confidence: Confidence;
  reportCount: number;
}

/** Shape returned by get_location_status / get_all_statuses (snake_case from Postgres). */
export interface LocationStatusRow {
  location_id: string;
  crowd_level: CrowdLevel | null;
  estimated_wait_minutes: number | null;
  confidence: Confidence;
  last_updated: string | null;
  report_count: number;
}

export interface SubmitReportInput {
  locationId: string;
  crowdLevel: CrowdLevel;
  waitMinutes?: number | null;
}

export interface SubmittedReport {
  id: string;
  locationId: string;
  crowdLevel: CrowdLevel;
  waitMinutes: number | null;
  createdAt: string;
}

export type ServiceErrorCode = 'network' | 'location_not_found' | 'invalid_input'
  | 'rate_limited' | 'not_authenticated' | 'configuration' | 'unexpected';

export interface QueueLessService {
  initializeSession(): Promise<void>;
  getLocations(): Promise<Location[]>;
  getAllStatuses(): Promise<CrowdEstimate[]>;
  getLocationStatus(locationId: string): Promise<CrowdEstimate>;
  submitReport(input: SubmitReportInput): Promise<SubmittedReport>;
}
