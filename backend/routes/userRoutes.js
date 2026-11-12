const router = require('express').Router();
const ctrl = require('../controllers/userController');
const { verifyToken, requireAdmin } = require('../middleware/auth');

router.get('/', requireAdmin, ctrl.list);
router.get('/:id', verifyToken, ctrl.getOne);
router.put('/:id', verifyToken, ctrl.update);
router.delete('/:id', requireAdmin, ctrl.remove);

module.exports = router;
