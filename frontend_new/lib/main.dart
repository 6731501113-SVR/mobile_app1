import 'package:flutter/material.dart';

import 'core/api_client.dart';
import 'core/models.dart';
import 'core/theme.dart';
import 'features/admin/admin_home.dart';
import 'features/admin/data/api_repository.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/login_page.dart';
import 'features/borrow/borrow.dart';
import 'features/home/equipment_repository.dart';
import 'features/home/home_page.dart';

void main() => runApp(const BorrowApp());

class BorrowApp extends StatefulWidget {
  const BorrowApp({super.key});

  @override
  State<BorrowApp> createState() => _BorrowAppState();
}

class _BorrowAppState extends State<BorrowApp> {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  late final ApiClient _api = ApiClient()..onUnauthorized = _onSessionExpired;
  late final AuthRepository _auth = ApiAuthRepository(_api, SecureTokenStore());
  late final EquipmentRepository _equipment = ApiEquipmentRepository(_api);
  late final BorrowRepository _borrow = ApiBorrowRepository(_api);

  AppUser? _user;
  bool _booting = true;
  String? _bootError;

  @override
  void initState() {
    super.initState();
    // Admin screens send the token held by this same client.
    ApiRepository.client = _api;
    _restore();
  }

  Future<void> _restore() async {
    setState(() {
      _booting = true;
      _bootError = null;
    });
    try {
      final user = await _auth.restoreSession();
      if (!mounted) return;
      setState(() {
        _user = user;
        _booting = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _bootError = e.message;
        _booting = false;
      });
    }
  }

  void _onSessionExpired() {
    if (_user == null) return;
    _auth.logout();
    setState(() => _user = null);
    _messengerKey.currentState?.showSnackBar(
      const SnackBar(content: Text('เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่')),
    );
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (mounted) setState(() => _user = null);
  }

  Widget _home() {
    if (_booting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_bootError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_bootError!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                OutlinedButton(onPressed: _restore, child: const Text('ลองอีกครั้ง')),
              ],
            ),
          ),
        ),
      );
    }
    final user = _user;
    if (user == null) {
      return LoginPage(
        repo: _auth,
        onLoggedIn: (u) => setState(() => _user = u),
      );
    }
    // One login screen for everyone: route by role.
    return switch (user.role) {
      UserRole.admin => AdminHome(user: user, onLogout: _logout),
      UserRole.borrower => HomePage(
          user: user,
          repo: _equipment,
          borrowRepo: _borrow,
          onLogout: _logout,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ระบบเช่า-คืนครุภัณฑ์',
      theme: buildTheme(),
      scaffoldMessengerKey: _messengerKey,
      home: _home(),
    );
  }
}
