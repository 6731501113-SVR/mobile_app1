import 'package:flutter/material.dart';

import '../../core/common_widgets.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import 'auth_repository.dart';
import 'login_controller.dart';
import 'register_page.dart';

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
  late final LoginController _controller = LoginController(widget.repo);
  bool _hide = true;

  @override
  void dispose() {
    _controller.dispose();
    _id.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final user = await _controller.submit(username: _id.text, password: _pw.text);
    if (user != null && mounted) widget.onLoggedIn(user); // role routing is in main.dart
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
            child: const Icon(Icons.inventory_2_outlined, color: AppColors.primary),
          ),
          const SizedBox(height: 20),
          const Text(
            'ระบบเช่า-คืนครุภัณฑ์',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'กล้อง ไมค์ วอล์กกี้ทอล์กกี้ และอุปกรณ์สำหรับจัดกิจกรรม จองเช่าได้จากมือถือ',
            style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 13.5, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _card() {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final busy = _controller.busy;
        final error = _controller.error;
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
                  enabled: !busy,
                  textInputAction: TextInputAction.next,
                  validator: LoginController.validateUsername,
                ),
                const SizedBox(height: 14),
                LabeledField(
                  label: 'รหัสผ่าน',
                  controller: _pw,
                  enabled: !busy,
                  obscure: _hide,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  validator: LoginController.validatePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _hide ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _hide = !_hide),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 14),
                  ErrorBox(error),
                ],
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: busy ? null : _submit,
                  child: busy
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
                      onPressed: busy ? null : _openRegister,
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
      },
    );
  }
}
