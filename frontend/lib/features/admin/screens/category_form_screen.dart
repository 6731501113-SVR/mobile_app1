import 'package:flutter/material.dart';
import '../repositories/api_repository.dart';

class CategoryFormScreen extends StatefulWidget {
  const CategoryFormScreen({super.key});

  @override
  State<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends State<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiRepository _apiRepository = ApiRepository();
  final TextEditingController _categoryNameController = TextEditingController();
  bool _isLoading = false;

  void _submitCategory() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        bool success = await _apiRepository.saveCategory(_categoryNameController.text);
        if (!mounted) return;
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('เพิ่มหมวดหมู่สำเร็จ')),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('เพิ่มหมวดหมู่ไม่สำเร็จ')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('เพิ่มหมวดหมู่ใหม่ (Category)')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _categoryNameController,
                decoration: const InputDecoration(
                  labelText: 'ชื่อหมวดหมู่ (Category Name)',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.isEmpty ? 'กรุณากรอกชื่อหมวดหมู่' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitCategory,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('บันทึกหมวดหมู่', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
