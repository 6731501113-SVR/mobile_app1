const mysql = require('mysql2');
const { db } = require('./env');

// ระบบทั้งหมดใช้เวลาไทย (UTC+7) ทั้งฝั่ง Node และฝั่ง MySQL (NOW())
const TIME_ZONE = '+07:00';

// ใช้ pool (ไม่ใช่ connection เดี่ยว) เพื่อให้ขอ connection ไปทำ transaction ได้
const basePool = mysql.createPool({
    host: db.host,
    port: db.port,
    user: db.user,
    password: db.password,
    database: db.database,
    ssl: { rejectUnauthorized: false },
    waitForConnections: true,
    connectionLimit: 10,
    timezone: TIME_ZONE,
    // ป้องกันปัญหาวันที่ (start_date, end_date) เลื่อน 7 ชม. ตอนแปลงเป็น JSON
    dateStrings: ['DATE']
});

// ให้ NOW() ใน MySQL ใช้โซนเวลาเดียวกับที่ Node ใช้แปลงค่า DATETIME
basePool.on('connection', (conn) => {
    conn.query(`SET time_zone = '${TIME_ZONE}'`, (err) => {
        if (err) console.error('Failed to set session time zone:', err.message);
    });
});

const pool = basePool.promise();

// รันงานหลายคำสั่งใน transaction เดียว: สำเร็จ -> commit, โยน error -> rollback
async function withTransaction(work) {
    const conn = await pool.getConnection();
    try {
        await conn.beginTransaction();
        const result = await work(conn);
        await conn.commit();
        return result;
    } catch (err) {
        try { await conn.rollback(); } catch (_) { /* ignore */ }
        throw err;
    } finally {
        conn.release();
    }
}

async function checkConnection() {
    await pool.query('SELECT 1');
}

async function ensureBorrowHistorySnapshots() {
    const [rows] = await pool.query(
        `SELECT COLUMN_NAME
         FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = ? AND TABLE_NAME = 'borrow_items'
           AND COLUMN_NAME IN ('equipment_name', 'asset_code')`,
        [db.database]
    );
    const columns = new Set(rows.map((row) => row.COLUMN_NAME));

    if (!columns.has('equipment_name')) {
        await pool.query('ALTER TABLE borrow_items ADD COLUMN equipment_name VARCHAR(255) NULL');
    }
    if (!columns.has('asset_code')) {
        await pool.query('ALTER TABLE borrow_items ADD COLUMN asset_code VARCHAR(100) NULL');
    }

    await pool.query(`
        UPDATE borrow_items bi
        JOIN equipment e ON e.id = bi.equipment_id
        SET bi.equipment_name = COALESCE(bi.equipment_name, e.name),
            bi.asset_code = COALESCE(bi.asset_code, e.asset_code)
    `);
}

module.exports = { pool, withTransaction, checkConnection, ensureBorrowHistorySnapshots };