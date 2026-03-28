import express from 'express';
import { supabase } from '../config/supabase.js';
import { authenticateToken, requireManager } from '../middleware/auth.js';

const router = express.Router();

// Get all tasks with filters
router.get('/', authenticateToken, async (req, res) => {
  try {
    const { project_id, assignee_id, status } = req.query;
    
    let query = supabase
      .from('tasks')
      .select(`
        *,
        project:projects(id, name),
        assignee:users!tasks_assignee_id_fkey(id, name, email)
      `)
      .order('created_at', { ascending: false });

    if (project_id) {
      query = query.eq('project_id', project_id);
    }

    if (assignee_id) {
      query = query.eq('assignee_id', assignee_id);
    }

    if (status) {
      query = query.eq('status', status);
    }

    // Workers can only see their own tasks
    if (req.user.role === 'worker') {
      query = query.eq('assignee_id', req.user.id);
    }

    const { data: tasks, error } = await query;

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json({ tasks });
  } catch (error) {
    console.error('Get tasks error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get single task
router.get('/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;

    const { data: task, error } = await supabase
      .from('tasks')
      .select(`
        *,
        project:projects(id, name),
        assignee:users!tasks_assignee_id_fkey(id, name, email)
      `)
      .eq('id', id)
      .single();

    if (error || !task) {
      return res.status(404).json({ error: 'Task not found' });
    }

    // Get related purchase requests
    const { data: purchaseRequests } = await supabase
      .from('purchase_requests')
      .select(`
        *,
        creator:users!purchase_requests_created_by_fkey(id, name),
        approved_by_user:users!purchase_requests_approved_by_fkey(id, name),
        items:purchase_request_items(*)
      `)
      .eq('task_id', id)
      .order('created_at', { ascending: false });

    res.json({ task: { ...task, purchaseRequests } });
  } catch (error) {
    console.error('Get task error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create task (manager only)
router.post('/', authenticateToken, requireManager, async (req, res) => {
  try {
    console.log('Creating task, user role:', req.user.role);
    const { project_id, title, description, assignee_id, status = 'new', due_date } = req.body;

    if (!project_id || !title) {
      return res.status(400).json({ error: 'Project ID and title are required' });
    }

    const { data: task, error } = await supabase
      .from('tasks')
      .insert([{ 
        project_id, 
        title, 
        description, 
        assignee_id, 
        status,
        due_date
      }])
      .select()
      .single();

    if (error) {
      console.error('Supabase error creating task:', error);
      return res.status(400).json({ error: error.message });
    }

    console.log('Task created successfully:', task);
    res.status(201).json({ task });
  } catch (error) {
    console.error('Create task error:', error);
    res.status(500).json({ error: 'Internal server error: ' + error.message });
  }
});

// Update task
router.put('/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { title, description, assignee_id, status, due_date } = req.body;

    // Check if task exists
    const { data: existingTask } = await supabase
      .from('tasks')
      .select('*')
      .eq('id', id)
      .single();

    if (!existingTask) {
      return res.status(404).json({ error: 'Task not found' });
    }

    // Workers can only update their own tasks
    if (req.user.role === 'worker' && existingTask.assignee_id !== req.user.id) {
      return res.status(403).json({ error: 'You can only update your own tasks' });
    }

    const { data: task, error } = await supabase
      .from('tasks')
      .update({ 
        title, 
        description, 
        assignee_id, 
        status,
        due_date,
        updated_at: new Date().toISOString()
      })
      .eq('id', id)
      .select()
      .single();

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json({ task });
  } catch (error) {
    console.error('Update task error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Delete task (manager only)
router.delete('/:id', authenticateToken, requireManager, async (req, res) => {
  try {
    const { id } = req.params;

    const { error } = await supabase
      .from('tasks')
      .delete()
      .eq('id', id);

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json({ message: 'Task deleted successfully' });
  } catch (error) {
    console.error('Delete task error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;
