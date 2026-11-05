const express = require('express');
const cors = require('cors');
const path = require('path');
const app = express();

// --- Middlewares ---
app.use(cors());
app.use(express.json());

// ทำให้เข้าถึงรูปภาพผ่าน URL ได้
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// --- Routes Import ---
const authRoutes = require('./modules/authRoutes');
const userRoutes = require('./modules/userRoutes');
const uploadRoutes = require('./modules/uploadRoutes');
const categoryRoutes = require('./modules/categoryRoutes');
const equipmentRoutes = require('./modules/equipmentRoutes');
const borrowRoutes = require('./modules/borrowRoutes');

app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/categories', categoryRoutes);
app.use('/api/equipments', equipmentRoutes);
app.use('/api/borrows', borrowRoutes);
app.use('/api/', uploadRoutes);

// --- Test Route ---
app.get('/', (req, res) => {
    res.send('Welcome to Mobile App API (Borrowing System)');
});

// --- Run Server ---
app.listen(3000, () => console.log('Server is running at port 3000'));