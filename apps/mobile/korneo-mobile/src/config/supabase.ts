import { createClient } from '@supabase/supabase-js';
import AsyncStorage from '@react-native-async-storage/async-storage';

// Из текущего проекта (index.html)
const SUPABASE_URL = 'https://jmxjbdnqnzkzxgsfywha.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpteGpiZG5xbnprenhnc2Z5d2hhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzExNTQ0MzQsImV4cCI6MjA4NjczMDQzNH0.z6y6DGs9Z6kojQYeAdsgKA-m4pxuoeABdY4rAojPEE4';

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    storage: AsyncStorage,
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: false,
  },
});

