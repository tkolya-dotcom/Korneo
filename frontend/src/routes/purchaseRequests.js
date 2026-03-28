import express from 'express';
import { supabase } from '../config/supabase.js';
import { authenticateToken, requireManager } from '../middleware/auth.js';

const router = express.Router();

// Get all purchase requests with filters
router.get('/', authenticateToken, async (req, res) => {
  try {
    const { status, project_id, created_by } = req.query;
    
    let query = supabase
      .from('purchase_requests')
      .select(`
        *,
        task:tasks(id, title, project_id, project:projects(id, name)),
        installation:installations(id, title, project_id, project:projects(id, name)),
        creator:users!purchase_requests_created_by_fkey(id, name, email),
        approved_by_user:users!purchase_requests_approved_by_fkey(id, name),
        items:purchase_request_items(*)
      `)
      .order('created_at', { ascending: false });

    if (status) {
      query = query.eq('status', status);
    }

    if (project_id) {
      query = query.or(`task.project_id.eq.${project_id},installation.project_id.eq.${project_id}`);
    }

    if (created_by) {
      query = query.eq('created_by', created_by);
    }

    // Workers can only see their own purchase requests
    if (req.user.role === 'worker') {
      query = query.eq('created_by', req.user.id);
    }

    const { data: purchaseRequests, error } = await query;

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json({ purchaseRequests });
  } catch (error) {
    console.error('Get purchase requests error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get single purchase request
router.get('/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;

    const { data: purchaseRequest, error } = await supabase
      .from('purchase_requests')
      .select(`
        *,
        task:tasks(id, title, project_id, project:projects(id, name)),
        installation:installations(id, title, project_id, project:projects(id, name)),
        creator:users!purchase_requests_created_by_fkey(id, name, email),
        approved_by_user:users!purchase_requests_approved_by_fkey(id, name),
        items:purchase_request_items(*)
      `)
      .eq('id', id)
      .single();

    if (error || !purchaseRequest) {
      return res.status(404).json({ error: 'Purchase request not found' });
    }

    res.json({ purchaseRequest });
  } catch (error) {
    console.error('Get purchase request error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create purchase request
router.post('/', authenticateToken, async (req, res) => {
  try {
    const { task_id, installation_id, comment, items } = req.body;

    if (!task_id && !installation_id) {
      return res.status(400).json({ error: 'Task ID or Installation ID is required' });
    }

    // Verify the user has access to this task/installation
    if (task_id) {
      const { data: task } = await supabase
        .from('tasks')
        .select('assignee_id')
        .eq('id', task_id)
        .single();
      
      if (req.user.role !== 'manager' && task?.assignee_id !== req.user.id) {
        return res.status(403).json({ error: 'You can only create requests for your own tasks' });
      }
    }

    if (installation_id) {
      const { data: installation } = await supabase
        .from('installations')
        .select('assignee_id')
        .eq('id', installation_id)
        .single();
      
      if (req.user.role !== 'manager' && installation?.assignee_id !== req.user.id) {
        return res.status(403).json({ error: 'You can only create requests for your own installations' });
      }
    }

    // Create purchase request
    const { data: purchaseRequest, error } = await supabase
      .from('purchase_requests')
      .insert([{
        task_id,
        installation_id,
        created_by: req.user.id,
        comment,
        status: 'draft'
      }])
      .select()
      .single();

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    // Add items if provided
    if (items && items.length > 0) {
      const itemsWithRequestId = items.map(item => ({
        purchase_request_id: purchaseRequest.id,
        name: item.name,
        quantity: item.quantity,
        unit: item.unit,
        note: item.note
      }));

      const { error: itemsError } = await supabase
        .from('purchase_request_items')
        .insert(itemsWithRequestId);

      if (itemsError) {
        // Rollback purchase request if items fail
        await supabase.from('purchase_requests').delete().eq('id', purchaseRequest.id);
        return res.status(400).json({ error: itemsError.message });
      }
    }

    // Fetch the complete purchase request with items
    const { data: completeRequest } = await supabase
      .from('purchase_requests')
      .select(`
        *,
        items:purchase_request_items(*)
      `)
      .eq('id', purchaseRequest.id)
      .single();

    res.status(201).json({ purchaseRequest: completeRequest });
  } catch (error) {
    console.error('Create purchase request error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update purchase request status (approve/reject - manager only)
router.put('/:id/status', authenticateToken, requireManager, async (req, res) => {
  try {
    const { id } = req.params;
    const { status, comment } = req.body;

    if (!status || !['approved', 'rejected'].includes(status)) {
      return res.status(400).json({ error: 'Status must be approved or rejected' });
    }

    const { data: purchaseRequest, error } = await supabase
      .from('purchase_requests')
      .update({ 
        status, 
        approved_by: req.user.id,
        comment: comment || null,
        updated_at: new Date().toISOString()
      })
      .eq('id', id)
      .select()
      .single();

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json({ purchaseRequest });
  } catch (error) {
    console.error('Update purchase request status error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update purchase request (comment or draft status)
router.put('/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { comment } = req.body;

    // Check if purchase request exists and belongs to user
    const { data: existing } = await supabase
      .from('purchase_requests')
      .select('*')
      .eq('id', id)
      .single();

    if (!existing) {
      return res.status(404).json({ error: 'Purchase request not found' });
    }

    // Workers can only update their own draft/pending requests
    if (req.user.role === 'worker' && existing.created_by !== req.user.id) {
      return res.status(403).json({ error: 'You can only update your own requests' });
    }

    if (req.user.role === 'worker' && !['draft', 'pending'].includes(existing.status)) {
      return res.status(403).json({ error: 'You can only update draft or pending requests' });
    }

    const { data: purchaseRequest, error } = await supabase
      .from('purchase_requests')
      .update({ 
        comment,
        updated_at: new Date().toISOString()
      })
      .eq('id', id)
      .select()
      .single();

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json({ purchaseRequest });
  } catch (error) {
    console.error('Update purchase request error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Add item to purchase request
router.post('/:id/items', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { name, quantity, unit, note } = req.body;

    if (!name || !quantity || !unit) {
      return res.status(400).json({ error: 'Name, quantity and unit are required' });
    }

    // Check if purchase request exists
    const { data: purchaseRequest } = await supabase
      .from('purchase_requests')
      .select('*')
      .eq('id', id)
      .single();

    if (!purchaseRequest) {
      return res.status(404).json({ error: 'Purchase request not found' });
    }

    // Workers can only add items to their own draft/pending requests
    if (req.user.role === 'worker') {
      if (purchaseRequest.created_by !== req.user.id) {
        return res.status(403).json({ error: 'You can only add items to your own requests' });
      }
      if (!['draft', 'pending'].includes(purchaseRequest.status)) {
        return res.status(403).json({ error: 'You can only add items to draft or pending requests' });
      }
    }

    const { data: item, error } = await supabase
      .from('purchase_request_items')
      .insert([{ 
        purchase_request_id: id, 
        name, 
        quantity, 
        unit, 
        note 
      }])
      .select()
      .single();

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.status(201).json({ item });
  } catch (error) {
    console.error('Add item error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update purchase request item
router.put('/items/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { name, quantity, unit, note } = req.body;

    // Check if item exists
    const { data: existingItem } = await supabase
      .from('purchase_request_items')
      .select('*, purchase_request:purchase_requests(*)')
      .eq('id', id)
      .single();

    if (!existingItem) {
      return res.status(404).json({ error: 'Item not found' });
    }

    // Workers can only update items in their own draft/pending requests
    if (req.user.role === 'worker') {
      const purchaseRequest = existingItem.purchase_request;
      if (purchaseRequest.created_by !== req.user.id) {
        return res.status(403).json({ error: 'You can only update items in your own requests' });
      }
      if (!['draft', 'pending'].includes(purchaseRequest.status)) {
        return res.status(403).json({ error: 'You can only update items in draft or pending requests' });
      }
    }

    const { data: item, error } = await supabase
      .from('purchase_request_items')
      .update({ 
        name, 
        quantity, 
        unit, 
        note,
        updated_at: new Date().toISOString()
      })
      .eq('id', id)
      .select()
      .single();

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json({ item });
  } catch (error) {
    console.error('Update item error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Delete purchase request item
router.delete('/items/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;

    // Check if item exists
    const { data: existingItem } = await supabase
      .from('purchase_request_items')
      .select('*, purchase_request:purchase_requests(*)')
      .eq('id', id)
      .single();

    if (!existingItem) {
      return res.status(404).json({ error: 'Item not found' });
    }

    // Workers can only delete items in their own draft/pending requests
    if (req.user.role === 'worker') {
      const purchaseRequest = existingItem.purchase_request;
      if (purchaseRequest.created_by !== req.user.id) {
        return res.status(403).json({ error: 'You can only delete items from your own requests' });
      }
      if (!['draft', 'pending'].includes(purchaseRequest.status)) {
        return res.status(403).json({ error: 'You can only delete items from draft or pending requests' });
      }
    }

    const { error } = await supabase
      .from('purchase_request_items')
      .delete()
      .eq('id', id);

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json({ message: 'Item deleted successfully' });
  } catch (error) {
    console.error('Delete item error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Delete purchase request
router.delete('/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;

    // Check if purchase request exists
    const { data: purchaseRequest } = await supabase
      .from('purchase_requests')
      .select('*')
      .eq('id', id)
      .single();

    if (!purchaseRequest) {
      return res.status(404).json({ error: 'Purchase request not found' });
    }

    // Workers can only delete their own draft/pending requests
    if (req.user.role === 'worker') {
      if (purchaseRequest.created_by !== req.user.id) {
        return res.status(403).json({ error: 'You can only delete your own requests' });
      }
      if (!['draft', 'pending'].includes(purchaseRequest.status)) {
        return res.status(403).json({ error: 'You can only delete draft or pending requests' });
      }
    }

    const { error } = await supabase
      .from('purchase_requests')
      .delete()
      .eq('id', id);

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json({ message: 'Purchase request deleted successfully' });
  } catch (error) {
    console.error('Delete purchase request error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;
