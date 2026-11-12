# Backend — Mobile App API (ระบบยืม-คืนอุปกรณ์)

REST API สำหรับแอปยืม-คืนอุปกรณ์ เขียนด้วย Node.js + Express 5 + MySQL/MariaDB ยืนยันตัวตนด้วย JWT

## 1. สิ่งที่ต้องมีในเครื่อง

| โปรแกรม | หมายเหตุ |
|---|---|
| Node.js | เวอร์ชัน LTS (20 ขึ้นไป) |
| MySQL หรือ MariaDB | แนะนำติดตั้งผ่าน XAMPP (ใช้ phpMyAdmin จัดการได้) |
| Postman | ใช้ทดสอบ API (ไม่บังคับ) |

## 2. ขั้นตอนย้ายเครื่อง / ติดตั้งครั้งแรก

### 2.1 ติดตั้งโปรแกรมและเปิด MySQL
ติดตั้ง Node.js และ XAMPP แล้วเปิด **MySQL** ใน XAMPP Control Panel (ให้เป็นสีเขียว)
ถ้าจะเปิด phpMyAdmin (`http://localhost/phpmyadmin`) ต้องเปิด **Apache** ด้วย

### 2.2 สร้างฐานข้อมูลและนำเข้า `database.sql`
1. เปิด phpMyAdmin → กด **New** → ตั้งชื่อ `mobile_app` (collation `utf8mb4_general_ci`) → Create
2. คลิกชื่อ `mobile_app` ทางซ้าย (ต้องเข้าไปอยู่ใน database นี้ก่อน ไม่งั้นจะขึ้น `#1046 No database selected`)
3. แท็บ **Import** → เลือกไฟล์ `database.sql` → กด **Import**

### 2.3 สร้างผู้ใช้ฐานข้อมูล (ไม่ใช้ root)
แท็บ **SQL** ใน phpMyAdmin แล้วรัน (เปลี่ยนรหัสผ่านเป็นของคุณเอง ใช้รหัสที่เดายาก):

```sql
CREATE USER 'mobile_app'@'localhost' IDENTIFIED BY 'ใส่รหัสผ่านใหม่ที่นี่';
GRANT ALL PRIVILEGES ON mobile_app.* TO 'mobile_app'@'localhost';
FLUSH PRIVILEGES;
```

### 2.4 สร้างไฟล์ `.env`
```bash
cp .env.example .env        # Windows CMD: copy .env.example .env
```
เปิด `.env` แล้วกรอก:

| ตัวแปร | ความหมาย |
|---|---|
| `DB_USER` / `DB_PASSWORD` | ผู้ใช้และรหัสผ่านที่สร้างในข้อ 2.3 |
| `DB_NAME` | `mobile_app` |
| `JWT_SECRET` | กุญแจเซ็น token ยาวอย่างน้อย 32 ตัวอักษร สร้างด้วยคำสั่งด้านล่าง |
| `BASE_URL` | URL ที่แอปเข้าถึง server ได้ เช่น `http://192.168.1.50:3000` (ใช้สร้างลิงก์รูป) |

สร้าง `JWT_SECRET`:
```bash
node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"
```

> **ห้าม commit `.env` ขึ้น Git** (ถูกใส่ใน `.gitignore` แล้ว) และห้ามส่งค่าจริงในแชทหรือรูปหน้าจอ

### 2.5 ติดตั้งแพ็กเกจและรัน
```bash
cd backend
npm install
npm run dev      # รันแบบ restart อัตโนมัติเมื่อแก้โค้ด (หรือ npm start)
```
ถ้าสำเร็จจะขึ้น `Server is running at port 3000` เปิด `http://localhost:3000` จะเห็นข้อความต้อนรับ

### 2.6 สร้างบัญชีแอดมิน
การสมัครผ่านแอป (`/api/auth/register`) จะได้ role `borrower` เสมอ เพื่อความปลอดภัย
ต้องการแอดมินให้เปลี่ยน role ใน phpMyAdmin (เปลี่ยน `6731501044` เป็น username ของบัญชีนั้น):

```sql
UPDATE users SET role = 'admin' WHERE username = '6731501044';
```
แล้ว **ล็อกอินใหม่** เพื่อรับ token ที่มี role ใหม่

> `database.sql` มีบัญชีตัวอย่าง 2 บัญชี: `123456` (borrower) และ `12345` (admin) รหัสผ่านของทั้งสองเดาง่ายมาก ใช้สำหรับทดสอบ/เดโมเท่านั้น ต้องเปลี่ยนรหัสหรือลบทิ้งก่อนใช้งานจริง

## 3. โครงสร้างโฟลเดอร์ (MVC)

```
backend/
├── app.js                  จุดเริ่มต้น: ต่อ middleware, routes, error handler แล้วรัน server
├── config/
│   ├── env.js              อ่าน .env และตรวจค่าที่จำเป็น (ขาดค่าไหนจะบอกชัดเจน)
│   └── db.js               MySQL pool + withTransaction()
├── routes/                 จับคู่ URL กับ controller และกำหนดสิทธิ์
├── controllers/            รับ request, ตรวจข้อมูล, ตัดสินใจ, ตอบกลับ
├── models/                 คำสั่ง SQL ทั้งหมด (ไม่แตะ req/res)
├── middleware/
│   ├── auth.js             verifyToken / requireAdmin (ไฟล์เดียวใช้ทั้งระบบ)
│   ├── upload.js           ตั้งค่า multer (รูปอุปกรณ์, สลิป, อัปโหลดทั่วไป)
│   └── errorHandler.js     ตอบ error แบบ JSON ไม่เปิดเผยรายละเอียดภายใน
├── utils/                  httpError.js, files.js (ลบไฟล์อัปโหลดอย่างปลอดภัย)
├── uploads/                ไฟล์รูปที่อัปโหลด (ไม่ถูก commit)
├── .env.example            ตัวอย่างค่าตั้งค่า (ไม่มีค่าจริง)
└── database.sql            โครงสร้างตารางและข้อมูลตัวอย่าง
```

เพิ่ม endpoint ใหม่: เขียน SQL ใน `models/` → เขียนลอจิกใน `controllers/` → ผูก URL ใน `routes/`

## 4. รายการ API

ส่ง token ในหัว `Authorization: Bearer <token>` (ได้จาก `/api/auth/login`)

| Method | Path | สิทธิ์ |
|---|---|---|
| POST | `/api/auth/register` | เปิดสาธารณะ (ได้ role borrower เสมอ) |
| POST | `/api/auth/login` | เปิดสาธารณะ |
| POST | `/api/auth/logout` | เปิดสาธารณะ |
| GET | `/api/users` | Admin |
| GET / PUT | `/api/users/:id` | เจ้าของบัญชี หรือ Admin |
| DELETE | `/api/users/:id` | Admin |
| GET | `/api/categories`, `/api/categories/:id` | เปิดสาธารณะ |
| POST / PUT / DELETE | `/api/categories[/:id]` | Admin |
| GET | `/api/equipments`, `/api/equipments/:id` | เปิดสาธารณะ |
| POST / PUT / DELETE | `/api/equipments[/:id]` | Admin (POST/PUT ส่งเป็น form-data ได้ field `image`) |
| POST | `/api/upload` | Admin (form-data field `image`, `name` ไม่บังคับ) |
| GET | `/api/borrows` | Admin |
| GET | `/api/borrows/user/:userId` | เจ้าของ หรือ Admin |
| GET | `/api/borrows/equipment/:id/booked-dates` | เปิดสาธารณะ |
| GET | `/api/borrows/:id` | เจ้าของใบ หรือ Admin |
| POST | `/api/borrows` | ผู้ใช้ที่ล็อกอิน |
| PUT | `/api/borrows/:id/slip` | เจ้าของใบ หรือ Admin (form-data field `slip`) |
| PUT | `/api/borrows/:id/verify-payment` | Admin |
| PUT | `/api/borrows/:id/approve` | Admin (`status`: approved / rejected) |
| PUT | `/api/borrows/:id/handover` | Admin |
| PUT | `/api/borrows/:id/return` | Admin |
| PUT | `/api/borrows/:id/cancel` | เจ้าของใบ หรือ Admin (เฉพาะใบ pending) |

รหัสตอบกลับที่ควรรู้: `401` ไม่มี/ใช้ token ไม่ได้/หมดอายุ · `403` ไม่มีสิทธิ์ · `409` ข้อมูลชนกัน (เช่น รหัสครุภัณฑ์ซ้ำ)

## 5. กฎความปลอดภัยของโปรเจกต์

- ความลับทั้งหมด (รหัสผ่าน DB, `JWT_SECRET`) อยู่ใน `.env` เท่านั้น ห้ามเขียนในโค้ด
- ถ้าเคยมีความลับหลุดขึ้น repo สาธารณะ ให้ **เปลี่ยนค่าใหม่ทั้งหมด** (การลบออกจากโค้ดไม่พอ เพราะยังอยู่ในประวัติ Git) การเปลี่ยน `JWT_SECRET` ทำให้ token เก่าใช้ไม่ได้ทั้งหมด ทุกคนต้องล็อกอินใหม่
- `role` ถูกกำหนดจาก token เท่านั้น ห้ามรับ `role`, `user_id`, `approved_by` จาก body
- ราคา มัดจำ และค่าปรับ คำนวณที่ server เสมอ ไม่รับตัวเลขจากแอป
- ไฟล์อัปโหลดรับเฉพาะ jpg/png/gif/webp ไม่เกิน 5MB และตั้งนามสกุลจากชนิดไฟล์จริง

## 6. แก้ปัญหาที่พบบ่อย

| อาการ | สาเหตุ / วิธีแก้ |
|---|---|
| `Missing environment variables: ...` | ยังไม่ได้สร้าง `.env` หรือกรอกไม่ครบ ดูข้อ 2.4 |
| `JWT_SECRET must be at least 32 characters` | สร้างค่าใหม่ด้วยคำสั่งในข้อ 2.4 |
| `Cannot connect to MySQL ... ECONNREFUSED` | ยังไม่ได้เปิด MySQL ใน XAMPP หรือ `DB_HOST` / `DB_PORT` ผิด |
| `Access denied for user` | `DB_USER` / `DB_PASSWORD` ใน `.env` ไม่ตรงกับที่สร้างไว้ในข้อ 2.3 |
| `Unknown database 'mobile_app'` | ยังไม่ได้สร้างหรือนำเข้า database ดูข้อ 2.2 |
| `Cannot find module 'xxx'` | ยังไม่ได้รัน `npm install` ในโฟลเดอร์ `backend` |
| ทุก request ได้ `401` | ไม่ได้แนบ token หรือ token หมดอายุ (อายุ 1 วัน) ล็อกอินใหม่ |
| เปลี่ยน role แล้วไม่มีผล | role ฝังอยู่ใน token ต้องล็อกอินใหม่ |
