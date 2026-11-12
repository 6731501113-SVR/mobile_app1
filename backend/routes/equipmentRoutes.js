const router = require('express').Router();
const ctrl = require('../controllers/equipmentController');
const { requireAdmin } = require('../middleware/auth');
const { uploadEquipmentImage } = require('../middleware/upload');

router.get('/', ctrl.list);
router.get('/:id', ctrl.getOne);
// เช็กสิทธิ์ Admin ก่อนรับไฟล์ ผู้ที่ไม่มีสิทธิ์จะอัปโหลดอะไรลงเครื่องไม่ได้
router.post('/', requireAdmin, uploadEquipmentImage, ctrl.create);
router.put('/:id', requireAdmin, uploadEquipmentImage, ctrl.update);
router.delete('/:id', requireAdmin, ctrl.remove);

module.exports = router;
