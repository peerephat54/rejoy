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
        final detail = error.toString().contains('TimeoutException')
            ? 'เซิร์ฟเวอร์ฟรีกำลังตื่นอยู่ ลองกดอีกครั้งในอีกไม่กี่วินาทีนะ'
            : error.toString();
        _message = 'ยังเข้าไม่ได้: $detail';
        _loading = false;
      });
    }
  }

  Future<void> _loginWithDemo() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final email = 'demo-$now@rejoy.demo';
    const password = 'ReJoyDemo123!';

    setState(() {
      _loading = true;
      _message = 'กำลังเตรียมบัญชี Demo ใหม่...';
    });

    try {
      ReJoyApiClient.clearCache();
      final result = await _client.registerWithEmail(
        email: email,
        password: password,
        firstName: 'Demo',
        surname: 'ReJoy',
        age: 16,
      );

      await AuthSession.save(
        token: result.token,
        refreshToken: result.refreshToken,
        userId: result.user.id,
        email: result.user.email.isEmpty ? email : result.user.email,
      );

      await _client.updateUserProfile(
        userId: result.user.id,
        firstName: 'Demo',
        surname: 'ReJoy',
        age: 16,
        allergies: const ['ข้อมูลจำลอง: ไม่มีข้อมูลแพ้ยาที่ระบุ'],
        emergencyContactNumbers: const ['ข้อมูลจำลอง: 08X-XXX-XXXX'],
        currentMedications: const [
          'ข้อมูลจำลอง: อยู่ระหว่างติดตามโดยผู้เชี่ยวชาญ',
        ],
        medicalHistory:
            'ข้อมูลจำลองสำหรับสาธิต: ผู้ใช้ภาวะซึมเศร้าระดับรุนแรง ใช้โชว์ workflow รายงานแพทย์เท่านั้น',
        onboardingComplete: true,
      );
      await _client.appendPhq9Log(userId: result.user.id, totalScore: 23);
      await _client.appendMoodLog(userId: result.user.id, moodLevel: 2);
      await _client.appendSymptomMatrixLog(
        userId: result.user.id,
        moodScore: 9,
        somaticScore: 8,
        behavioralScore: 7,
      );
      final today = DateTime.now();
      final demoReports = [
        (daysAgo: 4, phq9: 19, mood: 'หม่นมาก', cbt: '1/5', sos: false),
        (daysAgo: 3, phq9: 21, mood: 'เหนื่อยล้า', cbt: '0/5', sos: false),
        (daysAgo: 2, phq9: 22, mood: 'โดดเดี่ยว', cbt: '1/5', sos: true),
        (daysAgo: 1, phq9: 23, mood: 'หนักมาก', cbt: '0/5', sos: true),
        (daysAgo: 0, phq9: 23, mood: 'ซึมเศร้ารุนแรง', cbt: '1/5', sos: true),
      ];
      for (final report in demoReports) {
        await _client.createReportForUser(
          userId: result.user.id,
          phq9Score: report.phq9,
          symptomMatrix: const {
            'mood_score': 9,
            'somatic_score': 8,
            'behavioral_score': 7,
          },
          dailyMood: 'ข้อมูลจำลอง: ${report.mood}',
          diaryNote:
              'ข้อมูลจำลองสำหรับสาธิต: วันนี้รู้สึกหนัก เหนื่อยง่าย นอนหลับยาก และไม่ค่อยอยากทำกิจกรรม ต้องการให้แพทย์เห็นแนวโน้มโดยไม่ต้องเล่าย้อนหลังทั้งหมด',
          cbtCompletionRate: report.cbt,
          unlockedAnimalToday: report.sos
              ? 'owl-urgent-demo'
              : 'otter-care-demo',
          isRestDay: report.cbt == '0/5',
          isSosTriggered: report.sos,
          date: today.subtract(Duration(days: report.daysAgo)),
        );
      }

      if (!mounted) return;
      widget.onSignedIn();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        final detail = error.toString().contains('TimeoutException')
            ? 'เซิร์ฟเวอร์ฟรีกำลังตื่นอยู่ ลองกด Demo อีกครั้งในอีกไม่กี่วินาทีนะ'
            : error.toString();
        _message = 'ยังเข้า Demo ไม่ได้: $detail';
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
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _loginWithDemo,
                      icon: const Icon(Icons.science_rounded),
                      label: const Text('เข้าสู่ระบบแบบ Demo'),
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
