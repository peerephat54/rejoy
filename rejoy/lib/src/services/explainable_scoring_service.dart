class ExplainableScoringService {
  const ExplainableScoringService();

  String explain({
    required double averagePhq9,
    required int moodScore,
    required int somaticScore,
    required int behavioralScore,
    required double cbtRate,
  }) {
    final strongest = <String, int>{
      'อารมณ์': moodScore,
      'ร่างกาย/การนอน/พลังงาน': somaticScore,
      'พฤติกรรมและกิจวัตร': behavioralScore,
    }.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final mainAxis = strongest.first.key;
    final phqText = averagePhq9 >= 15
        ? 'คะแนนเฉลี่ยอยู่ในช่วงที่ควรเฝ้าระวังใกล้ชิด'
        : averagePhq9 >= 10
        ? 'คะแนนเฉลี่ยเริ่มมีสัญญาณที่ควรติดตาม'
        : 'คะแนนเฉลี่ยยังอยู่ในช่วงที่ติดตามต่อได้แบบไม่ตื่นตระหนก';
    final cbtText = cbtRate >= 70
        ? 'การทำกิจกรรม CBT ค่อนข้างสม่ำเสมอ'
        : cbtRate >= 35
        ? 'การทำกิจกรรม CBT มีบางวันทำได้และบางวันควรประคอง'
        : 'การทำกิจกรรม CBT ยังน้อย ระบบควรเริ่มจากเควสเบามาก ๆ';

    return '$phqText โดยแกนที่เด่นที่สุดคือ $mainAxis และ $cbtText ข้อมูลนี้ใช้เพื่อดูแนวโน้ม ไม่ใช่การวินิจฉัยโรค';
  }
}
