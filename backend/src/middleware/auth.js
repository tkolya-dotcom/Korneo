import jwt from 'jsonwebtoken';
import { supabase } from '../config/supabase.js';

export const authenticateToken = async (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    const { data: user, error } = await supabase
      .from('users')
      .select('*')
      .eq('id', decoded.userId)
      .single();

    if (error || !user) {
      return res.status(401).json({ error: 'User not found' });
    }

    req.user = user;
    next();
  } catch (error) {
    return res.status(403).json({ error: 'Invalid or expired token' });
  }
};

export const requireManager = (req, res, next) => {
  console.log('requireManager check: user role =', req.user?.role);
  if (req.user?.role !== 'manager') {
    return res.status(403).json({ error: 'Доступ запрещён. Только менеджер может создавать монтажи.' });
  }
  next();
};

export const requireWorker = (req, res, next) => {
  if (req.user?.role !== 'worker' && req.user?.role !== 'manager') {
    return res.status(403).json({ error: 'Access denied. Valid role required.' });
  }
  next();
};

export const optionalAuth = async (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    req.user = null;
    return next();
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const { data: user } = await supabase
      .from('users')
      .select('*')
      .eq('id', decoded.userId)
      .single();
    
    req.user = user || null;
  } catch (error) {
    req.user = null;
  }
  
  next();
};
