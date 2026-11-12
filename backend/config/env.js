const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

// ค่าที่ต้องมี (DB_PASSWORD เว้นว่างได้ แต่ต้องประกาศไว้)
const missing = ['DB_HOST', 'DB_USER', 'DB_NAME', 'JWT_SECRET'].filter((k) => !process.env[k]);
if (process.env.DB_PASSWORD === undefined) missing.push('DB_PASSWORD');

if (missing.length > 0) {
    throw new Error(
        `Missing environment variables: ${missing.join(', ')}\n` +
        'Copy .env.example to .env and fill in the values.'
    );
}
if (process.env.JWT_SECRET.length < 32) {
    throw new Error(
        'JWT_SECRET must be at least 32 characters. Generate one with:\n' +
        `  node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"`
    );
}

const port = Number(process.env.PORT) || 3000;

module.exports = {
    port,
    baseUrl: (process.env.BASE_URL || `http://localhost:${port}`).replace(/\/+$/, ''),
    db: {
        host: process.env.DB_HOST,
        port: Number(process.env.DB_PORT) || 3306,
        user: process.env.DB_USER,
        password: process.env.DB_PASSWORD,
        database: process.env.DB_NAME
    },
    jwt: {
        secret: process.env.JWT_SECRET,
        expiresIn: process.env.JWT_EXPIRES_IN || '1d'
    }
};
