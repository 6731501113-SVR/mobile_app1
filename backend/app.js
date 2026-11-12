const config = require('./config/env'); // โหลด .env และตรวจค่าที่จำเป็นก่อนอย่างอื่น
const express = require('express');
const cors = require('cors');
const db = require('./config/db');
const { UPLOAD_DIR } = require('./utils/files');
const { notFound, errorHandler } = require('./middleware/errorHandler');
const paymentExpiry = require('./config/paymentExpiry');

const authRoutes = require('./routes/authRoutes');
const userRoutes = require('./routes/userRoutes');
const categoryRoutes = require('./routes/categoryRoutes');
const equipmentRoutes = require('./routes/equipmentRoutes');
const borrowRoutes = require('./routes/borrowRoutes');
const uploadRoutes = require('./routes/uploadRoutes');

const app = express();

// --- Middlewares ---
app.use(cors());
app.use(express.json());

// เปิดรูปผ่าน URL ได้ (nosniff กันเบราว์เซอร์เดาชนิดไฟล์เอง)
app.use('/uploads', express.static(UPLOAD_DIR, {
    setHeaders: (res) => res.set('X-Content-Type-Options', 'nosniff')
}));

// --- Routes ---
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/categories', categoryRoutes);
app.use('/api/equipments', equipmentRoutes);
app.use('/api/borrows', borrowRoutes);
app.use('/api/upload', uploadRoutes);

app.get('/', (req, res) => {
    res.send('Welcome to Mobile App API (Borrowing System)');
});

app.use(notFound);
app.use(errorHandler);

// --- Run Server (เริ่มรับ request หลังต่อฐานข้อมูลได้แล้วเท่านั้น) ---
db.checkConnection()
    .then(() => {
        app.listen(config.port, () => {
            console.log(`Server is running at port ${config.port}`);
            
            // เริ่มรันระบบเช็กตัดยอดใบคำขอที่เกิน 24 ชม. ทันทีเมื่อเปิดเซิร์ฟเวอร์
            paymentExpiry.start();
        });
    })
    .catch((err) => {
        console.error(`Cannot connect to MySQL (${config.db.host}:${config.db.port}): ${err.message}`);
        console.error('ตรวจว่าเปิด MySQL แล้ว และค่า DB_* ในไฟล์ .env ถูกต้อง');
        process.exit(1);
    });