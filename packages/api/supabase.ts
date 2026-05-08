import { createClient } from '@supabase/supabase-js';
import { Database } from '../../packages/domain/types'; // shared domain types

import type { UserRole, Task, Installation, AvrTask, User } from '../../packages/domain/types';

const SUPABASE_URL = 'https://jmxjbdnqnzkzxgsfywha.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpteGpiZG5xbnprenhnc2Z5d2hhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzExNTQ0MzQsImV4cCI6MjA4NjczMDQzNH0.z6y6DGs9Z6kojQYeAdsgKA-m4pxuoeABdY4rAojPEE4';

export const supabase = createClient<Database>(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: false,
  },
});

// Auth helpers
export async function getUserProfile(userId: string): Promise<User | null> {
  try {
    const { data, error } = await supabase
      .from('users')
      .select('*')
      .eq('id', userId)
      .single();
    if (error) throw error;
    return data as User;
  } catch (error) {
    console.error('getUserProfile error:', error);
    return null;
  }
}

// Tasks queries
export async function fetchTasks(status?: string, assignee_id?: string): Promise<Task[]> {
  try {
    let query = supabase.from('tasks').select('*').order('created_at', { ascending: false });
    if (status && status !== 'all') query = query.eq('status', status);
    if (assignee_id) query = query.eq('assignee_id', assignee_id);
    const { data, error } = await query;
    if (error) throw error;
    return data as Task[];
  } catch (error) {
    console.error('fetchTasks error:', error);
    return [];
  }
}

export async function updateTaskStatus(id: string, status: UserRole): Promise<boolean> {
  try {
    const { error } = await supabase
      .from('tasks')
      .update({ status })
      .eq('id', id);
    if (error) throw error;
    return true;
  } catch (error) {
    console.error('updateTaskStatus error:', error);
    return false;
  }
}

// Installations
export async function fetchInstallations(status?: string, assignee_id?: string): Promise<Installation[]> {
  try {
    let query = supabase.from('installations').select('*').order('scheduled_at', { ascending: false });
    if (status && status !== 'all') query = query.eq('status', status);
    if (assignee_id) query = query.eq('assignee_id', assignee_id);
    const { data, error } = await query;
    if (error) throw error;
    return data as Installation[];
  } catch (error) {
    console.error('fetchInstallations error:', error);
    return [];
  }
}

// AVR (reuse tasks logic or separate table)
export async function fetchAvrTasks(status?: string): Promise<AvrTask[]> {
  return fetchTasks(status) as Promise<AvrTask[]>;
}

