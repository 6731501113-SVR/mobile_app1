const categoryModel = require('../models/categoryModel');
const HttpError = require('../utils/httpError');

function requireName(body) {
    const name = body && typeof body.category_name === 'string' ? body.category_name.trim() : '';
    if (!name) throw new HttpError(400, { message: 'category_name is required' });
    return name;
}

// GET /api/categories (Public)
exports.list = async (req, res) => {
    res.json(await categoryModel.findAll());
};

// GET /api/categories/:id (Public)
exports.getOne = async (req, res) => {
    const category = await categoryModel.findById(req.params.id);
    if (!category) throw new HttpError(404, { message: 'Category not found' });
    res.json(category);
};

// POST /api/categories (Admin)
exports.create = async (req, res) => {
    const name = requireName(req.body);
    if (await categoryModel.nameTaken(name)) {
        throw new HttpError(409, { message: 'Category already exists' });
    }
    const id = await categoryModel.create(name);
    res.status(201).json({ message: 'Category created', id });
};

// PUT /api/categories/:id (Admin)
exports.update = async (req, res) => {
    const name = requireName(req.body);
    if (await categoryModel.nameTaken(name, req.params.id)) {
        throw new HttpError(409, { message: 'Category name already in use' });
    }
    const affected = await categoryModel.rename(req.params.id, name);
    if (affected === 0) throw new HttpError(404, { message: 'Category not found' });
    res.json({ message: 'Category updated' });
};

// DELETE /api/categories/:id (Admin)
exports.remove = async (req, res) => {
    if (await categoryModel.isUsedByEquipment(req.params.id)) {
        throw new HttpError(409, { message: 'Cannot delete: category is used by equipment' });
    }
    const affected = await categoryModel.remove(req.params.id);
    if (affected === 0) throw new HttpError(404, { message: 'Category not found' });
    res.json({ message: 'Category deleted' });
};
