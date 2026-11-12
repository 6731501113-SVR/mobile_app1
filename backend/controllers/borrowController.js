const borrowModel = require('../models/borrowModel');
const equipmentModel = require('../models/equipmentModel');
const { withTransaction } = require('../config/db');
const HttpError = require('../utils/httpError');
const { removeUploadedFile, cleanupOnError } = require('../utils/files');

const CONDITIONS = ['good', 'damaged', 'lost'];
const EQUIPMENT_STATUS_AFTER_RETURN = { good: 'available', damaged: 'maintenance', lost: 'lost' };
const MAX_BORROW_DAYS = 4;
const FINE_PER_DAY = 30; // บาท/วัน
const MS_PER_DAY = 24 * 60 * 60 * 1000;

const isAdmin = (user) => user.role === 'admin';

// GET /api/borrows (Admin) รองรับ ?status=
exports.list = async (req, res) => {
    res.json(await borrowModel.listAll(req.query.status));
};

// GET /api/borrows/user/:userId (เจ้าของหรือ Admin)
exports.listByUser = async (req, res) => {
    if (!isAdmin(req.user) && req.user.id !== Number(req.params.userId)) {
        throw new HttpError(403, { message: 'You can only view your own borrow history' });
    }
    const rows = await borrowModel.listByUser(req.params.userId);
    res.json(await borrowModel.attachItems(rows));
};

// GET /api/borrows/equipment/:id/booked-dates (Public) ช่วงวันที่ที่อุปกรณ์ถูกจองแล้ว
exports.bookedDates = async (req, res) => {
    const rows = await borrowModel.findBookedDates(req.params.id);
    res.json({ success: true, booked_dates: rows });
};

// GET /api/borrows/:id (เจ้าของหรือ Admin)
exports.getOne = async (req, res) => {
    const row = await borrowModel.findDetailById(req.params.id);
    if (!row) throw new HttpError(404, { message: 'Borrow request not found' });

    if (!isAdmin(req.user) && row.user_id !== req.user.id) {
        throw new HttpError(403, { message: 'You can only view your own borrow request' });
    }
    const [full] = await borrowModel.attachItems([row]);
    res.json({ success: true, data: full });
};

// POST /api/borrows (ผู้ใช้ที่ล็อกอิน) คำนวณราคา/มัดจำที่ server, ไม่เกิน 4 วัน, กันวันชนซ้ำ
exports.create = async (req, res) => {
    const userId = req.user.id;
    const { purpose, start_date, end_date, equipment_ids } = req.body || {};

    if (!start_date || !end_date || !Array.isArray(equipment_ids) || equipment_ids.length === 0) {
        throw new HttpError(400, {
            success: false,
            message: 'Please provide purpose, start_date, end_date, and equipment_ids.'
        });
    }
    const ids = [...new Set(equipment_ids.map(Number))];
    if (ids.some((n) => !Number.isInteger(n) || n <= 0)) {
        throw new HttpError(400, { success: false, message: 'equipment_ids must contain valid equipment ids.' });
    }

    const start = new Date(start_date);
    const end = new Date(end_date);
    const diffDays = Math.ceil((end - start) / MS_PER_DAY) + 1;

    if (Number.isNaN(diffDays) || diffDays <= 0) {
        throw new HttpError(400, { success: false, message: 'Invalid borrow duration dates.' });
    }
    if (diffDays > MAX_BORROW_DAYS) {
        throw new HttpError(400, { success: false, message: 'Maximum borrow duration is 4 days only.' });
    }

    const result = await withTransaction(async (conn) => {
        // ล็อกแถวอุปกรณ์ก่อน เพื่อให้คำขอที่เข้ามาพร้อมกันต้องต่อคิว แล้วตรวจวันชนซ้ำได้ถูกต้อง
        const equipments = await equipmentModel.findByIdsForUpdate(ids, conn);

        if (equipments.length !== ids.length) {
            throw new HttpError(400, { success: false, message: 'Some equipment items not found.' });
        }
        for (const item of equipments) {
            if (item.status !== 'available') {
                throw new HttpError(400, { success: false, message: `Equipment ID ${item.id} is not available.` });
            }
        }

        const overlaps = await borrowModel.findOverlaps(ids, start_date, end_date, conn);
        if (overlaps.length > 0) {
            const conflicted = [...new Set(overlaps.map((o) => o.equipment_id))].join(', ');
            throw new HttpError(400, {
                success: false,
                message: `Some equipment items are already booked or requested during this period (IDs: ${conflicted}).`
            });
        }

        let totalPrice = 0;
        let totalDeposit = 0;
        for (const item of equipments) {
            totalPrice += (Number(item.price_per_day) || 0) * diffDays;
            totalDeposit += Number(item.deposit) || 0;
        }

        const requestId = await borrowModel.createRequest({
            user_id: userId,
            purpose: purpose || '',
            start_date,
            end_date,
            total_price: totalPrice,
            total_deposit: totalDeposit
        }, conn);
        await borrowModel.addItems(requestId, ids, conn);

        return { request_id: requestId, total_days: diffDays, total_price: totalPrice, total_deposit: totalDeposit };
    });

    res.status(201).json({ success: true, message: 'Borrow request created successfully.', data: result });
};

// PUT /api/borrows/:id/slip (เจ้าของใบหรือ Admin) form-data: slip (ไฟล์รูป)
exports.uploadSlip = cleanupOnError(async (req, res) => {
    const borrow = await borrowModel.findRequestById(req.params.id);
    if (!borrow) throw new HttpError(404, { success: false, message: 'Borrow request not found.' });

    if (borrow.user_id !== req.user.id && !isAdmin(req.user)) {
        throw new HttpError(403, { success: false, message: 'You can only upload a slip for your own request.' });
    }
    if (!req.file) {
        throw new HttpError(400, { success: false, message: 'Payment slip image is required.' });
    }

    const slipUrl = `/uploads/${req.file.filename}`;
    await borrowModel.setSlip(borrow.id, slipUrl);
    removeUploadedFile(borrow.slip_url); // ลบสลิปเก่าที่ถูกแทนที่

    res.json({ success: true, message: 'Payment slip uploaded successfully.', slip_url: slipUrl });
});

// PUT /api/borrows/:id/verify-payment (Admin) body: { payment_status: "paid"|"rejected", admin_note? }
exports.verifyPayment = async (req, res) => {
    const { payment_status, admin_note } = req.body || {};

    if (!['paid', 'rejected'].includes(payment_status)) {
        throw new HttpError(400, {
            success: false,
            message: "Invalid payment status. Must be 'paid' or 'rejected'."
        });
    }
    const borrow = await borrowModel.findRequestById(req.params.id);
    if (!borrow) throw new HttpError(404, { success: false, message: 'Borrow request not found.' });

    await borrowModel.setPaymentStatus(borrow.id, payment_status, admin_note || null);
    res.json({ success: true, message: `Payment status updated to '${payment_status}' successfully.` });
};

// PUT /api/borrows/:id/approve (Admin) body: { status?: "approved"|"rejected", admin_note? }
exports.approve = async (req, res) => {
    const { status = 'approved', admin_note } = req.body || {};
    const adminId = req.user.id;

    if (!['approved', 'rejected'].includes(status)) {
        throw new HttpError(400, { message: 'status must be "approved" or "rejected"' });
    }

    const borrow = await borrowModel.findRequestById(req.params.id);
    if (!borrow) throw new HttpError(404, { message: 'Borrow request not found' });
    if (borrow.status !== 'pending') {
        throw new HttpError(400, { message: `Cannot approve/reject: status is ${borrow.status}` });
    }

    if (status === 'rejected') {
        const ok = await borrowModel.setReviewed(borrow.id, 'rejected', adminId, admin_note || null);
        if (!ok) throw new HttpError(409, { message: 'Request status changed, please retry' });
        return res.json({ message: 'Borrow request rejected' });
    }

    // อนุมัติ: จองอุปกรณ์ทุกชิ้นในใบ + เปลี่ยนสถานะใบ ใน transaction เดียว (ไม่สำเร็จ = ย้อนกลับทั้งหมด)
    await withTransaction(async (conn) => {
        const items = await borrowModel.getItems(borrow.id, conn);
        if (items.length === 0) throw new HttpError(400, { message: 'This request has no items' });

        for (const it of items) {
            const claimed = await equipmentModel.claim(it.equipment_id, conn);
            if (!claimed) {
                throw new HttpError(400, {
                    message: 'Some equipment is no longer available',
                    equipment_id: it.equipment_id
                });
            }
        }

        const ok = await borrowModel.setReviewed(borrow.id, 'approved', adminId, admin_note || null, conn);
        if (!ok) throw new HttpError(409, { message: 'Request status changed, please retry' });
    });

    res.json({ message: 'Borrow request approved' });
};

// PUT /api/borrows/:id/handover (Admin) บันทึกส่งมอบอุปกรณ์
exports.handover = async (req, res) => {
    const borrow = await borrowModel.findRequestById(req.params.id);
    if (!borrow) throw new HttpError(404, { success: false, message: 'Borrow request not found.' });

    if (borrow.status !== 'approved') {
        throw new HttpError(400, {
            success: false,
            message: `Cannot handover: request status must be 'approved' (current: ${borrow.status})`
        });
    }

    await borrowModel.setHandledBy(borrow.id, req.user.id);
    res.json({ success: true, message: 'Equipment handover recorded successfully.' });
};

// PUT /api/borrows/:id/return (Admin) body: { admin_note?, items?: [{ equipment_id, condition_after, fine_paid? }] }
// ค่าปรับคำนวณที่ server (30 บาท/วัน) ไม่รับจากแอป แล้วหักจากเงินมัดจำ
exports.returnEquipment = async (req, res) => {
    const { admin_note, items: returned = [] } = req.body || {};

    const borrow = await borrowModel.findRequestById(req.params.id);
    if (!borrow) throw new HttpError(404, { success: false, message: 'Borrow request not found.' });

    if (!['approved', 'borrowed'].includes(borrow.status)) {
        throw new HttpError(400, { success: false, message: `Cannot return: status is ${borrow.status}` });
    }
    if (!Array.isArray(returned)) {
        throw new HttpError(400, { success: false, message: 'items must be an array' });
    }

    // ตรวจข้อมูลที่ส่งมาให้ครบก่อนเริ่มเขียนข้อมูล
    const detail = {};
    for (const r of returned) {
        const cond = r.condition_after ?? 'good';
        if (!CONDITIONS.includes(cond)) {
            throw new HttpError(400, { success: false, message: 'Invalid condition' });
        }
        detail[Number(r.equipment_id)] = { cond, paid: r.fine_paid ? 1 : 0 };
    }

    // คำนวณค่าปรับ
    const now = new Date();
    const dueDate = new Date(borrow.end_date);
    let lateDays = 0;
    let fineAmount = 0;
    if (now > dueDate) {
        lateDays = Math.ceil((now - dueDate) / MS_PER_DAY);
        fineAmount = lateDays * FINE_PER_DAY;
    }
    const totalDeposit = Number(borrow.total_deposit) || 0;
    const depositRefund = Math.max(0, totalDeposit - fineAmount);

    await withTransaction(async (conn) => {
        const items = await borrowModel.getItems(borrow.id, conn);

        const ok = await borrowModel.markReturned(borrow.id, fineAmount, admin_note || null, conn);
        if (!ok) throw new HttpError(409, { success: false, message: 'Request status changed, please retry' });

        for (const it of items) {
            const d = detail[it.equipment_id] || { cond: 'good', paid: 0 };
            // เฉลี่ยค่าปรับต่อชิ้น
            await borrowModel.updateItemAfterReturn(it.id, d.cond, fineAmount / items.length, d.paid, conn);
            await equipmentModel.setStatus(it.equipment_id, EQUIPMENT_STATUS_AFTER_RETURN[d.cond], conn);
        }
    });

    res.json({
        success: true,
        message: 'Equipment returned successfully with server-calculated fine.',
        data: {
            borrow_id: borrow.id,
            late_days: lateDays,
            fine_amount: fineAmount,
            original_deposit: totalDeposit,
            deposit_refund: depositRefund
        }
    });
};

// PUT /api/borrows/:id/cancel (เจ้าของใบหรือ Admin) ยกเลิกได้เฉพาะใบที่ยัง pending
exports.cancel = async (req, res) => {
    const borrow = await borrowModel.findRequestById(req.params.id);
    if (!borrow) throw new HttpError(404, { message: 'Borrow request not found' });

    if (!isAdmin(req.user) && borrow.user_id !== req.user.id) {
        throw new HttpError(403, { message: 'You can only cancel your own request' });
    }
    if (borrow.status !== 'pending') {
        throw new HttpError(400, { message: 'Only pending requests can be cancelled' });
    }

    const ok = await borrowModel.cancel(borrow.id);
    if (!ok) throw new HttpError(409, { message: 'Request status changed, please retry' });

    res.json({ message: 'Borrow request cancelled' });
};
