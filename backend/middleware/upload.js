const multer = require('multer');
const { UPLOAD_DIR } = require('../utils/files');

const MAX_SIZE = 5 * 1024 * 1024; // 5MB

// นามสกุลไฟล์กำหนดจากชนิดไฟล์ ไม่เชื่อชื่อไฟล์ที่ผู้ใช้ส่งมา
// (กันการแนบ .html/.svg ที่หลอกว่าเป็นรูป แล้วถูกเปิดจาก /uploads)
const EXT_BY_MIME = {
    'image/jpeg': '.jpg',
    'image/png': '.png',
    'image/gif': '.gif',
    'image/webp': '.webp'
};

function createUploader(prefix, label = '') {
    return multer({
        storage: multer.diskStorage({
            destination: (req, file, cb) => cb(null, UPLOAD_DIR),
            filename: (req, file, cb) => {
                const ext = EXT_BY_MIME[file.mimetype] || '';
                cb(null, `${prefix}-${Date.now()}-${Math.round(Math.random() * 1e6)}${ext}`);
            }
        }),
        limits: { fileSize: MAX_SIZE },
        fileFilter: (req, file, cb) => {
            if (EXT_BY_MIME[file.mimetype]) return cb(null, true);
            cb(new Error(`Only image files (jpg, png, gif, webp) are allowed${label}`));
        }
    });
}

// แปลง error ของ multer (ไฟล์ใหญ่/ชนิดผิด) เป็น 400 JSON
function single(uploader, field) {
    return (req, res, next) => {
        uploader.single(field)(req, res, (err) => {
            if (err) return res.status(400).json({ success: false, message: err.message });
            next();
        });
    };
}

module.exports = {
    uploadEquipmentImage: single(createUploader('equipment'), 'image'),
    uploadSlipImage: single(createUploader('slip', ' for payment slip'), 'slip'),
    uploadGenericImage: single(createUploader('img'), 'image')
};
