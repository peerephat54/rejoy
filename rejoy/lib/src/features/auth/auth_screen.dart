import 'package:flutter/material.dart';

import '../../core/api_config.dart';
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

  final _apiController = TextEditingController(
    text: ApiConfig.configuredBaseUrl,
  );
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
    _apiController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _surnameController.dispose();
    _ageController.dispose();
    _client.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final apiUrl = _apiController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (!apiUrl.startsWith(RegExp(r'https?://'))) {
      setState(
        () => _message = 'API URL ต้องขึ้นต้นด้วย http:// หรือ https://',
      );
      return;
    }
    if (email.isEmpty || password.length < 8) {
      setState(() => _message = 'ใส่อีเมล และรหัสผ่านอย่างน้อย 8 ตัวอักษร');
      return;
    }

    setState(() {
      _loading = true;
      _message = _registerMode ? 'กำลังสมัครสมาชิก...' : 'กำลังเข้าสู่ระบบ...';
    });

    try {
      await ApiConfig.saveBaseUrlOverride(apiUrl);
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
              const SizedBox(height: 24),
              const Text(
                'ReJoy',
                style: TextStyle(
                  color: Color(0xFF17343C),
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'ล็อกอินด้วยอีเมลเพื่อเก็บข้อมูลสุขภาพใจของคุณอย่างเป็นส่วนตัว',
                style: TextStyle(color: Color(0xFF607A81), height: 1.4),
              ),
              const SizedBox(height: 24),
              _card(
                children: [
                  TextField(
                    controller: _apiController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Backend / Cloud API URL',
                      hintText: 'https://rejoy-backend.onrender.com',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      helperText: 'อย่างน้อย 8 ตัวอักษร',
                    ),
                  ),
                  if (_registerMode) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(labelText: 'ชื่อ'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _surnameController,
                      decoration: const InputDecoration(labelText: 'นามสกุล'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'อายุ'),
                    ),
                  ],
                  const SizedBox(height: 18),
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
                        fontWeight: FontWeight.w700,
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
        color: Colors.white.withValues(alpha: 0.86),
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
