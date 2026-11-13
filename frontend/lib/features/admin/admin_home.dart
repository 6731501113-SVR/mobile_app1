import 'package:flutter/material.dart';

import '../../core/models.dart';
import 'screens/admin_pending_borrow_screen.dart';
import 'screens/admin_delivery_return_screen.dart';
import 'screens/admin_pending_slip_screen.dart';
import 'screens/category_form_screen.dart';
import 'screens/equipment_form_screen.dart';

/// Admin menu (Editor 2's screens). Replaces the old AdminHomeStub.
class AdminHome extends StatelessWidget {
  const AdminHome({super.key, required this.user, required this.onLogout});

  final AppUser user;
  final VoidCallback onLogout;

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ผู้ดูแลระบบ'),
        actions: [
          IconButton(
            tooltip: 'ออกจากระบบ',
            icon: const Icon(Icons.logout_rounded),
            onPressed: onLogout,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('สวัสดี ${user.fullName}', style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => _open(context, const EquipmentFormScreen()),
            child: const Text('เพิ่ม/แก้ไขอุปกรณ์ (พร้อมรูปภาพ)'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => _open(context, const CategoryFormScreen()),
            child: const Text('เพิ่มหมวดหมู่'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => _open(context, const AdminPendingBorrowScreen()),
            child: const Text('อนุมัติคำขอเช่า'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => _open(context, const AdminPendingSlipScreen()),
            child: const Text('ตรวจสอบสลิปโอนเงิน'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => _open(context, const AdminDeliveryReturnScreen()),
            child: const Text('ส่งมอบ/รับคืนอุปกรณ์'),
          ),
        ],
      ),
    );
  }
}
