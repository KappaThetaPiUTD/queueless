export type CrowdLevel = 'low' | 'medium' | 'high';

export type LocationCategory = 'dining' | 'gym' | 'library' | 'advising' | 'study';

export interface Location {
  id: string;
  name: string;
  category: LocationCategory;
  latitude?: number;
  longitude?: number;
  openHours?: string;
}

export interface Report {
  id: string;
  locationId: string;
  timestamp: number; // milliseconds since epoch
  crowdLevel: CrowdLevel;
  estimatedWaitMinutes?: number;
  userId: string; // anonymous Firebase auth uid
}

export interface CrowdEstimate {
  locationId: string;
  crowdLevel: CrowdLevel | null; // null when no recent reports
  estimatedWaitMinutes: number | null;
  lastUpdated: number | null;
  confidence: 'low' | 'medium' | 'high';
  reportCount: number;
}
