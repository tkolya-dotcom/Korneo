import express from 'express';
import { supabase } from '../config/supabase.js';
import { authenticateToken, requireManager } from '../middleware/auth.js';

const router = express.Router();

// Get all installations with filters
router.get('/', authenticateToken, async (req, res) => {
  try {
    const { project_id, assignee_id, status } = req.query;
    
    let query = supabase
      .from('installations')
      .select(`
        *,
        project:projects(id, name),
        assignee:users!installations_assignee_id_fkey(id, name, email)
      `)
      .order('scheduled_at', { ascending: true });

    if (project_id) {
      query = query.eq('project_id', project_id);
    }

    if (assignee_id) {
      query = query.eq('assignee_id', assignee_id);
    }

    if (status) {
      query = query.eq('status', status);
    }

    // Workers can only see their own installations
    if (req.user.role === 'worker') {
      query = query.eq('assignee_id', req.user.id);
    }

    const { data: installations, error } = await query;

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json({ installations });
  } catch (error) {
    console.error('Get installations error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get single installation
router.get('/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;

    const { data: installation, error } = await supabase
      .from('installations')
      .select(`
        *,
        project:projects(id, name),
        assignee:users!installations_assignee_id_fkey(id, name, email)
      `)
      .eq('id', id)
      .single();

    if (error || !installation) {
      return res.status(404).json({ error: 'Installation not found' });
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
      .eq('installation_id', id)
      .order('created_at', { ascending: false });

    res.json({ installation: { ...installation, purchaseRequests } });
  } catch (error) {
    console.error('Get installation error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create installation (manager only)
router.post('/', authenticateToken, requireManager, async (req, res) => {
  try {
    console.log('Creating installation, user role:', req.user.role);
    const { project_id, title, description, assignee_id, status = 'new', scheduled_at, address } = req.body;

    if (!project_id || !title) {
      return res.status(400).json({ error: 'Project ID and title are required' });
    }

    const { data: installation, error } = await supabase
      .from('installations')
      .insert([{ 
        project_id, 
        title, 
        description, 
        assignee_id, 
        status,
        scheduled_at,
        address
      }])
      .select()
      .single();

    if (error) {
      console.error('Supabase error creating installation:', error);
      return res.status(400).json({ error: error.message });
    }

    console.log('Installation created successfully:', installation);
    res.status(201).json({ installation });
  } catch (error) {
    console.error('Create installation error:', error);
    res.status(500).json({ error: 'Internal server error: ' + error.message });
  }
});

// Update installation
router.put('/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { title, description, assignee_id, status, scheduled_at, address } = req.body;

    // Check if installation exists
    const { data: existingInstallation } = await supabase
      .from('installations')
      .select('*')
      .eq('id', id)
      .single();

    if (!existingInstallation) {
      return res.status(404).json({ error: 'Installation not found' });
    }

    // Workers can only update their own installations
    if (req.user.role === 'worker' && existingInstallation.assignee_id !== req.user.id) {
      return res.status(403).json({ error: 'You can only update your own installations' });
    }

    const { data: installation, error } = await supabase
      .from('installations')
      .update({ 
        title, 
        description, 
        assignee_id, 
        status,
        scheduled_at,
        address,
        updated_at: new Date().toISOString()
      })
      .eq('id', id)
      .select()
      .single();

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json({ installation });
  } catch (error) {
    console.error('Update installation error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Delete installation (manager only)
router.delete('/:id', authenticateToken, requireManager, async (req, res) => {
  try {
    const { id } = req.params;

    const { error } = await supabase
      .from('installations')
      .delete()
      .eq('id', id);

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json({ message: 'Installation deleted successfully' });
  } catch (error) {
    console.error('Delete installation error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;
