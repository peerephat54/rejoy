enum ClinicalRiskLevel { green, yellow, orange, red }

class SafetyScreeningResult {
  const SafetyScreeningResult({
    required this.level,
    required this.reason,
    required this.shouldBlockAi,
  });

  final ClinicalRiskLevel level;
  final String reason;
  final bool shouldBlockAi;

  bool get isRedFlag => level == ClinicalRiskLevel.red;
}

class SafetyGuardService {
  const SafetyGuardService();

  static final RegExp _redFlagPattern = RegExp(
    r'(อยากตาย|ฆ่าตัวตาย|ทำร้ายตัวเอง|ไม่อยากอยู่|หายไปตลอด|suicide|kill myself|end my life|self harm)',
    caseSensitive: false,
  );

  static final RegExp _orangePattern = RegExp(
    r'(ไม่ไหวแล้ว|หมดหวัง|ไม่เหลือใคร|อยากหายไป|เจ็บปวดมาก|ทรมานมาก)',
    caseSensitive: false,
  );

  static final RegExp _yellowPattern = RegExp(
    r'(เครียด|เหนื่อย|เศร้า|กังวล|นอนไม่หลับ|ร้องไห้|โดดเดี่ยว)',
    caseSensitive: false,
  );

  SafetyScreeningResult screen(String text) {
    final value = text.trim();
    if (value.isEmpty) {
      return const SafetyScreeningResult(
        level: ClinicalRiskLevel.green,
        reason: 'empty_text',
        shouldBlockAi: false,
      );
    }

    if (_redFlagPattern.hasMatch(value)) {
      return const SafetyScreeningResult(
        level: ClinicalRiskLevel.red,
        reason: 'red_flag_keyword',
        shouldBlockAi: true,
      );
    }

    if (_orangePattern.hasMatch(value)) {
      return const SafetyScreeningResult(
        level: ClinicalRiskLevel.orange,
        reason: 'high_distress_keyword',
        shouldBlockAi: false,
      );
    }

    if (_yellowPattern.hasMatch(value)) {
      return const SafetyScreeningResult(
        level: ClinicalRiskLevel.yellow,
        reason: 'distress_keyword',
        shouldBlockAi: false,
      );
    }

    return const SafetyScreeningResult(
      level: ClinicalRiskLevel.green,
      reason: 'no_risk_keyword',
      shouldBlockAi: false,
    );
  }
}
