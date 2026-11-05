const express = require('express');
const router = express.Router();
const con = require('../db_config').promise();
const jwt = require('jsonwebtoken');

const JWT_KEY = 'sdf1216werxfw@dsjfrewi'; // คีย์ลับตัวเดิมของระบบ

// Middleware ตรวจสอบ Admin
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

// GET /api/categories (Public)
router.get('/', async (req, res) => {
    try {
        const [rows] = await con.query('SELECT * FROM categories ORDER BY id ASC');
        res.json(rows);
    } catch (err) {
        console.error(err);
        res.status(500).json({ message: 'Server error' });
    }
});

// GET /api/categories/:id (Public)
router.get('/:id', async (req, res) => {
    try {
        const [rows] = await con.query('SELECT * FROM categories WHERE id = ?', [req.params.id]);
        if (rows.length === 0) return res.status(404).json({ message: 'Category not found' });
        res.json(rows[0]);
    } catch (err) {
        console.error(err);
        res.status(500).json({ message: 'Server error' });
    }
});

// POST /api/categories (Admin)
router.post('/', requireAdmin, async (req, res) => {
    try {
        const { category_name } = req.body || {};
        if (!category_name || !category_name.trim()) {
            return res.status(400).json({ message: 'category_name is required' });
        }
        const name = category_name.trim();

        const [dup] = await con.query('SELECT id FROM categories WHERE category_name = ?', [name]);
        if (dup.length > 0) return res.status(409).json({ message: 'Category already exists' });

        const [result] = await con.query('INSERT INTO categories (category_name) VALUES (?)', [name]);
        res.status(201).json({ message: 'Category created', id: result.insertId });
    } catch (err) {
        console.error(err);
        res.status(500).json({ message: 'Server error' });
    }
});

// PUT /api/categories/:id (Admin)
router.put('/:id', requireAdmin, async (req, res) => {
    try {
        const { category_name } = req.body || {};
        if (!category_name || !category_name.trim()) {
            return res.status(400).json({ message: 'category_name is required' });
        }
        const name = category_name.trim();

        const [dup] = await con.query(
            'SELECT id FROM categories WHERE category_name = ? AND id <> ?',
            [name, req.params.id]
        );
        if (dup.length > 0) return res.status(409).json({ message: 'Category name already in use' });

        const [result] = await con.query(
            'UPDATE categories SET category_name = ? WHERE id = ?',
            [name, req.params.id]
        );
        if (result.affectedRows === 0) return res.status(404).json({ message: 'Category not found' });
        res.json({ message: 'Category updated' });
    } catch (err) {
        console.error(err);
        res.status(500).json({ message: 'Server error' });
    }
});

// DELETE /api/categories/:id (Admin)
router.delete('/:id', requireAdmin, async (req, res) => {
    try {
        const [used] = await con.query('SELECT id FROM equipment WHERE category_id = ? LIMIT 1', [req.params.id]);
        if (used.length > 0) {
            return res.status(409).json({ message: 'Cannot delete: category is used by equipment' });
        }

        const [result] = await con.query('DELETE FROM categories WHERE id = ?', [req.params.id]);
        if (result.affectedRows === 0) return res.status(404).json({ message: 'Category not found' });
        res.json({ message: 'Category deleted' });
    } catch (err) {
        console.error(err);
        res.status(500).json({ message: 'Server error' });
    }
});

module.exports = router;