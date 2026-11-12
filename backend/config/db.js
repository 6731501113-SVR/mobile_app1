const mysql = require('mysql2');
const { db } = require('./env');

// ใช้ pool (ไม่ใช่ connection เดี่ยว) เพื่อให้ขอ connection ไปทำ transaction ได้
const pool = mysql
    .createPool({
        host: db.host,
        port: db.port,
        user: db.user,
        password: db.password,
        database: db.database,
        waitForConnections: true,
        connectionLimit: 10
    })
    .promise();

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

module.exports = { pool, withTransaction, checkConnection };
