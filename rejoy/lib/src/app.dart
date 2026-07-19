import 'package:flutter/material.dart';

import 'core/auth_session.dart';
import 'core/privacy_consent.dart';
import 'core/rejoy_session.dart';
import 'core/rejoy_theme.dart';
import 'features/auth/auth_screen.dart';
import 'features/chat/chat_screen.dart';
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

class _ReJoyAuthGateState extends State<ReJoyAuthGate> {
  final ReJoyApiClient _client = ReJoyApiClient();
  final AuditLogService _auditLog = const AuditLogService();
  bool _signedIn = AuthSession.isSignedIn;
  bool? _consentAccepted;
  bool _onboardingFinishedThisSession = false;
  Future<ClinicalProfilePayload>? _profileFuture;

  @override
  void initState() {
    super.initState();
    _loadConsent();
    if (_signedIn) {
      _profileFuture = _client.fetchActiveClinicalProfile(forceRefresh: true);
    }
  }

  @override
  void dispose() {
    _client.dispose();
    super.dispose();
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
          if (!user.onboardingComplete) {
            return ConversationalOnboardingScreen(
              user: user,
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
            onSignedOut: () => setState(() {
              _signedIn = false;
              _onboardingFinishedThisSession = false;
              _profileFuture = null;
            }),
          );
        },
      );
    }

    return ReJoyShell(
      onSignedOut: () => setState(() {
        _signedIn = false;
        _onboardingFinishedThisSession = false;
        _profileFuture = null;
      }),
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
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              const SizedBox(height: 24),
              const Text(
                'Privacy & Safety Consent',
                style: TextStyle(
                  color: Color(0xFF17343C),
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'ReJoy stores sensitive mental-health support data such as mood logs, diary notes, PHQ-9 screening scores, SOS flags, and clinical PDF summaries. This data is used to help you review patterns with a qualified professional.',
                style: TextStyle(color: Color(0xFF31525A), height: 1.45),
              ),
              const SizedBox(height: 14),
              const _ConsentBullet(
                text:
                    'ReJoy is not a diagnosis tool and does not replace doctors, therapists, emergency services, or prescribed treatment.',
              ),
              const _ConsentBullet(
                text:
                    'In a crisis or emergency, contact local emergency services, a trusted person, or a qualified crisis hotline immediately.',
              ),
              const _ConsentBullet(
                text:
                    'Your local app session uses secure storage for login tokens, but exported PDFs and screenshots should be protected by you.',
              ),
              const _ConsentBullet(
                text:
                    'By continuing, you agree that ReJoy may save your entered data for app features and doctor-report export.',
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAccepted,
                icon: const Icon(Icons.verified_user_rounded),
                label: const Text('I understand and agree'),
              ),
            ],
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
  const ReJoyShell({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<ReJoyShell> createState() => _ReJoyShellState();
}

class _ReJoyShellState extends State<ReJoyShell> {
  final ReJoySession session = ReJoySession.seed();
  final AuditLogService _auditLog = const AuditLogService();
  final Map<int, Widget> _pageCache = {};
  int selectedIndex = 0;

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
      if (pageIndex != null) selectedIndex = pageIndex;
      session.addJournal(message, highlight: true);
    });
  }

  Widget _pageForIndex(int index) {
    return _pageCache.putIfAbsent(index, () {
      switch (index) {
        case 0:
          return IslandScreen(
            session: session,
            onMoodSelected: _setMood,
            onCrisisSelected: _setCrisis,
            onChatSelected: () => setState(() => selectedIndex = 1),
            onSosSelected: () {
              _setCrisis(CrisisLevel.urgent);
              setState(() => selectedIndex = 4);
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
          return MissionsScreen(session: session, onEnergySelected: _setEnergy);
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
      body: _pageForIndex(selectedIndex),
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
            setState(() => selectedIndex = _pageIndexFromVisibleNav(value)),
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
