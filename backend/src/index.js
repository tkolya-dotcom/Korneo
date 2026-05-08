import express from 'express';
import cors from 'cors';
import { supabase } from './config/supabase.js';
import { authenticateToken } from './middleware/auth.js';
import purchaseRequestsRouter from './routes/purchaseRequests.js';
import materialsRouter from './routes/materials.js';
import warehouseRouter from './routes/warehouse.js';

// ⚠️ app должен быть объявлен ДО регистрации любых роутов
const app = express();

app.use(cors());
app.use(express.json());

// --- Основные роуты ---
app.use('/api/purchase-requests', purchaseRequestsRouter);
app.use('/api/materials', materialsRouter);
app.use('/api/warehouse', warehouseRouter);

// --- Чат API ---
app.get('/api/chats/:chatId/members', authenticateToken, async (req, res) => {
  try {
    const { chatId } = req.params;

    const { data, error } = await supabase
      .from('chat_members')
      .select(`
        user_id,
        joined_at,
        role,
        users(id, name, email, role, is_online)
      `)
      .eq('chat_id', chatId);

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json({ members: data || [] });
  } catch (error) {
    console.error('Get chat members error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// --- Health check ---
app.get('/health', (_req, res) => res.json({ status: 'ok' }));

export default app;
