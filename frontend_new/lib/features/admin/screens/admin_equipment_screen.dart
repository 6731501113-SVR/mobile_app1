import 'package:flutter/material.dart';

import '../data/admin_equipment.dart';
import '../data/api_repository.dart';
import 'equipment_form_screen.dart';

class AdminEquipmentScreen extends StatefulWidget {
  const AdminEquipmentScreen({super.key, this.repository});

  final ApiRepository? repository;

  @override
  State<AdminEquipmentScreen> createState() => _AdminEquipmentScreenState();
}

class _AdminEquipmentScreenState extends State<AdminEquipmentScreen> {
  late final ApiRepository _repository = widget.repository ?? ApiRepository();
  late Future<List<Equipment>> _equipment;
  int? _deletingEquipmentId;

  @override
  void initState() {
    super.initState();
    _equipment = _repository.getEquipmentList();
  }

  void _reload() {
    setState(() {
      _equipment = _repository.getEquipmentList();
    });
  }

  Future<void> _openForm({Equipment? equipment}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            EquipmentFormScreen(equipment: equipment, repository: _repository),
      ),
    );
    if (saved == true && mounted) _reload();
  }

  Future<void> _confirmDelete(Equipment equipment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ยืนยันการลบอุปกรณ์'),
        content: Text(
          'ต้องการลบ "${equipment.name}" หรือไม่?\nประวัติการยืมจะยังคงอยู่',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('ลบอุปกรณ์'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingEquipmentId = equipment.id);
    try {
      await _repository.deleteEquipment(equipment.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ลบ "${equipment.name}" สำเร็จ')));
      _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ลบอุปกรณ์ไม่สำเร็จ: ${error.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _deletingEquipmentId = null);
    }
  }

  String _imageUrl(String imageUrl) {
    if (imageUrl.startsWith('http')) return imageUrl;
    return '${ApiRepository.serverUrl}${imageUrl.startsWith('/') ? '' : '/'}$imageUrl';
  }

  static String _statusLabel(String status) => switch (status) {
    'available' => 'พร้อมใช้งาน',
    'borrowed' => 'ถูกยืม',
    'maintenance' => 'ซ่อมบำรุง',
    'lost' => 'สูญหาย',
    _ => status,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการอุปกรณ์'),
        actions: [
          IconButton(
            tooltip: 'โหลดรายการใหม่',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('เพิ่มอุปกรณ์'),
      ),
      body: FutureBuilder<List<Equipment>>(
        future: _equipment,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'โหลดรายการอุปกรณ์ไม่สำเร็จ: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _reload,
                      child: const Text('ลองอีกครั้ง'),
                    ),
                  ],
                ),
              ),
            );
          }

          final equipment = snapshot.data ?? const <Equipment>[];
          if (equipment.isEmpty) {
            return const Center(child: Text('ยังไม่มีอุปกรณ์'));
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
            itemCount: equipment.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = equipment[index];
              return Card(
                child: ListTile(
                  onTap: () => _openForm(equipment: item),
                  leading: _equipmentImage(item),
                  title: Text(item.name),
                  subtitle: Text(
                    '${item.assetCode} · ${item.categoryName}\n'
                    '${item.pricePerDay} บาท/วัน · มัดจำ ${item.deposit} บาท · ${_statusLabel(item.status)}',
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'แก้ไขอุปกรณ์',
                        onPressed: () => _openForm(equipment: item),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'ลบอุปกรณ์',
                        onPressed: _deletingEquipmentId == item.id
                            ? null
                            : () => _confirmDelete(item),
                        icon: _deletingEquipmentId == item.id
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.delete_outline),
                        color: Colors.red,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _equipmentImage(Equipment item) {
    final url = item.imageUrl;
    if (url == null || url.isEmpty) {
      return const CircleAvatar(child: Icon(Icons.inventory_2_outlined));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        _imageUrl(url),
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const CircleAvatar(child: Icon(Icons.broken_image_outlined)),
      ),
    );
  }
}
