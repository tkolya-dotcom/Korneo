import express from 'express';
import { supabase } from '../config/supabase.js';
import { authenticateToken, requireManager } from '../middleware/auth.js';
import { sendPushNotification } from '../utils/pushNotifications.js';

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
      .eq('is_archived', false)
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

// Get archived installations
router.get('/archived', authenticateToken, async (req, res) => {
  try {
    let query = supabase
      .from('installations')
      .select(`
        *,
        project:projects(id, name),
        assignee:users!installations_assignee_id_fkey(id, name, email)
      `)
      .eq('is_archived', true)
      .order('scheduled_at', { ascending: true });

    // Workers can only see their own archived installations
    if (req.user.role === 'worker') {
      query = query.eq('assignee_id', req.user.id);
    }

    const { data: installations, error } = await query;

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json({ installations });
  } catch (error) {
    console.error('Get archived installations error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Search addresses from atss_q1_2026 and kasip_azm_q1_2026
router.get('/search-address', authenticateToken, async (req, res) => {
  try {
    const { q } = req.query;
    
    if (!q || q.length < 2) {
      return res.json({ addresses: [] });
    }

    // Search in atss_q1_2026 table
    const { data: atssAddresses, error: atssError } = await supabase
      .from('atss_q1_2026')
      .select(`
        id_ploshadki,
        servisnyy_id,
        adres_razmeshcheniya,
        rayon,
        id_sk1,
        naimenovanie_sk1,
        status_oborudovaniya1,
        tip_sk_po_dogovoru1,
        id_sk2,
        naimenovanie_sk2,
        status_oborudovaniya2,
        tip_sk_po_dogovoru2,
        id_sk3,
        naimenovanie_sk3,
        status_oborudovaniya3,
        tip_sk_po_dogovoru3,
        id_sk4,
        naimenovanie_sk4,
        status_oborudovaniya4,
        tip_sk_po_dogovoru4,
        id_sk5,
        naimenovanie_sk5,
        status_oborudovaniya5,
        tip_sk_po_dogovoru5,
        id_sk6,
        naimenovanie_sk6,
        status_oborudovaniya6,
        tip_sk_po_dogovoru6,
        planovaya_data_1_kv_2026
      `)
      .ilike('adres_razmeshcheniya', `%${q}%`)
      .limit(20);

    if (atssError) {
      console.error('Search ATSS addresses error:', atssError);
    }

    // Search in kasip_azm_q1_2026 table
    const { data: kasipAddresses, error: kasipError } = await supabase
      .from('kasip_azm_q1_2026')
      .select(`
        id_ploshadki,
        servisnyy_id,
        adres_raspolozheniya,
        rayon,
        id_konditsionera1,
        naimenovanie_sk1,
        status_sk1,
        tip_sk_po_dogovoru1,
        id_konditsionera2,
        naimenovanie_sk2,
        status_sk2,
        tip_sk_po_dogovoru2,
        id_konditsionera3,
        naimenovanie_sk3,
        status_sk3,
        tip_sk_po_dogovoru3,
        id_konditsionera4,
        naimenovanie_sk4,
        status_sk4,
        tip_sk_po_dogovoru4,
        id_konditsionera5,
        naimenovanie_sk5,
        status_sk5,
        tip_sk_po_dogovoru5,
        id_konditsionera6,
        naimenovanie_sk6,
        status_sk6,
        tip_sk_po_dogovoru6,
        plan_yanvar,
        plan_fevral,
        plan_mart
      `)
      .ilike('adres_raspolozheniya', `%${q}%`)
      .limit(20);

    if (kasipError) {
      console.error('Search KASIP addresses error:', kasipError);
    }

    // Transform ATSS data for frontend
    const transformedAtssAddresses = (atssAddresses || []).map(addr => ({
      id_ploshadki: addr.id_ploshadki,
      servisnyy_id: addr.servisnyy_id,
      adres_razmeshcheniya: addr.adres_razmeshcheniya,
      rayon: addr.rayon,
      planovaya_data_1_kv_2026: addr.planovaya_data_1_kv_2026 ? String(addr.planovaya_data_1_kv_2026) : null,
      source: 'atss',
      sk_count: [
        addr.id_sk1,
        addr.id_sk2,
        addr.id_sk3,
        addr.id_sk4,
        addr.id_sk5,
        addr.id_sk6
      ].filter(Boolean).length,
      sk: [
        addr.id_sk1 ? { id_sk: addr.id_sk1, naimenovanie_sk: addr.naimenovanie_sk1, status_oborudovaniya: addr.status_oborudovaniya1, tip_sk_po_dogovoru: addr.tip_sk_po_dogovoru1 } : null,
        addr.id_sk2 ? { id_sk: addr.id_sk2, naimenovanie_sk: addr.naimenovanie_sk2, status_oborudovaniya: addr.status_oborudovaniya2, tip_sk_po_dogovoru: addr.tip_sk_po_dogovoru2 } : null,
        addr.id_sk3 ? { id_sk: addr.id_sk3, naimenovanie_sk: addr.naimenovanie_sk3, status_oborudovaniya: addr.status_oborudovaniya3, tip_sk_po_dogovoru: addr.tip_sk_po_dogovoru3 } : null,
        addr.id_sk4 ? { id_sk: addr.id_sk4, naimenovanie_sk: addr.naimenovanie_sk4, status_oborudovaniya: addr.status_oborudovaniya4, tip_sk_po_dogovoru: addr.tip_sk_po_dogovoru4 } : null,
        addr.id_sk5 ? { id_sk: addr.id_sk5, naimenovanie_sk: addr.naimenovanie_sk5, status_oborudovaniya: addr.status_oborudovaniya5, tip_sk_po_dogovoru: addr.tip_sk_po_dogovoru5 } : null,
        addr.id_sk6 ? { id_sk: addr.id_sk6, naimenovanie_sk: addr.naimenovanie_sk6, status_oborudovaniya: addr.status_oborudovaniya6, tip_sk_po_dogovoru: addr.tip_sk_po_dogovoru6 } : null
      ].filter(Boolean)
    }));

    // Transform KASIP data for frontend (normalize field names)
    const transformedKasipAddresses = (kasipAddresses || []).map(addr => ({
      id_ploshadki: addr.id_ploshadki,
      servisnyy_id: addr.servisnyy_id,
      adres_razmeshcheniya: addr.adres_raspolozheniya,
      rayon: addr.rayon,
      planovaya_data_1_kv_2026: addr.plan_yanvar ? String(addr.plan_yanvar) : (addr.plan_fevral ? String(addr.plan_fevral) : (addr.plan_mart ? String(addr.plan_mart) : null)),
      source: 'kasip_azm',
      sk_count: [
        addr.id_konditsionera1,
        addr.id_konditsionera2,
        addr.id_konditsionera3,
        addr.id_konditsionera4,
        addr.id_konditsionera5,
        addr.id_konditsionera6
      ].filter(Boolean).length,
      sk: [
        addr.id_konditsionera1 ? { id_sk: addr.id_konditsionera1, naimenovanie_sk: addr.naimenovanie_sk1, status_oborudovaniya: addr.status_sk1, tip_sk_po_dogovoru: addr.tip_sk_po_dogovoru1 } : null,
        addr.id_konditsionera2 ? { id_sk: addr.id_konditsionera2, naimenovanie_sk: addr.naimenovanie_sk2, status_oborudovaniya: addr.status_sk2, tip_sk_po_dogovoru: addr.tip_sk_po_dogovoru2 } : null,
        addr.id_konditsionera3 ? { id_sk: addr.id_konditsionera3, naimenovanie_sk: addr.naimenovanie_sk3, status_oborudovaniya: addr.status_sk3, tip_sk_po_dogovoru: addr.tip_sk_po_dogovoru3 } : null,
        addr.id_konditsionera4 ? { id_sk: addr.id_konditsionera4, naimenovanie_sk: addr.naimenovanie_sk4, status_oborudovaniya: addr.status_sk4, tip_sk_po_dogovoru: addr.tip_sk_po_dogovoru4 } : null,
        addr.id_konditsionera5 ? { id_sk: addr.id_konditsionera5, naimenovanie_sk: addr.naimenovanie_sk5, status_oborudovaniya: addr.status_sk5, tip_sk_po_dogovoru: addr.tip_sk_po_dogovoru5 } : null,
        addr.id_konditsionera6 ? { id_sk: addr.id_konditsionera6, naimenovanie_sk: addr.naimenovanie_sk6, status_oborudovaniya: addr.status_sk6, tip_sk_po_dogovoru: addr.tip_sk_po_dogovoru6 } : null
      ].filter(Boolean)
    }));

    // Combine and sort results
    const allAddresses = [...transformedAtssAddresses, ...transformedKasipAddresses]
      .sort((a, b) => (a.adres_razmeshcheniya || '').localeCompare(b.adres_razmeshcheniya || ''))
      .slice(0, 20);

    res.json({ addresses: allAddresses });
  } catch (error) {
    console.error('Search addresses error:', error);
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
    const { 
      project_id, title, description, assignee_id, status = 'new', 
      scheduled_at, address, receipt_address, received_at,
      // SK fields
      id_ploshadki, servisnyy_id, rayon, planovaya_data_1_kv_2026,
      id_sk1, naimenovanie_sk1, status_oborudovaniya1, tip_sk_po_dogovoru1,
      id_sk2, naimenovanie_sk2, status_oborudovaniya2, tip_sk_po_dogovoru2,
      id_sk3, naimenovanie_sk3, status_oborudovaniya3, tip_sk_po_dogovoru3,
      id_sk4, naimenovanie_sk4, status_oborudovaniya4, tip_sk_po_dogovoru4,
      id_sk5, naimenovanie_sk5, status_oborudovaniya5, tip_sk_po_dogovoru5,
      id_sk6, naimenovanie_sk6, status_oborudovaniya6, tip_sk_po_dogovoru6
    } = req.body;

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
        address,
        receipt_address,
        received_at,
        // SK fields
        id_ploshadki,
        servisnyy_id,
        rayon,
        planovaya_data_1_kv_2026,
        id_sk1,
        naimenovanie_sk1,
        status_oborudovaniya1,
        tip_sk_po_dogovoru1,
        id_sk2,
        naimenovanie_sk2,
        status_oborudovaniya2,
        tip_sk_po_dogovoru2,
        id_sk3,
        naimenovanie_sk3,
        status_oborudovaniya3,
        tip_sk_po_dogovoru3,
        id_sk4,
        naimenovanie_sk4,
        status_oborudovaniya4,
        tip_sk_po_dogovoru4,
        id_sk5,
        naimenovanie_sk5,
        status_oborudovaniya5,
        tip_sk_po_dogovoru5,
        id_sk6,
        naimenovanie_sk6,
        status_oborudovaniya6,
        tip_sk_po_dogovoru6
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
    const { 
      title, description, assignee_id, status, scheduled_at, address, receipt_address, received_at,
      is_archived,
      // SK fields
      id_ploshadki, servisnyy_id, rayon, planovaya_data_1_kv_2026,
      id_sk1, naimenovanie_sk1, status_oborudovaniya1, tip_sk_po_dogovoru1,
      id_sk2, naimenovanie_sk2, status_oborudovaniya2, tip_sk_po_dogovoru2,
      id_sk3, naimenovanie_sk3, status_oborudovaniya3, tip_sk_po_dogovoru3,
      id_sk4, naimenovanie_sk4, status_oborudovaniya4, tip_sk_po_dogovoru4,
      id_sk5, naimenovanie_sk5, status_oborudovaniya5, tip_sk_po_dogovoru5,
      id_sk6, naimenovanie_sk6, status_oborudovaniya6, tip_sk_po_dogovoru6
    } = req.body;

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

    let updateData = { 
      title, 
      description, 
      assignee_id, 
      status,
      scheduled_at,
      address,
      receipt_address,
      received_at,
      // SK fields
      id_ploshadki,
      servisnyy_id,
      rayon,
      planovaya_data_1_kv_2026,
      id_sk1,
      naimenovanie_sk1,
      status_oborudovaniya1,
      tip_sk_po_dogovoru1,
      id_sk2,
      naimenovanie_sk2,
      status_oborudovaniya2,
      tip_sk_po_dogovoru2,
      id_sk3,
      naimenovanie_sk3,
      status_oborudovaniya3,
      tip_sk_po_dogovoru3,
      id_sk4,
      naimenovanie_sk4,
      status_oborudovaniya4,
      tip_sk_po_dogovoru4,
      id_sk5,
      naimenovanie_sk5,
      status_oborudovaniya5,
      tip_sk_po_dogovoru5,
      id_sk6,
      naimenovanie_sk6,
      status_oborudovaniya6,
      tip_sk_po_dogovoru6,
      updated_at: new Date().toISOString()
    };
    
    // Handle archiving/unarchiving
    if (is_archived !== undefined) {
      updateData.is_archived = is_archived;
    }
    
    if (status && existingInstallation.status !== status) {
      updateData.status_changed_at = new Date().toISOString();
      updateData.status_changed_by = req.user.id;
    }

    const { data: installation, error } = await supabase
      .from('installations')
      .update(updateData)
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
