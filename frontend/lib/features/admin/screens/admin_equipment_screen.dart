import 'package:flutter/material.dart';

import '../models/equipment.dart';
import '../repositories/api_repository.dart';
import 'equipment_form_screen.dart';

class AdminEquipmentScreen extends StatefulWidget {
  const AdminEquipmentScreen({super.key});

  @override
  State<AdminEquipmentScreen> createState() => _AdminEquipmentScreenState();
}

class _AdminEquipmentScreenState extends State<AdminEquipmentScreen> {
  final ApiRepository _repository = ApiRepository();
  late Future<List<Equipment>> _equipment;

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
        builder: (_) => EquipmentFormScreen(equipment: equipment),
      ),
    );
    if (saved == true && mounted) _reload();
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
                  trailing: IconButton(
                    tooltip: 'แก้ไขอุปกรณ์',
                    onPressed: () => _openForm(equipment: item),
                    icon: const Icon(Icons.edit_outlined),
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
