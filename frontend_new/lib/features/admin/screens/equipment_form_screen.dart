import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/admin_equipment.dart';
import '../data/api_repository.dart';

class EquipmentFormScreen extends StatefulWidget {
  final Equipment? equipment;

  const EquipmentFormScreen({super.key, this.equipment});

  @override
  State<EquipmentFormScreen> createState() => _EquipmentFormScreenState();
}

class _EquipmentFormScreenState extends State<EquipmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiRepository _apiRepository = ApiRepository();
  final ImagePicker _picker = ImagePicker();

  late String _assetCode;
  late String _name;
  late int? _categoryId;
  List<Map<String, dynamic>> _categories = [];
  bool _loadingCategories = true;
  late String _status;
  late double _pricePerDay;
  late double _deposit;
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _assetCode = widget.equipment?.assetCode ?? '';
    _name = widget.equipment?.name ?? '';
    _categoryId = widget.equipment?.categoryId;
    _loadCategories();
    _status = widget.equipment?.status ?? 'available';
    _pricePerDay = widget.equipment?.pricePerDay ?? 0.0;
    _deposit = widget.equipment?.deposit ?? 0.0;
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _apiRepository.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = cats;
        _loadingCategories = false;
        // When adding a new item, nothing is selected until the admin picks one.
        if (_categoryId != null && !cats.any((c) => c['id'] == _categoryId)) {
          _categoryId = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingCategories = false);
      _showError('โหลดหมวดหมู่ไม่สำเร็จ');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        if (!mounted) return;
        setState(() {
          _selectedImage = pickedFile;
          _selectedImageBytes = bytes;
        });
      }
    } catch (e) {
      _showError('ไม่สามารถเลือกรูปภาพได้: $e');
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('เลือกจากคลังภาพ (Gallery)'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('ถ่ายภาพด้วยกล้อง (Camera)'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() => _isLoading = true);

      final categoryName = _categories
          .firstWhere((c) => c['id'] == _categoryId)['name'] as String;

      final newEquipment = Equipment(
        id: widget.equipment?.id,
        assetCode: _assetCode,
        name: _name,
        categoryId: _categoryId!,
        categoryName: categoryName,
        status: _status,
        pricePerDay: _pricePerDay,
        deposit: _deposit,
        stock: widget.equipment?.stock ?? 1,
        imageUrl: widget.equipment?.imageUrl,
      );

      try {
        bool success = await _apiRepository.saveEquipmentWithImage(
          newEquipment,
          imageFile: _selectedImage,
          isUpdate: widget.equipment != null,
        );
        if (success) {
          if (!mounted) return;
          Navigator.pop(context, true);
        } else {
          _showError('บันทึกข้อมูลไม่สำเร็จ');
        }
      } catch (e) {
        _showError('เกิดข้อผิดพลาด: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    bool isEdit = widget.equipment != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'แก้ไขอุปกรณ์' : 'เพิ่มอุปกรณ์ใหม่')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // --- ส่วนอัปโหลดและแสดงตัวอย่างรูปภาพ ---
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade400),
                      ),
                      child: _selectedImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                _selectedImageBytes!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : (widget.equipment?.imageUrl != null &&
                                widget.equipment!.imageUrl!.isNotEmpty)
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                widget.equipment!.imageUrl!.startsWith('http')
                                    ? widget.equipment!.imageUrl!
                                    : '${ApiRepository.serverUrl}${widget.equipment!.imageUrl!.startsWith('/') ? '' : '/'}${widget.equipment!.imageUrl}',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(
                                      Icons.broken_image,
                                      size: 50,
                                      color: Colors.grey,
                                    ),
                              ),
                            )
                          : const Icon(
                              Icons.image,
                              size: 60,
                              color: Colors.grey,
                            ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _showImageSourceDialog,
                      icon: const Icon(Icons.add_a_photo),
                      label: Text(
                        _selectedImage == null
                            ? 'เพิ่ม / เปลี่ยนรูปภาพ'
                            : 'เปลี่ยนรูปภาพ',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _assetCode,
                decoration: const InputDecoration(
                  labelText: 'รหัสสินทรัพย์ (Asset Code)',
                ),
                validator: (val) => val == null || val.isEmpty
                    ? 'กรุณากรอกรหัสสินทรัพย์'
                    : null,
                onSaved: (val) => _assetCode = val!,
              ),
              TextFormField(
                initialValue: _name,
                decoration: const InputDecoration(labelText: 'ชื่ออุปกรณ์'),
                validator: (val) =>
                    val == null || val.isEmpty ? 'กรุณากรอกชื่ออุปกรณ์' : null,
                onSaved: (val) => _name = val!,
              ),
              DropdownButtonFormField<int>(
                initialValue: _categoryId,
                decoration: InputDecoration(
                  labelText: _loadingCategories
                      ? 'กำลังโหลดหมวดหมู่...'
                      : 'หมวดหมู่',
                ),
                items: [
                  for (final c in _categories)
                    DropdownMenuItem<int>(
                      value: c['id'] as int,
                      child: Text(c['name'] as String),
                    ),
                ],
                validator: (val) => val == null ? 'กรุณาเลือกหมวดหมู่' : null,
                onChanged: (val) => setState(() => _categoryId = val),
              ),
              TextFormField(
                initialValue: _pricePerDay.toString(),
                decoration: const InputDecoration(
                  labelText: 'ราคาเช่าต่อวัน (บาท)',
                ),
                keyboardType: TextInputType.number,
                validator: (val) => double.tryParse(val ?? '') == null
                    ? 'กรุณากรอกตัวเลขที่ถูกต้อง'
                    : null,
                onSaved: (val) => _pricePerDay = double.parse(val!),
              ),
              TextFormField(
                initialValue: _deposit.toString(),
                decoration: const InputDecoration(labelText: 'เงินมัดจำ (บาท)'),
                keyboardType: TextInputType.number,
                validator: (val) => double.tryParse(val ?? '') == null
                    ? 'กรุณากรอกตัวเลขที่ถูกต้อง'
                    : null,
                onSaved: (val) => _deposit = double.parse(val!),
              ),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'สถานะอุปกรณ์'),
                items: [
                  const DropdownMenuItem(
                    value: 'available',
                    child: Text('พร้อมใช้งาน (Available)'),
                  ),
                  // Only the borrow flow can set 'borrowed'; keep it visible
                  // (read-only) while editing an item that is currently out.
                  if (_status == 'borrowed')
                    const DropdownMenuItem(
                      value: 'borrowed',
                      child: Text('ถูกยืม (Borrowed)'),
                    ),
                  const DropdownMenuItem(
                    value: 'maintenance',
                    child: Text('กำลังซ่อมบำรุง (Maintenance)'),
                  ),
                  const DropdownMenuItem(value: 'lost', child: Text('สูญหาย (Lost)')),
                ],
                onChanged: (val) => setState(() => _status = val!),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : Text(isEdit ? 'บันทึกการแก้ไข' : 'เพิ่มอุปกรณ์'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
