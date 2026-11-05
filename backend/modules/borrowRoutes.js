const express = require('express');
const router = express.Router();
const con = require('../db_config').promise();
const jwt = require('jsonwebtoken');

const JWT_KEY = 'sdf1216werxfw@dsjfrewi';

// Middleware ตรวจสอบ Token ทั่วไป (สำหรับ Borrower และ Admin)
const verifyToken = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    if (!authHeader) return res.status(401).json({ message: 'No token provided' });
    const token = authHeader.split(' ')[1];
    jwt.verify(token, JWT_KEY, (err, decoded) => {
        if (err) return res.status(403).json({ message: 'Invalid token' });
        req.user = decoded;
        next();
    });
};

// Middleware เฉพาะ Admin
const requireAdmin = (req, res, next) => {
    verifyToken(req, res, () => {
        if (req.user.role !== 'admin') return res.status(403).json({ message: 'Admin only' });
        next();
    });
};

const CONDITIONS = ['good', 'damaged', 'lost'];
const EQUIPMENT_STATUS_AFTER_RETURN = { good: 'available', damaged: 'maintenance', lost: 'lost' };

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

async function getRequest(id) {
    const [rows] = await con.query('SELECT * FROM borrow_requests WHERE id = ?', [id]);
    return rows[0];
}

async function getItems(requestId) {
    const [rows] = await con.query('SELECT * FROM borrow_items WHERE request_id = ?', [requestId]);
    return rows;
}

async function attachItems(requests) {
    if (requests.length === 0) return requests;
    const ids = requests.map((r) => r.id);
    const [items] = await con.query(ITEM_SELECT + ' WHERE bi.request_id IN (?) ORDER BY bi.id', [ids]);

    const byRequest = {};
    for (const it of items) {
        (byRequest[it.request_id] ||= []).push(it);
    }
    return requests.map((r) => ({ ...r, items: byRequest[r.id] || [] }));
}

async function releaseEquipment(equipmentIds) {
    if (equipmentIds.length === 0) return;
    await con.query("UPDATE equipment SET status = 'available' WHERE id IN (?) AND status = 'borrowed'", [equipmentIds]);
}

// POST /api/borrows (User ทั่วไปสร้างใบคำขอ - ต้องใช้ verifyToken)
router.post('/', verifyToken, async (req, res) => {
    try {
        const { purpose, start_date, end_date, equipment_ids } = req.body || {};
        const user_id = req.user.id;

        if (!purpose || !start_date || !end_date) {
            return res.status(400).json({ message: 'purpose, start_date and end_date are required' });
        }
        if (!Array.isArray(equipment_ids) || equipment_ids.length === 0) {
            return res.status(400).json({ message: 'equipment_ids must be a non-empty array' });
        }
        const ids = [...new Set(equipment_ids.map(Number))];
        if (new Date(end_date) < new Date(start_date)) {
            return res.status(400).json({ message: 'end_date must not be before start_date' });
        }

        const [eq] = await con.query('SELECT id, name, status FROM equipment WHERE id IN (?)', [ids]);
        if (eq.length !== ids.length) {
            const found = eq.map((e) => e.id);
            return res.status(404).json({ message: 'Some equipment not found', missing: ids.filter((id) => !found.includes(id)) });
        }
        const unavailable = eq.filter((e) => e.status !== 'available');
        if (unavailable.length > 0) {
            return res.status(400).json({ message: 'Some equipment is not available', unavailable });
        }

        const [result] = await con.query(
            `INSERT INTO borrow_requests (user_id, purpose, start_date, end_date, status) VALUES (?, ?, ?, ?, 'pending')`,
            [user_id, purpose, start_date, end_date]
        );
        const requestId = result.insertId;

        try {
            await con.query('INSERT INTO borrow_items (request_id, equipment_id) VALUES ?', [ids.map((id) => [requestId, id])]);
        } catch (err) {
            await con.query('DELETE FROM borrow_requests WHERE id = ?', [requestId]);
            throw err;
        }

        res.status(201).json({ message: 'Borrow request created', id: requestId, item_count: ids.length });
    } catch (err) {
        console.error(err);
        res.status(500).json({ message: 'Server error' });
    }
});

// GET /api/borrows (Admin ดูทั้งหมด)
router.get('/', requireAdmin, async (req, res) => {
    try {
        const { status } = req.query;
        let sql = REQUEST_SELECT;
        const params = [];
        if (status) {
            sql += ' WHERE b.status = ?';
            params.push(status);
        }
        sql += ' ORDER BY b.id DESC';
        const [rows] = await con.query(sql, params);
        res.json(rows);
    } catch (err) {
        console.error(err);
        res.status(500).json({ message: 'Server error' });
    }
});

// GET /api/borrows/user/:userId
router.get('/user/:userId', verifyToken, async (req, res) => {
    try {
        if (req.user.role !== 'admin' && req.user.id !== Number(req.params.userId)) {
            return res.status(403).json({ message: 'You can only view your own borrow history' });
        }
        const [rows] = await con.query(REQUEST_SELECT + ' WHERE b.user_id = ? ORDER BY b.id DESC', [req.params.userId]);
        res.json(await attachItems(rows));
    } catch (err) {
        console.error(err);
        res.status(500).json({ message: 'Server error' });
    }
});

// GET /api/borrows/:id
router.get('/:id', verifyToken, async (req, res) => {
    try {
        const [rows] = await con.query(REQUEST_SELECT + ' WHERE b.id = ?', [req.params.id]);
        if (rows.length === 0) return res.status(404).json({ message: 'Borrow request not found' });
        if (req.user.role !== 'admin' && rows[0].user_id !== req.user.id) {
            return res.status(403).json({ message: 'You can only view your own borrow request' });
        }
        const [full] = await attachItems(rows);
        res.json(full);
    } catch (err) {
        console.error(err);
        res.status(500).json({ message: 'Server error' });
    }
});

// PUT /api/borrows/:id/approve (Admin)
router.put('/:id/approve', requireAdmin, async (req, res) => {
    try {
        const { status = 'approved', admin_note } = req.body || {};
        const approved_by = req.user.id;
        const handled_by = req.user.id;

        if (!['approved', 'rejected'].includes(status)) {
            return res.status(400).json({ message: 'status must be "approved" or "rejected"' });
        }

        const borrow = await getRequest(req.params.id);
        if (!borrow) return res.status(404).json({ message: 'Borrow request not found' });
        if (borrow.status !== 'pending') return res.status(400).json({ message: `Cannot approve/reject: status is ${borrow.status}` });

        if (status === 'rejected') {
            await con.query(
                `UPDATE borrow_requests SET status = 'rejected', approved_by = ?, handled_by = ?, admin_note = ? WHERE id = ?`,
                [approved_by, handled_by, admin_note || null, borrow.id]
            );
            return res.json({ message: 'Borrow request rejected' });
        }

        const items = await getItems(borrow.id);
        if (items.length === 0) return res.status(400).json({ message: 'This request has no items' });

        const claimed = [];
        for (const it of items) {
            const [c] = await con.query("UPDATE equipment SET status = 'borrowed' WHERE id = ? AND status = 'available'", [it.equipment_id]);
            if (c.affectedRows === 0) {
                await releaseEquipment(claimed);
                return res.status(400).json({ message: 'Some equipment is no longer available', equipment_id: it.equipment_id });
            }
            claimed.push(it.equipment_id);
        }

        await con.query(
            `UPDATE borrow_requests SET status = 'approved', approved_by = ?, handled_by = ?, admin_note = ? WHERE id = ?`,
            [approved_by, handled_by, admin_note || null, borrow.id]
        );
        res.json({ message: 'Borrow request approved' });
    } catch (err) {
        console.error(err);
        res.status(500).json({ message: 'Server error' });
    }
});

// PUT /api/borrows/:id/return (Admin)
router.put('/:id/return', requireAdmin, async (req, res) => {
    try {
        const { admin_note, items: returned = [] } = req.body || {};
        const handled_by = req.user.id;

        const borrow = await getRequest(req.params.id);
        if (!borrow) return res.status(404).json({ message: 'Borrow request not found' });
        if (!['approved', 'borrowed'].includes(borrow.status)) {
            return res.status(400).json({ message: `Cannot return: status is ${borrow.status}` });
        }

        const items = await getItems(borrow.id);
        const detail = {};
        for (const r of returned) {
            const eid = Number(r.equipment_id);
            if (!items.some((it) => it.equipment_id === eid)) {
                return res.status(400).json({ message: `equipment_id ${r.equipment_id} is not in this request` });
            }
            const cond = r.condition_after ?? 'good';
            if (!CONDITIONS.includes(cond)) return res.status(400).json({ message: `Invalid condition` });
            const fine = Number(r.fine_amount ?? 0);
            detail[eid] = { cond, fine, paid: r.fine_paid ? 1 : 0 };
        }

        await con.query(
            `UPDATE borrow_requests SET status = 'returned', actual_return_date = NOW(), handled_by = ?, admin_note = COALESCE(?, admin_note) WHERE id = ?`,
            [handled_by, admin_note || null, borrow.id]
        );

        let totalFine = 0;
        for (const it of items) {
            const d = detail[it.equipment_id] || { cond: 'good', fine: 0, paid: 0 };
            totalFine += d.fine;
            await con.query('UPDATE borrow_items SET condition_after = ?, fine_amount = ?, fine_paid = ? WHERE id = ?', [d.cond, d.fine, d.paid, it.id]);
            await con.query('UPDATE equipment SET status = ? WHERE id = ?', [EQUIPMENT_STATUS_AFTER_RETURN[d.cond], it.equipment_id]);
        }

        res.json({ message: 'Equipment returned', total_fine: totalFine });
    } catch (err) {
        console.error(err);
        res.status(500).json({ message: 'Server error' });
    }
});

// PUT /api/borrows/:id/cancel
router.put('/:id/cancel', verifyToken, async (req, res) => {
    try {
        const borrow = await getRequest(req.params.id);
        if (!borrow) return res.status(404).json({ message: 'Borrow request not found' });
        if (req.user.role !== 'admin' && borrow.user_id !== req.user.id) {
            return res.status(403).json({ message: 'You can only cancel your own request' });
        }
        if (borrow.status !== 'pending') return res.status(400).json({ message: 'Only pending requests can be cancelled' });

        await con.query("UPDATE borrow_requests SET status = 'cancelled' WHERE id = ?", [borrow.id]);
        res.json({ message: 'Borrow request cancelled' });
    } catch (err) {
        console.error(err);
        res.status(500).json({ message: 'Server error' });
    }
});

module.exports = router;