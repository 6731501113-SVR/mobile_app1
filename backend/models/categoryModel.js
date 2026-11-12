const { pool } = require('../config/db');

exports.findAll = async () => {
    const [rows] = await pool.query('SELECT * FROM categories ORDER BY id ASC');
    return rows;
};

exports.findById = async (id) => {
    const [rows] = await pool.query('SELECT * FROM categories WHERE id = ?', [id]);
    return rows[0];
};

exports.exists = async (id) => {
    const [rows] = await pool.query('SELECT id FROM categories WHERE id = ?', [id]);
    return rows.length > 0;
};

// หาชื่อซ้ำ (excludeId ใช้ตอนแก้ไข เพื่อไม่นับตัวเอง)
exports.nameTaken = async (name, excludeId) => {
    const [rows] = excludeId === undefined
        ? await pool.query('SELECT id FROM categories WHERE category_name = ?', [name])
        : await pool.query('SELECT id FROM categories WHERE category_name = ? AND id <> ?', [name, excludeId]);
    return rows.length > 0;
};

exports.create = async (name) => {
    const [result] = await pool.query('INSERT INTO categories (category_name) VALUES (?)', [name]);
    return result.insertId;
};

exports.rename = async (id, name) => {
    const [result] = await pool.query('UPDATE categories SET category_name = ? WHERE id = ?', [name, id]);
    return result.affectedRows;
};

exports.remove = async (id) => {
    const [result] = await pool.query('DELETE FROM categories WHERE id = ?', [id]);
    return result.affectedRows;
};

exports.isUsedByEquipment = async (id) => {
    const [rows] = await pool.query('SELECT id FROM equipment WHERE category_id = ? LIMIT 1', [id]);
    return rows.length > 0;
};
