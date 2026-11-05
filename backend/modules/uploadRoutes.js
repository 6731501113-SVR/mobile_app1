const express = require('express');
const router = express.Router();
const multer = require('multer');
const fs = require('fs');
const path = require('path');

// 1. ตั้งค่าการจัดเก็บไฟล์ด้วย Multer
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        cb(null, 'uploads/'); // บันทึกไฟล์ไว้ที่โฟลเดอร์ uploads/
    },
    filename: (req, file, cb) => {
        // ตั้งชื่อไฟล์ใหม่กันชื่อซ้ำ โดยใช้วันเวลาปัจจุบัน + นามสกุลเดิม
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, uniqueSuffix + path.extname(file.originalname));
    }
});

const upload = multer({ 
    storage: storage,
    limits: { fileSize: 5 * 1024 * 1024 }, // จำกัดขนาดไฟล์ไม่เกิน 5MB
    fileFilter: (req, file, cb) => {
        // อนุญาตเฉพาะไฟล์รูปภาพ
        if (file.mimetype.startsWith('image/')) {
            cb(null, true);
        } else {
            cb(new Error('Only image files are allowed!'), false);
        }
    }
});

// 2. POST /api/upload (Endpoint สำหรับรับรูปภาพ)
router.post('/upload', upload.single('image'), async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ success: false, message: 'No file uploaded.' });
        }

        const equipmentName = typeof req.body.name === 'string' ? req.body.name.trim() : '';
        if (equipmentName) {
            const safeName = equipmentName
                .normalize('NFKC')
                .replace(/[<>:"/\\|?*\x00-\x1F]/g, '-')
                .replace(/\s+/g, '-')
                .replace(/-+/g, '-')
                .replace(/^[.-]+|[.-]+$/g, '')
                .slice(0, 80);

            if (safeName) {
                const uniqueSuffix = path.basename(req.file.filename, path.extname(req.file.filename));
                const filename = `${safeName}-${uniqueSuffix}${path.extname(req.file.originalname)}`;
                const newPath = path.join(path.dirname(req.file.path), filename);
                await fs.promises.rename(req.file.path, newPath);
                req.file.filename = filename;
                req.file.path = newPath;
            }
        }

        // สร้าง URL สำหรับเข้าถึงรูปภาพ
        const imageUrl = `http://localhost:3000/uploads/${encodeURIComponent(req.file.filename)}`;

        res.status(200).json({
            success: true,
            message: 'Image uploaded successfully.',
            data: {
                filename: req.file.filename,
                imageUrl: imageUrl
            }
        });
    } catch (error) {
        console.error(error);
        res.status(500).json({ success: false, message: 'Internal server error.', error: error.message });
    }
});

module.exports = router;