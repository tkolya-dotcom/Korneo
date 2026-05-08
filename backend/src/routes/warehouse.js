import express from 'express';
import { supabase } from '../config/supabase.js';
import { authenticateToken, requireManager } from '../middleware/auth.js';

const router = express.Router();

// Get warehouse stock by material (с остатками)
router.get('/', authenticateToken, async (req, res) => {
  try {
    const { material_ids } = req.query;

    let query = supabase
      .from('warehouse')
      .select(`
        *,
        material:materials(name, unit, category)
      `)
      .order('updated_at', { ascending: false });

    if (material_ids) {
      const ids = material_ids.split(',').map(id => id.trim());
      query = query.in('material_id', ids);
    }

    const { data: stock, error } = await query;

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    // Группируем по material_id
    const stockByMaterial = {};
    stock.forEach(item => {
      const matId = item.material_id;
      if (!stockByMaterial[matId]) {
        stockByMaterial[matId] = {
          material_id: matId,
          quantity: 0,
          material: item.material,
          updated_at: item.updated_at,
        };
      }
      stockByMaterial[matId].quantity += parseFloat(item.quantity || 0);
    });

    res.json({ stock: Object.values(stockByMaterial) });
  } catch (error) {
    console.error('Get warehouse error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get all warehouse overview
router.get('/overview', authenticateToken, async (req, res) => {
  try {
    const { search, category } = req.query;

    let query = supabase
      .from('warehouse')
      .select(`
        material_id,
        quantity,
        material:materials(name, unit, category, min_quantity)
      `)
      .order('updated_at', { ascending: false });

    if (category) {
      query = query.eq('material.category', category);
    }

    const { data, error } = await query;

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    // Группируем в JS и фильтруем по поиску
    const byMaterial = {};
    (data || []).forEach(row => {
      const id = row.material_id;
      if (!byMaterial[id]) {
        byMaterial[id] = { material_id: id, total_quantity: 0, material: row.material };
      }
      byMaterial[id].total_quantity += parseFloat(row.quantity || 0);
    });

    let result = Object.values(byMaterial);
    if (search) {
      const q = search.toLowerCase();
      result = result.filter(r => r.material?.name?.toLowerCase().includes(q));
    }
    result.sort((a, b) => b.total_quantity - a.total_quantity);

    res.json({ warehouse: result });
  } catch (error) {
    console.error('Get warehouse overview error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update stock quantity (manager only, для прихода/списания)
router.put('/:material_id/stock', authenticateToken, requireManager, async (req, res) => {
  try {
    const { material_id } = req.params;
    const { quantity_delta, operation, note, location } = req.body;
    // quantity_delta: положительное = приход, отрицательное = списание
    // operation: 'receipt' | 'usage'

    if (quantity_delta === undefined || quantity_delta === null) {
      return res.status(400).json({ error: 'quantity_delta required' });
    }

    const parsedDelta = parseFloat(quantity_delta);
    if (isNaN(parsedDelta)) {
      return res.status(400).json({ error: 'Invalid quantity_delta' });
    }

    // Получаем текущий остаток для информации в ответе
    let currentQty = 0;
    if (parsedDelta < 0) {
      const { data: stockRows } = await supabase
        .from('warehouse')
        .select('quantity')
        .eq('material_id', material_id);
      currentQty = (stockRows || []).reduce((s, r) => s + parseFloat(r.quantity || 0), 0);
    }

    // UPSERT warehouse
    const { data: existing, error: fetchError } = await supabase
      .from('warehouse')
      .select('*')
      .eq('material_id', material_id)
      .maybeSingle();

    if (fetchError && fetchError.code !== 'PGRST116') {
      return res.status(500).json({ error: fetchError.message });
    }

    let newRecord;
    if (existing) {
      newRecord = {
        id: existing.id,
        material_id,
        quantity: parseFloat(existing.quantity || 0) + parsedDelta,
        location: location || existing.location,
        updated_at: new Date().toISOString(),
      };
      await supabase.from('warehouse').update(newRecord).eq('id', existing.id);
    } else {
      newRecord = {
        material_id,
        quantity: parsedDelta,
        location: location || 'Основной склад',
        updated_at: new Date().toISOString(),
      };
      const { data: inserted, error: insertError } = await supabase
        .from('warehouse')
        .insert([newRecord])
        .select()
        .single();
      if (insertError) {
        return res.status(400).json({ error: insertError.message });
      }
      newRecord.id = inserted.id;
    }

    // Логирование в materials_usage при списании
    if (parsedDelta < 0 && operation === 'usage') {
      await supabase.from('materials_usage').insert([{
        material_id,
        quantity: Math.abs(parsedDelta),
        user_id: req.user.id,
        note: note || `Списание (${operation})`,
        used_at: new Date().toISOString(),
      }]);
    }

    const newQty = newRecord.quantity;

    // Если ушли в минус — триггер БД (handle_negative_stock) уже создал purchase_request.
    // Возвращаем предупреждение в ответе, чтобы UI мог показать алерт.
    const response = {
      message: 'Stock updated',
      material_id,
      new_quantity: newQty,
      delta: parsedDelta,
    };

    if (newQty < 0) {
      response.warning = `Остаток ушёл в минус (${newQty}). Автоматически создана заявка на закупку.`;
      response.deficit = Math.abs(newQty);
    }

    res.json(response);
  } catch (error) {
    console.error('Update stock error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;
