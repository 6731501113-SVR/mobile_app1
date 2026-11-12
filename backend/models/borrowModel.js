const { pool } = require('../config/db');

const runner = (conn) => conn || pool;

const REQUEST_SELECT = `
    SELECT b.*,
           u.full_name AS user_name,
           (SELECT COUNT(*) FROM borrow_items bi WHERE bi.request_id = b.id) AS item_count
    FROM borrow_requests b
    JOIN users u ON u.id = b.user_id`;

const ITEM_SELECT = `
    SELECT bi.*,
           e.name      AS equipment_name,
           e.asset_code,
           e.image_url AS equipment_image
    FROM borrow_items bi
    JOIN equipment e ON e.id = bi.equipment_id`;

// ---------- อ่านข้อมูล ----------

exports.findRequestById = async (id, conn) => {
    const [rows] = await runner(conn).query('SELECT * FROM borrow_requests WHERE id = ?', [id]);
    return rows[0];
};

exports.getItems = async (requestId, conn) => {
    const [rows] = await runner(conn).query('SELECT * FROM borrow_items WHERE request_id = ?', [requestId]);
    return rows;
};

exports.listAll = async (status) => {
    let sql = REQUEST_SELECT;
    const params = [];
    if (status) {
        sql += ' WHERE b.status = ?';
        params.push(status);
    }
    sql += ' ORDER BY b.id DESC';
    const [rows] = await pool.query(sql, params);
    return rows;
};

exports.listByUser = async (userId) => {
    const [rows] = await pool.query(REQUEST_SELECT + ' WHERE b.user_id = ? ORDER BY b.id DESC', [userId]);
    return rows;
};

exports.findDetailById = async (id) => {
    const [rows] = await pool.query(REQUEST_SELECT + ' WHERE b.id = ?', [id]);
    return rows[0];
};

// แนบรายการอุปกรณ์ย่อย (items) เข้าไปในแต่ละใบคำขอ ด้วย query เดียว
exports.attachItems = async (requests) => {
    if (requests.length === 0) return requests;
    const ids = requests.map((r) => r.id);
    const [items] = await pool.query(ITEM_SELECT + ' WHERE bi.request_id IN (?) ORDER BY bi.id', [ids]);

    const byRequest = {};
    for (const it of items) {
        (byRequest[it.request_id] ||= []).push(it);
    }
    return requests.map((r) => ({ ...r, items: byRequest[r.id] || [] }));
};

exports.findBookedDates = async (equipmentId) => {
    const [rows] = await pool.query(
        `SELECT br.start_date, br.end_date
         FROM borrow_requests br
         JOIN borrow_items bi ON bi.request_id = br.id
         WHERE bi.equipment_id = ? AND br.status = 'approved'`,
        [equipmentId]
    );
    return rows;
};

// อุปกรณ์ที่มีใบคำขออื่น (pending/approved) ทับช่วงวันที่ขอ
exports.findOverlaps = async (equipmentIds, startDate, endDate, conn) => {
    const [rows] = await runner(conn).query(
        `SELECT bi.equipment_id
         FROM borrow_requests br
         JOIN borrow_items bi ON bi.request_id = br.id
         WHERE bi.equipment_id IN (?)
           AND br.status IN ('approved', 'pending')
           AND NOT (br.end_date < ? OR br.start_date > ?)`,
        [equipmentIds, startDate, endDate]
    );
    return rows;
};

// ---------- เขียนข้อมูล ----------

exports.createRequest = async (d, conn) => {
    const [result] = await runner(conn).query(
        `INSERT INTO borrow_requests
            (user_id, purpose, start_date, end_date, total_price, total_deposit, status, payment_status)
         VALUES (?, ?, ?, ?, ?, ?, 'pending', 'pending')`,
        [d.user_id, d.purpose, d.start_date, d.end_date, d.total_price, d.total_deposit]
    );
    return result.insertId;
};

exports.addItems = async (requestId, equipmentIds, conn) => {
    await runner(conn).query(
        'INSERT INTO borrow_items (request_id, equipment_id) VALUES ?',
        [equipmentIds.map((eid) => [requestId, eid])]
    );
};

exports.setSlip = async (id, slipUrl) => {
    await pool.query(
        "UPDATE borrow_requests SET slip_url = ?, payment_status = 'pending' WHERE id = ?",
        [slipUrl, id]
    );
};

exports.setPaymentStatus = async (id, paymentStatus, adminNote) => {
    await pool.query(
        'UPDATE borrow_requests SET payment_status = ?, admin_note = ? WHERE id = ?',
        [paymentStatus, adminNote, id]
    );
};

// อนุมัติ/ปฏิเสธ (เฉพาะใบที่ยัง pending) คืน true ถ้าเปลี่ยนสำเร็จ
exports.setReviewed = async (id, status, adminId, adminNote, conn) => {
    const [result] = await runner(conn).query(
        `UPDATE borrow_requests
         SET status = ?, approved_by = ?, handled_by = ?, admin_note = ?
         WHERE id = ? AND status = 'pending'`,
        [status, adminId, adminId, adminNote, id]
    );
    return result.affectedRows > 0;
};

exports.setHandledBy = async (id, adminId) => {
    await pool.query('UPDATE borrow_requests SET handled_by = ? WHERE id = ?', [adminId, id]);
};

// บันทึกการคืน (เฉพาะใบที่ approved/borrowed) คืน true ถ้าสำเร็จ
exports.markReturned = async (id, fineAmount, adminNote, conn) => {
    const [result] = await runner(conn).query(
        `UPDATE borrow_requests
         SET status = 'returned', actual_return_date = NOW(), fine_amount = ?,
             admin_note = COALESCE(?, admin_note)
         WHERE id = ? AND status IN ('approved', 'borrowed')`,
        [fineAmount, adminNote, id]
    );
    return result.affectedRows > 0;
};

exports.updateItemAfterReturn = async (itemId, condition, fineAmount, finePaid, conn) => {
    await runner(conn).query(
        'UPDATE borrow_items SET condition_after = ?, fine_amount = ?, fine_paid = ? WHERE id = ?',
        [condition, fineAmount, finePaid, itemId]
    );
};

// ยกเลิก (เฉพาะใบที่ยัง pending) คืน true ถ้าสำเร็จ
exports.cancel = async (id) => {
    const [result] = await pool.query(
        "UPDATE borrow_requests SET status = 'cancelled' WHERE id = ? AND status = 'pending'",
        [id]
    );
    return result.affectedRows > 0;
};
