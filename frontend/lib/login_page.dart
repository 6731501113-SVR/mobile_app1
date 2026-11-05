import 'package:flutter/material.dart';

import 'models.dart';
import 'register_page.dart';
import 'repositories.dart';
import 'theme.dart';
import 'widgets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.repo, required this.onLoggedIn});

  final AuthRepository repo;
  final ValueChanged<AppUser> onLoggedIn;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _pw = TextEditingController();
  bool _hide = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _id.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await widget.repo.login(
        username: _id.text.trim(),
        password: _pw.text,
      );
      if (!mounted) return;
      widget.onLoggedIn(user); // role routing happens in the app root
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'เชื่อมต่อไม่สำเร็จ กรุณาลองอีกครั้ง';
        _busy = false;
      });
    }
  }

  Future<void> _openRegister() async {
    final user = await Navigator.of(context).push<AppUser>(
      MaterialPageRoute(builder: (_) => RegisterPage(repo: widget.repo)),
    );
    if (user != null && mounted) widget.onLoggedIn(user);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            _header(context),
            Transform.translate(
              offset: const Offset(0, -28),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _card(),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(32, 0, 32, 32),
              child: Text(
                'ผู้ดูแลระบบใช้หน้าเข้าสู่ระบบเดียวกัน ระบบจะพาไปหน้าที่ตรงกับสิทธิ์ (role) อัตโนมัติ',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.primary,
      padding: EdgeInsets.fromLTRB(
        24,
        MediaQuery.paddingOf(context).top + 36,
        24,
        52,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.inventory_2_outlined,
                color: AppColors.primary),
          ),
          const SizedBox(height: 20),
          const Text(
            'ระบบยืม-คืนครุภัณฑ์',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'กล้อง ไมค์ วอล์กกี้ทอล์กกี้ และอุปกรณ์สำหรับจัดกิจกรรม จองยืมได้จากมือถือ',
            style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 13.5, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _card() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'เข้าสู่ระบบ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            LabeledField(
              label: 'รหัสนักศึกษา / ไอดีผู้ใช้',
              controller: _id,
              enabled: !_busy,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'กรุณากรอกรหัสนักศึกษา' : null,
            ),
            const SizedBox(height: 14),
            LabeledField(
              label: 'รหัสผ่าน',
              controller: _pw,
              enabled: !_busy,
              obscure: _hide,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'กรุณากรอกรหัสผ่าน' : null,
              suffixIcon: IconButton(
                icon: Icon(
                  _hide ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 20,
                ),
                onPressed: () => setState(() => _hide = !_hide),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              ErrorBox(_error!),
            ],
            const SizedBox(height: 14),
            // กล่องบัญชีทดลอง (ใช้ตอนพัฒนา/ส่งงาน ลบออกได้เมื่อใช้จริง)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.tealSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'บัญชีสำหรับทดลอง',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'ผู้ยืม:  user123  /  รหัสผ่าน 1234',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                  Text(
                    'แอดมิน:  admin123  /  รหัสผ่าน 1234',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text('เข้าสู่ระบบ'),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'ยังไม่มีบัญชี?',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
                TextButton(
                  onPressed: _busy ? null : _openRegister,
                  child: const Text(
                    'สมัครสมาชิก',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
