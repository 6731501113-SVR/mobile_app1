const express = require('express');
const router = express.Router();
const db = require('../db_config'); // เชื่อมต่อฐานข้อมูล mobile_app
const argon2 = require('argon2'); 
const jwt = require('jsonwebtoken');

// FIXME: Move this to an Environment Variable (.env) in production
const JWT_KEY = 'sdf1216werxfw@dsjfrewi';

// 1. POST /api/auth/register (Register + Hash with Argon2 + Save to DB)
router.post('/register', async (req, res) => {
    try {
        const { username, password, full_name, role } = req.body;

        if (!username || !password || !full_name) {
            return res.status(400).json({ success: false, message: 'Please provide all required fields.' });
        }

        // --- Hash password using Argon2 ---   
        const hashedPassword = await argon2.hash(password);

        const sql = 'INSERT INTO users (username, password, full_name, role) VALUES (?, ?, ?, ?)';
        const defaultRole = role || 'borrower'; //change from 'user' to 'borrower' to match database

        // Save to the mobile_app database
        db.query(sql, [username, hashedPassword, full_name, defaultRole], (err, result) => {
            if (err) {
                console.error(err);
                return res.status(500).json({ success: false, message: 'Registration failed (Username may already exist).', error: err.message });
            }

            res.status(201).json({
                success: true,
                message: 'Registration successful.',
                data: { userId: result.insertId, username, full_name, role: defaultRole }
            });
        });

    } catch (error) {
        console.error(error);
        res.status(500).json({ success: false, message: 'Internal server error.', error: error.message });
    }
});

// 2. POST /api/auth/login (Login + Verify with Argon2 + Generate JWT Token)
router.post('/login', async (req, res) => {
    try {
        const { username, password } = req.body;

        if (!username || !password) {
            return res.status(400).json({ success: false, message: 'Please provide username and password.' });
        }

        const sql = "SELECT * FROM users WHERE username = ?";
        
        db.query(sql, [username], async (err, results) => {
            if (err) {
                console.error(err);
                return res.status(500).json({ success: false, message: 'Database error.', error: err.message });
            }

            if (results.length === 0) {
                return res.status(401).json({ success: false, message: 'User not found.' });
            }

            const user = results[0];

            // --- Verify password using argon2.verify against database record ---
            let isPasswordValid = false;
            try {
                isPasswordValid = await argon2.verify(user.password, password);
            } catch (verifyErr) {
                console.error('Argon2 verify error:', verifyErr);
            }

            if (!isPasswordValid) {
                return res.status(401).json({ success: false, message: 'Incorrect password.' });
            }

            // --- Generate JWT Token after successful login ---
            const payload = { 
                id: user.id, 
                username: user.username, 
                role: user.role 
            };
            
            const token = jwt.sign(payload, JWT_KEY, { expiresIn: '1d' });

            // Send token and user data back to the Flutter app
            res.status(200).json({
                success: true,
                message: 'Login successful.',
                token: token, // Flutter app should store this token for future requests
                data: {
                    userId: user.id,
                    username: user.username,
                    full_name: user.full_name,
                    role: user.role 
                }
            });
        });

    } catch (error) {
        console.error(error);
        res.status(500).json({ success: false, message: 'Internal server error.', error: error.message });
    }
});

// 3. POST /api/auth/logout (Logout)
router.post('/logout', (req, res) => {
    // For stateless JWT, the Flutter app simply discards the token on its end.
    res.status(200).json({
        success: true,
        message: 'Logout successful.'
    });
});

module.exports = router;