const express = require("express");
const router = express.Router();
const db = require("../db_config");
const argon2 = require("argon2");
const jwt = require("jsonwebtoken");

// คีย์ลับสำหรับตรวจสอบ Token (ควรตรงกับไฟล์ authRoutes)
const JWT_KEY = "sdf1216werxfw@dsjfrewi";

// --- Middleware สำหรับตรวจสอบ JWT Token ---
const verifyToken = (req, res, next) => {
  const authHeader = req.headers["authorization"];
  if (!authHeader) {
    return res
      .status(401)
      .json({ success: false, message: "No token provided. Access denied." });
  }

  let token = authHeader;
  if (token.startsWith("Bearer ")) {
    token = token.split(" ")[1];
  }

  jwt.verify(token, JWT_KEY, (err, decoded) => {
    if (err) {
      return res
        .status(403)
        .json({ success: false, message: "Invalid or expired token." });
    }
    // เก็บข้อมูล payload (id, username, role) ไว้ใน req.user เพื่อนำไปใช้ต่อใน API
    req.user = decoded;
    next();
  });
};

// 1. GET /api/users (Admin only: ดึงรายชื่อผู้ใช้ทั้งหมดในระบบ)
router.get("/", verifyToken, (req, res) => {
  // ตรวจสอบสิทธิ์ว่าต้องเป็น admin เท่านั้น
  if (req.user.role !== "admin") {
    return res
      .status(403)
      .json({ success: false, message: "Permission denied. Admin only." });
  }

  const sql = "SELECT id, username, full_name, role FROM users";
  db.query(sql, (err, results) => {
    if (err) {
      console.error(err);
      return res
        .status(500)
        .json({
          success: false,
          message: "Database error.",
          error: err.message,
        });
    }
    res.status(200).json({ success: true, data: results });
  });
});

// 2. GET /api/users/:id (ดึงข้อมูลผู้ใช้รายบุคคล)
router.get("/:id", verifyToken, (req, res) => {
  const userId = req.params.id;

  // อนุญาตให้ Admin หรือเจ้าของบัญชีนั้นๆ เป็นคนเรียกดูข้อมูลเท่านั้น
  if (req.user.role !== "admin" && req.user.id != userId) {
    return res
      .status(403)
      .json({ success: false, message: "Permission denied." });
  }

  const sql = "SELECT id, username, full_name, role FROM users WHERE id = ?";
  db.query(sql, [userId], (err, results) => {
    if (err) {
      console.error(err);
      return res
        .status(500)
        .json({
          success: false,
          message: "Database error.",
          error: err.message,
        });
    }

    if (results.length === 0) {
      return res
        .status(404)
        .json({ success: false, message: "User not found." });
    }

    res.status(200).json({ success: true, data: results[0] });
  });
});

// 3. PUT /api/users/:id (แก้ไขข้อมูลผู้ใช้ เช่น ชื่อ หรือรหัสผ่าน)
router.put("/:id", verifyToken, async (req, res) => {
  const userId = req.params.id;
  const { full_name, password } = req.body;

  // ตรวจสอบสิทธิ์ (Admin หรือเจ้าของไอดีแก้ไขได้เอง)
  if (req.user.role !== "admin" && req.user.id != userId) {
    return res
      .status(403)
      .json({ success: false, message: "Permission denied." });
  }

  try {
    let sql = "";
    let values = [];

    // ถ้ารหัสผ่านถูกส่งมาด้วย แปลว่าต้องการเปลี่ยนรหัสผ่าน (ต้องทำ Hash ด้วย Argon2)
    if (password) {
      const hashedPassword = await argon2.hash(password);
      sql = "UPDATE users SET full_name = ?, password = ? WHERE id = ?";
      values = [full_name, hashedPassword, userId];
    } else {
      sql = "UPDATE users SET full_name = ? WHERE id = ?";
      values = [full_name, userId];
    }

    db.query(sql, values, (err, result) => {
      if (err) {
        console.error(err);
        return res
          .status(500)
          .json({
            success: false,
            message: "Database error.",
            error: err.message,
          });
      }

      if (result.affectedRows === 0) {
        return res
          .status(404)
          .json({ success: false, message: "User not found." });
      }

      res
        .status(200)
        .json({ success: true, message: "User updated successfully." });
    });
  } catch (error) {
    console.error(error);
    res
      .status(500)
      .json({
        success: false,
        message: "Internal server error.",
        error: error.message,
      });
  }

  // 4. DELETE /api/users/:id (Admin only: ลบผู้ใช้ตาม ID)
  router.delete("/:id", verifyToken, (req, res) => {
    const userIdToDelete = req.params.id;

    // ตรวจสอบสิทธิ์: ต้องเป็น admin เท่านั้น
    if (req.user.role !== "admin") {
      return res
        .status(403)
        .json({ success: false, message: "Permission denied. Admin only." });
    }

    // ป้องกันไม่ให้ Admin เผลอลบบัญชีตัวเองทิ้ง
    if (req.user.id == userIdToDelete) {
      return res
        .status(400)
        .json({
          success: false,
          message: "You cannot delete your own admin account.",
        });
    }

    const sql = "DELETE FROM users WHERE id = ?";
    db.query(sql, [userIdToDelete], (err, result) => {
      if (err) {
        console.error(err);
        // กรณีที่มี foreign key ผูกอยู่ เช่น ผู้ใช้นี้เคยไปยืมของแล้วมีประวัติค้างอยู่
        if (err.code === "ER_ROW_IS_REFERENCED_2") {
          return res
            .status(409)
            .json({
              success: false,
              message:
                "Cannot delete user because they have associated borrow records.",
            });
        }
        return res
          .status(500)
          .json({
            success: false,
            message: "Database error.",
            error: err.message,
          });
      }

      if (result.affectedRows === 0) {
        return res
          .status(404)
          .json({ success: false, message: "User not found." });
      }

      res
        .status(200)
        .json({ success: true, message: "User deleted successfully." });
    });
  });
});

module.exports = router;
