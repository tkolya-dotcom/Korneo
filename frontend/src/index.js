import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

import authRoutes from './routes/auth.js';
import projectsRoutes from './routes/projects.js';
import tasksRoutes from './routes/tasks.js';
import installationsRoutes from './routes/installations.js';
import purchaseRequestsRoutes from './routes/purchaseRequests.js';
import materialsRoutes from './routes/materials.js';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3001;

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const rootDir = join(__dirname, '..');

app.use(cors());
app.use(express.json());

app.use(express.static(rootDir));

app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.use('/api/auth', authRoutes);
app.use('/api/projects', projectsRoutes);
app.use('/api/tasks', tasksRoutes);
app.use('/api/installations', installationsRoutes);
app.use('/api/purchase-requests', purchaseRequestsRoutes);
app.use('/api/materials', materialsRoutes);

app.get('*', (req, res) => {
  res.sendFile(join(rootDir, 'index.html'));
});

app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

app.listen(PORT, () => {
  console.log(`========================================`);
  console.log(`рџљЂ Task Manager Application Started!`);
  console.log(`========================================`);
  console.log(`рџ“± Open your browser at:`);
  console.log(`   http://localhost:${PORT}`);
  console.log(`\nрџ“‹ Test accounts:`);
  console.log(`   Manager: Tkolya@gmail.com`);
  console.log(`   Worker: worker@test.com`);
  console.log(`   (Password: any)`);
  console.log(`\nрџ’ѕ Make sure Supabase is configured`);
  console.log(`   with the schema from sql/schema.sql`);
  console.log(`========================================`);
});

export default app;
