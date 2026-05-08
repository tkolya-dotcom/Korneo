import express from 'express';
import { supabase } from '../config/supabase.js';

const router = express.Router();

// Get all materials
router.get('/', async (req, res) => {
  try {
    const { category, search } = req.query;
    
    let query = supabase
      .from('materials')
      .select('*')
      .order('category', { ascending: true })
      .order('name', { ascending: true });
    
    if (category) {
      query = query.eq('category', category);
    }
    
    if (search) {
      query = query.ilike('name', `%${search}%`);
    }
    
    const { data, error } = await query;
    
    if (error) throw error;
    
    res.json({ materials: data });
  } catch (err) {
    console.error('Error fetching materials:', err);
    res.status(500).json({ error: err.message });
  }
});

// Get material by ID
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    const { data, error } = await supabase
      .from('materials')
      .select('*')
      .eq('id', id)
      .single();
    
    if (error) throw error;
    
    if (!data) {
      return res.status(404).json({ error: 'Material not found' });
    }
    
    res.json({ material: data });
  } catch (err) {
    console.error('Error fetching material:', err);
    res.status(500).json({ error: err.message });
  }
});

// Get materials by category
router.get('/category/:category', async (req, res) => {
  try {
    const { category } = req.params;
    
    const { data, error } = await supabase
      .from('materials')
      .select('*')
      .eq('category', category)
      .order('name', { ascending: true });
    
    if (error) throw error;
    
    res.json({ materials: data });
  } catch (err) {
    console.error('Error fetching materials by category:', err);
    res.status(500).json({ error: err.message });
  }
});

// Get all categories
router.get('/categories/list', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('materials')
      .select('category')
      .order('category', { ascending: true });
    
    if (error) throw error;
    
    // Get unique categories
    const categories = [...new Set(data.map(item => item.category))];
    
    res.json({ categories });
  } catch (err) {
    console.error('Error fetching categories:', err);
    res.status(500).json({ error: err.message });
  }
});

// Create material (manager only)
router.post('/', async (req, res) => {
  try {
    const { name, category, default_unit, is_optional, comment } = req.body;
    
    if (!name || !category || !default_unit) {
      return res.status(400).json({ error: 'Name, category and default_unit are required' });
    }
    
    const { data, error } = await supabase
      .from('materials')
      .insert([{ name, category, default_unit, is_optional, comment }])
      .select()
      .single();
    
    if (error) throw error;
    
    res.status(201).json({ material: data });
  } catch (err) {
    console.error('Error creating material:', err);
    res.status(500).json({ error: err.message });
  }
});

// Update material (manager only)
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { name, category, default_unit, is_optional, comment } = req.body;
    
    const { data, error } = await supabase
      .from('materials')
      .update({ name, category, default_unit, is_optional, comment, updated_at: new Date().toISOString() })
      .eq('id', id)
      .select()
      .single();
    
    if (error) throw error;
    
    res.json({ material: data });
  } catch (err) {
    console.error('Error updating material:', err);
    res.status(500).json({ error: err.message });
  }
});

// Delete material (manager only)
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    const { error } = await supabase
      .from('materials')
      .delete()
      .eq('id', id);
    
    if (error) throw error;
    
    res.json({ message: 'Material deleted successfully' });
  } catch (err) {
    console.error('Error deleting material:', err);
    res.status(500).json({ error: err.message });
  }
});

export default router;
