const equipmentModel = require('../models/equipmentModel');
const categoryModel = require('../models/categoryModel');
const HttpError = require('../utils/httpError');
const { removeUploadedFile, cleanupOnError } = require('../utils/files');

// สถานะที่ Admin ตั้งเองได้ ส่วน 'borrowed' ระบบตั้งให้เองตอนอนุมัติการยืม
const MANUAL_STATUSES = ['available', 'maintenance', 'lost'];

// แปลงราคา/มัดจำ: ไม่ส่งมา -> undefined, ส่งมาแต่ไม่ใช่ตัวเลข >= 0 -> 400
function parseMoney(value, field) {
    if (value === undefined || value === '') return undefined;
    const n = Number(value);
    if (Number.isNaN(n) || n < 0) {
        throw new HttpError(400, { message: `${field} must be a number >= 0` });
    }
    return n;
}

// GET /api/equipments (Public) รองรับ ?search= &category_id= &status=
exports.list = async (req, res) => {
    const { search, category_id, status } = req.query;
    res.json(await equipmentModel.findAll({ search, category_id, status }));
};

// GET /api/equipments/:id (Public)
exports.getOne = async (req, res) => {
    const item = await equipmentModel.findById(req.params.id);
    if (!item) throw new HttpError(404, { message: 'Equipment not found' });
    res.json(item);
};

// POST /api/equipments (Admin) form-data: asset_code, name, category_id, price_per_day?, deposit?, image?
exports.create = cleanupOnError(async (req, res) => {
    const body = req.body || {};
    const { asset_code, name, category_id, status = 'available' } = body;

    if (!asset_code || !name || !category_id) {
        throw new HttpError(400, { message: 'asset_code, name and category_id are required' });
    }
    if (!MANUAL_STATUSES.includes(status)) {
        throw new HttpError(400, { message: `status must be one of: ${MANUAL_STATUSES.join(', ')}` });
    }
    const pricePerDay = parseMoney(body.price_per_day, 'price_per_day') ?? 0;
    const deposit = parseMoney(body.deposit, 'deposit') ?? 0;

    if (!(await categoryModel.exists(category_id))) {
        throw new HttpError(400, { message: 'category_id does not exist' });
    }

    const imageUrl = req.file ? `/uploads/${req.file.filename}` : (body.image_url || null);

    let id;
    try {
        id = await equipmentModel.create({
            asset_code, name, category_id, status,
            price_per_day: pricePerDay, deposit, image_url: imageUrl
        });
    } catch (err) {
        if (err.code === 'ER_DUP_ENTRY') throw new HttpError(409, { message: 'asset_code already exists' });
        throw err;
    }

    res.status(201).json({
        message: 'Equipment created',
        id,
        price_per_day: pricePerDay,
        deposit,
        image_url: imageUrl
    });
});

// PUT /api/equipments/:id (Admin) ส่งเฉพาะ field ที่ต้องการแก้
exports.update = cleanupOnError(async (req, res) => {
    const body = req.body || {};
    const { asset_code, name, category_id, status } = body;

    const old = await equipmentModel.findRawById(req.params.id);
    if (!old) throw new HttpError(404, { message: 'Equipment not found' });

    if (category_id !== undefined && !(await categoryModel.exists(category_id))) {
        throw new HttpError(400, { message: 'category_id does not exist' });
    }

    let newStatus = old.status;
    if (status !== undefined && status !== old.status) {
        if (!MANUAL_STATUSES.includes(status)) {
            throw new HttpError(400, { message: `status must be one of: ${MANUAL_STATUSES.join(', ')}` });
        }
        if (old.status === 'borrowed') {
            throw new HttpError(409, { message: 'Cannot change status: equipment is currently borrowed' });
        }
        newStatus = status;
    }

    const pricePerDay = parseMoney(body.price_per_day, 'price_per_day') ?? old.price_per_day;
    const deposit = parseMoney(body.deposit, 'deposit') ?? old.deposit;
    const imageUrl = req.file ? `/uploads/${req.file.filename}` : (body.image_url ?? old.image_url);

    try {
        await equipmentModel.update(old.id, {
            asset_code: asset_code ?? old.asset_code,
            name: name ?? old.name,
            category_id: category_id ?? old.category_id,
            status: newStatus,
            price_per_day: pricePerDay,
            deposit,
            image_url: imageUrl
        });
    } catch (err) {
        if (err.code === 'ER_DUP_ENTRY') throw new HttpError(409, { message: 'asset_code already exists' });
        throw err;
    }

    // อัปโหลดรูปใหม่แทนรูปเก่า -> ลบไฟล์เก่าออกจากเครื่อง
    if (req.file) removeUploadedFile(old.image_url);

    res.json({ message: 'Equipment updated', price_per_day: pricePerDay, deposit, image_url: imageUrl });
});

// DELETE /api/equipments/:id (Admin)
exports.remove = async (req, res) => {
    const item = await equipmentModel.findRawById(req.params.id);
    if (!item) throw new HttpError(404, { message: 'Equipment not found' });

    if (item.status === 'borrowed') {
        throw new HttpError(409, { message: 'Cannot delete: equipment is currently borrowed' });
    }
    // ตารางไม่มี foreign key จึงเช็กเองว่ามีประวัติการยืมไหม (ไม่ให้ประวัติกำพร้า)
    if (await equipmentModel.hasBorrowHistory(item.id)) {
        throw new HttpError(409, {
            message: 'Cannot delete: equipment has borrow history. Set status to maintenance or lost instead.'
        });
    }

    await equipmentModel.remove(item.id);
    removeUploadedFile(item.image_url);
    res.json({ message: 'Equipment deleted' });
};
