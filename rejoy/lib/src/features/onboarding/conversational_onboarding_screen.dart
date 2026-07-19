import 'package:flutter/material.dart';

import '../../services/rejoy_api_client.dart';

class ConversationalOnboardingScreen extends StatefulWidget {
  const ConversationalOnboardingScreen({
    super.key,
    required this.user,
    required this.onFinished,
  });

  final BackendUser user;
  final VoidCallback onFinished;

  @override
  State<ConversationalOnboardingScreen> createState() =>
      _ConversationalOnboardingScreenState();
}

class _ConversationalOnboardingScreenState
    extends State<ConversationalOnboardingScreen> {
  final _client = ReJoyApiClient();
  final _answerController = TextEditingController();
  final List<_OnboardingMessage> _messages = [];

  late final List<_OnboardingStep> _steps;
  int _stepIndex = 0;
  bool _saving = false;
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
    _steps = [
      _OnboardingStep(
        botText:
            'สวัสดีครับ วันนี้พี่ขอชวนคุยเบาๆ ก่อนเริ่มดูแลเกาะนะครับ อยากให้เราเรียกคุณว่าอะไรดี?',
        hintText: 'พิมพ์ชื่อที่อยากให้เรียก...',
        initialValue: _firstName,
        emptyFallback: widget.user.firstName.isEmpty
            ? 'ReJoy Friend'
            : widget.user.firstName,
        quickReplies: const [],
        onSave: (value) => _firstName = value,
      ),
      _OnboardingStep(
        botText:
            'ขอบคุณนะ $_displayName แล้วตอนนี้อายุเท่าไหร่ครับ? ข้อนี้ช่วยให้ ReJoy ปรับการดูแลให้เหมาะขึ้น',
        hintText: 'เช่น 16',
        keyboardType: TextInputType.number,
        initialValue: _age > 0 ? _age.toString() : '',
        emptyFallback: _age > 0 ? _age.toString() : '0',
        quickReplies: const [],
        onSave: (value) => _age = int.tryParse(value) ?? widget.user.age,
      ),
      _OnboardingStep(
        botText:
            'ตอนนี้มียาหรืออาหารเสริมที่กินเป็นประจำไหมครับ? ตอบเท่าที่สะดวกได้เลย',
        hintText: 'เช่น fluoxetine, vitamin D หรือพิมพ์ว่า ไม่มี',
        initialValue: _joinList(_medications),
        emptyFallback: 'ไม่มี',
        quickReplies: const ['ไม่มี', 'จำชื่อยาไม่ได้', 'ขอกรอกทีหลัง'],
        onSave: (value) => _medications = _splitList(value),
      ),
      _OnboardingStep(
        botText:
            'มีประวัติแพ้ยา แพ้อาหาร หรือแพ้อะไรที่สำคัญไหมครับ? เราจะเก็บไว้ใน Soul Profile ให้ปลอดภัยขึ้น',
        hintText: 'เช่น penicillin, seafood หรือพิมพ์ว่า ไม่มี',
        initialValue: _joinList(_allergies),
        emptyFallback: 'ไม่มี',
        quickReplies: const ['ไม่มี', 'ไม่แน่ใจ', 'ขอกรอกทีหลัง'],
        onSave: (value) => _allergies = _splitList(value),
      ),
      _OnboardingStep(
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
    _pushBot(_steps.first.botText);
    _answerController.text = _steps.first.initialValue;
  }

  @override
  void dispose() {
    _client.dispose();
    _answerController.dispose();
    super.dispose();
  }

  String get _displayName {
    final trimmed = _firstName.trim();
    return trimmed.isEmpty ? 'เพื่อนคนนี้' : trimmed;
  }

  void _pushBot(String text) {
    _messages.add(_OnboardingMessage(text: text, isBot: true));
  }

  void _pushUser(String text) {
    _messages.add(_OnboardingMessage(text: text, isBot: false));
  }

  void _submitCurrentAnswer({String? quickReply}) {
    final step = _steps[_stepIndex];
    final raw = quickReply ?? _answerController.text.trim();
    final answer = raw.isEmpty ? step.emptyFallback : raw;

    step.onSave(answer);
    setState(() {
      _errorMessage = null;
      _pushUser(answer.isEmpty ? 'ขอกรอกทีหลัง' : answer);
    });

    if (_stepIndex == _steps.length - 1) {
      _finishOnboarding();
      return;
    }

    setState(() {
      _stepIndex += 1;
      final nextStep = _steps[_stepIndex];
      _answerController.text = nextStep.initialValue;
      _pushBot(nextStep.botText);
    });
  }

  Future<void> _finishOnboarding() async {
    setState(() => _saving = true);
    try {
      await _client.updateUserProfile(
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
        onboardingComplete: true,
      );

      if (!mounted) return;
      setState(() {
        _saving = false;
        _pushBot(
          'เรียบร้อยแล้วนะครับ ขอบคุณที่เล่าให้ฟัง ข้อมูลนี้จะช่วยให้ ReJoy ดูแลคุณได้อ่อนโยนและปลอดภัยขึ้น',
        );
      });
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (mounted) widget.onFinished();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = 'ยังบันทึกไม่ได้: $error';
      });
    }
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
    final step = _steps[_stepIndex];
    final progress = (_stepIndex + 1) / _steps.length;

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
                left: 22,
                bottom: 202,
                child: _SoftCloud(width: 82, height: 48),
              ),
              const Positioned(
                right: -14,
                bottom: 230,
                child: _SoftCloud(width: 88, height: 52),
              ),
              Column(
                children: [
                  Container(
                    height: 78,
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.30),
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withValues(alpha: 0.34),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        _RoundIconButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onPressed: _saving ? null : widget.onFinished,
                        ),
                        const Spacer(),
                        const _BuddyMark(),
                        const SizedBox(width: 8),
                        const Text(
                          'ReJoy Buddy',
                          style: TextStyle(
                            color: Color(0xFF142C2B),
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: 38,
                          child: Text(
                            '${_stepIndex + 1}/${_steps.length}',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: const Color(
                                0xFF5F7A74,
                              ).withValues(alpha: 0.76),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor: Colors.white.withValues(alpha: 0.34),
                        color: const Color(0xFF7DDE8B),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                      itemCount: _messages.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _messages.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 26, bottom: 80),
                            child: Text(
                              'วันนี้ ${TimeOfDay.now().format(context)} น.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: const Color(
                                  0xFF7D928A,
                                ).withValues(alpha: 0.55),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        }
                        return _ChatBubble(message: _messages[index]);
                      },
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      22,
                      0,
                      22,
                      18 + MediaQuery.viewInsetsOf(context).bottom * 0.08,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (step.quickReplies.isNotEmpty)
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (final reply in step.quickReplies)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ActionChip(
                                      label: Text(reply),
                                      backgroundColor: Colors.white.withValues(
                                        alpha: 0.64,
                                      ),
                                      side: BorderSide(
                                        color: Colors.white.withValues(
                                          alpha: 0.74,
                                        ),
                                      ),
                                      onPressed: _saving
                                          ? null
                                          : () => _submitCurrentAnswer(
                                              quickReply: reply,
                                            ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        if (step.quickReplies.isNotEmpty)
                          const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFE9F3D4,
                            ).withValues(alpha: 0.78),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.42),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF698278,
                                ).withValues(alpha: 0.14),
                                blurRadius: 24,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _answerController,
                                  keyboardType: step.keyboardType,
                                  minLines: 1,
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                    hintText: step.hintText,
                                    border: InputBorder.none,
                                    isDense: true,
                                    hintStyle: const TextStyle(
                                      color: Color(0xFF5E7068),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  onSubmitted: (_) {
                                    if (!_saving) _submitCurrentAnswer();
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              _SendButton(
                                saving: _saving,
                                onPressed: _saving
                                    ? null
                                    : _submitCurrentAnswer,
                              ),
                            ],
                          ),
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Color(0xFFB6534B),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
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

class _OnboardingStep {
  const _OnboardingStep({
    required this.botText,
    required this.hintText,
    required this.initialValue,
    required this.emptyFallback,
    required this.quickReplies,
    required this.onSave,
    this.keyboardType,
  });

  final String botText;
  final String hintText;
  final String initialValue;
  final String emptyFallback;
  final List<String> quickReplies;
  final ValueChanged<String> onSave;
  final TextInputType? keyboardType;
}

class _OnboardingMessage {
  const _OnboardingMessage({required this.text, required this.isBot});

  final String text;
  final bool isBot;
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final _OnboardingMessage message;

  @override
  Widget build(BuildContext context) {
    final isBot = message.isBot;
    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.74,
        ),
        margin: EdgeInsets.only(
          top: 8,
          bottom: 8,
          left: isBot ? 0 : 44,
          right: isBot ? 44 : 0,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: isBot
              ? const Color(0xFF76CFA6)
              : Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isBot ? 6 : 20),
            bottomRight: Radius.circular(isBot ? 20 : 6),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F6B61).withValues(alpha: 0.15),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isBot ? const Color(0xFF12332D) : const Color(0xFF243B3B),
            height: 1.38,
            fontSize: 13,
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
      borderRadius: BorderRadius.circular(99),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.44),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF1D3130), width: 1.3),
        ),
        child: Icon(icon, size: 16, color: const Color(0xFF1D3130)),
      ),
    );
  }
}

class _BuddyMark extends StatelessWidget {
  const _BuddyMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      height: 26,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: Color(0xFF76E673),
              shape: BoxShape.circle,
            ),
          ),
          Positioned(
            top: 1,
            child: Container(
              width: 20,
              height: 8,
              decoration: BoxDecoration(
                color: const Color(0xFF86EF72),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Positioned(
            bottom: 3,
            child: Container(
              width: 25,
              height: 6,
              decoration: BoxDecoration(
                color: const Color(0xFF60D765),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.saving, required this.onPressed});

  final bool saving;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        width: 42,
        height: 42,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFF7D69FF), Color(0xFF485DFF)],
          ),
        ),
        child: saving
            ? const Padding(
                padding: EdgeInsets.all(11),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(
                Icons.navigation_rounded,
                color: Color(0xFF111629),
                size: 22,
              ),
      ),
    );
  }
}

class _SoftCloud extends StatelessWidget {
  const _SoftCloud({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(width, height), painter: _SoftCloudPainter());
  }
}

class _SoftCloudPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFAECAB1).withValues(alpha: 0.46)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromLTWH(
        size.width * 0.06,
        size.height * 0.42,
        size.width * 0.80,
        size.height * 0.45,
      ),
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.30, size.height * 0.45),
      size.height * 0.33,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.56, size.height * 0.38),
      size.height * 0.42,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
