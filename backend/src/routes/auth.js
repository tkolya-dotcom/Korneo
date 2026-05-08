import express from 'express';
import jwt from 'jsonwebtoken';
import { supabase } from '../config/supabase.js';
import { authenticateToken } from '../middleware/auth.js';

const router = express.Router();

// Login - using Supabase Auth
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    console.log('=== LOGIN DEBUG ===');
    console.log('Login attempt for email:', email);

    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required' });
    }

    // For demo purposes, check against users table
    // In production, use Supabase Auth: supabase.auth.signInWithPassword
    const { data: user, error } = await supabase
      .from('users')
      .select('*')
      .eq('email', email)
      .single();

    console.log('User from database:', JSON.stringify(user));
    console.log('User role from database:', user?.role);

    if (error || !user) {
      console.error('Login error - user not found:', error);
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Generate JWT token
    const tokenPayload = { userId: user.id, email: user.email, role: user.role };
    console.log('JWT token payload:', JSON.stringify(tokenPayload));
    
    const jwtSecret = process.env.JWT_SECRET || 'dev-secret-key-change-in-production';
    
    const token = jwt.sign(
      tokenPayload,
      jwtSecret,
      { expiresIn: '7d' }
    );

    const responseData = {
      token,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        role: user.role
      }
    };
    console.log('Login response:', JSON.stringify(responseData));

    res.json(responseData);
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Register new user (for demo - in production this would use Supabase Auth)
router.post('/register', async (req, res) => {
  try {
    const { email, password, name, role = 'worker' } = req.body;

    console.log('=== REGISTRATION DEBUG ===');
    console.log('Received role from request:', role);
    console.log('Request body:', JSON.stringify(req.body));

    if (!email || !password || !name) {
      return res.status(400).json({ error: 'Email, password and name are required' });
    }

    // Check if user already exists
    const { data: existing } = await supabase
      .from('users')
      .select('id')
      .eq('email', email)
      .single();

    if (existing) {
      return res.status(400).json({ error: 'User already exists' });
    }

    // Create user (in production, use Supabase Auth to create user)
    const insertData = { email, display_name: name, role };
    console.log('Inserting data into users table:', JSON.stringify(insertData));

    const { data: user, error } = await supabase
      .from('users')
      .insert([insertData])
      .select()
      .single();

    if (error) {
      console.error('Supabase insert error:', error);
      return res.status(400).json({ error: error.message });
    }

    console.log('User created in database:', JSON.stringify(user));
    console.log('User role in database:', user.role);

    // Generate JWT token
    const tokenPayload = { userId: user.id, email: user.email, role: user.role };
    console.log('JWT token payload:', JSON.stringify(tokenPayload));

    const token = jwt.sign(
      tokenPayload,
      process.env.JWT_SECRET,
      { expiresIn: '7d' }
    );

    const responseData = {
      token,
      user: {
        id: user.id,
        email: user.email,
        name: user.display_name,
        role: user.role
      }
    };
    console.log('Response data:', JSON.stringify(responseData));

    res.status(201).json(responseData);
  } catch (error) {
    console.error('Register error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get current user
router.get('/me', authenticateToken, async (req, res) => {
  try {
    console.log('=== /ME DEBUG ===');
    console.log('User from token:', JSON.stringify(req.user));
    console.log('User role from token:', req.user?.role);
    
    res.json({ user: req.user });
  } catch (error) {
    console.error('Get user error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get all users (for dropdowns)
router.get('/users', authenticateToken, async (req, res) => {
  try {
    const { role } = req.query;
    
    let query = supabase.from('users').select('id, email, name, role, created_at');
    
    if (role) {
      query = query.eq('role', role);
    }

    const { data: users, error } = await query;

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json({ users });
  } catch (error) {
    console.error('Get users error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;
