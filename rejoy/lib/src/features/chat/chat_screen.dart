import 'package:flutter/material.dart';
import 'dart:async';

import '../../core/rejoy_session.dart';
import '../../services/audit_log_service.dart';
import '../../services/rejoy_api_client.dart';
import '../../services/safety_guard_service.dart';

class _DailyChatTopic {
  const _DailyChatTopic({
    required this.title,
    required this.opener,
    required this.questionLead,
  });

  final String title;
  final String opener;
  final String questionLead;
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.session,
    required this.onMoodSelected,
    required this.onEnergySelected,
    required this.onSafetyEscalation,
  });

  final ReJoySession session;
  final ValueChanged<MoodState> onMoodSelected;
  final ValueChanged<EnergyLevel> onEnergySelected;
  final ValueChanged<ClinicalRiskLevel> onSafetyEscalation;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ReJoyApiClient _client;
  final SafetyGuardService _safetyGuard = const SafetyGuardService();
  final AuditLogService _auditLog = const AuditLogService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  final List<int> _screeningScores = [];

  BackendUser? _user;
  bool _loading = true;
  bool _sending = false;
  bool _savedToday = false;
  bool _tapMode = false;
  int _questionIndex = 0;

  static const String _hotlineText =
      'ถ้าตอนนี้ไม่ปลอดภัยหรืออยากคุยกับคนจริง ๆ โทรสายด่วน 1300 ได้เลยนะ เขามีคนรับฟังตลอด 24 ชั่วโมง';

  static const List<_ScreeningPrompt> _prompts = [
    _ScreeningPrompt(
      symptomGroup: _SymptomGroup.mood,
      question:
          'ในเรื่องที่เราคุยกันวันนี้ ยังมีอะไรเล็ก ๆ ที่พอทำให้รู้สึกสนใจหรืออยากแตะมันอยู่บ้างไหม',
    ),
    _ScreeningPrompt(
      symptomGroup: _SymptomGroup.mood,
      question:
          'เวลานึกถึงเรื่องนี้ ใจมันออกไปทางหม่น หนัก หรือยังพอมีช่องให้หายใจบ้าง',
    ),
    _ScreeningPrompt(
      symptomGroup: _SymptomGroup.somatic,
      question: 'พอเรื่องนี้วนอยู่ในหัว ตอนกลางคืนมันไปรบกวนการนอนของคุณแค่ไหน',
    ),
    _ScreeningPrompt(
      symptomGroup: _SymptomGroup.somatic,
      question:
          'ช่วงนี้พลังงานในตัวเหลือประมาณไหน เหมือนยังพอไหว หรือเหมือนแบตใกล้หมด',
    ),
    _ScreeningPrompt(
      symptomGroup: _SymptomGroup.somatic,
      question:
          'เรื่องกินช่วงนี้โดนอารมณ์พาไปบ้างไหม เช่น กินไม่ลง หรือกินมากกว่าปกติ',
    ),
    _ScreeningPrompt(
      symptomGroup: _SymptomGroup.mood,
      question:
          'เวลามันหนักขึ้น มีเสียงในหัวที่โทษตัวเองหรือกดตัวเองลงมาบ้างไหม',
    ),
    _ScreeningPrompt(
      symptomGroup: _SymptomGroup.behavioral,
      question:
          'ถ้าต้องอ่าน แชท เรียน หรือดูอะไรสักอย่าง สมาธิยังเกาะอยู่กับมันได้แค่ไหน',
    ),
    _ScreeningPrompt(
      symptomGroup: _SymptomGroup.behavioral,
      question:
          'จังหวะร่างกายช่วงนี้เป็นยังไง ช้าลงมาก ๆ หรือกระสับกระส่ายกว่าปกติไหม',
    ),
    _ScreeningPrompt(
      symptomGroup: _SymptomGroup.mood,
      question:
          'ขอถามแบบเบามาก ๆ นะ มีช่วงไหนที่อยากหายไป ไม่อยากอยู่ หรือคิดทำร้ายตัวเองโผล่มาบ้างไหม',
      isSafetyQuestion: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _client = ReJoyApiClient();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _client.dispose();
    super.dispose();
  }

  _DailyChatTopic get _todayDailyTopic {
    const topics = [
      _DailyChatTopic(
        title: 'อาหารและน้ำวันนี้',
        opener:
            'วันนี้เราชวนคุยเรื่องอาหารกับน้ำแบบเบา ๆ นะ ไม่ต้องตอบให้ดี แค่เล่าว่าวันนี้ร่างกายได้อะไรเข้าไปบ้างก็พอ',
        questionLead: 'ถ้ามองผ่านเรื่องกิน/ดื่มของวันนี้',
      ),
      _DailyChatTopic(
        title: 'การนอนและตอนตื่น',
        opener:
            'วันนี้เราคุยเรื่องการนอนกับจังหวะตอนตื่นกันนะ เล่าได้ทั้งหลับดี หลับยาก หรือตื่นมาแล้วไม่อยากลุก',
        questionLead: 'ถ้ามองผ่านเรื่องการนอนและตอนตื่น',
      ),
      _DailyChatTopic(
        title: 'เรียน งาน หรือสิ่งที่ต้องรับผิดชอบ',
        opener:
            'วันนี้เราคุยเรื่องเรียน งาน หรือสิ่งที่ต้องรับผิดชอบกัน ไม่ต้องเก่ง ไม่ต้องสำเร็จ แค่เล่าว่าวันนี้มันหนักหรือเบายังไง',
        questionLead: 'ถ้ามองผ่านเรื่องเรียน งาน หรือภาระวันนี้',
      ),
      _DailyChatTopic(
        title: 'คนรอบตัวและการคุยกับคน',
        opener:
            'วันนี้เราคุยเรื่องคนรอบตัวกันนะ มีใครทำให้สบายใจ อึดอัด เหนื่อย หรือรู้สึกโดดเดี่ยวบ้างไหม',
        questionLead: 'ถ้ามองผ่านเรื่องคนรอบตัววันนี้',
      ),
      _DailyChatTopic(
        title: 'มือถือ โซเชียล และเวลาหน้าจอ',
        opener:
            'วันนี้เราคุยเรื่องมือถือ โซเชียล หรือเวลาหน้าจอกันนะ มันช่วยให้พัก หรือทำให้ใจหนักขึ้นตรงไหนบ้าง',
        questionLead: 'ถ้ามองผ่านเรื่องมือถือและโซเชียลวันนี้',
      ),
      _DailyChatTopic(
        title: 'มุมห้องและกิจวัตรเล็ก ๆ',
        opener:
            'วันนี้เราคุยเรื่องมุมห้อง ของใช้ หรือกิจวัตรเล็ก ๆ กันนะ เช่น อาบน้ำ เก็บเตียง เปิดหน้าต่าง หรือแค่นั่งนิ่ง ๆ',
        questionLead: 'ถ้ามองผ่านกิจวัตรเล็ก ๆ ของวันนี้',
      ),
      _DailyChatTopic(
        title: 'การพักผ่อนโดยไม่รู้สึกผิด',
        opener:
            'วันนี้เราคุยเรื่องการพักแบบไม่ต้องรู้สึกผิดกันนะ พักจริงไหม พักแล้วยังคิดวนไหม หรือวันนี้แค่ประคองตัวก็พอ',
        questionLead: 'ถ้ามองผ่านเรื่องการพักของวันนี้',
      ),
    ];
    return topics[DateTime.now().weekday - 1];
  }

  String get _todayTopic {
    return _todayDailyTopic.title;
    // ignore: dead_code
    final topics = [
      'พลังใจตอนตื่นนอน',
      'สิ่งที่ค้างอยู่ในใจ',
      'แรงใจในการเจอผู้คน',
      'จังหวะร่างกายวันนี้',
      'สิ่งเล็ก ๆ ที่ยังพอไหว',
      'ความคิดที่วนซ้ำ',
      'การพักโดยไม่รู้สึกผิด',
    ];
    return topics[DateTime.now().weekday - 1];
  }

  Future<void> _load() async {
    try {
      final users = await _client.fetchUsers();
      if (!mounted) return;
      setState(() {
        _user = users.isEmpty ? null : users.first;
        _loading = false;
        _messages.add(_ChatMessage.bot(_openingQuestion()));
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _messages.add(_ChatMessage.bot(_openingQuestion()));
      });
    }
  }

  String _openingQuestion() {
    final opener = _todayDailyTopic.opener.trim();
    final question = _currentQuestion().trim();
    return opener.isEmpty ? question : '$opener\n\n$question';
  }

  String _currentQuestion() => _prompts[_questionIndex].question;

  Future<void> _sendFreeText() async {
    final text = _controller.text.trim();
    await _sendUserText(text, clearInput: true);
  }

  Future<void> _sendQuickReply(String text) async {
    await _sendUserText(text, clearInput: false);
  }

  Future<void> _sendUserText(String text, {required bool clearInput}) async {
    if (text.isEmpty || _sending) return;
    final safety = _safetyGuard.screen(text);

    setState(() {
      _sending = true;
      if (clearInput) _controller.clear();
      _messages.add(_ChatMessage.user(text));
    });
    _scrollToBottom();

    if (safety.shouldBlockAi) {
      await _auditLog.record(
        type: 'RED_FLAG_TRIGGERED',
        riskLevel: safety.level.name,
        detail: safety.reason,
      );
      widget.onSafetyEscalation(safety.level);
      if (!mounted) return;
      setState(() {
        _messages.add(
          const _ChatMessage.bot(
            'เราเป็นห่วงความปลอดภัยของคุณมากนะ ข้อความนี้จะไม่ถูกส่งต่อไปยัง AI ตอนนี้ ReJoy จะพาไปหน้า SOS เพื่อช่วยตั้งหลักและติดต่อความช่วยเหลือทันที',
          ),
        );
        _sending = false;
      });
      _scrollToBottom();
      return;
    }

    if (safety.level == ClinicalRiskLevel.orange ||
        safety.level == ClinicalRiskLevel.yellow) {
      await _auditLog.record(
        type: 'CLINICAL_ESCALATION_${safety.level.name.toUpperCase()}',
        riskLevel: safety.level.name,
        detail: safety.reason,
      );
      widget.onSafetyEscalation(safety.level);
    }

    if (!_savedToday && _questionIndex < _prompts.length) {
      await _handleScreeningReply(text);
    } else {
      _analyzePostScreeningTextSilently(text);
      _addSafetyOrExpertNudge(text);
      await _sendCompanionReply(text);
    }

    if (!mounted) return;
    setState(() {
      _sending = false;
    });
    _scrollToBottom();
  }

  void _analyzePostScreeningTextSilently(String text) {
    final prompt = _prompts[_bestPromptForText(text)];
    _estimateScore(text, prompt);
  }

  void _addSafetyOrExpertNudge(String text) {
    final normalized = text.toLowerCase();
    final isDanger = _hasAny(normalized, [
      'ทำร้ายตัวเอง',
      'อยากตาย',
      'ไม่อยากอยู่',
      'หายไป',
      'suicide',
      'kill myself',
    ]);
    final isMedication = _hasAny(normalized, [
      'ยา',
      'หยุดยา',
      'เพิ่มยา',
      'ลดยา',
      'กินยา',
      'med',
      'medicine',
    ]);

    if (isDanger) {
      setState(() {
        _messages.add(
          _ChatMessage.bot(
            'เราเป็นห่วงจริง ๆ นะ ตอนนี้อย่าอยู่คนเดียวได้ไหม ลองขยับไปอยู่ใกล้คนที่ไว้ใจ $_hotlineText เราจะคุยต่อกับคุณตรงนี้ด้วย',
          ),
        );
      });
      return;
    }

    if (isMedication) {
      setState(() {
        _messages.add(
          const _ChatMessage.bot(
            'เรื่องยาเราไม่อยากเดาแทนหมอนะ แต่เราช่วยจดคำถามนี้ให้เอาไปถามแพทย์ เภสัชกร หรือสายด่วน 1300 ได้ ถ้าต้องการ เดี๋ยวเราช่วยเรียบเรียงให้พูดง่ายขึ้น',
          ),
        );
      });
    }
  }

  int _bestPromptForText(String text) {
    final normalized = text.toLowerCase();
    if (_hasAny(normalized, ['นอน', 'หลับ'])) return 2;
    if (_hasAny(normalized, ['แรง', 'เหนื่อย', 'หมดพลัง'])) return 3;
    if (_hasAny(normalized, ['กิน', 'อาหาร'])) return 4;
    if (_hasAny(normalized, ['โทษ', 'ผิด', 'ไม่ดีพอ'])) return 5;
    if (_hasAny(normalized, ['สมาธิ', 'อ่าน', 'เรียน'])) return 6;
    if (_hasAny(normalized, ['ช้า', 'กระสับกระส่าย'])) return 7;
    if (_hasAny(normalized, ['ทำร้าย', 'อยากตาย', 'หายไป'])) return 8;
    if (_hasAny(normalized, ['สนใจ', 'อยากทำ'])) return 0;
    return 1;
  }

  Future<void> _handleScreeningReply(String text) async {
    final prompt = _prompts[_questionIndex];
    final score = _estimateScore(text, prompt);

    setState(() {
      _screeningScores.add(score);
    });

    if (prompt.isSafetyQuestion && score > 0) {
      setState(() {
        _messages.add(
          _ChatMessage.bot(
            'ขอบคุณที่ไว้ใจเล่านะ ถ้าความคิดนี้แรงขึ้นหรือรู้สึกไม่ปลอดภัย อย่าอยู่คนเดียว $_hotlineText',
          ),
        );
      });
    }

    if (_questionIndex < _prompts.length - 1) {
      setState(() {
        _questionIndex += 1;
        _messages.add(_ChatMessage.bot(_bridgeToNextQuestion()));
      });
      return;
    }

    await _finishScreening();
  }

  Future<void> _sendCompanionReply(String text) async {
    try {
      final reply = await _client.sendCompanionMessage(
        message: text,
        topic: _todayTopic,
        history: _messages
            .take(_messages.length - 1)
            .map(
              (message) => {
                'role': message.isUser ? 'user' : 'bot',
                'text': message.text,
              },
            )
            .toList(),
      );
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage.bot(reply.message));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          const _ChatMessage.bot(
            'เราได้ยินนะ เล่าเพิ่มได้เลยว่าส่วนไหนของเรื่องนี้หนักกับใจที่สุด เราจะค่อย ๆ อยู่ตรงนี้กับคุณ',
          ),
        );
      });
    }
  }

  String _bridgeToNextQuestion() {
    return _currentQuestion();
  }

  int _estimateScore(String text, _ScreeningPrompt prompt) {
    final normalized = text.toLowerCase().trim();
    if (normalized.isEmpty) return 1;

    if (prompt.isSafetyQuestion &&
        _hasAny(normalized, [
          'ทำร้ายตัวเอง',
          'อยากตาย',
          'ไม่อยากอยู่',
          'หายไป',
        ])) {
      return 3;
    }
    if (_hasAny(normalized, [
      'ทุกวัน',
      'ตลอด',
      'แทบทุก',
      'ไม่ไหว',
      'หนักมาก',
      'แย่มาก',
      'ทั้งวัน',
      'ตลอดเวลา',
    ])) {
      return 3;
    }
    if (_hasAny(normalized, [
      'บ่อย',
      'หลายวัน',
      'ครึ่ง',
      'มากขึ้น',
      'หนักขึ้น',
    ])) {
      return 2;
    }
    if (_hasAny(normalized, [
      'นิดหน่อย',
      'บางวัน',
      'บ้าง',
      'นิดนึง',
      'บางที',
    ])) {
      return 1;
    }
    if (_hasAny(normalized, [
      'ไม่มี',
      'ไม่ค่อย',
      'ปกติ',
      'โอเค',
      'ดี',
      'ยังไหว',
      'ไม่เป็น',
      'สบาย',
    ])) {
      return 0;
    }

    final negativeCount = [
      'เศร้า',
      'หม่น',
      'เหนื่อย',
      'หมดแรง',
      'นอนไม่หลับ',
      'กินไม่ลง',
      'โทษตัวเอง',
      'ไม่มีสมาธิ',
      'กระสับกระส่าย',
    ].where((signal) => normalized.contains(signal)).length;

    if (negativeCount >= 2) return 2;
    if (negativeCount == 1) return 1;
    return 1;
  }

  Future<void> _finishScreening() async {
    final total = _screeningScores.fold<int>(0, (sum, value) => sum + value);
    final moodScore = _groupScore(_SymptomGroup.mood);
    final somaticScore = _groupScore(_SymptomGroup.somatic);
    final behavioralScore = _groupScore(_SymptomGroup.behavioral);
    final moodLevel = (10 - (total / 27 * 10)).round().clamp(0, 10);

    setState(() {
      _savedToday = true;
      _messages.add(
        const _ChatMessage.bot(
          'ขอบคุณที่คุยกับเราจนครบนะ เราเก็บภาพรวมวันนี้ไว้ให้แล้ว หลังจากนี้คุยต่อได้เหมือนเดิมเลย ไม่ต้องตอบเป็นแบบประเมินแล้ว เล่าแบบเพื่อนคุยกันได้',
        ),
      );
    });

    _applyIslandState(total);

    final user = _user;
    if (user == null) return;

    try {
      await _client.appendPhq9Log(userId: user.id, totalScore: total);
      await _client.appendMoodLog(userId: user.id, moodLevel: moodLevel);
      await _client.appendSymptomMatrixLog(
        userId: user.id,
        moodScore: moodScore,
        somaticScore: somaticScore,
        behavioralScore: behavioralScore,
      );
      await _client.createReportForUser(
        userId: user.id,
        phq9Score: total,
        symptomMatrix: {
          'mood_score': moodScore,
          'somatic_score': somaticScore,
          'behavioral_score': behavioralScore,
        },
        dailyMood: widget.session.mood.label,
        diaryNote: 'Conversational check-in topic: $_todayTopic',
        date: DateTime.now(),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage.bot(
            'บันทึกขึ้นระบบยังไม่สำเร็จ แต่บทสนทนานี้ยังอยู่บนหน้านี้นะ: $error',
          ),
        );
      });
    }
  }

  int _groupScore(_SymptomGroup group) {
    var total = 0;
    for (var i = 0; i < _screeningScores.length && i < _prompts.length; i++) {
      if (_prompts[i].symptomGroup == group) total += _screeningScores[i];
    }
    return total;
  }

  void _applyIslandState(int total) {
    if (total >= 20) {
      widget.onMoodSelected(MoodState.crisis);
      widget.onEnergySelected(EnergyLevel.low);
    } else if (total >= 15) {
      widget.onMoodSelected(MoodState.heavy);
      widget.onEnergySelected(EnergyLevel.low);
    } else if (total >= 10) {
      widget.onMoodSelected(MoodState.tired);
      widget.onEnergySelected(EnergyLevel.low);
    } else if (total >= 5) {
      widget.onMoodSelected(MoodState.hopeful);
      widget.onEnergySelected(EnergyLevel.medium);
    } else {
      widget.onMoodSelected(MoodState.calm);
      widget.onEnergySelected(EnergyLevel.high);
    }
  }

  bool _hasAny(String text, List<String> signals) {
    return signals.any((signal) => text.contains(signal));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = _savedToday
        ? 'บันทึกภาพรวมวันนี้แล้ว คุยต่อได้เรื่อย ๆ'
        : 'กำลังคุยเรื่อง $_todayTopic';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEAF7F4), Color(0xFFFFF8E9)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Color(0xFF91CDBB),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.smart_toy_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ReJoy Companion',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF17343C),
                          ),
                        ),
                        Text(
                          progress,
                          style: const TextStyle(color: Color(0xFF60787A)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  SegmentedButton<bool>(
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith((
                        states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          return const Color(0xFF4B5570);
                        }
                        return Colors.white.withValues(alpha: 0.82);
                      }),
                      foregroundColor: WidgetStateProperty.resolveWith((
                        states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          return Colors.white;
                        }
                        return const Color(0xFF37565E);
                      }),
                      side: WidgetStateProperty.all(
                        const BorderSide(color: Color(0xFF9BB8B1), width: 1.2),
                      ),
                    ),
                    segments: const [
                      ButtonSegment(
                        value: false,
                        icon: Icon(Icons.keyboard_rounded, size: 18),
                        tooltip: 'โหมดพิมพ์',
                      ),
                      ButtonSegment(
                        value: true,
                        icon: Icon(Icons.touch_app_rounded, size: 18),
                        tooltip: 'โหมดกด',
                      ),
                    ],
                    selected: {_tapMode},
                    showSelectedIcon: false,
                    onSelectionChanged: (value) {
                      setState(() {
                        _tapMode = value.first;
                      });
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        return _MessageBubble(message: _messages[index]);
                      },
                    ),
            ),
            if (_tapMode)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: _QuickReplyPanel(
                  enabled: !_sending,
                  savedToday: _savedToday,
                  onReply: _sendQuickReply,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: _tapMode
                  ? TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _tapMode = false;
                        });
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF31525A),
                        backgroundColor: const Color(0xFFEAF5F1),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      icon: const Icon(Icons.keyboard_rounded),
                      label: const Text('กลับมาโหมดพิมพ์'),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            minLines: 1,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: 'เล่าแบบที่รู้สึกจริงได้เลย...',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: const BorderSide(
                                  color: Color(0xFFD6E5DF),
                                ),
                              ),
                            ),
                            onSubmitted: (_) => _sendFreeText(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton.filled(
                          onPressed: _sending ? null : _sendFreeText,
                          icon: _sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatefulWidget {
  const _MessageBubble({required this.message});

  final _ChatMessage message;

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  Timer? _timer;
  String _visibleText = '';
  int _cursor = 0;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  @override
  void didUpdateWidget(covariant _MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.text != widget.message.text ||
        oldWidget.message.animate != widget.message.animate) {
      _startTyping();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTyping() {
    _timer?.cancel();
    final message = widget.message;
    if (message.isUser || !message.animate || message.text.length <= 4) {
      _visibleText = message.text;
      _cursor = message.text.length;
      return;
    }

    _visibleText = '';
    _cursor = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 13), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cursor >= message.text.length) {
        timer.cancel();
        return;
      }
      setState(() {
        _cursor += 1;
        _visibleText = message.text.substring(0, _cursor);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final showCursor =
        !message.isUser && message.animate && _cursor < message.text.length;

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 330),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: message.isUser ? const Color(0xFFB8D8FF) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: message.isUser
                ? const Color(0xFF8DB9EE)
                : const Color(0xFFDDEAE5),
          ),
        ),
        child: Text.rich(
          TextSpan(
            text: _visibleText,
            children: [
              if (showCursor)
                const TextSpan(
                  text: '  ',
                  style: TextStyle(backgroundColor: Color(0xFF91CDBB)),
                ),
            ],
          ),
          style: const TextStyle(color: Color(0xFF20383F), height: 1.35),
        ),
      ),
    );
  }
}

class _QuickReplyPanel extends StatelessWidget {
  const _QuickReplyPanel({
    required this.enabled,
    required this.savedToday,
    required this.onReply,
  });

  final bool enabled;
  final bool savedToday;
  final ValueChanged<String> onReply;

  @override
  Widget build(BuildContext context) {
    final replies = savedToday
        ? [
            'อยากให้ช่วยฟังต่อ',
            'ช่วยเรียบเรียงคำถามไปถามผู้เชี่ยวชาญ',
            'เรื่องยา อยากเอาไปถามหมอ',
            'ตอนนี้ไม่อยากอยู่คนเดียว',
            'ขอคำปลอบใจสั้น ๆ',
            'ช่วยสรุปสิ่งที่เล่าให้หน่อย',
          ]
        : [
            'ตรงนี้ยังไหวอยู่',
            'มีบ้างบางวัน',
            'เป็นบ่อยหลายวัน',
            'แทบทุกวันและหนักมาก',
            'ยังเล่าเป็นคำยาว ๆ ไม่ไหว',
            'ไม่ค่อยมีเลย',
          ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBFD7CE), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B8E84).withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: replies.map((reply) {
          return ActionChip(
            avatar: Icon(
              Icons.touch_app_rounded,
              size: 16,
              color: enabled
                  ? const Color(0xFF4C7A72)
                  : const Color(0xFF7C918B),
            ),
            label: Text(reply),
            labelStyle: TextStyle(
              color: enabled
                  ? const Color(0xFF17343C)
                  : const Color(0xFF687D77),
              fontWeight: FontWeight.w800,
              height: 1.12,
            ),
            onPressed: enabled ? () => onReply(reply) : null,
            backgroundColor: const Color(0xFFEAF7F2),
            disabledColor: const Color(0xFFE5EEE9),
            side: BorderSide(
              color: enabled
                  ? const Color(0xFF9EC7BC)
                  : const Color(0xFFCBD9D4),
              width: 1.1,
            ),
            elevation: enabled ? 1 : 0,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          );
        }).toList(),
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isUser,
    required this.animate,
  });

  const _ChatMessage.user(String text)
    : this(text: text, isUser: true, animate: false);
  const _ChatMessage.bot(String text, {bool animate = true})
    : this(text: text, isUser: false, animate: animate);

  final String text;
  final bool isUser;
  final bool animate;
}

class _ScreeningPrompt {
  const _ScreeningPrompt({
    required this.symptomGroup,
    required this.question,
    this.isSafetyQuestion = false,
  });

  final _SymptomGroup symptomGroup;
  final String question;
  final bool isSafetyQuestion;
}

enum _SymptomGroup { mood, somatic, behavioral }
