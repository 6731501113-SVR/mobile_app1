import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'home_page.dart';
import 'login_page.dart';
import 'models.dart';
import 'repositories.dart';
import 'screens/admin/admin_shell.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ต้องมีบรรทัดนี้ เพื่อให้ปฏิทินในหน้าจองแสดงเดือน/วันเป็นภาษาไทย
  await initializeDateFormatting('th_TH', null);
  runApp(const BorrowApp());
}

class BorrowApp extends StatefulWidget {
  const BorrowApp({super.key});

  @override
  State<BorrowApp> createState() => _BorrowAppState();
}

class _BorrowAppState extends State<BorrowApp> {
  // Swap these for real API-backed repositories later.
  final AuthRepository _auth = MockAuthRepository();
  final EquipmentRepository _equipment = MockEquipmentRepository();

  AppUser? _user;

  void _logout() => setState(() => _user = null);

  Widget _home() {
    final user = _user;
    if (user == null) {
      return LoginPage(
        repo: _auth,
        onLoggedIn: (u) => setState(() => _user = u),
      );
    }
    // One login screen for everyone: route by role.
    return switch (user.role) {
      UserRole.admin => AdminShell(onLogout: _logout),
      UserRole.borrower =>
        HomePage(user: user, repo: _equipment, onLogout: _logout),
    };
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ระบบยืม-คืนครุภัณฑ์',
      theme: buildTheme(),
      home: _home(),
    );
  }
}
