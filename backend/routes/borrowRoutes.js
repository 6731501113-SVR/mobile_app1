const router = require('express').Router();
const ctrl = require('../controllers/borrowController');
const { verifyToken, requireAdmin } = require('../middleware/auth');
const { uploadSlipImage } = require('../middleware/upload');

// หมายเหตุ: route ที่เจาะจงกว่า (/user/..., /equipment/...) ต้องอยู่ก่อน /:id
router.get('/', requireAdmin, ctrl.list);
router.get('/user/:userId', verifyToken, ctrl.listByUser);
router.get('/equipment/:id/booked-dates', ctrl.bookedDates);
router.get('/:id', verifyToken, ctrl.getOne);

router.post('/', verifyToken, ctrl.create);

router.put('/:id/slip', verifyToken, uploadSlipImage, ctrl.uploadSlip);
router.put('/:id/verify-payment', requireAdmin, ctrl.verifyPayment);
router.put('/:id/approve', requireAdmin, ctrl.approve);
router.put('/:id/handover', requireAdmin, ctrl.handover);
router.put('/:id/return', requireAdmin, ctrl.returnEquipment);
router.put('/:id/cancel', verifyToken, ctrl.cancel);
router.put('/:id/pay-fine', requireAdmin, ctrl.payFine);

module.exports = router;
