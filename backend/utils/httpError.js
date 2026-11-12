// error ที่รู้ status code และ body ที่จะตอบกลับ โยนจาก controller แล้ว errorHandler จะส่งให้เอง
class HttpError extends Error {
    constructor(status, body) {
        const payload = typeof body === 'string' ? { message: body } : body || {};
        super(payload.message || 'Error');
        this.status = status;
        this.body = payload;
    }
}

module.exports = HttpError;
