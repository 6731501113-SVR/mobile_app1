const HttpError = require('../utils/httpError');

function notFound(req, res) {
    res.status(404).json({ success: false, message: 'Route not found' });
}

// ตัวจัดการ error กลาง (Express 5 ส่ง error จาก async handler มาที่นี่เอง)
// ไม่ส่งข้อความ error ภายใน (เช่น SQL) กลับไปให้ผู้เรียก เพื่อไม่ให้เปิดเผยโครงสร้างระบบ
function errorHandler(err, req, res, next) {
    if (res.headersSent) return next(err);

    if (err instanceof HttpError) {
        return res.status(err.status).json(err.body);
    }
    if (err.type === 'entity.parse.failed') {
        return res.status(400).json({ success: false, message: 'Invalid JSON body' });
    }

    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
}

module.exports = { notFound, errorHandler };
