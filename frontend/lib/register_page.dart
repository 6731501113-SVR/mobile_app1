import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// import 'models.dart';
import 'repositories.dart';
import 'theme.dart';
import 'widgets.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, required this.repo});

  final AuthRepository repo;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  static const _studentIdLength = 10;

  final _formKey = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _name = TextEditingController();
  final _pw = TextEditingController();
  final _confirm = TextEditingController();
  bool _hide = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _id.dispose();
    _name.dispose();
    _pw.dispose();
    _confirm.dispose();
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
      final user = await widget.repo.register(
        username: _id.text.trim(),
        fullName: _name.text.trim(),
        password: _pw.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(user); // login page signs the user in
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
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
                      'สร้างบัญชีผู้ยืมเพื่อจองอุปกรณ์สำหรับกิจกรรมของคุณ',
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
                        hint: 'เช่น 6731501087',
                        controller: _id,
                        enabled: !_busy,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(_studentIdLength),
                        ],
                        validator: (v) {
                          final s = v?.trim() ?? '';
                          if (s.isEmpty) return 'กรุณากรอกรหัสนักศึกษา';
                          if (s.length != _studentIdLength) {
                            return 'รหัสนักศึกษาต้องมี $_studentIdLength หลัก';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      LabeledField(
                        label: 'ชื่อ-นามสกุล',
                        hint: 'ชื่อ นามสกุล',
                        controller: _name,
                        enabled: !_busy,
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'กรุณากรอกชื่อ-นามสกุล'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      LabeledField(
                        label: 'รหัสผ่าน',
                        hint: 'อย่างน้อย 8 ตัวอักษร',
                        controller: _pw,
                        enabled: !_busy,
                        obscure: _hide,
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v == null || v.length < 8)
                            ? 'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร'
                            : null,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _hide
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
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
                        enabled: !_busy,
                        obscure: _hide,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        validator: (v) =>
                            v != _pw.text ? 'รหัสผ่านไม่ตรงกัน' : null,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'รหัสผ่านจะถูกเข้ารหัสด้วย Argon2id ก่อนเก็บลงระบบ',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        ErrorBox(_error!),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
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
          ),
        ),
      ),
    );
  }
}
