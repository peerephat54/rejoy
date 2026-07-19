import '../core/rejoy_session.dart';

class CompassionateGamificationService {
  const CompassionateGamificationService();

  String animalName(String animalId) {
    final id = animalId.toLowerCase();
    if (id.contains('fox')) return 'จิ้งจอกแสงอุ่น';
    if (id.contains('otter')) return 'นากใจดี';
    if (id.contains('rabbit')) return 'กระต่ายพักใจ';
    if (id.contains('owl')) return 'นกฮูกเฝ้าใจ';
    if (id.contains('deer')) return 'กวางเดินช้า';
    if (id.contains('seal')) return 'แมวน้ำกอดคลื่น';
    if (id.contains('cat')) return 'แมวเฝ้าสมุด';
    if (id.contains('lion')) return 'สิงโตใจอ่อนโยน';
    if (id.contains('whale')) return 'วาฬฟังเงียบ';
    if (id.contains('turtle')) return 'เต่าค่อยเป็นค่อยไป';
    if (id.contains('bear')) return 'หมีผ้าห่ม';
    if (id.contains('panda')) return 'แพนด้าหายใจลึก';
    return 'เพื่อนตัวน้อยบนเกาะ';
  }

  String encounterCopy({
    required List<String> newAnimals,
    required int completedQuests,
    String backendMessage = '',
  }) {
    if (backendMessage.trim().isNotEmpty) {
      return backendMessage.trim();
    }
    if (newAnimals.isNotEmpty) {
      final name = animalName(newAnimals.last);
      return '$name อพยพมาอยู่บนเกาะ เพราะวันนี้คุณค่อย ๆ ทำสำเร็จ $completedQuests เควส';
    }
    return 'วันนี้ไม่มีสัตว์ตัวใหม่ซ้ำเข้ามา แต่สัตว์บนเกาะเห็นความพยายามของคุณครบถ้วนแล้ว';
  }

  String mirrorCopy({required MoodState mood, required List<String> animals}) {
    final companion = animals.isEmpty
        ? 'เพื่อนตัวน้อยบนเกาะ'
        : animalName(animals.last);
    return switch (mood) {
      MoodState.crisis =>
        '$companion จะอยู่ใกล้ ๆ แบบไม่เร่งนะ ตอนนี้แค่หายใจและขอความช่วยเหลือก็พอ',
      MoodState.heavy =>
        '$companion ขอนั่งเงียบ ๆ ข้างคุณ วันนี้ไม่ต้องเก่งมากก็ได้',
      MoodState.tired =>
        '$companion เห็นแล้วว่าวันนี้คุณเหนื่อย แค่ก้าวเล็ก ๆ ก็นับ',
      MoodState.calm =>
        '$companion กำลังเดินเล่นบนเกาะ และเก็บช่วงเวลานุ่ม ๆ วันนี้ไว้ให้',
      MoodState.hopeful => '$companion ดีใจที่เห็นคุณยังลองดูแลตัวเองทีละนิด',
    };
  }

  String nightPrompt(MoodState mood) {
    return switch (mood) {
      MoodState.crisis =>
        'ตอนนี้มีอะไรหนึ่งอย่างที่ช่วยให้คุณปลอดภัยขึ้นอีกนิดได้ไหม เช่น โทรหาใครสักคน หรืออยู่ใกล้คนที่ไว้ใจ',
      MoodState.heavy =>
        'วันนี้มีช่วงสั้น ๆ ตรงไหนที่คุณยังพาตัวเองผ่านมาได้ แม้มันจะเล็กมากก็ตาม',
      MoodState.tired =>
        'คืนนี้อยากขอบคุณร่างกายตัวเองเรื่องเล็ก ๆ อะไรหนึ่งอย่าง',
      MoodState.calm => 'วันนี้มีภาพ เสียง หรือคำพูดไหนที่ทำให้ใจเบาลงนิดหนึ่ง',
      MoodState.hopeful =>
        'พรุ่งนี้อยากเก็บแรงใจเล็ก ๆ จากวันนี้ไปใช้กับเรื่องอะไร',
    };
  }
}
