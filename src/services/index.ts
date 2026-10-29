import 'react-native-url-polyfill/auto';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { createClient, processLock } from '@supabase/supabase-js';
import { AppState, Platform } from 'react-native';
import { createQueueLessService } from './service';
import { ServiceError } from './errors';

const url = process.env.EXPO_PUBLIC_SUPABASE_URL;
const key = process.env.EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
if (!url || !key || key.startsWith('replace-')) {
  throw new ServiceError('configuration', 'Set the Supabase URL and public key in .env, then restart Expo.');
}
export const supabase = createClient(url, key, {
  auth: { storage: AsyncStorage, autoRefreshToken: true, persistSession: true,
    detectSessionInUrl: false, lock: processLock },
});

if (Platform.OS !== 'web') {
  if (AppState.currentState === 'active') supabase.auth.startAutoRefresh();
  const subscription = AppState.addEventListener('change', state => {
    if (state === 'active') supabase.auth.startAutoRefresh();
    else supabase.auth.stopAutoRefresh();
  });
  // Expo Fast Refresh must not accumulate listeners or refresh timers.
  const hot = (module as NodeModule & { hot?: { dispose(callback: () => void): void } }).hot;
  if (hot) hot.dispose(() => {
    subscription.remove();
    supabase.auth.stopAutoRefresh();
  });
}

export const queueLessService = createQueueLessService(supabase);
export const { initializeSession, getLocations, getAllStatuses, getLocationStatus, submitReport } = queueLessService;
export { ServiceError } from './errors';
