const fs = require('fs');
const path = require('path');
const { baseUrl } = require('../config/env');
const HttpError = require('../utils/httpError');
const { cleanupOnError } = require('../utils/files');

// ทำชื่อให้ปลอดภัยสำหรับใช้เป็นส่วนหนึ่งของชื่อไฟล์
function toSafeName(name) {
    return name
        .normalize('NFKC')
        .replace(/[<>:"/\\|?*\x00-\x1F]/g, '-')
        .replace(/\s+/g, '-')
        .replace(/-+/g, '-')
        .replace(/^[.-]+|[.-]+$/g, '')
        .slice(0, 80);
}

// POST /api/upload (Admin) form-data: image (ไฟล์), name? (ใช้ตั้งชื่อไฟล์ให้อ่านง่าย)
exports.uploadImage = cleanupOnError(async (req, res) => {
    if (!req.file) {
        throw new HttpError(400, { success: false, message: 'No file uploaded.' });
    }

    const rawName = req.body && typeof req.body.name === 'string' ? req.body.name.trim() : '';
    const safeName = rawName ? toSafeName(rawName) : '';

    if (safeName) {
        const ext = path.extname(req.file.filename);
        const uniqueSuffix = path.basename(req.file.filename, ext);
        const filename = `${safeName}-${uniqueSuffix}${ext}`;
        const newPath = path.join(path.dirname(req.file.path), filename);
        await fs.promises.rename(req.file.path, newPath);
        req.file.filename = filename;
        req.file.path = newPath;
    }

    res.status(200).json({
        success: true,
        message: 'Image uploaded successfully.',
        data: {
            filename: req.file.filename,
            imageUrl: `${baseUrl}/uploads/${encodeURIComponent(req.file.filename)}`
        }
    });
});
