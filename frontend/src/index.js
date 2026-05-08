import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

// Import routes
import authRoutes from './routes/auth.js';
import projectsRoutes from './routes/projects.js';
import tasksRoutes from './routes/tasks.js';
import installationsRoutes from './routes/installations.js';
import purchaseRequestsRoutes from './routes/purchaseRequests.js';
import materialsRoutes from './routes/materials.js';

// Load environment variables
dotenv.config();

const app = express();
const PORT = process.env.PORT || 3001;

// Get the directory paths
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Resolve the root directory (parent of backend/)
const rootDir = join(__dirname, '..');

// Middleware
app.use(cors());
app.use(express.json());

// Serve static files from the root directory (where index.html is located)
app.use(express.static(rootDir));

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// API Routes
app.use('/api/auth', authRoutes);
app.use('/api/projects', projectsRoutes);
app.use('/api/tasks', tasksRoutes);
app.use('/api/installations', installationsRoutes);
app.use('/api/purchase-requests', purchaseRequestsRoutes);
app.use('/api/materials', materialsRoutes);

// Serve index.html for all other routes (SPA support)
app.get('*', (req, res) => {
  res.sendFile(join(rootDir, 'index.html'));
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

// Start server
app.listen(PORT, () => {
  console.log(`========================================`);
  console.log(`🚀 Task Manager Application Started!`);
  console.log(`========================================`);
  console.log(`📱 Open your browser at:`);
  console.log(`   http://localhost:${PORT}`);
  console.log(`\n📋 Test accounts:`);
  console.log(`   Manager: Tkolya@gmail.com`);
  console.log(`   Worker: worker@test.com`);
  console.log(`   (Password: any)`);
  console.log(`\n💾 Make sure Supabase is configured`);
  console.log(`   with the schema from sql/schema.sql`);
  console.log(`========================================`);
});

export default app;
