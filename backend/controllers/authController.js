const argon2 = require('argon2');
const jwt = require('jsonwebtoken');
const { jwt: jwtConfig } = require('../config/env');
const userModel = require('../models/userModel');
const HttpError = require('../utils/httpError');

// POST /api/auth/register
// role ถูกบังคับเป็น 'borrower' เสมอ ไม่รับจาก body (กันสมัครตัวเองเป็น admin)
// ถ้าจะสร้าง admin ให้แก้ role ในฐานข้อมูลโดยตรง
exports.register = async (req, res) => {
    const { username, password, full_name } = req.body || {};

    if (!username || !password || !full_name) {
        throw new HttpError(400, { success: false, message: 'Please provide all required fields.' });
    }
    if (typeof username !== 'string' || typeof password !== 'string' || typeof full_name !== 'string') {
        throw new HttpError(400, { success: false, message: 'Invalid field types.' });
    }
    if (!/^\d+$/.test(username)) {
        throw new HttpError(400, { success: false, message: 'Username must contain numbers only.' });
    }
    // ตรงกับขนาดคอลัมน์ใน database (users.username = 20, users.full_name = 100)
    if (username.length > 20) {
        throw new HttpError(400, { success: false, message: 'Username must be at most 20 digits.' });
    }
    if (full_name.length > 100) {
        throw new HttpError(400, { success: false, message: 'full_name must be at most 100 characters.' });
    }

    const hashedPassword = await argon2.hash(password);

    let userId;
    try {
        userId = await userModel.create({
            username,
            password: hashedPassword,
            full_name,
            role: 'borrower'
        });
    } catch (err) {
        if (err.code === 'ER_DUP_ENTRY') {
            throw new HttpError(409, { success: false, message: 'Username already exists.' });
        }
        throw err;
    }

    res.status(201).json({
        success: true,
        message: 'Registration successful.',
        data: { userId, username, full_name, role: 'borrower' }
    });
};

// POST /api/auth/login
exports.login = async (req, res) => {
    const { username, password } = req.body || {};

    if (!username || !password || typeof username !== 'string' || typeof password !== 'string') {
        throw new HttpError(400, { success: false, message: 'Please provide username and password.' });
    }

    const user = await userModel.findByUsername(username);

    let valid = false;
    if (user) {
        try {
            valid = await argon2.verify(user.password, password);
        } catch (err) {
            console.error('Argon2 verify error:', err.message);
        }
    }
    // ข้อความเดียวกันทั้ง "ไม่พบผู้ใช้" และ "รหัสผ่านผิด" เพื่อไม่ให้เดาได้ว่ามี username นี้ในระบบ
    if (!valid) {
        throw new HttpError(401, { success: false, message: 'Invalid username or password.' });
    }

    const token = jwt.sign(
        { id: user.id, username: user.username, role: user.role },
        jwtConfig.secret,
        { expiresIn: jwtConfig.expiresIn }
    );

    res.status(200).json({
        success: true,
        message: 'Login successful.',
        token,
        data: {
            userId: user.id,
            username: user.username,
            full_name: user.full_name,
            role: user.role
        }
    });
};

// POST /api/auth/logout  (JWT ไม่เก็บ state ฝั่ง server แอปแค่ทิ้ง token)
exports.logout = (req, res) => {
    res.status(200).json({ success: true, message: 'Logout successful.' });
};
