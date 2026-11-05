import 'package:flutter/material.dart';

import '../../mock/app_store.dart';
import 'admin_dashboard_screen.dart';
import 'admin_equipment_screen.dart';
import 'admin_requests_screen.dart';
import 'admin_returns_screen.dart';

/// โครงหน้าแอดมิน: แถบเมนูล่าง 4 แท็บ (แดชบอร์ด / คำขอ / อุปกรณ์ / รับคืน)
class AdminShell extends StatefulWidget {
  final VoidCallback onLogout;

  const AdminShell({super.key, required this.onLogout});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  static const _titles = ['แดชบอร์ดแอดมิน', 'คำขอยืม', 'จัดการอุปกรณ์', 'รับคืนอุปกรณ์'];
  final AppStore _store = AppStore.instance;
  int _index = 0;

  void _go(int i) => setState(() => _index = i);

  Widget _badgeIcon(IconData icon, int count) {
    return Badge(
      label: Text('$count'),
      isLabelVisible: count > 0,
      child: Icon(icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(_titles[_index]),
            actions: [
              IconButton(
                tooltip: 'ออกจากระบบ',
                onPressed: widget.onLogout,
                icon: const Icon(Icons.logout_rounded),
              ),
            ],
          ),
          body: IndexedStack(
            index: _index,
            children: [
              AdminDashboardScreen(onGoTab: _go),
              const AdminRequestsScreen(),
              const AdminEquipmentScreen(),
              const AdminReturnsScreen(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _go,
            destinations: [
              const NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined), label: 'แดชบอร์ด'),
              NavigationDestination(
                  icon: _badgeIcon(Icons.inbox_outlined, _store.pendingCount), label: 'คำขอ'),
              const NavigationDestination(
                  icon: Icon(Icons.inventory_2_outlined), label: 'อุปกรณ์'),
              NavigationDestination(
                  icon: _badgeIcon(Icons.assignment_return_outlined, _store.overdueCount),
                  label: 'รับคืน'),
            ],
          ),
        );
      },
    );
  }
}
