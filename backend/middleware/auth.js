const jwt = require('jsonwebtoken');
const { jwt: jwtConfig } = require('../config/env');

// ตรวจ token จากหัว Authorization: Bearer <token>
// ผ่านแล้วได้ req.user = { id, username, role }
function verifyToken(req, res, next) {
    const header = req.headers.authorization;
    if (!header) {
        return res.status(401).json({ success: false, message: 'No token provided. Access denied.' });
    }
    const token = header.startsWith('Bearer ') ? header.slice(7).trim() : header.trim();

    jwt.verify(token, jwtConfig.secret, { algorithms: ['HS256'] }, (err, decoded) => {
        if (err) {
            const message = err.name === 'TokenExpiredError'
                ? 'Token expired, please login again.'
                : 'Invalid token.';
            return res.status(401).json({ success: false, message });
        }
        req.user = { id: decoded.id, username: decoded.username, role: decoded.role };
        next();
    });
}

function adminOnly(req, res, next) {
    if (!req.user || req.user.role !== 'admin') {
        return res.status(403).json({ success: false, message: 'Admin only' });
    }
    next();
}

// ใช้ตัวเดียวได้เลย: ตรวจ token แล้วเช็กว่าเป็น admin
const requireAdmin = [verifyToken, adminOnly];

module.exports = { verifyToken, requireAdmin };
