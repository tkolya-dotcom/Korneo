/// packages/domain/types.ts
// Общие типы для Korneo (TypeScript для Expo/React Native)

export type UserRole = 'worker' | 'engineer' | 'manager' | 'deputy_head' | 'support';

export interface User {
  id: string;
  email: string;
  name: string;
  role: UserRole;
  is_online: boolean;
  fcm_token?: string;
  avatar_url?: string;
}

export type TaskStatus = 'new' | 'in_progress' | 'waiting_materials' | 'done' | 'postponed' | 'archived';

export interface Task {
  id: string;
  short_id: number;
  title: string;
  status: TaskStatus;
  assignee_id: string;
  project_id?: string;
  due_date?: string;
  created_at: string;
  updated_at: string;
}

export type InstallationStatus = 'new' | 'planned' | 'in_progress' | 'done';

export interface Installation {
  id: string;
  short_id: number;
  title: string;
  status: InstallationStatus;
  assignee_id: string;
  project_id?: string;
  address?: string;
  scheduled_at?: string;
  sk_data: Array<{ // SK1..SK7
    id_sk: string;
    naimenovanie: string;
    status: string;
    tip_sk: string;
  }>;
}

export type AvrStatus = TaskStatus; // Reuse TaskStatus

export interface AvrTask extends Omit<Task, 'status'> {
  status: AvrStatus;
  address?: string;
}

export interface Chat {
  id: string;
  name?: string;
  type: 'private' | 'group' | 'job';
  members: User[];
  unread_count?: number;
  partnerOnline?: boolean;
}

export interface Message {
  id: string;
  chat_id: string;
  sender_id: string;
  content: string;
  created_at: string;
  reactions?: Record<string, number>;
}

export type MaterialUnit = 'шт' | 'м' | 'кг' | 'комплект';

export interface Material {
  id: string;
  name: string;
  unit: MaterialUnit;
  min_quantity: number;
}

export type RequestStatus = 'pending' | 'approved' | 'rejected' | 'in_order' | 'ready_for_receipt' | 'received';

export interface PurchaseRequest {
  id: string;
  short_id: string;
  status: RequestStatus;
  requester_id: string;
  items: Array<{
    material_id: string;
    name: string;
    quantity: number;
    unit: MaterialUnit;
  }>;
}

// Supabase enums для validation
export const ROLES: UserRole[] = ['worker', 'engineer', 'manager', 'deputy_head', 'support'];
export const TASK_STATUSES: TaskStatus[] = ['new', 'in_progress', 'waiting_materials', 'done', 'postponed', 'archived'];

