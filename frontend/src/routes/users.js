import express from 'express';
import { supabase } from '../config/supabase.js';
import { authenticateToken } from '../middleware/auth.js';

const router = express.Router();

// Get all users with their online status
router.get('/status', authenticateToken, async (req, res) => {
  try {
    // Mark users as offline if they haven't been seen in 2 minutes
    const twoMinutesAgo = new Date(Date.now() - 2 * 60 * 1000).toISOString();
    
    // First, update all users who haven't sent heartbeat in 2 minutes
    await supabase
      .from('users')
      .update({ is_online: false })
      .lt('last_seen_at', twoMinutesAgo)
      .eq('is_online', true);

    // Get all users with their status
    const { data: users, error } = await supabase
      .from('users')
      .select('id, email, display_name, role, is_online, last_seen_at')
      .order('display_name');

    if (error) {
      console.error('Error fetching users status:', error);
      return res.status(400).json({ error: error.message });
    }

    // Group users by online/offline
    const onlineUsers = users.filter(u => u.is_online);
    const offlineUsers = users.filter(u => !u.is_online);

    res.json({
      users,
      onlineUsers,
      offlineUsers,
      onlineCount: onlineUsers.length,
      offlineCount: offlineUsers.length
    });
  } catch (error) {
    console.error('Get users status error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update user heartbeat (mark as online)
router.post('/heartbeat', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.userId;

    if (!userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const { error } = await supabase
      .from('users')
      .update({ 
        is_online: true,
        last_seen_at: new Date().toISOString()
      })
      .eq('id', userId);

    if (error) {
      console.error('Error updating heartbeat:', error);
      return res.status(400).json({ error: error.message });
    }

    res.json({ success: true, is_online: true });
  } catch (error) {
    console.error('Heartbeat error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Mark user as offline (for logout or tab close)
router.post('/offline', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.userId;

    if (!userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const { error } = await supabase
      .from('users')
      .update({ 
        is_online: false,
        last_seen_at: new Date().toISOString()
      })
      .eq('id', userId);

    if (error) {
      console.error('Error marking offline:', error);
      return res.status(400).json({ error: error.message });
    }

    res.json({ success: true, is_online: false });
  } catch (error) {
    console.error('Mark offline error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;

