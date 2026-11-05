const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const router = express.Router();
const con = require('../db_config').promise();
const jwt = require('jsonwebtoken');

const JWT_KEY = 'sdf1216werxfw@dsjfrewi';

const requireAdmin = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    if (!authHeader) return res.status(401).json({ message: 'No token provided' });
    const token = authHeader.split(' ')[1];
    jwt.verify(token, JWT_KEY, (err, decoded) => {
        if (err) return res.status(403).json({ message: 'Invalid token' });
        if (decoded.role !== 'admin') return res.status(403).json({ message: 'Admin only' });
        req.user = decoded;
        next();
    });
};

const uploadDir = path.join(__dirname, '..', 'uploads');
fs.mkdirSync(uploadDir, { recursive: true });

const upload = multer({
    storage: multer.diskStorage({
        destination: (req, file, cb) => cb(null, uploadDir),
        filename: (req, file, cb) => {
            const ext = path.extname(file.originalname).toLowerCase();
            cb(null, `equipment-${Date.now()}-${Math.round(Math.random() * 1e6)}${ext}`);
        }
    }),
    limits: { fileSize: 5 * 1024 * 1024 },
    fileFilter: (req, file, cb) => {
        if (/^image\/(jpeg|png|gif|webp)$/.test(file.mimetype)) return cb(null, true);
        cb(new Error('Only image files (jpg, png, gif, webp) are allowed'));
    }
});

function uploadImage(req, res, next) {
    upload.single('image')(req, res, (err) => {
        if (err) return res.status(400).json({ message: err.message });
        next();
    });
}

function discardUpload(req) {
    if (req.file) fs.unlink(req.file.path, () => {});
}

const MANUAL_STATUSES = ['available', 'maintenance', 'lost'];

// GET /api/equipments
router.get('/', async (req, res) => {
    try {
        const { search, category_id, status } = req.query;
        let sql = `SELECT e.*, c.category_name FROM equipment e LEFT JOIN categories c ON c.id = e.category_id WHERE 1=1`;
        const params = [];

        if (search) {
            sql += ' AND (e.name LIKE ? OR e.asset_code LIKE ?)';
            params.push(`%${search}%`, `%${search}%`);
        }
        if (category_id) {
            sql += ' AND e.category_id = ?';
            params.push(category_id);
        }
        if (status) {
            sql += ' AND e.status = ?';
            params.push(status);
        }
        sql += ' ORDER BY e.id DESC';

        const [rows] = await con.query(sql, params);
        res.json(rows);
    } catch (err) {
        console.error(err);
        res.status(500).json({ message: 'Server error' });
    }
});

// GET /api/equipments/:id
router.get('/:id', async (req, res) => {
    try {
        const [rows] = await con.query(
            `SELECT e.*, c.category_name FROM equipment e LEFT JOIN categories c ON c.id = e.category_id WHERE e.id = ?`,
            [req.params.id]
        );
        if (rows.length === 0) return res.status(404).json({ message: 'Equipment not found' });
        res.json(rows[0]);
    } catch (err) {
        console.error(err);
        res.status(500).json({ message: 'Server error' });
    }
});

// POST /api/equipments
router.post('/', requireAdmin, uploadImage, async (req, res) => {
    try {
        const { asset_code, name, category_id, status = 'available' } = req.body || {};
        if (!asset_code || !name || !category_id) {
            discardUpload(req);
            return res.status(400).json({ message: 'asset_code, name and category_id are required' });
        }
        if (!MANUAL_STATUSES.includes(status)) {
            discardUpload(req);
            return res.status(400).json({ message: `status must be one of: ${MANUAL_STATUSES.join(', ')}` });
        }

        const [cat] = await con.query('SELECT id FROM categories WHERE id = ?', [category_id]);
        if (cat.length === 0) {
            discardUpload(req);
            return res.status(400).json({ message: 'category_id does not exist' });
        }

        const imageUrl = req.file ? `/uploads/${req.file.filename}` : (req.body.image_url || null);
        const [result] = await con.query(
            `INSERT INTO equipment (asset_code, name, category_id, status, image_url) VALUES (?, ?, ?, ?, ?)`,
            [asset_code, name, category_id, status, imageUrl]
        );
        res.status(201).json({ message: 'Equipment created', id: result.insertId, image_url: imageUrl });
    } catch (err) {
        discardUpload(req);
        if (err.code === 'ER_DUP_ENTRY') return res.status(409).json({ message: 'asset_code already exists' });
        console.error(err);
        res.status(500).json({ message: 'Server error' });
    }
});

// PUT /api/equipments/:id
router.put('/:id', requireAdmin, uploadImage, async (req, res) => {
    try {
        const { asset_code, name, category_id, status } = req.body || {};
        const [rows] = await con.query('SELECT * FROM equipment WHERE id = ?', [req.params.id]);
        if (rows.length === 0) {
            discardUpload(req);
            return res.status(404).json({ message: 'Equipment not found' });
        }
        const old = rows[0];

        if (category_id !== undefined) {
            const [cat] = await con.query('SELECT id FROM categories WHERE id = ?', [category_id]);
            if (cat.length === 0) {
                discardUpload(req);
                return res.status(400).json({ message: 'category_id does not exist' });
            }
        }

        let newStatus = old.status;
        if (status !== undefined && status !== old.status) {
            if (!MANUAL_STATUSES.includes(status)) {
                discardUpload(req);
                return res.status(400).json({ message: `status must be one of: ${MANUAL_STATUSES.join(', ')}` });
            }
            if (old.status === 'borrowed') {
                discardUpload(req);
                return res.status(409).json({ message: 'Cannot change status: equipment is currently borrowed' });
            }
            newStatus = status;
        }

        const newImage = req.file ? `/uploads/${req.file.filename}` : (req.body.image_url ?? old.image_url);
        await con.query(
            `UPDATE equipment SET asset_code = ?, name = ?, category_id = ?, status = ?, image_url = ? WHERE id = ?`,
            [asset_code ?? old.asset_code, name ?? old.name, category_id ?? old.category_id, newStatus, newImage, old.id]
        );

        if (req.file && old.image_url && old.image_url.startsWith('/uploads/')) {
            fs.unlink(path.join(__dirname, '..', old.image_url), () => {});
        }
        res.json({ message: 'Equipment updated', image_url: newImage });
    } catch (err) {
        discardUpload(req);
        if (err.code === 'ER_DUP_ENTRY') return res.status(409).json({ message: 'asset_code already exists' });
        console.error(err);
        res.status(500).json({ message: 'Server error' });
    }
});

// DELETE /api/equipments/:id
router.delete('/:id', requireAdmin, async (req, res) => {
    try {
        const [rows] = await con.query('SELECT * FROM equipment WHERE id = ?', [req.params.id]);
        if (rows.length === 0) return res.status(404).json({ message: 'Equipment not found' });
        if (rows[0].status === 'borrowed') return res.status(409).json({ message: 'Cannot delete: equipment is currently borrowed' });

        const [used] = await con.query('SELECT id FROM borrow_items WHERE equipment_id = ? LIMIT 1', [req.params.id]);
        if (used.length > 0) {
            return res.status(409).json({ message: 'Cannot delete: equipment has borrow history. Set status to maintenance or lost instead.' });
        }

        await con.query('DELETE FROM equipment WHERE id = ?', [req.params.id]);
        if (rows[0].image_url && rows[0].image_url.startsWith('/uploads/')) {
            fs.unlink(path.join(__dirname, '..', rows[0].image_url), () => {});
        }
        res.json({ message: 'Equipment deleted' });
    } catch (err) {
        console.error(err);
        res.status(500).json({ message: 'Server error' });
    }
});

module.exports = router;