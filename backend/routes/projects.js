import express from 'express';
import { supabase } from '../config/supabase.js';
import { authenticateToken, requireManager } from '../middleware/auth.js';

const router = express.Router();

// Get all projects
router.get('/', authenticateToken, async (req, res) => {
  try {
    const { status } = req.query;
    let query = supabase
      .from('projects')
      .select(`
        *,
        creator:users!projects_created_by_fkey(id, name, email),
        tasks(id, title, status, assignee_id),
        installations(id, title, status, assignee_id)
      `)
      .order('created_at', { ascending: false });

    if (status) {
      query = query.eq('status', status);
    }

    // If worker, only show projects they are assigned to
    if (req.user.role === 'worker') {
      query = query.or(`tasks.assignee_id.eq.${req.user.id},installations.assignee_id.eq.${req.user.id}`);
    }

    const { data: projects, error } = await query;

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json({ projects });
  } catch (error) {
    console.error('Get projects error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get single project
router.get('/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;

    const { data: project, error } = await supabase
      .from('projects')
      .select(`
        *,
        creator:users!projects_created_by_fkey(id, name, email)
      `)
      .eq('id', id)
      .single();

    if (error || !project) {
      return res.status(404).json({ error: 'Project not found' });
    }

    // Get related tasks
    const { data: tasks } = await supabase
      .from('tasks')
      .select(`
        *,
        assignee:users!tasks_assignee_id_fkey(id, name, email)
      `)
      .eq('project_id', id)
      .order('created_at', { ascending: false });

    // Get related installations
    const { data: installations } = await supabase
      .from('installations')
      .select(`
        *,
        assignee:users!installations_assignee_id_fkey(id, name, email)
      `)
      .eq('project_id', id)
      .order('scheduled_at', { ascending: true });

    res.json({ project: { ...project, tasks, installations } });
  } catch (error) {
    console.error('Get project error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create project (manager only)
router.post('/', authenticateToken, requireManager, async (req, res) => {
  try {
    const { name, description } = req.body;

    if (!name) {
      return res.status(400).json({ error: 'Project name is required' });
    }

    const { data: project, error } = await supabase
      .from('projects')
      .insert([{ 
        name, 
        description, 
        created_by: req.user.id 
      }])
      .select()
      .single();

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.status(201).json({ project });
  } catch (error) {
    console.error('Create project error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update project (manager only)
router.put('/:id', authenticateToken, requireManager, async (req, res) => {
  try {
    const { id } = req.params;
    const { name, description, status } = req.body;

    const { data: project, error } = await supabase
      .from('projects')
      .update({ 
        name, 
        description, 
        status,
        updated_at: new Date().toISOString()
      })
      .eq('id', id)
      .select()
      .single();

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json({ project });
  } catch (error) {
    console.error('Update project error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Delete project (manager only)
router.delete('/:id', authenticateToken, requireManager, async (req, res) => {
  try {
    const { id } = req.params;

    const { error } = await supabase
      .from('projects')
      .delete()
      .eq('id', id);

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json({ message: 'Project deleted successfully' });
  } catch (error) {
    console.error('Delete project error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;
