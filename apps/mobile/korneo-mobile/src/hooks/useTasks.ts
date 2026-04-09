import { useQuery } from '@tanstack/react-query';
import { supabase } from '../config/supabase';
import { Task, TaskStatus } from '../../../packages/domain/types';

export function useTasks(statusFilter: TaskStatus, userId?: string) {
  return useQuery({
    queryKey: ['tasks', statusFilter, userId],
    queryFn: async () => {
      let query = supabase
        .from('tasks')
        .select(`
          *,
          profiles!assignee_id (
            name,
            role
          )
        `, { count: 'exact' })
        .order('created_at', { ascending: false })
        .limit(50); // Pagination ready

      if (statusFilter !== 'all') {
        query = query.eq('status', statusFilter);
      }

      if (userId) {
        query = query.eq('assignee_id', userId);
      }

      const { data, error, count } = await query;
      if (error) throw error;
      return { tasks: data || [], total: count || 0 };
    },
    staleTime: 2 * 60 * 1000, // 2min
    retry: 1,
  });
}

