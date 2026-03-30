import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  console.error('Missing Supabase configuration. Check your environment variables.');
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

// Helper to handle Supabase responses
const handleSupabaseResponse = (data, error) => {
  if (error) throw new Error(error.message);
  return data;
};

// Auth API
export const authApi = {
  login: async (email, password) => {
    const { data, error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) throw error;
    
    // Get user details from users table
    const { data: user, error: userError } = await supabase
      .from('users')
      .select('*')
      .eq('id', data.user.id)
      .single();
      
    if (userError) throw userError;
    
    return { token: data.session.access_token, user };
  },
  
  register: async (email, password, name, role) => {
    const { data, error } = await supabase.auth.signUp({ email, password });
    if (error) throw error;
    
    // Create user record in users table
    const { data: user, error: userError } = await supabase
      .from('users')
      .insert([{ id: data.user.id, email, name, role }])
      .select()
      .single();
      
    if (userError) throw userError;
    
    return { token: data.session.access_token, user };
  },
  
  getMe: async () => {
    const { data: { user: authUser }, error: authError } = await supabase.auth.getUser();
    if (authError || !authUser) throw new Error('Not authenticated');
    
    const { data: user, error: userError } = await supabase
      .from('users')
      .select('*')
      .eq('id', authUser.id)
      .single();
      
    if (userError) throw userError;
    return { user };
  },
  
  getUsers: async (role) => {
    let query = supabase.from('users').select('*');
    if (role) query = query.eq('role', role);
    const { data, error } = await query;
    return handleSupabaseResponse(data, error);
  }
};

// Users Status API
export const usersApi = {
  getStatus: async () => {
    const { data, error } = await supabase.from('users').select('id, name, role, is_online, last_seen_at');
    return handleSupabaseResponse(data, error);
  },
  heartbeat: async () => {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return;
    const { error } = await supabase
      .from('users')
      .update({ is_online: true, last_seen_at: new Date().toISOString() })
      .eq('id', user.id);
    if (error) console.error('Heartbeat error:', error);
  },
  markOffline: async () => {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return;
    await supabase
      .from('users')
      .update({ is_online: false, last_seen_at: new Date().toISOString() })
      .eq('id', user.id);
  }
};

// Projects API
export const projectsApi = {
  getAll: async (status) => {
    let query = supabase.from('projects').select('*, manager:manager_id(*)');
    if (status) query = query.eq('status', status);
    const { data, error } = await query;
    return handleSupabaseResponse(data, error);
  },
  getById: async (id) => {
    const { data, error } = await supabase
      .from('projects')
      .select('*, manager:manager_id(*)')
      .eq('id', id)
      .single();
    return handleSupabaseResponse(data, error);
  },
  create: async (project) => {
    const { data, error } = await supabase.from('projects').insert([project]).select().single();
    return handleSupabaseResponse(data, error);
  },
  update: async (id, project) => {
    const { data, error } = await supabase.from('projects').update(project).eq('id', id).select().single();
    return handleSupabaseResponse(data, error);
  },
  delete: async (id) => {
    const { error } = await supabase.from('projects').delete().eq('id', id);
    if (error) throw error;
  }
};

// Tasks API
export const tasksApi = {
  getAll: async (filters = {}) => {
    let query = supabase.from('tasks').select('*, project:project_id(*), assignee:assignee_id(*)');
    if (filters.project_id) query = query.eq('project_id', filters.project_id);
    if (filters.assignee_id) query = query.eq('assignee_id', filters.assignee_id);
    if (filters.status) query = query.eq('status', filters.status);
    const { data, error } = await query;
    return handleSupabaseResponse(data, error);
  },
  getById: async (id) => {
    const { data, error } = await supabase
      .from('tasks')
      .select('*, project:project_id(*), assignee:assignee_id(*)')
      .eq('id', id)
      .single();
    return handleSupabaseResponse(data, error);
  },
  create: async (task) => {
    const { data, error } = await supabase.from('tasks').insert([task]).select().single();
    return handleSupabaseResponse(data, error);
  },
  update: async (id, task) => {
    const { data, error } = await supabase.from('tasks').update(task).eq('id', id).select().single();
    return handleSupabaseResponse(data, error);
  },
  delete: async (id) => {
    const { error } = await supabase.from('tasks').delete().eq('id', id);
    if (error) throw error;
  }
};

// Installations API
export const installationsApi = {
  getAll: async (filters = {}) => {
    let query = supabase.from('installations').select('*, project:project_id(*), assignee:assignee_id(*)');
    if (filters.project_id) query = query.eq('project_id', filters.project_id);
    if (filters.assignee_id) query = query.eq('assignee_id', filters.assignee_id);
    if (filters.status) query = query.eq('status', filters.status);
    const { data, error } = await query;
    return handleSupabaseResponse(data, error);
  },
  getById: async (id) => {
    const { data, error } = await supabase
      .from('installations')
      .select('*, project:project_id(*), assignee:assignee_id(*), purchase_requests:purchase_requests(*)')
      .eq('id', id)
      .single();
    return handleSupabaseResponse(data, error);
  },
  create: async (installation) => {
    const { data, error } = await supabase.from('installations').insert([installation]).select().single();
    return handleSupabaseResponse(data, error);
  },
  update: async (id, installation) => {
    const { data, error } = await supabase.from('installations').update(installation).eq('id', id).select().single();
    return handleSupabaseResponse(data, error);
  },
  delete: async (id) => {
    const { error } = await supabase.from('installations').delete().eq('id', id);
    if (error) throw error;
  }
};

// Purchase Requests API
export const purchaseRequestsApi = {
  getAll: async (filters = {}) => {
    let query = supabase.from('purchase_requests').select('*, installation:installation_id(*), creator:creator_id(*), approved_by:approved_by_id(*)');
    if (filters.status) query = query.eq('status', filters.status);
    const { data, error } = await query;
    return handleSupabaseResponse(data, error);
  },
  getById: async (id) => {
    const { data, error } = await supabase
      .from('purchase_requests')
      .select('*, items:purchase_request_items(*), installation:installation_id(*), creator:creator_id(*)')
      .eq('id', id)
      .single();
    return handleSupabaseResponse(data, error);
  },
  create: async (request) => {
    const { items, ...reqData } = request;
    const { data: pr, error: prError } = await supabase.from('purchase_requests').insert([reqData]).select().single();
    if (prError) throw prError;
    
    if (items && items.length > 0) {
      const itemsToInsert = items.map(item => ({ ...item, purchase_request_id: pr.id }));
      const { error: itemsError } = await supabase.from('purchase_request_items').insert(itemsToInsert);
      if (itemsError) throw itemsError;
    }
    
    return pr;
  },
  updateStatus: async (id, status, comment, receipt_address, received_at) => {
    const { data: { user } } = await supabase.auth.getUser();
    const update = { status, comment, receipt_address, received_at };
    if (status === 'approved' || status === 'completed') {
      update.approved_by_id = user.id;
    }
    const { data, error } = await supabase.from('purchase_requests').update(update).eq('id', id).select().single();
    return handleSupabaseResponse(data, error);
  }
};

// Materials API
export const materialsApi = {
  getAll: async () => {
    const { data, error } = await supabase.from('materials').select('*');
    return handleSupabaseResponse(data, error);
  },
  search: async (searchTerm) => {
    const { data, error } = await supabase.from('materials').select('*').ilike('name', `%${searchTerm}%`);
    return handleSupabaseResponse(data, error);
  }
};

// Warehouse API
export { warehouseApi } from './warehouseApi.js';
