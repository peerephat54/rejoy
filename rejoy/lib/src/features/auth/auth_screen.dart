import 'package:flutter/material.dart';

import '../../core/auth_session.dart';
import '../../services/rejoy_api_client.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.onSignedIn});

  final VoidCallback onSignedIn;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const _authTextColor = Color(0xFF17343C);
  static const _authMutedTextColor = Color(0xFF53666E);
  static const _authBorderColor = Color(0xFF8CA0AA);

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController(text: 'ReJoy');
  final _surnameController = TextEditingController(text: 'Friend');
  final _ageController = TextEditingController(text: '16');
  final _client = ReJoyApiClient();

  bool _registerMode = false;
  bool _loading = false;
  String? _message;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _surnameController.dispose();
    _ageController.dispose();
    _client.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.length < 8) {
      setState(() => _message = 'ใส่อีเมลและรหัสผ่านอย่างน้อย 8 ตัวอักษรนะ');
      return;
    }

    setState(() {
      _loading = true;
      _message = _registerMode ? 'กำลังสมัครสมาชิก...' : 'กำลังเข้าสู่ระบบ...';
    });

    try {
      ReJoyApiClient.clearCache();
      final result = _registerMode
          ? await _client.registerWithEmail(
              email: email,
              password: password,
              firstName: _firstNameController.text.trim().isEmpty
                  ? 'ReJoy'
                  : _firstNameController.text.trim(),
              surname: _surnameController.text.trim().isEmpty
                  ? 'Friend'
                  : _surnameController.text.trim(),
              age: int.tryParse(_ageController.text.trim()) ?? 0,
            )
          : await _client.loginWithEmail(email: email, password: password);

      await AuthSession.save(
        token: result.token,
        refreshToken: result.refreshToken,
        userId: result.user.id,
        email: result.user.email.isEmpty ? email : result.user.email,
      );

      if (!mounted) return;
      widget.onSignedIn();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = 'ยังเข้าไม่ได้: $error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8F6F4), Color(0xFFFFF4DA)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              const SizedBox(height: 28),
              const Text(
                'ReJoy',
                style: TextStyle(
                  color: _authTextColor,
                  fontSize: 46,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'ล็อกอินด้วยอีเมลเพื่อเก็บข้อมูลสุขภาพใจของคุณอย่างเป็นส่วนตัว',
                style: TextStyle(
                  color: Color(0xFF607A81),
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              _card(
                children: [
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(
                      color: _authTextColor,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(
                      color: _authTextColor,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      helperText: 'อย่างน้อย 8 ตัวอักษร',
                    ),
                  ),
                  if (_registerMode) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _firstNameController,
                      style: const TextStyle(
                        color: _authTextColor,
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: const InputDecoration(labelText: 'ชื่อ'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _surnameController,
                      style: const TextStyle(
                        color: _authTextColor,
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: const InputDecoration(labelText: 'นามสกุล'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        color: _authTextColor,
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: const InputDecoration(labelText: 'อายุ'),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _loading ? null : _submit,
                      icon: _loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.lock_open_rounded),
                      label: Text(
                        _registerMode ? 'สมัครสมาชิก' : 'เข้าสู่ระบบ',
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() {
                            _registerMode = !_registerMode;
                            _message = null;
                          }),
                    child: Text(
                      _registerMode
                          ? 'มีบัญชีแล้ว? เข้าสู่ระบบ'
                          : 'ยังไม่มีบัญชี? สมัครสมาชิก',
                    ),
                  ),
                  if (_message != null)
                    Text(
                      _message!,
                      style: const TextStyle(
                        color: Color(0xFF31525A),
                        fontWeight: FontWeight.w800,
                        height: 1.35,
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

  Widget _card({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5F9B91).withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          textTheme: Theme.of(context).textTheme.apply(
            bodyColor: _authTextColor,
            displayColor: _authTextColor,
          ),
          inputDecorationTheme: InputDecorationTheme(
            labelStyle: const TextStyle(
              color: _authMutedTextColor,
              fontWeight: FontWeight.w800,
            ),
            floatingLabelStyle: const TextStyle(
              color: _authTextColor,
              fontWeight: FontWeight.w900,
            ),
            hintStyle: TextStyle(
              color: _authMutedTextColor.withValues(alpha: 0.72),
              fontWeight: FontWeight.w700,
            ),
            helperStyle: const TextStyle(
              color: _authMutedTextColor,
              fontWeight: FontWeight.w700,
            ),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: _authBorderColor, width: 1.25),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: _authTextColor, width: 1.9),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFA8BEFF),
              foregroundColor: _authTextColor,
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF4E73D9),
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(
            color: _authTextColor,
            fontWeight: FontWeight.w800,
          ),
          child: Column(children: children),
        ),
      ),
    );
  }
}
