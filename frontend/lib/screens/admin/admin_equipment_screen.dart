import 'package:flutter/material.dart';

import '../../mock/app_store.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// A3: จัดการอุปกรณ์ — ค้นหา กรองสถานะ เปลี่ยนสถานะ และเพิ่มอุปกรณ์ใหม่
class AdminEquipmentScreen extends StatefulWidget {
  const AdminEquipmentScreen({super.key});

  @override
  State<AdminEquipmentScreen> createState() => _AdminEquipmentScreenState();
}

class _AdminEquipmentScreenState extends State<AdminEquipmentScreen> {
  final AppStore _store = AppStore.instance;
  final TextEditingController _search = TextEditingController();
  EquipmentStatus? _filter; // null = ทั้งหมด

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Equipment> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return _store.equipment.where((e) {
      if (_filter != null && e.status != _filter) return false;
      if (q.isEmpty) return true;
      return e.name.toLowerCase().contains(q) || e.assetCode.toLowerCase().contains(q);
    }).toList();
  }

  static String statusLabel(EquipmentStatus s) => switch (s) {
        EquipmentStatus.available => 'ว่าง',
        EquipmentStatus.borrowed => 'ถูกยืม',
        EquipmentStatus.maintenance => 'ซ่อมบำรุง',
        EquipmentStatus.lost => 'สูญหาย',
      };

  static Widget statusBadge(EquipmentStatus s) => switch (s) {
        EquipmentStatus.available => const StatusBadge(
            label: 'ว่าง', background: AppColors.greenSoft, foreground: AppColors.greenText),
        EquipmentStatus.borrowed => const StatusBadge(
            label: 'ถูกยืม', background: AppColors.blueSoft, foreground: AppColors.blueText),
        EquipmentStatus.maintenance => const StatusBadge(
            label: 'ซ่อมบำรุง',
            background: AppColors.amberSoft,
            foreground: AppColors.amberText),
        EquipmentStatus.lost => const StatusBadge(
            label: 'สูญหาย', background: AppColors.redSoft, foreground: AppColors.redText),
      };

  Future<void> _changeStatus(Equipment e) async {
    if (e.status == EquipmentStatus.borrowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('อุปกรณ์ถูกยืมอยู่ ต้องบันทึกรับคืนที่แท็บ "รับคืน" ก่อน')),
      );
      return;
    }
    final picked = await showModalBottomSheet<EquipmentStatus>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('${e.name} (${e.assetCode})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            for (final s in [
              EquipmentStatus.available,
              EquipmentStatus.maintenance,
              EquipmentStatus.lost,
            ])
              ListTile(
                title: Text(statusLabel(s)),
                trailing: e.status == s ? const Icon(Icons.check, color: AppColors.teal) : null,
                onTap: () => Navigator.of(ctx).pop(s),
              ),
          ],
        ),
      ),
    );
    if (picked != null && picked != e.status) {
      _store.setEquipmentStatus(e.id, picked);
    }
  }

  Future<void> _add() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _AddEquipmentDialog(store: _store),
    );
    if (ok == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('เพิ่มอุปกรณ์แล้ว')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('เพิ่มอุปกรณ์'),
      ),
      body: ListenableBuilder(
        listenable: _store,
        builder: (context, _) {
          final list = _filtered;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    hintText: 'ค้นหาชื่อหรือรหัสครุภัณฑ์',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(children: [
                  _chip('ทั้งหมด', null),
                  _chip('ว่าง', EquipmentStatus.available),
                  _chip('ถูกยืม', EquipmentStatus.borrowed),
                  _chip('ซ่อม', EquipmentStatus.maintenance),
                  _chip('สูญหาย', EquipmentStatus.lost),
                ]),
              ),
              Expanded(
                child: list.isEmpty
                    ? const Center(
                        child: Text('ไม่พบอุปกรณ์', style: TextStyle(color: AppColors.muted)))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 90),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final e = list[i];
                          return InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => _changeStatus(e),
                            child: AppCard(
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppColors.tealSoft,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.inventory_2_outlined,
                                        color: AppColors.teal),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(e.name,
                                            style: const TextStyle(
                                                fontSize: 14, fontWeight: FontWeight.w600)),
                                        Text('${e.assetCode} · ${e.categoryName}',
                                            style: const TextStyle(
                                                fontSize: 12, color: AppColors.muted)),
                                      ],
                                    ),
                                  ),
                                  statusBadge(e.status),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _chip(String label, EquipmentStatus? value) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        selectedColor: AppColors.teal,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.text,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        ),
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }
}

class _AddEquipmentDialog extends StatefulWidget {
  final AppStore store;

  const _AddEquipmentDialog({required this.store});

  @override
  State<_AddEquipmentDialog> createState() => _AddEquipmentDialogState();
}

class _AddEquipmentDialogState extends State<_AddEquipmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _code = TextEditingController();
  late String _category = widget.store.categories.first;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final err = widget.store.addEquipment(
      name: _name.text,
      code: _code.text,
      category: _category,
    );
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('เพิ่มอุปกรณ์'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'ชื่ออุปกรณ์'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอกชื่อ' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'รหัสครุภัณฑ์ เช่น CAM-004'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอกรหัส' : null,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'หมวดหมู่'),
                items: [
                  for (final c in widget.store.categories)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Notice(
                  background: AppColors.redSoft,
                  foreground: AppColors.redText,
                  icon: Icons.error_outline,
                  text: _error!,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false), child: const Text('ยกเลิก')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: _submit,
          child: const Text('บันทึก'),
        ),
      ],
    );
  }
}
