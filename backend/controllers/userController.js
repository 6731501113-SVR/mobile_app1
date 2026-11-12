const argon2 = require('argon2');
const userModel = require('../models/userModel');
const HttpError = require('../utils/httpError');

const isOwnerOrAdmin = (user, targetId) => user.role === 'admin' || user.id === Number(targetId);

// GET /api/users (Admin)
exports.list = async (req, res) => {
    res.status(200).json({ success: true, data: await userModel.findAll() });
};

// GET /api/users/:id (Admin หรือเจ้าของบัญชี)
exports.getOne = async (req, res) => {
    if (!isOwnerOrAdmin(req.user, req.params.id)) {
        throw new HttpError(403, { success: false, message: 'Permission denied.' });
    }
    const user = await userModel.findById(req.params.id);
    if (!user) throw new HttpError(404, { success: false, message: 'User not found.' });

    res.status(200).json({ success: true, data: user });
};

// PUT /api/users/:id (Admin หรือเจ้าของบัญชี) แก้ได้เฉพาะ full_name และ password
exports.update = async (req, res) => {
    if (!isOwnerOrAdmin(req.user, req.params.id)) {
        throw new HttpError(403, { success: false, message: 'Permission denied.' });
    }

    const { full_name, password } = req.body || {};
    const fields = {};

    if (full_name !== undefined) {
        if (typeof full_name !== 'string' || !full_name.trim()) {
            throw new HttpError(400, { success: false, message: 'full_name must be a non-empty string.' });
        }
        fields.full_name = full_name.trim();
    }
    if (password !== undefined) {
        if (typeof password !== 'string' || !password) {
            throw new HttpError(400, { success: false, message: 'password must be a non-empty string.' });
        }
        fields.password = await argon2.hash(password);
    }
    if (Object.keys(fields).length === 0) {
        throw new HttpError(400, { success: false, message: 'Provide full_name and/or password to update.' });
    }

    const affected = await userModel.update(req.params.id, fields);
    if (affected === 0) throw new HttpError(404, { success: false, message: 'User not found.' });

    res.status(200).json({ success: true, message: 'User updated successfully.' });
};

// DELETE /api/users/:id (Admin)
exports.remove = async (req, res) => {
    const targetId = Number(req.params.id);

    if (req.user.id === targetId) {
        throw new HttpError(400, { success: false, message: 'You cannot delete your own admin account.' });
    }
    if (await userModel.hasBorrowRequests(targetId)) {
        throw new HttpError(409, {
            success: false,
            message: 'Cannot delete user because they have associated borrow records.'
        });
    }

    let affected;
    try {
        affected = await userModel.remove(targetId);
    } catch (err) {
        if (err.code === 'ER_ROW_IS_REFERENCED_2') {
            throw new HttpError(409, {
                success: false,
                message: 'Cannot delete user because they have associated borrow records.'
            });
        }
        throw err;
    }
    if (affected === 0) throw new HttpError(404, { success: false, message: 'User not found.' });

    res.status(200).json({ success: true, message: 'User deleted successfully.' });
};
