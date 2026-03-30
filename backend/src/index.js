import express from 'express';
import cors from 'cors';
import purchaseRequestsRouter from './routes/purchaseRequests.js';
import materialsRouter from './routes/materials.js';
import warehouseRouter from './routes/warehouse.js';
// ... другие импорты

const app = express();

app.use(cors());
app.use(express.json());

app.use('/api/purchase-requests', purchaseRequestsRouter);
app.use('/api/materials', materialsRouter);
app.use('/api/warehouse', warehouseRouter);

// ... остальные роуты

export default app;

