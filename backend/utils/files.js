const fs = require('fs');
const path = require('path');

const UPLOAD_DIR = path.join(__dirname, '..', 'uploads');
fs.mkdirSync(UPLOAD_DIR, { recursive: true });

// ลบไฟล์ที่อัปโหลดไว้ รับ path แบบ "/uploads/xxx.jpg"
// ใช้ basename เสมอ กันการแอบใส่ ../ เพื่อลบไฟล์นอกโฟลเดอร์ uploads
function removeUploadedFile(urlPath) {
    if (typeof urlPath !== 'string' || !urlPath.startsWith('/uploads/')) return;
    fs.unlink(path.join(UPLOAD_DIR, path.basename(urlPath)), () => {});
}

// ลบไฟล์ที่เพิ่งอัปโหลดผ่าน multer (ใช้เมื่อขั้นตอนถัดไปล้มเหลว)
function discardUpload(req) {
    if (req.file) fs.unlink(req.file.path, () => {});
}

// ครอบ handler: ถ้าเกิด error ให้ลบไฟล์ที่เพิ่งอัปโหลดทิ้ง แล้วโยน error ต่อ
function cleanupOnError(handler) {
    return async (req, res, next) => {
        try {
            await handler(req, res, next);
        } catch (err) {
            discardUpload(req);
            throw err;
        }
    };
}

module.exports = { UPLOAD_DIR, removeUploadedFile, discardUpload, cleanupOnError };
