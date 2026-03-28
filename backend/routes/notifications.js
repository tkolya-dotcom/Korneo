import express from 'express';
import { supabase } from '../config/supabase.js';
import { sendPushNotification, sendMulticastNotification } from '../firebase.js';
import jwt from 'jsonwebtoken';

const router = express.Router();

// Middleware для проверки авторизации
const authenticateToken = async (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];
  
  if (!token) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'your-secret-key');
    req.user = decoded;
    next();
  } catch (error) {
    return res.status(403).json({ error: 'Invalid token' });
  }
};

// POST /api/notifications/send - Отправка уведомления конкретному пользователю
router.post('/send', authenticateToken, async (req, res) => {
  try {
    const { userId, title, body, data } = req.body;
    
    if (!userId || !title || !body) {
      return res.status(400).json({ error: 'Missing required fields: userId, title, body' });
    }
    
    // Получаем FCM токен пользователя из базы данных
    const { data: userData, error: userError } = await supabase
      .from('users')
      .select('fcm_token')
      .eq('id', userId)
      .single();
    
    if (userError || !userData?.fcm_token) {
      return res.status(404).json({ 
        error: 'User FCM token not found',
        message: 'Пользователь не зарегистрирован для push-уведомлений'
      });
    }
    
    // Отправляем уведомление через Firebase Admin SDK
    const result = await sendPushNotification(
      userData.fcm_token,
      title,
      body,
      data || {}
    );
    
    if (result.success) {
      // Сохраняем в историю уведомлений
      await supabase.from('notification_queue').insert([{
        user_id: userId,
        title: title,
        body: body,
        type: data?.type || 'custom',
        reference_id: data?.reference_id,
        sent: true,
        sent_at: new Date().toISOString()
      }]);
      
      res.json({ 
        success: true, 
        messageId: result.messageId,
        message: 'Уведомление отправлено успешно'
      });
    } else {
      res.status(500).json({ 
        success: false, 
        error: result.error,
        message: 'Ошибка отправки уведомления'
      });
    }
  } catch (error) {
    console.error('Error sending notification:', error);
    res.status(500).json({ 
      error: 'Internal server error',
      message: error.message 
    });
  }
});

// POST /api/notifications/send-bulk - Массовая рассылка уведомлений
router.post('/send-bulk', authenticateToken, async (req, res) => {
  try {
    const { userIds, title, body, data } = req.body;
    
    if (!Array.isArray(userIds) || userIds.length === 0) {
      return res.status(400).json({ error: 'userIds must be a non-empty array' });
    }
    
    if (!title || !body) {
      return res.status(400).json({ error: 'Missing required fields: title, body' });
    }
    
    // Получаем FCM токены всех пользователей
    const { data: users, error: usersError } = await supabase
      .from('users')
      .select('id, fcm_token')
      .in('id', userIds);
    
    if (usersError) {
      return res.status(500).json({ error: 'Database error', message: usersError.message });
    }
    
    const tokens = users
      .filter(u => u.fcm_token)
      .map(u => u.fcm_token);
    
    if (tokens.length === 0) {
      return res.status(404).json({ 
        error: 'No valid FCM tokens found',
        message: 'Ни один пользователь не зарегистрирован для push-уведомлений'
      });
    }
    
    // Отправляем массовое уведомление
    const result = await sendMulticastNotification(
      tokens,
      title,
      body,
      data || {}
    );
    
    if (result.success) {
      // Сохраняем в историю
      const notifications = userIds.map(userId => ({
        user_id: userId,
        title: title,
        body: body,
        type: data?.type || 'custom',
        reference_id: data?.reference_id,
        sent: true,
        sent_at: new Date().toISOString()
      }));
      
      await supabase.from('notification_queue').insert(notifications);
      
      res.json({ 
        success: true, 
        successCount: result.successCount,
        failureCount: result.failureCount,
        totalRecipients: userIds.length,
        message: `Отправлено ${result.successCount} из ${userIds.length}`
      });
    } else {
      res.status(500).json({ 
        success: false, 
        error: result.error,
        message: 'Ошибка массовой рассылки'
      });
    }
  } catch (error) {
    console.error('Error sending bulk notification:', error);
    res.status(500).json({ 
      error: 'Internal server error',
      message: error.message 
    });
  }
});

// GET /api/notifications/status/:userId - Проверка статуса уведомлений пользователя
router.get('/status/:userId', authenticateToken, async (req, res) => {
  try {
    const { userId } = req.params;
    
    const { data: userData, error } = await supabase
      .from('users')
      .select('fcm_token, notification_enabled')
      .eq('id', userId)
      .single();
    
    if (error) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    res.json({
      hasFcmToken: !!userData.fcm_token,
      notificationsEnabled: userData.notification_enabled !== false,
      lastChecked: new Date().toISOString()
    });
  } catch (error) {
    console.error('Error checking notification status:', error);
    res.status(500).json({ error: error.message });
  }
});

export default router;
