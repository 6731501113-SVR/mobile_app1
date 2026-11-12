const router = require('express').Router();
const ctrl = require('../controllers/categoryController');
const { requireAdmin } = require('../middleware/auth');

router.get('/', ctrl.list);
router.get('/:id', ctrl.getOne);
router.post('/', requireAdmin, ctrl.create);
router.put('/:id', requireAdmin, ctrl.update);
router.delete('/:id', requireAdmin, ctrl.remove);

module.exports = router;
