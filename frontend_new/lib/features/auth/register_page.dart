import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/common_widgets.dart';
import '../../core/theme.dart';
import 'auth_repository.dart';
import 'register_controller.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, required this.repo});

  final AuthRepository repo;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _name = TextEditingController();
  final _pw = TextEditingController();
  final _confirm = TextEditingController();
  late final RegisterController _controller = RegisterController(widget.repo);
  bool _hide = true;

  @override
  void dispose() {
    _controller.dispose();
    _id.dispose();
    _name.dispose();
    _pw.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final user = await _controller.submit(
      username: _id.text,
      fullName: _name.text,
      password: _pw.text,
      confirm: _confirm.text,
    );
    if (user != null && mounted) {
      Navigator.of(context).pop(user); // login page signs the user in
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => _content(context),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final busy = _controller.busy;
    final error = _controller.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SquareIconButton(
          icon: Icons.chevron_left_rounded,
          tooltip: 'กลับ',
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: 18),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'สมัครสมาชิก',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 4),
              Text(
                'สร้างบัญชีผู้เช่าเพื่อจองอุปกรณ์สำหรับกิจกรรมของคุณ',
                style: TextStyle(fontSize: 13.5, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LabeledField(
                  label: 'รหัสนักศึกษา (ใช้เป็น username)',
                  hint: 'เช่น 6xxxxxxxxx',
                  controller: _id,
                  enabled: !busy,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(RegisterController.studentIdLength),
                  ],
                  validator: RegisterController.validateStudentId,
                ),
                const SizedBox(height: 14),
                LabeledField(
                  label: 'ชื่อ-นามสกุล',
                  hint: 'ชื่อ นามสกุล',
                  controller: _name,
                  enabled: !busy,
                  textInputAction: TextInputAction.next,
                  validator: RegisterController.validateFullName,
                ),
                const SizedBox(height: 14),
                LabeledField(
                  label: 'รหัสผ่าน',
                  hint: 'อย่างน้อย ${RegisterController.minPasswordLength} ตัวอักษร',
                  controller: _pw,
                  enabled: !busy,
                  obscure: _hide,
                  textInputAction: TextInputAction.next,
                  validator: RegisterController.validatePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _hide ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _hide = !_hide),
                  ),
                ),
                const SizedBox(height: 14),
                LabeledField(
                  label: 'ยืนยันรหัสผ่าน',
                  hint: 'กรอกรหัสผ่านอีกครั้ง',
                  controller: _confirm,
                  enabled: !busy,
                  obscure: _hide,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  validator: (v) => RegisterController.validateConfirm(_pw.text, v),
                ),
                const SizedBox(height: 12),
                const Text(
                  'รหัสผ่านจะถูกเข้ารหัสด้วย Argon2id ก่อนเก็บลงระบบ',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                if (error != null) ...[
                  const SizedBox(height: 14),
                  ErrorBox(error),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: busy ? null : _submit,
          child: busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
              : const Text('สร้างบัญชี'),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'มีบัญชีอยู่แล้ว?',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            TextButton(
              onPressed: busy ? null : () => Navigator.of(context).pop(),
              child: const Text(
                'เข้าสู่ระบบ',
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
    );
  }
}
