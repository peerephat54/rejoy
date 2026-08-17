import 'package:flutter/material.dart';

import 'core/auth_session.dart';
import 'core/privacy_consent.dart';
import 'core/privacy_policy_screen.dart';
import 'core/rejoy_session.dart';
import 'core/rejoy_theme.dart';
import 'features/auth/auth_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/doctor/doctor_dashboard_screen.dart';
import 'features/home/island_screen.dart';
import 'features/missions/missions_screen.dart';
import 'features/onboarding/conversational_onboarding_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/sos/sos_screen.dart';
import 'services/audit_log_service.dart';
import 'services/rejoy_api_client.dart';
import 'services/safety_guard_service.dart';
import 'widgets/rejoy_loading.dart';

class ReJoyApp extends StatelessWidget {
  const ReJoyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ReJoy',
      theme: ReJoyTheme.theme,
      home: const ReJoyAuthGate(),
    );
  }
}

class ReJoyAuthGate extends StatefulWidget {
  const ReJoyAuthGate({super.key});

  @override
  State<ReJoyAuthGate> createState() => _ReJoyAuthGateState();
}

class _ReJoyAuthGateState extends State<ReJoyAuthGate>
    with WidgetsBindingObserver {
  final ReJoyApiClient _client = ReJoyApiClient();
  final AuditLogService _auditLog = const AuditLogService();
  bool _signedIn = AuthSession.isSignedIn;
  bool? _consentAccepted;
  bool _onboardingFinishedThisSession = false;
  bool _roleSelectedThisSession = false;
  bool _openSosAfterOnboarding = false;
  Future<ClinicalProfilePayload>? _profileFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadConsent();
    if (_signedIn) {
      _profileFuture = _client.fetchActiveClinicalProfile(forceRefresh: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _client.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _enforceSessionTimeout();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      AuthSession.touch();
    }
  }

  Future<void> _enforceSessionTimeout() async {
    if (!AuthSession.isSignedIn) return;
    if (!await AuthSession.isExpired()) {
      await AuthSession.touch();
      return;
    }
    await AuthSession.clear();
    ReJoyApiClient.clearCache();
    if (!mounted) return;
    setState(() {
      _signedIn = false;
      _onboardingFinishedThisSession = false;
      _roleSelectedThisSession = false;
      _openSosAfterOnboarding = false;
      _profileFuture = null;
    });
  }

  void _handleSignedOut() {
    setState(() {
      _signedIn = false;
      _onboardingFinishedThisSession = false;
      _roleSelectedThisSession = false;
      _openSosAfterOnboarding = false;
      _profileFuture = null;
    });
  }

  Future<void> _selectRole(BackendUser user, String role) async {
    if (role == 'patient') {
      setState(() => _roleSelectedThisSession = true);
      return;
    }

    await _client.updateUserProfile(
      userId: user.id,
      firstName: user.firstName,
      surname: user.surname,
      age: user.age,
      allergies: user.allergies,
      emergencyContactNumbers: user.emergencyContactNumbers,
      currentMedications: user.currentMedications,
      medicalHistory: user.medicalHistory,
      onboardingComplete: true,
      role: 'doctor',
    );
    if (!mounted) return;
    setState(() {
      _roleSelectedThisSession = true;
      _profileFuture = _client.fetchActiveClinicalProfile(forceRefresh: true);
    });
  }

  Future<void> _loadConsent() async {
    final accepted = await PrivacyConsent.isAccepted();
    if (!mounted) return;
    setState(() => _consentAccepted = accepted);
  }

  @override
  Widget build(BuildContext context) {
    if (!_signedIn) {
      return AuthScreen(
        onSignedIn: () async {
          final accepted = await PrivacyConsent.isAccepted();
          if (!mounted) return;
          setState(() {
            _signedIn = true;
            _consentAccepted = accepted;
            _onboardingFinishedThisSession = false;
            _roleSelectedThisSession = false;
            _openSosAfterOnboarding = false;
            _profileFuture = _client.fetchActiveClinicalProfile(
              forceRefresh: true,
            );
          });
        },
      );
    }

    if (_consentAccepted == null) {
      return const ReJoyLoadingScreen(
        title: 'ยินดีต้อนรับสู่ ReJoy',
        message: 'กำลังเตรียมระบบความปลอดภัย...',
        progress: 0.62,
      );
    }

    if (!_consentAccepted!) {
      return _PrivacyConsentScreen(
        onAccepted: () async {
          await PrivacyConsent.accept();
          await _auditLog.record(type: 'CONSENT_ACCEPTED');
          if (!mounted) return;
          setState(() => _consentAccepted = true);
        },
      );
    }

    _profileFuture ??= _client.fetchActiveClinicalProfile(forceRefresh: true);

    if (!_onboardingFinishedThisSession) {
      return FutureBuilder<ClinicalProfilePayload>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const ReJoyLoadingScreen(
              title: 'กำลังเตรียมเกาะของเธอ',
              message: 'ReJoy กำลังเช็กข้อมูลเริ่มต้นนิดนึงนะ',
              progress: 0.8,
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return _ProfileLoadErrorScreen(
              message: snapshot.error?.toString() ?? 'โหลดข้อมูลไม่สำเร็จ',
              onRetry: () {
                setState(() {
                  _profileFuture = _client.fetchActiveClinicalProfile(
                    forceRefresh: true,
                  );
                });
              },
            );
          }

          final user = snapshot.data!.user;
          if (user.isClinician) {
            return DoctorDashboardScreen(onSignedOut: _handleSignedOut);
          }

          if (!user.onboardingComplete && !_roleSelectedThisSession) {
            return _RoleSelectionScreen(
              user: user,
              onRoleSelected: (role) => _selectRole(user, role),
            );
          }

          if (!user.onboardingComplete) {
            return ConversationalOnboardingScreen(
              user: user,
              onSafetyEscalation: (level) {
                if (level == ClinicalRiskLevel.red) {
                  _openSosAfterOnboarding = true;
                }
              },
              onFinished: () {
                setState(() {
                  _onboardingFinishedThisSession = true;
                  _profileFuture = _client.fetchActiveClinicalProfile(
                    forceRefresh: true,
                  );
                });
              },
            );
          }

          return ReJoyShell(
            initialIndex: _openSosAfterOnboarding ? 4 : 0,
            onSignedOut: _handleSignedOut,
          );
        },
      );
    }

    return ReJoyShell(
      initialIndex: _openSosAfterOnboarding ? 4 : 0,
      onSignedOut: _handleSignedOut,
    );
  }
}

class _RoleSelectionScreen extends StatefulWidget {
  const _RoleSelectionScreen({
    required this.user,
    required this.onRoleSelected,
  });

  final BackendUser user;
  final Future<void> Function(String role) onRoleSelected;

  @override
  State<_RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<_RoleSelectionScreen> {
  bool _saving = false;
  String? _error;

  Future<void> _choose(String role) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onRoleSelected(role);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.toString();
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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.84),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: const Color(0xFFCDE2DE)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF31525A).withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Choose Your ReJoy Role',
                      style: TextStyle(
                        color: Color(0xFF17343C),
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.user.email,
                      style: const TextStyle(color: Color(0xFF607A81)),
                    ),
                    const SizedBox(height: 18),
                    _RoleCard(
                      icon: Icons.favorite_rounded,
                      title: 'Patient',
                      subtitle:
                          'Use ReJoy as a gentle companion, answer onboarding questions, do Micro-CBT quests, and export a doctor report.',
                      enabled: !_saving,
                      onTap: () => _choose('patient'),
                    ),
                    const SizedBox(height: 12),
                    _RoleCard(
                      icon: Icons.health_and_safety_rounded,
                      title: 'Doctor / Care Team',
                      subtitle:
                          'Open a clinical dashboard for assigned patients, alert queues, and supportive care-plan follow-up without raw diary text.',
                      enabled: !_saving,
                      onTap: () => _choose('doctor'),
                    ),
                    if (_saving) ...[
                      const SizedBox(height: 16),
                      const LinearProgressIndicator(),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: Color(0xFFB6534B),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF4F1),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFCDE2DE)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF72B8AD),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF17343C),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF607A81),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF607A81)),
          ],
        ),
      ),
    );
  }
}

class _ProfileLoadErrorScreen extends StatelessWidget {
  const _ProfileLoadErrorScreen({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

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
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.86),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    color: Color(0xFFB6534B),
                    size: 38,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'ยังโหลดข้อมูลเริ่มต้นไม่ได้',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF17343C),
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF607A81),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('ลองใหม่'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivacyConsentScreen extends StatelessWidget {
  const _PrivacyConsentScreen({required this.onAccepted});

  final Future<void> Function() onAccepted;

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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: const Color(0xFFD7ECE7),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF31525A).withValues(alpha: 0.10),
                        blurRadius: 32,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.verified_user_rounded,
                        color: Color(0xFF5F9B91),
                        size: 44,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'ข้อตกลงความเป็นส่วนตัวและความปลอดภัย',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF17343C),
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'ReJoy จะเก็บข้อมูลสนับสนุนสุขภาพใจ เช่น บันทึกอารมณ์ ความในใจ คะแนนคัดกรอง PHQ-9 การกด SOS และสรุปรายงาน PDF เพื่อช่วยให้คุณและผู้เชี่ยวชาญมองเห็นแนวโน้มได้ชัดขึ้น',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF31525A),
                          height: 1.55,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const _ConsentBullet(
                        text:
                            'ReJoy ไม่วินิจฉัยโรค ไม่สั่งหรือปรับยา และไม่ทดแทนแพทย์ นักจิตวิทยา บริการฉุกเฉิน หรือการรักษาที่แพทย์สั่ง',
                      ),
                      const _ConsentBullet(
                        text:
                            'หากอยู่ในภาวะวิกฤตหรือฉุกเฉิน ควรติดต่อคนที่ไว้ใจ สายด่วนสุขภาพจิต 1323 หรือบริการฉุกเฉินในพื้นที่ทันที',
                      ),
                      const _ConsentBullet(
                        text:
                            'แอปใช้พื้นที่จัดเก็บที่ปลอดภัยสำหรับ token เข้าสู่ระบบ แต่ไฟล์ PDF และภาพหน้าจอที่ส่งออกควรเก็บรักษาอย่างระมัดระวัง',
                      ),
                      const _ConsentBullet(
                        text:
                            'เมื่อกดยอมรับ คุณอนุญาตให้ ReJoy บันทึกข้อมูลที่กรอก เพื่อใช้กับฟีเจอร์ในแอปและการสร้างรายงานให้แพทย์',
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const PrivacyPolicyScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.privacy_tip_outlined),
                        label: const Text('อ่านนโยบายความเป็นส่วนตัวฉบับเต็ม'),
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: onAccepted,
                        icon: const Icon(Icons.check_circle_rounded),
                        label: const Text('เข้าใจและยอมรับ'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConsentBullet extends StatelessWidget {
  const _ConsentBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF5F9B91)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFF31525A), height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class ReJoyShell extends StatefulWidget {
  const ReJoyShell({
    super.key,
    required this.onSignedOut,
    this.initialIndex = 0,
  });

  final VoidCallback onSignedOut;
  final int initialIndex;

  @override
  State<ReJoyShell> createState() => _ReJoyShellState();
}

class _ReJoyShellState extends State<ReJoyShell> {
  final ReJoySession session = ReJoySession.seed();
  final AuditLogService _auditLog = const AuditLogService();
  final Map<int, Widget> _pageCache = {};
  int _islandRefreshKey = 0;
  late int selectedIndex;

  @override
  void initState() {
    super.initState();
    selectedIndex = widget.initialIndex;
    if (selectedIndex == 4) {
      session.crisis = CrisisLevel.urgent;
      session.mood = MoodState.crisis;
      session.energy = EnergyLevel.low;
    }
  }

  void _setMood(MoodState mood) {
    setState(() {
      session.mood = mood;
      session.addJournal('Mood updated to ${mood.label}.', highlight: true);
    });
  }

  void _setEnergy(EnergyLevel energy) {
    setState(() {
      session.energy = energy;
      session.addJournal('Energy updated to ${energy.label}.', highlight: true);
    });
  }

  void _setCrisis(CrisisLevel crisis) {
    setState(() {
      session.crisis = crisis;
      session.addJournal(
        crisis == CrisisLevel.safe
            ? 'Crisis flag cleared.'
            : 'Crisis support raised to ${crisis.label}.',
        highlight: true,
      );
    });
  }

  void _handleSafetyEscalation(ClinicalRiskLevel level) {
    setState(() {
      switch (level) {
        case ClinicalRiskLevel.green:
          session.crisis = CrisisLevel.safe;
        case ClinicalRiskLevel.yellow:
          session.crisis = CrisisLevel.watch;
        case ClinicalRiskLevel.orange:
          session.crisis = CrisisLevel.watch;
          session.energy = EnergyLevel.low;
        case ClinicalRiskLevel.red:
          session.crisis = CrisisLevel.urgent;
          session.mood = MoodState.crisis;
          selectedIndex = 4;
      }
      session.addJournal(
        'Clinical escalation: ${level.name}',
        highlight: level == ClinicalRiskLevel.red,
      );
    });
  }

  void _selectPage(int index) {
    if (selectedIndex == index && index != 0) return;
    setState(() {
      if (index == 0) {
        _islandRefreshKey++;
        _pageCache.remove(0);
      }
      selectedIndex = index;
    });
  }

  Future<void> _openDemoSandbox() async {
    await _auditLog.record(type: 'DEMO_SANDBOX_OPENED', detail: 'profile_fab');
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFFFFFBF2),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Demo Sandbox',
                  style: TextStyle(
                    color: Color(0xFF17343C),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'โหมดนี้ใช้เดโมให้กรรมการเห็นระบบหลักทันที: สภาพอากาศตาม PHQ-9, สัตว์จากเควส, Red-Flag ไป SOS, และ Offline Haversine',
                  style: TextStyle(color: Color(0xFF607A81), height: 1.35),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _DemoButton(
                      label: 'PHQ-9 ต่ำ: เกาะสดใส',
                      icon: Icons.wb_sunny_rounded,
                      onPressed: () => _applyDemo(
                        mood: MoodState.calm,
                        energy: EnergyLevel.high,
                        crisis: CrisisLevel.safe,
                        pageIndex: 0,
                        message: 'Demo: low PHQ-9 weather',
                      ),
                    ),
                    _DemoButton(
                      label: 'PHQ-9 สูง: พายุเข้า',
                      icon: Icons.thunderstorm_rounded,
                      onPressed: () => _applyDemo(
                        mood: MoodState.crisis,
                        energy: EnergyLevel.low,
                        crisis: CrisisLevel.watch,
                        pageIndex: 0,
                        message: 'Demo: high PHQ-9 weather',
                      ),
                    ),
                    _DemoButton(
                      label: 'ปลดล็อกสัตว์จากเควส',
                      icon: Icons.pets_rounded,
                      onPressed: () => _applyDemo(
                        missionsDone: session.missionsDone + 3,
                        pageIndex: 0,
                        message: 'Demo: animal reward unlocked',
                      ),
                    ),
                    _DemoButton(
                      label: 'Red-Flag ไป SOS',
                      icon: Icons.sos_rounded,
                      onPressed: () => _applyDemo(
                        mood: MoodState.crisis,
                        energy: EnergyLevel.low,
                        crisis: CrisisLevel.urgent,
                        pageIndex: 4,
                        message: 'Demo: red flag to SOS',
                      ),
                    ),
                    _DemoButton(
                      label: 'เปิดหน้าเควส 10 ใบ',
                      icon: Icons.style_rounded,
                      onPressed: () => _applyDemo(
                        energy: EnergyLevel.low,
                        pageIndex: 2,
                        message: 'Demo: micro-CBT quest deck',
                      ),
                    ),
                    _DemoButton(
                      label: 'ทดสอบ Offline Haversine',
                      icon: Icons.near_me_rounded,
                      onPressed: () => _applyDemo(
                        crisis: CrisisLevel.urgent,
                        pageIndex: 4,
                        message: 'Demo: offline Haversine SOS route',
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

  void _applyDemo({
    MoodState? mood,
    EnergyLevel? energy,
    CrisisLevel? crisis,
    int? missionsDone,
    int? pageIndex,
    required String message,
  }) {
    Navigator.pop(context);
    _auditLog.record(type: 'DEMO_SCENARIO_APPLIED', detail: message);
    setState(() {
      if (mood != null) session.mood = mood;
      if (energy != null) session.energy = energy;
      if (crisis != null) session.crisis = crisis;
      if (missionsDone != null) session.missionsDone = missionsDone;
      if (pageIndex != null) {
        if (pageIndex == 0) {
          _islandRefreshKey++;
          _pageCache.remove(0);
        }
        selectedIndex = pageIndex;
      }
      session.addJournal(message, highlight: true);
    });
  }

  Widget _pageForIndex(int index) {
    return _pageCache.putIfAbsent(index, () {
      switch (index) {
        case 0:
          return IslandScreen(
            key: ValueKey('island-$_islandRefreshKey'),
            session: session,
            onMoodSelected: _setMood,
            onCrisisSelected: _setCrisis,
            onChatSelected: () => _selectPage(1),
            onSosSelected: () {
              _setCrisis(CrisisLevel.urgent);
              _selectPage(4);
            },
          );
        case 1:
          return ChatScreen(
            session: session,
            onMoodSelected: _setMood,
            onEnergySelected: _setEnergy,
            onSafetyEscalation: _handleSafetyEscalation,
          );
        case 2:
          return MissionsScreen(
            session: session,
            onEnergySelected: _setEnergy,
            onGoToIsland: () => _selectPage(0),
          );
        case 3:
          return ProfileScreen(
            session: session,
            onSignedOut: widget.onSignedOut,
          );
        case 4:
          return SosScreen(session: session, onCrisisSelected: _setCrisis);
        default:
          return const SizedBox.shrink();
      }
    });
  }

  Widget _buildPageStack() {
    return Stack(
      fit: StackFit.expand,
      children: List.generate(5, (index) {
        final isActive = selectedIndex == index;
        return Positioned.fill(
          child: IgnorePointer(
            ignoring: !isActive,
            child: TickerMode(
              enabled: isActive,
              child: AnimatedOpacity(
                opacity: isActive ? 1 : 0,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeInOutCubic,
                child: Offstage(
                  offstage: !isActive,
                  child: RepaintBoundary(child: _pageForIndex(index)),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  int _visibleNavIndex() {
    return switch (selectedIndex) {
      0 => 0,
      2 => 1,
      3 => 2,
      _ => 0,
    };
  }

  int _pageIndexFromVisibleNav(int value) {
    return switch (value) {
      0 => 0,
      1 => 2,
      2 => 3,
      _ => 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildPageStack(),
      floatingActionButton: selectedIndex == 3
          ? FloatingActionButton.extended(
              onPressed: _openDemoSandbox,
              icon: const Icon(Icons.science_rounded),
              label: const Text('Demo'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _visibleNavIndex(),
        onDestinationSelected: (value) =>
            _selectPage(_pageIndexFromVisibleNav(value)),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.public), label: 'Island'),
          NavigationDestination(icon: Icon(Icons.checklist), label: 'Missions'),
          NavigationDestination(icon: Icon(Icons.person), label: 'บันทึก'),
        ],
      ),
    );
  }
}

class _DemoButton extends StatelessWidget {
  const _DemoButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
