const router = require('express').Router();
const ctrl = require('../controllers/uploadController');
const { requireAdmin } = require('../middleware/auth');
const { uploadGenericImage } = require('../middleware/upload');

// POST /api/upload  (Admin เท่านั้น — เดิมเปิดให้ใครก็อัปโหลดได้)
router.post('/', requireAdmin, uploadGenericImage, ctrl.uploadImage);

module.exports = router;
