import 'package:flutter/material.dart';

import '../../services/rejoy_api_client.dart';
import '../../services/safety_guard_service.dart';

class ConversationalOnboardingScreen extends StatefulWidget {
  const ConversationalOnboardingScreen({
    super.key,
    required this.user,
    required this.onFinished,
    this.onSafetyEscalation,
  });

  final BackendUser user;
  final VoidCallback onFinished;
  final ValueChanged<ClinicalRiskLevel>? onSafetyEscalation;

  @override
  State<ConversationalOnboardingScreen> createState() =>
      _ConversationalOnboardingScreenState();
}

enum _OnboardingPhase { profile, baseline, result }

enum _SymptomGroup { mood, somatic, behavioral }

class _ConversationalOnboardingScreenState
    extends State<ConversationalOnboardingScreen> {
  final _client = ReJoyApiClient();
  final _answerController = TextEditingController();
  final _safetyGuard = const SafetyGuardService();

  late final List<_ProfileStep> _profileSteps;
  late final List<_BaselinePrompt> _baselinePrompts;

  final List<_ChatBubbleData> _messages = [];
  final List<int> _baselineScores = [];

  _OnboardingPhase _phase = _OnboardingPhase.profile;
  int _profileIndex = 0;
  int _baselineIndex = -1;
  bool _saving = false;
  bool _typedRiskTriggered = false;
  String? _errorMessage;

  String _firstName = '';
  int _age = 0;
  List<String> _medications = [];
  List<String> _allergies = [];
  List<String> _emergencyContacts = [];

  @override
  void initState() {
    super.initState();
    _firstName = widget.user.firstName;
    _age = widget.user.age;
    _medications = widget.user.currentMedications;
    _allergies = widget.user.allergies;
    _emergencyContacts = widget.user.emergencyContactNumbers;
    _profileSteps = _buildProfileSteps();
    _baselinePrompts = _buildBaselinePrompts();
    _pushBot(_profileSteps.first.botText);
    _answerController.text = _profileSteps.first.initialValue;
  }

  @override
  void dispose() {
    _client.dispose();
    _answerController.dispose();
    super.dispose();
  }

  List<_ProfileStep> _buildProfileSteps() {
    return [
      _ProfileStep(
        botText:
            'สวัสดีนะ วันนี้ ReJoy อยากรู้จักเธอแบบเบา ๆ ก่อนเข้าเกาะ เราควรเรียกเธอว่าอะไรดี?',
        hintText: 'พิมพ์ชื่อที่อยากให้เรียก...',
        initialValue: _firstName,
        emptyFallback: widget.user.firstName.isEmpty
            ? 'เพื่อนของ ReJoy'
            : widget.user.firstName,
        onSave: (value) => _firstName = value,
      ),
      _ProfileStep(
        botText:
            'ขอบคุณนะ $_displayName แล้วตอนนี้อายุเท่าไหร่ครับ? ข้อนี้ช่วยให้ ReJoy ปรับการดูแลให้เหมาะขึ้น',
        hintText: 'เช่น 16',
        keyboardType: TextInputType.number,
        initialValue: _age > 0 ? _age.toString() : '',
        emptyFallback: _age > 0 ? _age.toString() : '0',
        onSave: (value) => _age = int.tryParse(value) ?? widget.user.age,
      ),
      _ProfileStep(
        botText:
            'ตอนนี้มียาหรืออาหารเสริมที่กินประจำไหมครับ? ตอบเท่าที่สะดวกได้เลย',
        hintText: 'เช่น fluoxetine, vitamin D หรือพิมพ์ว่า ไม่มี',
        initialValue: _joinList(_medications),
        emptyFallback: 'ไม่มี',
        quickReplies: const ['ไม่มี', 'จำชื่อยาไม่ได้', 'ขอกรอกทีหลัง'],
        onSave: (value) => _medications = _splitList(value),
      ),
      _ProfileStep(
        botText:
            'มีประวัติแพ้ยา แพ้อาหาร หรือแพ้อะไรที่สำคัญไหมครับ? เราจะเก็บไว้ใน Soul Profile เพื่อความปลอดภัย',
        hintText: 'เช่น penicillin, seafood หรือพิมพ์ว่า ไม่มี',
        initialValue: _joinList(_allergies),
        emptyFallback: 'ไม่มี',
        quickReplies: const ['ไม่มี', 'ไม่แน่ใจ', 'ขอกรอกทีหลัง'],
        onSave: (value) => _allergies = _splitList(value),
      ),
      _ProfileStep(
        botText:
            'สุดท้าย ขอเบอร์ติดต่อผู้ปกครองหรือคนที่ไว้ใจได้ เผื่อกรณีฉุกเฉินนะครับ ข้อมูลนี้ใช้เพื่อความปลอดภัยเท่านั้น',
        hintText: 'เช่น 08x-xxx-xxxx, 09x-xxx-xxxx',
        keyboardType: TextInputType.phone,
        initialValue: _joinList(_emergencyContacts),
        emptyFallback: '',
        quickReplies: const ['ขอกรอกทีหลัง'],
        onSave: (value) => _emergencyContacts = _splitList(value),
      ),
    ];
  }

  List<_BaselinePrompt> _buildBaselinePrompts() {
    return const [
      _BaselinePrompt(
        text:
            'ช่วงสองสัปดาห์ที่ผ่านมา มีวันที่เรื่องที่เคยชอบกลับไม่ค่อยน่าสนุกเหมือนเดิมบ้างไหม',
        group: _SymptomGroup.mood,
      ),
      _BaselinePrompt(
        text:
            'มีวันที่ใจหม่น ๆ เหนื่อยล้า หรือรู้สึกหมดหวังกับบางเรื่องบ้างไหม',
        group: _SymptomGroup.mood,
      ),
      _BaselinePrompt(
        text:
            'เรื่องการนอนเป็นยังไงบ้าง หลับยาก ตื่นบ่อย หรือนอนมากกว่าปกติไหม',
        group: _SymptomGroup.somatic,
      ),
      _BaselinePrompt(
        text:
            'เรื่องกินเป็นยังไงบ้าง กินได้น้อยลงหรือกินมากกว่าปกติจนสังเกตได้ไหม',
        group: _SymptomGroup.somatic,
      ),
      _BaselinePrompt(
        text: 'มีวันที่เผลอโทษตัวเอง หรือรู้สึกว่าตัวเองไม่ดีพอบ้างไหม',
        group: _SymptomGroup.mood,
      ),
      _BaselinePrompt(
        text:
            'ช่วงนี้เวลาอ่าน ดูคลิป หรือทำอะไรสักอย่าง สมาธิหลุดง่ายกว่าปกติไหม',
        group: _SymptomGroup.behavioral,
      ),
      _BaselinePrompt(
        text:
            'มีใครบอกไหมว่าเธอดูช้าลง เงียบลง หรือในทางกลับกัน กระสับกระส่ายมากขึ้น',
        group: _SymptomGroup.behavioral,
      ),
      _BaselinePrompt(
        text:
            'มีวันที่รู้สึกเหนื่อยจนการเริ่มทำสิ่งเล็ก ๆ ในวันนั้นยากกว่าปกติไหม',
        group: _SymptomGroup.behavioral,
      ),
      _BaselinePrompt(
        text:
            'ข้อนี้สำคัญมากนะ มีช่วงไหนที่รู้สึกไม่อยากอยู่แล้ว หรือมีความคิดทำร้ายตัวเองบ้างไหม',
        group: _SymptomGroup.mood,
        isSafetyQuestion: true,
      ),
    ];
  }

  String get _displayName {
    final trimmed = _firstName.trim();
    return trimmed.isEmpty ? 'เพื่อนคนนี้' : trimmed;
  }

  void _pushBot(String text) {
    _messages.add(_ChatBubbleData(text: text, isBot: true));
  }

  void _pushUser(String text) {
    _messages.add(_ChatBubbleData(text: text, isBot: false));
  }

  Future<void> _submitProfileAnswer({String? quickReply}) async {
    final step = _profileSteps[_profileIndex];
    final raw = quickReply ?? _answerController.text.trim();
    final answer = raw.isEmpty ? step.emptyFallback : raw;
    final displayedAnswer = answer.isEmpty ? 'ขอกรอกทีหลัง' : answer;

    step.onSave(answer);
    setState(() {
      _errorMessage = null;
      _pushUser(displayedAnswer);
    });

    if (_profileIndex == _profileSteps.length - 1) {
      await _startBaselineCheckin();
      return;
    }

    setState(() {
      _profileIndex += 1;
      final nextStep = _profileSteps[_profileIndex];
      _answerController.text = nextStep.initialValue;
      _pushBot(nextStep.botText);
    });
  }

  Future<void> _startBaselineCheckin() async {
    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      await _saveProfile(onboardingComplete: false);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _phase = _OnboardingPhase.baseline;
        _baselineIndex = -1;
        _answerController.clear();
        _pushBot(
          'ต่อไป ReJoy ขอเช็กใจเบา ๆ อีกนิดนะ คำตอบนี้ใช้เพื่อปรับสภาพอากาศบนเกาะและสรุปภาพรวมให้เธอเท่านั้น ไม่ใช่การวินิจฉัยโรค และไม่แทนแพทย์ครับ',
        );
        _pushBot('ถ้าไม่พร้อมตอบตอนนี้ กด “ข้ามก่อน” ได้เลย');
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = 'ยังบันทึกข้อมูลส่วนตัวไม่ได้: $error';
      });
    }
  }

  void _beginBaselineQuestions() {
    setState(() {
      _baselineIndex = 0;
      _pushBot(_baselinePrompts.first.text);
    });
  }

  Future<void> _answerBaseline(int score, String label) async {
    if (_baselineIndex < 0 || _baselineIndex >= _baselinePrompts.length) {
      return;
    }

    final prompt = _baselinePrompts[_baselineIndex];
    _baselineScores.add(score);

    setState(() {
      _errorMessage = null;
      _pushUser(label);
    });

    if (prompt.isSafetyQuestion && score >= 2) {
      await _finishBaseline(isSosTriggered: true);
      widget.onSafetyEscalation?.call(ClinicalRiskLevel.red);
      return;
    }

    if (_baselineIndex == _baselinePrompts.length - 1) {
      await _finishBaseline();
      return;
    }

    setState(() {
      _baselineIndex += 1;
      _pushBot(_baselinePrompts[_baselineIndex].text);
    });
  }

  Future<void> _skipBaseline() async {
    setState(() {
      _saving = true;
      _errorMessage = null;
      _pushUser('ข้ามก่อน');
    });

    try {
      await _saveProfile(onboardingComplete: true);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _phase = _OnboardingPhase.result;
        _pushBot(
          'ได้เลย วันนี้ ReJoy จะตั้งเกาะเป็นโหมดอากาศกลาง ๆ ก่อนนะ ถ้าพร้อมเมื่อไหร่ค่อยมาเช็กใจกับบอทได้เสมอ',
        );
      });
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (mounted) widget.onFinished();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = 'ยังบันทึกการข้ามไม่ได้: $error';
      });
    }
  }

  Future<void> _finishBaseline({bool isSosTriggered = false}) async {
    final total = _baselineScores.fold<int>(0, (sum, value) => sum + value);
    final moodScore = _groupScore(_SymptomGroup.mood);
    final somaticScore = _groupScore(_SymptomGroup.somatic);
    final behavioralScore = _groupScore(_SymptomGroup.behavioral);
    final moodLevel = (10 - (total / 27 * 10)).round().clamp(0, 10);

    setState(() {
      _saving = true;
      _errorMessage = null;
      _phase = _OnboardingPhase.result;
      _pushBot(_resultMessage(total, isSosTriggered: isSosTriggered));
    });

    try {
      await _saveProfile(onboardingComplete: true);
      await _client.appendPhq9Log(userId: widget.user.id, totalScore: total);
      await _client.appendMoodLog(userId: widget.user.id, moodLevel: moodLevel);
      await _client.appendSymptomMatrixLog(
        userId: widget.user.id,
        moodScore: moodScore,
        somaticScore: somaticScore,
        behavioralScore: behavioralScore,
      );
      await _client.createReportForUser(
        userId: widget.user.id,
        phq9Score: total,
        symptomMatrix: {
          'mood_score': moodScore,
          'somatic_score': somaticScore,
          'behavioral_score': behavioralScore,
        },
        dailyMood: _dailyMoodLabel(total),
        diaryNote: 'Baseline emotional check-in after first onboarding',
        cbtCompletionRate: 'baseline',
        isSosTriggered: isSosTriggered,
        periodDays: 14,
        date: DateTime.now(),
      );

      if (!mounted) return;
      setState(() => _saving = false);
      await Future<void>.delayed(const Duration(milliseconds: 850));
      if (mounted) widget.onFinished();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage =
            'บันทึกเช็กใจยังไม่สำเร็จ แต่คำตอบยังอยู่บนหน้านี้นะ: $error';
      });
    }
  }

  Future<void> _saveProfile({required bool onboardingComplete}) {
    return _client.updateUserProfile(
      userId: widget.user.id,
      firstName: _firstName.trim().isEmpty
          ? widget.user.firstName
          : _firstName.trim(),
      surname: widget.user.surname,
      age: _age,
      allergies: _allergies,
      emergencyContactNumbers: _emergencyContacts,
      currentMedications: _medications,
      medicalHistory: widget.user.medicalHistory,
      onboardingComplete: onboardingComplete,
    );
  }

  int _groupScore(_SymptomGroup group) {
    var total = 0;
    for (
      var i = 0;
      i < _baselineScores.length && i < _baselinePrompts.length;
      i++
    ) {
      if (_baselinePrompts[i].group == group) total += _baselineScores[i];
    }
    return total;
  }

  String _dailyMoodLabel(int total) {
    if (total >= 20) return 'วิกฤต';
    if (total >= 15) return 'หนักมาก';
    if (total >= 10) return 'เหนื่อย';
    if (total >= 5) return 'มีเมฆบางส่วน';
    return 'สงบ';
  }

  String _resultMessage(int total, {required bool isSosTriggered}) {
    if (isSosTriggered) {
      return 'ขอบคุณที่ไว้ใจเล่านะ ข้อนี้สำคัญมาก ReJoy จะพาเธอไปหน้า SOS ที่มีขั้นตอนตั้งหลักและเบอร์ช่วยเหลือทันที เธอไม่ต้องอยู่กับเรื่องนี้คนเดียวนะ';
    }
    if (total >= 15) {
      return 'ขอบคุณที่ตอบจนครบนะ วันนี้เกาะอาจมีเมฆเยอะหน่อย เพราะระบบเห็นว่าใจเธอใช้แรงมากกว่าปกติ เราจะเริ่มจากเควสเล็ก ๆ ที่ไม่กดดันก่อน';
    }
    if (total >= 10) {
      return 'ขอบคุณนะ วันนี้เกาะจะเป็นอากาศครึ้มเบา ๆ เพื่อสะท้อนว่าวันนี้อาจต้องอ่อนโยนกับตัวเองมากขึ้น';
    }
    if (total >= 5) {
      return 'เรียบร้อยครับ วันนี้เกาะจะมีเมฆบาง ๆ แต่ยังมีแสงอุ่นอยู่ ReJoy จะช่วยเลือกเควสที่พอดีกับแรงใจวันนี้';
    }
    return 'เรียบร้อยครับ วันนี้เกาะจะสดใสและสงบ เหมาะกับการเริ่มวันแบบค่อยเป็นค่อยไป';
  }

  Future<void> _handleTypedBaselineText(String value) async {
    final result = _safetyGuard.screen(value);
    if (_typedRiskTriggered || result.level != ClinicalRiskLevel.red) {
      return;
    }

    _typedRiskTriggered = true;
    setState(() {
      _pushUser(value.trim().isEmpty ? 'ขอความช่วยเหลือ' : value.trim());
    });
    await _finishBaseline(isSosTriggered: true);
    widget.onSafetyEscalation?.call(ClinicalRiskLevel.red);
  }

  static String _joinList(List<String> values) => values.join(', ');

  static List<String> _splitList(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return [];
    if (['ไม่มี', 'none', 'no'].contains(normalized.toLowerCase())) {
      return [];
    }
    return normalized
        .split(RegExp(r'[,،\n]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final profileProgress = (_profileIndex + 1) / _profileSteps.length;
    final baselineProgress = _baselineIndex < 0
        ? 0.0
        : (_baselineIndex + 1) / _baselinePrompts.length;
    final progress = _phase == _OnboardingPhase.profile
        ? profileProgress
        : baselineProgress;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE7FAF9), Color(0xFFE1F4DA), Color(0xFFF5F0CF)],
            stops: [0.0, 0.58, 1.0],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              const Positioned(
                left: -18,
                bottom: 146,
                child: _SoftCloud(width: 112, height: 58),
              ),
              const Positioned(
                right: -14,
                bottom: 230,
                child: _SoftCloud(width: 88, height: 52),
              ),
              Column(
                children: [
                  _Header(
                    saving: _saving,
                    title: _phase == _OnboardingPhase.profile
                        ? 'ReJoy Buddy'
                        : 'เช็กใจเบา ๆ',
                    onBack: widget.onFinished,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 14, 22, 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 7,
                        value: progress == 0 ? null : progress,
                        backgroundColor: Colors.white.withValues(alpha: 0.50),
                        color: const Color(0xFF95D4C6),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) =>
                          _ChatBubble(data: _messages[index]),
                    ),
                  ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFB6534B),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  _InputArea(
                    phase: _phase,
                    saving: _saving,
                    profileStep: _phase == _OnboardingPhase.profile
                        ? _profileSteps[_profileIndex]
                        : null,
                    baselineStarted: _baselineIndex >= 0,
                    answerController: _answerController,
                    onProfileSubmit: _submitProfileAnswer,
                    onBeginBaseline: _beginBaselineQuestions,
                    onSkipBaseline: _skipBaseline,
                    onBaselineAnswer: _answerBaseline,
                    onTypedRiskDetected: _handleTypedBaselineText,
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

class _InputArea extends StatelessWidget {
  const _InputArea({
    required this.phase,
    required this.saving,
    required this.profileStep,
    required this.baselineStarted,
    required this.answerController,
    required this.onProfileSubmit,
    required this.onBeginBaseline,
    required this.onSkipBaseline,
    required this.onBaselineAnswer,
    required this.onTypedRiskDetected,
  });

  final _OnboardingPhase phase;
  final bool saving;
  final _ProfileStep? profileStep;
  final bool baselineStarted;
  final TextEditingController answerController;
  final Future<void> Function({String? quickReply}) onProfileSubmit;
  final VoidCallback onBeginBaseline;
  final Future<void> Function() onSkipBaseline;
  final Future<void> Function(int score, String label) onBaselineAnswer;
  final Future<void> Function(String text) onTypedRiskDetected;

  @override
  Widget build(BuildContext context) {
    if (phase == _OnboardingPhase.result) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
        child: _SavingPill(saving: saving),
      );
    }

    if (phase == _OnboardingPhase.baseline) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.76),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFCBE9DF)),
          ),
          child: baselineStarted
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        _ScoreButton(
                          score: 0,
                          label: 'แทบไม่มีเลย',
                          saving: saving,
                          onAnswer: onBaselineAnswer,
                        ),
                        _ScoreButton(
                          score: 1,
                          label: 'เป็นบางวัน',
                          saving: saving,
                          onAnswer: onBaselineAnswer,
                        ),
                        _ScoreButton(
                          score: 2,
                          label: 'บ่อยหลายวัน',
                          saving: saving,
                          onAnswer: onBaselineAnswer,
                        ),
                        _ScoreButton(
                          score: 3,
                          label: 'แทบทุกวัน',
                          saving: saving,
                          onAnswer: onBaselineAnswer,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      enabled: !saving,
                      onChanged: (value) => onTypedRiskDetected(value),
                      decoration: InputDecoration(
                        hintText: 'ถ้าอยากพิมพ์เพิ่ม พิมพ์ไว้ตรงนี้ได้...',
                        filled: true,
                        fillColor: const Color(0xFFF9FFFB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: saving ? null : onBeginBaseline,
                        child: const Text('เริ่มเช็กใจ'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: saving ? null : onSkipBaseline,
                      child: const Text('ข้ามก่อน'),
                    ),
                  ],
                ),
        ),
      );
    }

    final step = profileStep!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFCBE9DF)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7CAFA3).withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (step.quickReplies.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final reply in step.quickReplies)
                      ActionChip(
                        label: Text(reply),
                        onPressed: saving
                            ? null
                            : () => onProfileSubmit(quickReply: reply),
                      ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: answerController,
                    enabled: !saving,
                    keyboardType: step.keyboardType,
                    onSubmitted: (_) => saving ? null : onProfileSubmit(),
                    decoration: InputDecoration(
                      hintText: step.hintText,
                      filled: true,
                      fillColor: const Color(0xFFF9FFFB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF9EB9FF),
                  child: IconButton(
                    onPressed: saving ? null : () => onProfileSubmit(),
                    icon: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white),
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

class _ScoreButton extends StatelessWidget {
  const _ScoreButton({
    required this.score,
    required this.label,
    required this.saving,
    required this.onAnswer,
  });

  final int score;
  final String label;
  final bool saving;
  final Future<void> Function(int score, String label) onAnswer;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: saving ? null : () => onAnswer(score, label),
      child: Text(label),
    );
  }
}

class _SavingPill extends StatelessWidget {
  const _SavingPill({required this.saving});

  final bool saving;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (saving)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(Icons.check_circle_rounded, color: Color(0xFF5F9B91)),
            const SizedBox(width: 8),
            Text(saving ? 'กำลังบันทึกให้เกาะ...' : 'บันทึกเรียบร้อย'),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.saving,
    required this.title,
    required this.onBack,
  });

  final bool saving;
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.30),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.34)),
        ),
      ),
      child: Row(
        children: [
          _RoundIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onPressed: saving ? null : onBack,
          ),
          const Spacer(),
          const _BuddyMark(),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF142C2B),
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 38),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.data});

  final _ChatBubbleData data;

  @override
  Widget build(BuildContext context) {
    final isBot = data.isBot;
    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 310),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: isBot
              ? Colors.white.withValues(alpha: 0.78)
              : const Color(0xFFA8DEC9),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(22),
            topRight: const Radius.circular(22),
            bottomLeft: Radius.circular(isBot ? 4 : 22),
            bottomRight: Radius.circular(isBot ? 22 : 4),
          ),
          border: Border.all(
            color: isBot ? const Color(0xFFD8EAE4) : const Color(0xFF91CAB4),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6A968C).withValues(alpha: 0.10),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Text(
          data.text,
          style: const TextStyle(
            color: Color(0xFF193C42),
            fontSize: 14.2,
            height: 1.35,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.56),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFC6E5DE)),
        ),
        child: Icon(icon, color: const Color(0xFF18343C), size: 18),
      ),
    );
  }
}

class _BuddyMark extends StatelessWidget {
  const _BuddyMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: const BoxDecoration(
        color: Color(0xFF8DD5BE),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 18),
    );
  }
}

class _SoftCloud extends StatelessWidget {
  const _SoftCloud({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFB9CFC1).withValues(alpha: 0.36),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _ProfileStep {
  const _ProfileStep({
    required this.botText,
    required this.hintText,
    required this.initialValue,
    required this.emptyFallback,
    required this.onSave,
    this.keyboardType,
    this.quickReplies = const [],
  });

  final String botText;
  final String hintText;
  final String initialValue;
  final String emptyFallback;
  final ValueChanged<String> onSave;
  final TextInputType? keyboardType;
  final List<String> quickReplies;
}

class _BaselinePrompt {
  const _BaselinePrompt({
    required this.text,
    required this.group,
    this.isSafetyQuestion = false,
  });

  final String text;
  final _SymptomGroup group;
  final bool isSafetyQuestion;
}

class _ChatBubbleData {
  const _ChatBubbleData({required this.text, required this.isBot});

  final String text;
  final bool isBot;
}
