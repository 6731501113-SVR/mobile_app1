const { pool } = require('../config/db');

// ฟิลด์ที่ส่งออกไปได้ (ไม่รวม password)
const PUBLIC_FIELDS = 'id, username, full_name, role';

exports.findByUsername = async (username) => {
    const [rows] = await pool.query('SELECT * FROM users WHERE username = ?', [username]);
    return rows[0];
};

exports.findById = async (id) => {
    const [rows] = await pool.query(`SELECT ${PUBLIC_FIELDS} FROM users WHERE id = ?`, [id]);
    return rows[0];
};

exports.findAll = async () => {
    const [rows] = await pool.query(`SELECT ${PUBLIC_FIELDS} FROM users`);
    return rows;
};

exports.create = async ({ username, password, full_name, role }) => {
    const [result] = await pool.query(
        'INSERT INTO users (username, password, full_name, role) VALUES (?, ?, ?, ?)',
        [username, password, full_name, role]
    );
    return result.insertId;
};

// แก้เฉพาะ field ที่ส่งมา ({ full_name?, password? }) คืนจำนวนแถวที่แก้
exports.update = async (id, fields) => {
    const sets = [];
    const params = [];
    if (fields.full_name !== undefined) {
        sets.push('full_name = ?');
        params.push(fields.full_name);
    }
    if (fields.password !== undefined) {
        sets.push('password = ?');
        params.push(fields.password);
    }
    if (sets.length === 0) return 0;

    params.push(id);
    const [result] = await pool.query(`UPDATE users SET ${sets.join(', ')} WHERE id = ?`, params);
    return result.affectedRows;
};

exports.remove = async (id) => {
    const [result] = await pool.query('DELETE FROM users WHERE id = ?', [id]);
    return result.affectedRows;
};

exports.hasBorrowRequests = async (id) => {
    const [rows] = await pool.query('SELECT id FROM borrow_requests WHERE user_id = ? LIMIT 1', [id]);
    return rows.length > 0;
};
