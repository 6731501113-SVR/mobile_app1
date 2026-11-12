const { pool } = require('../config/db');

// conn (ไม่บังคับ) = connection ที่อยู่ใน transaction ถ้าไม่ส่งมาจะใช้ pool
const runner = (conn) => conn || pool;

const SELECT_WITH_CATEGORY = `
    SELECT e.*, c.category_name
    FROM equipment e
    LEFT JOIN categories c ON c.id = e.category_id`;

exports.findAll = async ({ search, category_id, status } = {}) => {
    let sql = SELECT_WITH_CATEGORY + ' WHERE 1=1';
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

    const [rows] = await pool.query(sql, params);
    return rows;
};

exports.findById = async (id) => {
    const [rows] = await pool.query(SELECT_WITH_CATEGORY + ' WHERE e.id = ?', [id]);
    return rows[0];
};

// แถวดิบจากตาราง equipment (ไม่ join)
exports.findRawById = async (id) => {
    const [rows] = await pool.query('SELECT * FROM equipment WHERE id = ?', [id]);
    return rows[0];
};

exports.create = async (d) => {
    const [result] = await pool.query(
        `INSERT INTO equipment (asset_code, name, category_id, status, price_per_day, deposit, image_url)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [d.asset_code, d.name, d.category_id, d.status, d.price_per_day, d.deposit, d.image_url]
    );
    return result.insertId;
};

exports.update = async (id, d) => {
    const [result] = await pool.query(
        `UPDATE equipment
         SET asset_code = ?, name = ?, category_id = ?, status = ?, price_per_day = ?, deposit = ?, image_url = ?
         WHERE id = ?`,
        [d.asset_code, d.name, d.category_id, d.status, d.price_per_day, d.deposit, d.image_url, id]
    );
    return result.affectedRows;
};

exports.remove = async (id) => {
    const [result] = await pool.query('DELETE FROM equipment WHERE id = ?', [id]);
    return result.affectedRows;
};

exports.hasBorrowHistory = async (id) => {
    const [rows] = await pool.query('SELECT id FROM borrow_items WHERE equipment_id = ? LIMIT 1', [id]);
    return rows.length > 0;
};

// ล็อกแถวอุปกรณ์ (FOR UPDATE) ใน transaction เพื่อกันสองคนจองชิ้นเดียวกันพร้อมกัน
exports.findByIdsForUpdate = async (ids, conn) => {
    const [rows] = await runner(conn).query(
        'SELECT id, price_per_day, deposit, status FROM equipment WHERE id IN (?) FOR UPDATE',
        [ids]
    );
    return rows;
};

// เปลี่ยน available -> borrowed แบบ atomic คืน true ถ้าจองสำเร็จ
exports.claim = async (id, conn) => {
    const [result] = await runner(conn).query(
        "UPDATE equipment SET status = 'borrowed' WHERE id = ? AND status = 'available'",
        [id]
    );
    return result.affectedRows === 1;
};

exports.setStatus = async (id, status, conn) => {
    await runner(conn).query('UPDATE equipment SET status = ? WHERE id = ?', [status, id]);
};
