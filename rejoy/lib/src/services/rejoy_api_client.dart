import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_config.dart';
import '../core/auth_session.dart';

class BackendHealth {
  const BackendHealth({
    required this.status,
    required this.service,
    required this.database,
    required this.timestamp,
    required this.uptimeSeconds,
  });

  final String status;
  final String service;
  final String database;
  final DateTime? timestamp;
  final int? uptimeSeconds;

  factory BackendHealth.fromJson(Map<String, dynamic> json) {
    return BackendHealth(
      status: json['status']?.toString() ?? 'unknown',
      service: json['service']?.toString() ?? 'unknown',
      database: json['database']?.toString() ?? 'unknown',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString())
          : null,
      uptimeSeconds: json['uptimeSeconds'] is int
          ? json['uptimeSeconds'] as int
          : int.tryParse(json['uptimeSeconds']?.toString() ?? ''),
    );
  }
}

class BackendUser {
  const BackendUser({
    required this.id,
    required this.email,
    required this.role,
    required this.firstName,
    required this.surname,
    required this.age,
    required this.allergies,
    required this.medicalHistory,
    required this.emergencyContactNumbers,
    required this.currentMedications,
    required this.symptomClusteringMatrix,
    required this.completedQuestsCount,
    required this.unlockedAnimals,
    required this.animalNicknames,
    required this.currentEnergyLevel,
    required this.selectedQuestsToday,
    required this.completedQuestsToday,
    required this.onboardingComplete,
  });

  final String id;
  final String email;
  final String role;
  final String firstName;
  final String surname;
  final int age;
  final List<String> allergies;
  final String medicalHistory;
  final List<String> emergencyContactNumbers;
  final List<String> currentMedications;
  final List<String> symptomClusteringMatrix;
  final int completedQuestsCount;
  final List<String> unlockedAnimals;
  final Map<String, String> animalNicknames;
  final String currentEnergyLevel;
  final List<String> selectedQuestsToday;
  final List<String> completedQuestsToday;
  final bool onboardingComplete;

  String get fullName => '$firstName $surname'.trim();
  String get patientCode {
    if (id.length < 6) return 'RJ-${id.toUpperCase()}';
    return 'RJ-${id.substring(id.length - 6).toUpperCase()}';
  }

  bool get isClinician =>
      role == 'doctor' || role == 'psychologist' || role == 'admin';

  int get questsUntilNextAnimal {
    final remainder = completedQuestsCount % 3;
    return remainder == 0 ? 3 : 3 - remainder;
  }

  factory BackendUser.fromJson(Map<String, dynamic> json) {
    final unlockedAnimalsValue =
        json['unlockedAnimals'] ?? json['unlocked_animals'];
    final animalNicknamesValue =
        json['animalNicknames'] ?? json['animal_nicknames'];
    final selectedQuestsTodayValue =
        json['selectedQuestsToday'] ?? json['selected_quests_today'];
    final completedQuestsTodayValue =
        json['completedQuestsToday'] ?? json['completed_quests_today'];
    final allergiesValue = json['allergies'];
    final emergencyContactNumbersValue = json['emergencyContactNumbers'];
    final currentMedicationsValue = json['currentMedications'];
    final symptomClusteringMatrixValue = json['symptomClusteringMatrix'];
    return BackendUser(
      id: json['_id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'patient',
      firstName: json['firstName']?.toString() ?? '',
      surname: json['surname']?.toString() ?? '',
      age: int.tryParse(json['age']?.toString() ?? '') ?? 0,
      allergies: allergiesValue is List
          ? allergiesValue.map((item) => item.toString()).toList()
          : <String>[],
      medicalHistory: json['medicalHistory']?.toString() ?? '',
      emergencyContactNumbers: emergencyContactNumbersValue is List
          ? emergencyContactNumbersValue.map((item) => item.toString()).toList()
          : <String>[],
      currentMedications: currentMedicationsValue is List
          ? currentMedicationsValue.map((item) => item.toString()).toList()
          : <String>[],
      symptomClusteringMatrix: symptomClusteringMatrixValue is List
          ? symptomClusteringMatrixValue.map((item) => item.toString()).toList()
          : <String>[],
      completedQuestsCount:
          int.tryParse(
            (json['completedQuestsCount'] ?? json['completed_quests_count'])
                    ?.toString() ??
                '',
          ) ??
          0,
      unlockedAnimals: unlockedAnimalsValue is List
          ? unlockedAnimalsValue.map((item) => item.toString()).toList()
          : <String>[],
      animalNicknames: animalNicknamesValue is Map
          ? animalNicknamesValue.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : <String, String>{},
      currentEnergyLevel: json['currentEnergyLevel']?.toString() ?? 'rest',
      selectedQuestsToday: selectedQuestsTodayValue is List
          ? selectedQuestsTodayValue.map((item) => item.toString()).toList()
          : <String>[],
      completedQuestsToday: completedQuestsTodayValue is List
          ? completedQuestsTodayValue.map((item) => item.toString()).toList()
          : <String>[],
      onboardingComplete:
          json['onboardingComplete'] == true ||
          json['onboardingComplete']?.toString() == 'true',
    );
  }
}

class QuestItem {
  const QuestItem({
    required this.id,
    required this.name,
    required this.description,
    required this.energyLevel,
    required this.reward,
    required this.animalId,
    required this.color,
    required this.isActive,
    this.isDoctorRecommended = false,
  });

  final String id;
  final String name;
  final String description;
  final String energyLevel;
  final String reward;
  final String animalId;
  final String color;
  final bool isActive;
  final bool isDoctorRecommended;

  factory QuestItem.fromJson(Map<String, dynamic> json) {
    final id = (json['_id'] ?? json['id'])?.toString() ?? '';
    final name = json['name']?.toString() ?? '';
    final animalId = json['animalId']?.toString() ?? '';
    return QuestItem(
      id: id,
      name: name,
      description: json['description']?.toString() ?? '',
      energyLevel: json['energyLevel']?.toString() ?? '',
      reward: json['reward']?.toString() ?? '',
      animalId: animalId,
      color: json['color']?.toString() ?? '#5A8DEE',
      isActive:
          json['isActive'] == true || json['isActive']?.toString() == 'true',
      isDoctorRecommended:
          json['isDoctorRecommended'] == true ||
          json['source']?.toString() == 'doctor' ||
          id.startsWith('doctor-') ||
          animalId.startsWith('doctor-') ||
          name.contains('เควสจากหมอ'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'description': description,
      'energyLevel': energyLevel,
      'reward': reward,
      'animalId': animalId,
      'color': color,
      'isActive': isActive,
      'isDoctorRecommended': isDoctorRecommended,
    };
  }
}

const List<QuestItem> _fallbackQuestBank = [
  QuestItem(
    id: 'local-rest-01',
    name: 'วางมือลงบนอกแล้วหายใจ 3 รอบ',
    description:
        'ไม่ต้องลุกจากที่เดิมก็ได้ แค่วางมือบนอกแล้วค่อย ๆ หายใจเข้าออก 3 รอบ ให้ร่างกายรู้ว่าตอนนี้ปลอดภัย',
    energyLevel: 'rest',
    reward: 'สัตว์พาสเทลจะค่อย ๆ แวะมาพักบนเกาะ',
    animalId: 'panda-01',
    color: '#8FD3CE',
    isActive: true,
  ),
  QuestItem(
    id: 'local-rest-02',
    name: 'จิบน้ำช้า ๆ 3 คำ',
    description:
        'หยิบน้ำใกล้ตัวแล้วจิบช้า ๆ สังเกตความเย็น รสชาติ หรือสัมผัสของแก้วแบบไม่ต้องรีบ',
    energyLevel: 'rest',
    reward: 'สัตว์พาสเทลจะค่อย ๆ แวะมาพักบนเกาะ',
    animalId: 'koala-02',
    color: '#A8C8E8',
    isActive: true,
  ),
  QuestItem(
    id: 'local-rest-03',
    name: 'ขยับปลายนิ้วปลุกตัวเองเบา ๆ',
    description:
        'ขยับนิ้วมือ นิ้วเท้า หรือไหล่เบา ๆ 20 วินาที เพื่อบอกสมองว่าเริ่มจากจุดเล็ก ๆ ได้',
    energyLevel: 'rest',
    reward: 'สัตว์พาสเทลจะค่อย ๆ แวะมาพักบนเกาะ',
    animalId: 'rabbit-03',
    color: '#F3B8C8',
    isActive: true,
  ),
  QuestItem(
    id: 'local-low-01',
    name: 'เปิดม่านรับแสงนิดเดียว',
    description:
        'ถ้าไหว ลองเปิดม่านหรือมองออกนอกหน้าต่าง 30 วินาที ไม่ต้องทำอะไรต่อ แค่ให้วันเริ่มเข้ามาเล็กน้อย',
    energyLevel: 'low',
    reward: 'สัตว์พาสเทลจะค่อย ๆ แวะมาพักบนเกาะ',
    animalId: 'owl-04',
    color: '#B9B3E8',
    isActive: true,
  ),
  QuestItem(
    id: 'local-low-02',
    name: 'ล้างหน้าหรือเช็ดหน้าแบบอ่อนโยน',
    description:
        'ใช้น้ำหรือผ้าชุบน้ำเช็ดหน้าเบา ๆ เพื่อรีเซ็ตความรู้สึก ไม่ต้องแต่งตัวหรือทำขั้นตอนอื่นต่อก็ได้',
    energyLevel: 'low',
    reward: 'สัตว์พาสเทลจะค่อย ๆ แวะมาพักบนเกาะ',
    animalId: 'seal-05',
    color: '#9CCB8A',
    isActive: true,
  ),
  QuestItem(
    id: 'local-low-03',
    name: 'เก็บของหนึ่งชิ้นกลับที่เดิม',
    description:
        'เลือกของแค่ 1 ชิ้นแล้ววางกลับที่เดิม ถ้าทำได้มากกว่านั้นคือโบนัส แต่หนึ่งชิ้นก็นับว่าสำเร็จแล้ว',
    energyLevel: 'low',
    reward: 'สัตว์พาสเทลจะค่อย ๆ แวะมาพักบนเกาะ',
    animalId: 'deer-06',
    color: '#D7B08A',
    isActive: true,
  ),
  QuestItem(
    id: 'local-low-04',
    name: 'เขียนประโยคใจดีกับตัวเอง',
    description:
        'เขียนสั้น ๆ หนึ่งประโยคเหมือนพูดกับเพื่อนที่เหนื่อย เช่น วันนี้ทำได้เท่าที่ไหวก็พอ',
    energyLevel: 'low',
    reward: 'สัตว์พาสเทลจะค่อย ๆ แวะมาพักบนเกาะ',
    animalId: 'fox-07',
    color: '#F2C47E',
    isActive: true,
  ),
  QuestItem(
    id: 'local-medium-01',
    name: 'เดินช้า ๆ 1 นาที',
    description:
        'เดินในห้องหรือหน้าบ้านช้า ๆ 1 นาที ถ้าร่างกายบอกว่าเหนื่อยให้หยุดได้ทันทีโดยไม่ต้องรู้สึกผิด',
    energyLevel: 'medium',
    reward: 'สัตว์พาสเทลจะค่อย ๆ แวะมาพักบนเกาะ',
    animalId: 'cat-08',
    color: '#E9A35F',
    isActive: true,
  ),
  QuestItem(
    id: 'local-medium-02',
    name: 'จัดมุมพักให้ตัวเอง 2 นาที',
    description:
        'ขยับหมอน ผ้าห่ม หรือแก้วน้ำให้หยิบง่ายขึ้น เพื่อทำให้พื้นที่วันนี้ปลอดภัยและเป็นมิตรขึ้นนิดหนึ่ง',
    energyLevel: 'medium',
    reward: 'สัตว์พาสเทลจะค่อย ๆ แวะมาพักบนเกาะ',
    animalId: 'otter-09',
    color: '#86B7D9',
    isActive: true,
  ),
  QuestItem(
    id: 'local-medium-03',
    name: 'ส่งข้อความหาคนที่ไว้ใจ',
    description:
        'พิมพ์สั้น ๆ ว่าวันนี้เราเหนื่อยนิดหน่อยนะ ไม่จำเป็นต้องอธิบายยาว แค่เปิดประตูให้มีคนอยู่ข้าง ๆ',
    energyLevel: 'medium',
    reward: 'สัตว์พาสเทลจะค่อย ๆ แวะมาพักบนเกาะ',
    animalId: 'turtle-10',
    color: '#8FC7A5',
    isActive: true,
  ),
  QuestItem(
    id: 'local-high-01',
    name: 'เลือกงานเล็กที่สุดหนึ่งอย่าง',
    description:
        'มองรายการสิ่งที่ต้องทำ แล้วเลือกแค่อย่างที่เล็กที่สุด ทำ 5 นาทีพอ ไม่ต้องจบทั้งหมด',
    energyLevel: 'high',
    reward: 'สัตว์พาสเทลจะค่อย ๆ แวะมาพักบนเกาะ',
    animalId: 'lion-11',
    color: '#F4A66A',
    isActive: true,
  ),
  QuestItem(
    id: 'local-high-02',
    name: 'อาบน้ำแบบไม่ต้องสมบูรณ์แบบ',
    description:
        'ถ้าไหว ลองอาบน้ำหรือเปลี่ยนเสื้อผ้าหนึ่งชิ้น เป้าหมายคือให้ตัวเบาขึ้น ไม่ใช่ต้องทำครบทุกขั้นตอน',
    energyLevel: 'high',
    reward: 'สัตว์พาสเทลจะค่อย ๆ แวะมาพักบนเกาะ',
    animalId: 'whale-12',
    color: '#7EB9D6',
    isActive: true,
  ),
  QuestItem(
    id: 'local-doctor-01',
    name: 'เควสจากหมอ: จดเวลานอนเมื่อคืน',
    description:
        'บันทึกคร่าว ๆ ว่าเข้านอนและตื่นประมาณกี่โมง เพื่อให้หมอเห็นแนวโน้มการนอนโดยไม่ต้องนึกย้อนหลัง',
    energyLevel: 'low',
    reward: 'เควสติดตามจากหมอ ช่วยให้การพบแพทย์ครั้งหน้าคุยได้เร็วขึ้น',
    animalId: 'doctor-panda-13',
    color: '#BFE5D8',
    isActive: true,
  ),
  QuestItem(
    id: 'local-doctor-02',
    name: 'เควสจากหมอ: เช็กผลข้างเคียงยา',
    description:
        'สำรวจตัวเองสั้น ๆ วันนี้ง่วงผิดปกติ มือสั่น คลื่นไส้ หรือใจสั่นไหม ถ้ามีให้จดไว้คุยกับผู้เชี่ยวชาญ',
    energyLevel: 'medium',
    reward: 'เควสติดตามจากหมอ ช่วยให้การพบแพทย์ครั้งหน้าคุยได้เร็วขึ้น',
    animalId: 'doctor-koala-14',
    color: '#D9E7FF',
    isActive: true,
  ),
  QuestItem(
    id: 'local-doctor-03',
    name: 'เควสจากหมอ: เลือกหนึ่งกิจกรรมที่ยังพอไหว',
    description:
        'เลือกกิจกรรมเล็ก ๆ ที่ไม่กดดัน เช่น นั่งรับลม ล้างแก้ว หรือยืดไหล่ เพื่อดูว่าพลังงานวันนี้อยู่ระดับไหน',
    energyLevel: 'medium',
    reward: 'เควสติดตามจากหมอ ช่วยให้การพบแพทย์ครั้งหน้าคุยได้เร็วขึ้น',
    animalId: 'doctor-redpanda-15',
    color: '#F5C7B8',
    isActive: true,
  ),
  QuestItem(
    id: 'local-doctor-04',
    name: 'เควสจากหมอ: ทำ Safety Plan หนึ่งบรรทัด',
    description:
        'เขียนชื่อคนที่ติดต่อได้หนึ่งคน หรือสถานที่ที่ทำให้ปลอดภัยขึ้นหนึ่งที่ เผื่อวันที่ใจหนักมาก',
    energyLevel: 'low',
    reward: 'เควสติดตามจากหมอ ช่วยให้การพบแพทย์ครั้งหน้าคุยได้เร็วขึ้น',
    animalId: 'doctor-capybara-16',
    color: '#F0D0A8',
    isActive: true,
  ),
];

class QuestCompletionResult {
  const QuestCompletionResult({
    required this.message,
    required this.unlockedAnimal,
    required this.questsUntilNextAnimal,
    required this.completedQuestsCount,
    required this.unlockedAnimals,
    required this.user,
  });

  final String message;
  final String unlockedAnimal;
  final int questsUntilNextAnimal;
  final int completedQuestsCount;
  final List<String> unlockedAnimals;
  final BackendUser? user;

  factory QuestCompletionResult.fromJson(Map<String, dynamic> json) {
    final unlockedAnimalsValue = json['unlockedAnimals'];
    final unlockedAnimals = unlockedAnimalsValue is List
        ? unlockedAnimalsValue.map((item) => item.toString()).toList()
        : <String>[];
    final userJson = json['user'];

    return QuestCompletionResult(
      message: json['message']?.toString() ?? 'Quest completed.',
      unlockedAnimal: json['unlockedAnimal']?.toString() ?? '',
      questsUntilNextAnimal:
          int.tryParse(json['questsUntilNextAnimal']?.toString() ?? '') ?? 3,
      completedQuestsCount:
          int.tryParse(json['completedQuestsCount']?.toString() ?? '') ?? 0,
      unlockedAnimals: unlockedAnimals,
      user: userJson is Map<String, dynamic>
          ? BackendUser.fromJson(userJson)
          : null,
    );
  }
}

class QuestDayFinishResult {
  const QuestDayFinishResult({
    required this.message,
    required this.totalSelectedQuests,
    required this.completedQuestsCount,
    required this.completionRate,
    required this.unlockedAnimalsToday,
    required this.companionMessage,
    required this.questsUntilNextAnimal,
    required this.user,
  });

  final String message;
  final int totalSelectedQuests;
  final int completedQuestsCount;
  final String completionRate;
  final List<String> unlockedAnimalsToday;
  final String companionMessage;
  final int questsUntilNextAnimal;
  final BackendUser? user;

  factory QuestDayFinishResult.fromJson(Map<String, dynamic> json) {
    final unlockedAnimalsValue = json['unlocked_animals_today'];
    final userJson = json['user'];
    return QuestDayFinishResult(
      message: json['message']?.toString() ?? 'Day finished.',
      totalSelectedQuests:
          int.tryParse(json['total_selected_quests']?.toString() ?? '') ?? 0,
      completedQuestsCount:
          int.tryParse(json['completed_quests_count']?.toString() ?? '') ?? 0,
      completionRate: json['completed_quests_rate']?.toString() ?? '0/0',
      unlockedAnimalsToday: unlockedAnimalsValue is List
          ? unlockedAnimalsValue.map((item) => item.toString()).toList()
          : <String>[],
      companionMessage: json['companion_message']?.toString() ?? '',
      questsUntilNextAnimal:
          int.tryParse(json['questsUntilNextAnimal']?.toString() ?? '') ?? 3,
      user: userJson is Map<String, dynamic>
          ? BackendUser.fromJson(userJson)
          : null,
    );
  }
}

class ReportSymptomMatrix {
  const ReportSymptomMatrix({
    required this.moodScore,
    required this.somaticScore,
    required this.behavioralScore,
  });

  final int moodScore;
  final int somaticScore;
  final int behavioralScore;

  factory ReportSymptomMatrix.fromJson(Map<String, dynamic> json) {
    return ReportSymptomMatrix(
      moodScore: int.tryParse(json['mood_score']?.toString() ?? '') ?? 0,
      somaticScore: int.tryParse(json['somatic_score']?.toString() ?? '') ?? 0,
      behavioralScore:
          int.tryParse(json['behavioral_score']?.toString() ?? '') ?? 0,
    );
  }
}

class ReportEntry {
  const ReportEntry({
    required this.id,
    required this.reportId,
    required this.userId,
    required this.date,
    required this.phq9Score,
    required this.symptomMatrix,
    required this.dailyMood,
    required this.diaryNote,
    required this.cbtCompletionRate,
    required this.unlockedAnimalToday,
    required this.isRestDay,
    required this.isSosTriggered,
    required this.periodDays,
  });

  final String id;
  final String reportId;
  final String userId;
  final DateTime? date;
  final int phq9Score;
  final ReportSymptomMatrix symptomMatrix;
  final String dailyMood;
  final String diaryNote;
  final String cbtCompletionRate;
  final String unlockedAnimalToday;
  final bool isRestDay;
  final bool isSosTriggered;
  final int periodDays;

  factory ReportEntry.fromJson(Map<String, dynamic> json) {
    final userIdValue = json['userId'];
    final String userId = userIdValue is Map
        ? userIdValue['_id']?.toString() ?? ''
        : userIdValue?.toString() ?? '';
    final symptomMatrixJson = json['symptomMatrix'];

    return ReportEntry(
      id: json['_id']?.toString() ?? '',
      reportId: json['reportId']?.toString() ?? '',
      userId: userId,
      date: json['date'] != null
          ? DateTime.tryParse(json['date'].toString())
          : null,
      phq9Score: int.tryParse(json['phq9Score']?.toString() ?? '') ?? 0,
      symptomMatrix: symptomMatrixJson is Map<String, dynamic>
          ? ReportSymptomMatrix.fromJson(symptomMatrixJson)
          : const ReportSymptomMatrix(
              moodScore: 0,
              somaticScore: 0,
              behavioralScore: 0,
            ),
      dailyMood: json['dailyMood']?.toString() ?? '',
      diaryNote: json['diaryNote']?.toString() ?? '',
      cbtCompletionRate: json['cbtCompletionRate']?.toString() ?? '0%',
      unlockedAnimalToday: json['unlockedAnimalToday']?.toString() ?? '',
      isRestDay:
          json['isRestDay'] == true || json['isRestDay']?.toString() == 'true',
      isSosTriggered:
          json['isSosTriggered'] == true ||
          json['isSosTriggered']?.toString() == 'true',
      periodDays: int.tryParse(json['periodDays']?.toString() ?? '') ?? 14,
    );
  }
}

class CompanionReply {
  const CompanionReply({required this.provider, required this.message});

  final String provider;
  final String message;

  factory CompanionReply.fromJson(Map<String, dynamic> json) {
    return CompanionReply(
      provider: json['provider']?.toString() ?? 'fallback',
      message: json['message']?.toString() ?? '',
    );
  }
}

class ClinicalProfilePayload {
  const ClinicalProfilePayload({required this.user, required this.reports});

  final BackendUser user;
  final List<ReportEntry> reports;

  factory ClinicalProfilePayload.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];
    final reportsJson = json['reports'];

    if (userJson is! Map<String, dynamic>) {
      throw const FormatException('Invalid clinical profile user payload');
    }

    return ClinicalProfilePayload(
      user: BackendUser.fromJson(userJson),
      reports: reportsJson is List
          ? reportsJson
                .whereType<Map>()
                .map(
                  (item) =>
                      ReportEntry.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : <ReportEntry>[],
    );
  }
}

class AuthResponse {
  const AuthResponse({
    required this.token,
    required this.refreshToken,
    required this.user,
  });

  final String token;
  final String refreshToken;
  final BackendUser user;

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];
    if (userJson is! Map<String, dynamic>) {
      throw const FormatException('Invalid auth user payload');
    }
    return AuthResponse(
      token: json['token']?.toString() ?? '',
      refreshToken: json['refreshToken']?.toString() ?? '',
      user: BackendUser.fromJson(userJson),
    );
  }
}

class _AuthHttpClient extends http.BaseClient {
  _AuthHttpClient(this._inner);

  final http.Client _inner;
  static Future<bool>? _refreshInFlight;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final retryRequest = request is http.Request
        ? _cloneRequest(request)
        : null;
    _attachToken(request);

    final response = await _inner.send(request);
    if (response.statusCode != 401 || retryRequest == null) {
      return response;
    }

    final refreshed = await _refreshAuthToken();
    if (!refreshed) {
      return response;
    }

    await response.stream.drain<void>();
    _attachToken(retryRequest, replace: true);
    return _inner.send(retryRequest);
  }

  @override
  void close() {
    _inner.close();
  }

  void _attachToken(http.BaseRequest request, {bool replace = false}) {
    final token = AuthSession.token;
    if (token == null || token.isEmpty) return;
    if (replace) {
      request.headers['authorization'] = 'Bearer $token';
    } else {
      request.headers.putIfAbsent('authorization', () => 'Bearer $token');
    }
  }

  http.Request _cloneRequest(http.Request request) {
    final clone = http.Request(request.method, request.url)
      ..bodyBytes = request.bodyBytes
      ..followRedirects = request.followRedirects
      ..maxRedirects = request.maxRedirects
      ..persistentConnection = request.persistentConnection;
    clone.headers.addAll(request.headers);
    return clone;
  }

  Future<bool> _refreshAuthToken() async {
    final currentRefresh = _refreshInFlight;
    if (currentRefresh != null) {
      return currentRefresh;
    }

    final refresh = _performRefreshAuthToken();
    _refreshInFlight = refresh;
    try {
      return await refresh;
    } finally {
      if (identical(_refreshInFlight, refresh)) {
        _refreshInFlight = null;
      }
    }
  }

  Future<bool> _performRefreshAuthToken() async {
    final refreshToken = AuthSession.refreshToken;
    final userId = AuthSession.userId;
    final email = AuthSession.email;
    if (refreshToken == null ||
        refreshToken.isEmpty ||
        userId == null ||
        email == null) {
      return false;
    }

    try {
      final response = await _inner
          .post(
            ApiConfig.authRefreshUri(),
            headers: {
              'accept': 'application/json',
              'content-type': 'application/json',
            },
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(const Duration(seconds: 65));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await AuthSession.clear();
        return false;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return false;
      final auth = AuthResponse.fromJson(decoded);
      await AuthSession.save(
        token: auth.token,
        refreshToken: auth.refreshToken,
        userId: auth.user.id.isEmpty ? userId : auth.user.id,
        email: auth.user.email.isEmpty ? email : auth.user.email,
      );
      ReJoyApiClient.clearCache();
      return true;
    } catch (_) {
      return false;
    }
  }
}

class _TimedCache<T> {
  const _TimedCache(this.value, this.createdAt);

  final T value;
  final DateTime createdAt;

  bool isFresh(Duration ttl) => DateTime.now().difference(createdAt) < ttl;
}

class ReJoyApiClient {
  ReJoyApiClient({http.Client? httpClient})
    : _http = httpClient == null
          ? _sharedHttpClient
          : _AuthHttpClient(httpClient),
      _ownsHttpClient = httpClient != null;

  // Screens are created and disposed frequently. Keeping one transport for the
  // app lets Android reuse HTTP keep-alive sockets instead of opening a new
  // connection every time the user changes tabs.
  static final http.Client _sharedHttpClient = _AuthHttpClient(http.Client());

  static const _quickReadTimeout = Duration(seconds: 12);
  static const _standardReadTimeout = Duration(seconds: 20);
  static const _standardWriteTimeout = Duration(seconds: 20);
  static const _authTimeout = Duration(seconds: 65);
  static const _coldStartTimeout = Duration(seconds: 65);
  static const _profileCacheTtl = Duration(seconds: 30);

  bool get _isLocalDemoSession =>
      AuthSession.email?.endsWith('@rejoy.demo') == true;
  static const _reportCacheTtl = Duration(seconds: 20);
  static const _questCacheTtl = Duration(minutes: 5);
  static const _storedQuestCacheTtl = Duration(hours: 12);
  static const _questCachePrefix = 'rejoy_quests_cache_v2';
  static const _localDoctorQuestStorageKey = 'rejoy_local_doctor_quests_v1';

  static _TimedCache<ClinicalProfilePayload>? _activeProfileCache;
  static final Map<String, _TimedCache<List<QuestItem>>> _questCache = {};
  static final Map<String, _TimedCache<List<ReportEntry>>> _reportCache = {};

  final http.Client _http;

  static void clearCache() {
    _activeProfileCache = null;
    _questCache.clear();
    _reportCache.clear();
  }

  static void _invalidateUserCaches() {
    _activeProfileCache = null;
    _questCache.clear();
    _reportCache.clear();
  }

  static String _questStorageKey(String cacheKey) =>
      '${_questCachePrefix}_$cacheKey';

  static String _questStorageTimeKey(String cacheKey) =>
      '${_questStorageKey(cacheKey)}_saved_at';

  static Future<List<QuestItem>?> _loadStoredQuests(String cacheKey) async {
    final prefs = await SharedPreferences.getInstance();
    final savedAt = prefs.getInt(_questStorageTimeKey(cacheKey));
    final raw = prefs.getString(_questStorageKey(cacheKey));
    if (savedAt == null || raw == null || raw.isEmpty) {
      return null;
    }

    final age = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(savedAt),
    );
    if (age > _storedQuestCacheTtl) {
      return null;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return null;
    }

    return decoded
        .whereType<Map>()
        .map((item) => QuestItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  static Future<void> _saveStoredQuests(
    String cacheKey,
    List<QuestItem> quests,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _questStorageTimeKey(cacheKey),
      DateTime.now().millisecondsSinceEpoch,
    );
    await prefs.setString(
      _questStorageKey(cacheKey),
      jsonEncode(quests.map((quest) => quest.toJson()).toList()),
    );
  }

  static Future<List<QuestItem>> _loadLocalDoctorQuests(String cacheKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localDoctorQuestStorageKey);
    if (raw == null || raw.isEmpty) return const <QuestItem>[];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return const <QuestItem>[];
    final quests = decoded
        .whereType<Map>()
        .map((item) => QuestItem.fromJson(Map<String, dynamic>.from(item)))
        .where((quest) => quest.isActive && quest.isDoctorRecommended)
        .where(
          (quest) =>
              cacheKey == 'all' ||
              quest.energyLevel == cacheKey ||
              quest.energyLevel == 'rest',
        )
        .toList();
    return quests;
  }

  static Future<void> _saveLocalDoctorQuest(QuestItem quest) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await _loadLocalDoctorQuests('all');
    final merged = <String, QuestItem>{
      for (final item in existing) item.id: item,
      quest.id: quest,
    };
    await prefs.setString(
      _localDoctorQuestStorageKey,
      jsonEncode(merged.values.map((item) => item.toJson()).toList()),
    );
    _questCache.clear();
  }

  static int _stableHash(String value) {
    var hash = 0;
    for (final codeUnit in value.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    return hash;
  }

  static List<QuestItem> _dailyQuestSelection({
    required List<QuestItem> source,
    required String cacheKey,
    int limit = 10,
  }) {
    final today = DateTime.now();
    final seed = _stableHash(
      '$cacheKey-${today.year}-${today.month}-${today.day}',
    );
    final quests = List<QuestItem>.of(source);
    quests.sort((a, b) {
      final aScore = _stableHash('${a.id}-$seed');
      final bScore = _stableHash('${b.id}-$seed');
      return aScore.compareTo(bScore);
    });

    final uniqueByName = <String, QuestItem>{};
    for (final quest in quests) {
      uniqueByName.putIfAbsent(quest.name.trim(), () => quest);
    }
    return uniqueByName.values.take(limit).toList();
  }

  static List<QuestItem> _fallbackQuestsFor(String cacheKey) {
    final source = cacheKey == 'all'
        ? _fallbackQuestBank
              .where((quest) => !quest.id.startsWith('local-doctor'))
              .toList()
        : _fallbackQuestBank
              .where(
                (quest) =>
                    !quest.id.startsWith('local-doctor') &&
                    (quest.energyLevel == cacheKey ||
                        quest.energyLevel == 'rest'),
              )
              .toList();
    return _dailyQuestSelection(source: source, cacheKey: cacheKey);
  }

  Future<http.Response> _sendWithRetry(
    Future<http.Response> Function() send, {
    Duration timeout = _standardReadTimeout,
    int retries = 0,
  }) async {
    for (var attempt = 0; attempt <= retries; attempt += 1) {
      try {
        final response = await send().timeout(timeout);
        if (attempt < retries &&
            const <int>{
              408,
              429,
              502,
              503,
              504,
            }.contains(response.statusCode)) {
          await Future<void>.delayed(_retryDelay(attempt));
          continue;
        }
        return response;
      } on TimeoutException {
        if (attempt == retries) rethrow;
      } on http.ClientException {
        if (attempt == retries) rethrow;
      }
      await Future<void>.delayed(_retryDelay(attempt));
    }

    throw StateError('Request retry loop finished unexpectedly');
  }

  Duration _retryDelay(int attempt) {
    // A small jitter prevents many phones from retrying the cloud service at
    // exactly the same moment after a temporary outage.
    final jitter = DateTime.now().microsecond % 180;
    return Duration(milliseconds: 260 + attempt * 240 + jitter);
  }

  /// Wakes a sleeping free cloud instance without blocking the login screen.
  Future<bool> warmUpBackend() async {
    try {
      final response = await _sendWithRetry(
        () => _http.get(
          ApiConfig.healthUri(),
          headers: {'accept': 'application/json'},
        ),
        timeout: _coldStartTimeout,
      );
      return response.statusCode >= 200 && response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  Future<AuthResponse> registerWithEmail({
    required String email,
    required String password,
    required String firstName,
    required String surname,
    required int age,
    String role = 'patient',
  }) async {
    final response = await _sendWithRetry(
      () => _http.post(
        ApiConfig.authRegisterUri(),
        headers: {
          'accept': 'application/json',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
          'firstName': firstName,
          'surname': surname,
          'age': age,
          'role': role,
        }),
      ),
      timeout: _authTimeout,
    );

    clearCache();
    return _decodeJsonObject(
      response,
      (json) => AuthResponse.fromJson(json),
      'Register failed',
    );
  }

  Future<AuthResponse> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await _sendWithRetry(
      () => _http.post(
        ApiConfig.authLoginUri(),
        headers: {
          'accept': 'application/json',
          'content-type': 'application/json',
        },
        body: jsonEncode({'email': email, 'password': password}),
      ),
      timeout: _authTimeout,
    );

    clearCache();
    return _decodeJsonObject(
      response,
      (json) => AuthResponse.fromJson(json),
      'Login failed',
    );
  }

  Future<void> logout() async {
    final refreshToken = AuthSession.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      return;
    }

    final response = await _http
        .post(
          ApiConfig.authLogoutUri(),
          headers: {
            'accept': 'application/json',
            'content-type': 'application/json',
          },
          body: jsonEncode({'refreshToken': refreshToken}),
        )
        .timeout(const Duration(seconds: 8));

    await _decodeJsonObject(response, (json) => json, 'Logout failed');
  }

  Future<BackendHealth> fetchHealth() async {
    final response = await _sendWithRetry(
      () => _http.get(
        ApiConfig.healthUri(),
        headers: {'accept': 'application/json'},
      ),
      timeout: _quickReadTimeout,
      retries: 1,
    );

    return _decodeJsonObject(
      response,
      (json) => BackendHealth.fromJson(json),
      'Health request failed',
    );
  }

  Future<Map<String, dynamic>> fetchClinicalDashboard() async {
    if (_isLocalDemoSession) {
      return _demoClinicalDashboard(
        note: 'Local demo dashboard is loaded instantly for presentation.',
      );
    }

    final response = await _sendWithRetry(
      () => _http.get(
        ApiConfig.clinicalDashboardUri(),
        headers: {'accept': 'application/json'},
      ),
      timeout: _standardReadTimeout,
      retries: 1,
    );

    if (response.statusCode == 404) {
      return _demoClinicalDashboard(
        note:
            'Cloud backend route is not deployed yet, so ReJoy is showing a local hospital demo dataset.',
      );
    }

    return _decodeJsonObject(
      response,
      (json) => json,
      'Clinical dashboard request failed',
    );
  }

  Future<Map<String, dynamic>> createCarePlan({
    required String title,
    required String focusArea,
    required String recommendedQuestEnergy,
    String? userId,
    String? note,
  }) async {
    final response = await _sendWithRetry(
      () => _http.post(
        ApiConfig.clinicalCarePlansUri(),
        headers: {
          'accept': 'application/json',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'title': title,
          'focusArea': focusArea,
          'recommendedQuestEnergy': recommendedQuestEnergy,
          if (userId != null && userId.isNotEmpty) 'userId': userId,
          if (note != null && note.isNotEmpty) 'note': note,
        }),
      ),
      timeout: _standardWriteTimeout,
    );

    final result = await _decodeJsonObject(
      response,
      (json) => json,
      'Create care plan failed',
    );
    _invalidateUserCaches();
    return result;
  }

  Future<QuestItem> createDoctorQuestForPatient({
    required String title,
    required String description,
    required String energyLevel,
    String? userId,
  }) async {
    final localQuest = QuestItem(
      id: 'doctor-${userId?.isNotEmpty == true ? userId : 'demo'}-${DateTime.now().millisecondsSinceEpoch}',
      name: title,
      description: description,
      energyLevel: energyLevel,
      reward: 'เควสที่หมอแนะนำเพื่อช่วยดูแลตัวเองวันนี้',
      animalId: 'doctor-care',
      color: '#E6B24D',
      isActive: true,
      isDoctorRecommended: true,
    );

    try {
      final result = await createCarePlan(
        userId: userId,
        title: title,
        focusArea: description,
        recommendedQuestEnergy: energyLevel,
        note: description,
      );
      final rawCarePlan = result['carePlan'];
      if (rawCarePlan is Map) {
        final carePlan = Map<String, dynamic>.from(rawCarePlan);
        final cloudQuest = _carePlanToQuest(carePlan);
        await _saveLocalDoctorQuest(cloudQuest);
        return cloudQuest;
      }
    } catch (_) {
      // Demo patients may not exist on cloud. Keep the quest locally so the
      // presentation flow still shows the clinician-to-patient handoff.
    }

    await _saveLocalDoctorQuest(localQuest);
    return localQuest;
  }

  Future<List<BackendUser>> fetchUsers() async {
    final response = await _sendWithRetry(
      () => _http.get(
        ApiConfig.usersUri(),
        headers: {'accept': 'application/json'},
      ),
      timeout: _quickReadTimeout,
      retries: 1,
    );

    return _decodeJsonList(
      response,
      (json) => BackendUser.fromJson(json),
      'Users request failed',
    );
  }

  Future<BackendUser> updateUserProfile({
    required String userId,
    required String firstName,
    required String surname,
    required int age,
    required List<String> allergies,
    required List<String> emergencyContactNumbers,
    required List<String> currentMedications,
    required String medicalHistory,
    bool? onboardingComplete,
    String? role,
  }) async {
    if (_isLocalDemoSession) {
      final prefs = await SharedPreferences.getInstance();
      if (onboardingComplete != null) {
        await prefs.setBool(
          'rejoy_demo_onboarding_complete',
          onboardingComplete,
        );
      }
      _invalidateUserCaches();
      return BackendUser(
        id: userId,
        email: AuthSession.email ?? 'demo@rejoy.demo',
        role:
            role ??
            (AuthSession.email?.startsWith('doctor-demo-') == true
                ? 'doctor'
                : 'patient'),
        firstName: firstName,
        surname: surname,
        age: age,
        allergies: allergies,
        medicalHistory: medicalHistory,
        emergencyContactNumbers: emergencyContactNumbers,
        currentMedications: currentMedications,
        symptomClusteringMatrix: const ['Mood', 'Somatic', 'Behavioral'],
        completedQuestsCount: 0,
        unlockedAnimals: const <String>[],
        animalNicknames: const <String, String>{},
        currentEnergyLevel: 'low',
        selectedQuestsToday: const <String>[],
        completedQuestsToday: const <String>[],
        onboardingComplete: onboardingComplete ?? false,
      );
    }

    final response = await _sendWithRetry(
      () => _http.patch(
        Uri.parse('${ApiConfig.baseUrl}/api/users/$userId'),
        headers: {
          'accept': 'application/json',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'firstName': firstName,
          'surname': surname,
          'age': age,
          'allergies': allergies,
          'emergencyContactNumbers': emergencyContactNumbers,
          'currentMedications': currentMedications,
          'medicalHistory': medicalHistory,
          if (role != null && role.isNotEmpty) 'role': role,
          if (onboardingComplete != null)
            'onboardingComplete': onboardingComplete,
        }),
      ),
      timeout: _standardWriteTimeout,
    );

    final user = await _decodeJsonObject(
      response,
      (json) => BackendUser.fromJson(json),
      'Update user profile failed',
    );
    _invalidateUserCaches();
    return user;
  }

  Future<BackendUser> saveAnimalNickname({
    required BackendUser user,
    required String animalId,
    required String nickname,
  }) async {
    final nicknames = Map<String, String>.from(user.animalNicknames);
    final trimmed = nickname.trim();
    if (trimmed.isEmpty) {
      nicknames.remove(animalId);
    } else {
      nicknames[animalId] = trimmed;
    }

    final response = await _sendWithRetry(
      () => _http.patch(
        Uri.parse('${ApiConfig.baseUrl}/api/users/${user.id}'),
        headers: {
          'accept': 'application/json',
          'content-type': 'application/json',
        },
        body: jsonEncode({'animalNicknames': nicknames}),
      ),
      timeout: _standardWriteTimeout,
    );

    final updatedUser = await _decodeJsonObject(
      response,
      (json) => BackendUser.fromJson(json),
      'Save animal nickname failed',
    );
    _invalidateUserCaches();
    return updatedUser;
  }

  Future<ClinicalProfilePayload> fetchActiveClinicalProfile({
    bool forceRefresh = false,
  }) async {
    final email = AuthSession.email ?? '';
    if (email.endsWith('@rejoy.demo')) {
      final prefs = await SharedPreferences.getInstance();
      return _demoClinicalProfile(
        isDoctor: email.startsWith('doctor-demo-'),
        email: email,
        onboardingComplete:
            prefs.getBool('rejoy_demo_onboarding_complete') ??
            email.startsWith('doctor-demo-'),
      );
    }

    final cached = _activeProfileCache;
    if (!forceRefresh && cached != null && cached.isFresh(_profileCacheTtl)) {
      return cached.value;
    }

    final response = await _sendWithRetry(
      () => _http.get(
        ApiConfig.activeClinicalProfileUri(),
        headers: {'accept': 'application/json'},
      ),
      timeout: _quickReadTimeout,
      retries: 1,
    );

    final payload = await _decodeJsonObject(
      response,
      (json) => ClinicalProfilePayload.fromJson(json),
      'Clinical profile request failed',
    );
    _activeProfileCache = _TimedCache(payload, DateTime.now());
    return payload;
  }

  Future<CompanionReply> sendCompanionMessage({
    required String message,
    required List<Map<String, String>> history,
    String? topic,
  }) async {
    final response = await _sendWithRetry(
      () => _http.post(
        ApiConfig.companionChatUri(),
        headers: {
          'accept': 'application/json',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'message': message,
          'history': history,
          if (topic != null && topic.isNotEmpty) 'topic': topic,
        }),
      ),
      timeout: _standardWriteTimeout,
      retries: 0,
    );

    return _decodeJsonObject(
      response,
      (json) => CompanionReply.fromJson(json),
      'Companion chat failed',
    );
  }

  Future<void> appendMoodLog({
    required String userId,
    required int moodLevel,
  }) async {
    if (_isLocalDemoSession) {
      _invalidateUserCaches();
      return;
    }

    final response = await _sendWithRetry(
      () => _http.post(
        ApiConfig.userMoodLogUri(userId),
        headers: {
          'accept': 'application/json',
          'content-type': 'application/json',
        },
        body: jsonEncode({'mood_level': moodLevel}),
      ),
      timeout: _standardWriteTimeout,
    );

    await _decodeJsonObject(response, (json) => json, 'Mood log failed');
    _invalidateUserCaches();
  }

  Future<void> appendPhq9Log({
    required String userId,
    required int totalScore,
  }) async {
    if (_isLocalDemoSession) {
      _invalidateUserCaches();
      return;
    }

    final response = await _sendWithRetry(
      () => _http.post(
        ApiConfig.userPhq9HistoryUri(userId),
        headers: {
          'accept': 'application/json',
          'content-type': 'application/json',
        },
        body: jsonEncode({'total_score': totalScore}),
      ),
      timeout: _standardWriteTimeout,
    );

    await _decodeJsonObject(response, (json) => json, 'PHQ-9 log failed');
    _invalidateUserCaches();
  }

  Future<void> appendSymptomMatrixLog({
    required String userId,
    required int moodScore,
    required int somaticScore,
    required int behavioralScore,
  }) async {
    if (_isLocalDemoSession) {
      _invalidateUserCaches();
      return;
    }

    final response = await _sendWithRetry(
      () => _http.post(
        ApiConfig.userSymptomMatrixHistoryUri(userId),
        headers: {
          'accept': 'application/json',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'mood_score': moodScore,
          'somatic_score': somaticScore,
          'behavioral_score': behavioralScore,
        }),
      ),
      timeout: _standardWriteTimeout,
    );

    await _decodeJsonObject(
      response,
      (json) => json,
      'Symptom matrix log failed',
    );
    _invalidateUserCaches();
  }

  Future<List<QuestItem>> fetchQuests({
    String? energyLevel,
    bool forceRefresh = false,
  }) async {
    final cacheKey = energyLevel == null || energyLevel.isEmpty
        ? 'all'
        : energyLevel;
    final cached = _questCache[cacheKey];
    if (!forceRefresh && cached != null && cached.isFresh(_questCacheTtl)) {
      return cached.value;
    }

    if (!forceRefresh) {
      final storedQuests = await _loadStoredQuests(cacheKey);
      if (storedQuests != null) {
        final doctorQuests = await _loadDoctorRecommendedQuests(cacheKey);
        final mergedStored = _mergeDoctorQuests(
          doctorQuests: doctorQuests,
          dailyQuests: storedQuests,
        );
        _questCache[cacheKey] = _TimedCache(mergedStored, DateTime.now());
        return mergedStored;
      }
    }

    final uri = energyLevel == null || energyLevel.isEmpty
        ? ApiConfig.questsUri().replace(queryParameters: {'limit': '50'})
        : ApiConfig.questsUri().replace(
            queryParameters: {'energyLevel': energyLevel, 'limit': '50'},
          );

    late final List<QuestItem> quests;
    try {
      final response = await _sendWithRetry(
        () => _http.get(uri, headers: {'accept': 'application/json'}),
        timeout: _quickReadTimeout,
        retries: 1,
      );

      quests = await _decodeJsonList(
        response,
        (json) => QuestItem.fromJson(json),
        'Quests request failed',
      );
    } on TimeoutException {
      quests = _fallbackQuestsFor(cacheKey);
    } on http.ClientException {
      quests = _fallbackQuestsFor(cacheKey);
    } on Object {
      quests = _fallbackQuestsFor(cacheKey);
    }

    final appQuests = quests
        .where(
          (quest) =>
              !quest.id.startsWith('local-doctor') &&
              !quest.animalId.startsWith('doctor-') &&
              !quest.name.contains('เควสจากหมอ'),
        )
        .toList();

    final dailyQuests = appQuests.isEmpty
        ? _fallbackQuestsFor(cacheKey)
        : _dailyQuestSelection(source: appQuests, cacheKey: cacheKey);
    final doctorQuests = await _loadDoctorRecommendedQuests(cacheKey);
    final mergedQuests = _mergeDoctorQuests(
      doctorQuests: doctorQuests,
      dailyQuests: dailyQuests,
    );
    _questCache[cacheKey] = _TimedCache(mergedQuests, DateTime.now());
    await _saveStoredQuests(cacheKey, dailyQuests);
    return mergedQuests;
  }

  Future<List<QuestItem>> _loadDoctorRecommendedQuests(String cacheKey) async {
    final localQuests = await _loadLocalDoctorQuests(cacheKey);
    final cloudQuests = <QuestItem>[];
    try {
      final response = await _sendWithRetry(
        () => _http.get(
          ApiConfig.clinicalCarePlansUri(),
          headers: {'accept': 'application/json'},
        ),
        timeout: _quickReadTimeout,
        retries: 0,
      );
      final payload = await _decodeJsonObject(
        response,
        (json) => json,
        'Care plans request failed',
      );
      final carePlans = payload['carePlans'];
      if (carePlans is List) {
        cloudQuests.addAll(
          carePlans
              .whereType<Map>()
              .map((item) => _carePlanToQuest(Map<String, dynamic>.from(item)))
              .where((quest) => quest.isActive)
              .where(
                (quest) =>
                    cacheKey == 'all' ||
                    quest.energyLevel == cacheKey ||
                    quest.energyLevel == 'rest',
              ),
        );
      }
    } catch (_) {
      // Doctor quests are additive. If the cloud is sleeping or unavailable,
      // keep app quests fast and use any local demo handoff.
    }

    return _mergeDoctorQuests(
      doctorQuests: cloudQuests,
      dailyQuests: localQuests,
    );
  }

  static QuestItem _carePlanToQuest(Map<String, dynamic> carePlan) {
    final title = carePlan['title']?.toString().trim();
    final note = carePlan['note']?.toString().trim();
    final focusArea = carePlan['focusArea']?.toString().trim();
    final rawId = carePlan['_id']?.toString() ?? carePlan['id']?.toString();
    return QuestItem(
      id: 'doctor-${rawId ?? _stableHash('${title ?? ''}-${note ?? ''}')}',
      name: title == null || title.isEmpty ? 'เควสที่หมอแนะนำ' : title,
      description: note != null && note.isNotEmpty
          ? note
          : (focusArea == null || focusArea.isEmpty
                ? 'ทำเท่าที่ไหว และหยุดพักได้ทันทีถ้าร่างกายไม่พร้อม'
                : focusArea),
      energyLevel: carePlan['recommendedQuestEnergy']?.toString() ?? 'low',
      reward: 'เควสที่หมอแนะนำเพื่อช่วยดูแลตัวเองวันนี้',
      animalId: 'doctor-care',
      color: '#E6B24D',
      isActive: carePlan['status']?.toString() != 'inactive',
      isDoctorRecommended: true,
    );
  }

  static List<QuestItem> _mergeDoctorQuests({
    required List<QuestItem> doctorQuests,
    required List<QuestItem> dailyQuests,
  }) {
    final merged = <String, QuestItem>{};
    for (final quest in doctorQuests) {
      merged[quest.id] = quest;
    }
    for (final quest in dailyQuests) {
      merged.putIfAbsent(quest.id, () => quest);
    }
    return merged.values.toList();
  }

  Future<List<ReportEntry>> fetchReports({
    String? userId,
    bool forceRefresh = false,
  }) async {
    final cacheKey = userId == null || userId.isEmpty ? 'all' : userId;
    final cached = _reportCache[cacheKey];
    if (!forceRefresh && cached != null && cached.isFresh(_reportCacheTtl)) {
      return cached.value;
    }

    final uri = userId == null || userId.isEmpty
        ? ApiConfig.reportsUri()
        : ApiConfig.userReportsUri(userId);

    final response = await _sendWithRetry(
      () => _http.get(uri, headers: {'accept': 'application/json'}),
      timeout: _quickReadTimeout,
      retries: 1,
    );

    final reports = await _decodeJsonList(
      response,
      (json) => ReportEntry.fromJson(json),
      'Reports request failed',
    );
    _reportCache[cacheKey] = _TimedCache(reports, DateTime.now());
    return reports;
  }

  Future<ReportEntry> updateReport({
    required String reportId,
    String? diaryNote,
    String? dailyMood,
    String? cbtCompletionRate,
    String? unlockedAnimalToday,
    bool? isRestDay,
    bool? isSosTriggered,
    DateTime? date,
  }) async {
    final body = <String, dynamic>{
      if (diaryNote != null) 'diaryNote': diaryNote,
      if (dailyMood != null) 'dailyMood': dailyMood,
      if (cbtCompletionRate != null) 'cbtCompletionRate': cbtCompletionRate,
      if (unlockedAnimalToday != null)
        'unlockedAnimalToday': unlockedAnimalToday,
      if (isRestDay != null) 'isRestDay': isRestDay,
      if (isSosTriggered != null) 'isSosTriggered': isSosTriggered,
      if (date != null) 'date': date.toIso8601String(),
    };

    final response = await _sendWithRetry(
      () => _http.patch(
        Uri.parse('${ApiConfig.baseUrl}/api/reports/$reportId'),
        headers: {
          'accept': 'application/json',
          'content-type': 'application/json',
        },
        body: jsonEncode(body),
      ),
      timeout: _standardWriteTimeout,
    );

    final report = await _decodeJsonObject(
      response,
      (json) => ReportEntry.fromJson(json),
      'Update report failed',
    );
    _invalidateUserCaches();
    return report;
  }

  Future<ReportEntry> generateReportForUser(String userId) async {
    final response = await _sendWithRetry(
      () => _http.post(
        ApiConfig.reportGenerateUri(userId),
        headers: {'accept': 'application/json'},
      ),
      timeout: _standardWriteTimeout,
    );

    final report = await _decodeJsonObject(
      response,
      (json) => ReportEntry.fromJson(json),
      'Generate report failed',
    );
    _invalidateUserCaches();
    return report;
  }

  Future<QuestCompletionResult> completeQuestForUser({
    required String userId,
    required String questName,
    String? questAnimalId,
    String? energyModeSelected,
    String? completionRate,
    bool? isRestDay,
  }) async {
    final body = <String, dynamic>{
      'quest_name': questName,
      if (questAnimalId != null) 'quest_animal_id': questAnimalId,
      if (energyModeSelected != null)
        'energy_mode_selected': energyModeSelected,
      if (completionRate != null) 'completion_rate': completionRate,
      if (isRestDay != null) 'is_rest_day': isRestDay,
    };

    final response = await _sendWithRetry(
      () => _http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/users/$userId/quest-complete'),
        headers: {
          'accept': 'application/json',
          'content-type': 'application/json',
        },
        body: jsonEncode(body),
      ),
      timeout: _standardWriteTimeout,
    );

    final result = await _decodeJsonObject(
      response,
      (json) => QuestCompletionResult.fromJson(json),
      'Complete quest failed',
    );
    _invalidateUserCaches();
    return result;
  }

  Future<QuestDayFinishResult> finishQuestDayForUser({
    required String userId,
    required List<String> selectedQuests,
    required List<String> completedQuests,
    String? energyModeSelected,
    String? completionRate,
    bool? isRestDay,
  }) async {
    final body = <String, dynamic>{
      'selected_quests': selectedQuests,
      'completed_quests': completedQuests,
      if (energyModeSelected != null)
        'energy_mode_selected': energyModeSelected,
      if (completionRate != null) 'completion_rate': completionRate,
      if (isRestDay != null) 'is_rest_day': isRestDay,
    };

    final response = await _sendWithRetry(
      () => _http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/users/$userId/quest-day/finish'),
        headers: {
          'accept': 'application/json',
          'content-type': 'application/json',
        },
        body: jsonEncode(body),
      ),
      timeout: _standardWriteTimeout,
    );

    final result = await _decodeJsonObject(
      response,
      (json) => QuestDayFinishResult.fromJson(json),
      'Finish quest day failed',
    );
    _invalidateUserCaches();
    return result;
  }

  Future<void> savePositiveMemoryForUser({
    required String userId,
    required String answer,
    String? prompt,
    String? animalId,
    String? moodState,
    DateTime? date,
  }) async {
    final body = <String, dynamic>{
      'answer': answer,
      if (prompt != null) 'prompt': prompt,
      if (animalId != null) 'animal_id': animalId,
      if (moodState != null) 'mood_state': moodState,
      if (date != null) 'date': date.toIso8601String(),
    };

    final response = await _sendWithRetry(
      () => _http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/users/$userId/positive-memory'),
        headers: {
          'accept': 'application/json',
          'content-type': 'application/json',
        },
        body: jsonEncode(body),
      ),
      timeout: _standardWriteTimeout,
    );

    await _decodeJsonObject(response, (json) => json, 'Save memory failed');
    _invalidateUserCaches();
  }

  Future<ReportEntry> createReportForUser({
    required String userId,
    int? phq9Score,
    Map<String, dynamic>? symptomMatrix,
    String? dailyMood,
    String? diaryNote,
    String? cbtCompletionRate,
    String? unlockedAnimalToday,
    bool? isRestDay,
    bool? isSosTriggered,
    int? periodDays,
    DateTime? date,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (_isLocalDemoSession) {
      _invalidateUserCaches();
      return ReportEntry(
        id: 'demo-report-${DateTime.now().millisecondsSinceEpoch}',
        reportId: 'RJ-DEMO-BASELINE',
        userId: userId,
        date: date ?? DateTime.now(),
        phq9Score: phq9Score ?? 0,
        symptomMatrix: ReportSymptomMatrix(
          moodScore:
              int.tryParse(symptomMatrix?['mood_score']?.toString() ?? '') ?? 0,
          somaticScore:
              int.tryParse(symptomMatrix?['somatic_score']?.toString() ?? '') ??
              0,
          behavioralScore:
              int.tryParse(
                symptomMatrix?['behavioral_score']?.toString() ?? '',
              ) ??
              0,
        ),
        dailyMood: dailyMood ?? 'baseline',
        diaryNote: diaryNote ?? '',
        cbtCompletionRate: cbtCompletionRate ?? 'baseline',
        unlockedAnimalToday: unlockedAnimalToday ?? '',
        isRestDay: isRestDay ?? false,
        isSosTriggered: isSosTriggered ?? false,
        periodDays: periodDays ?? 14,
      );
    }

    final body = <String, dynamic>{
      'userId': userId,
      if (phq9Score != null) 'phq9Score': phq9Score,
      if (symptomMatrix != null) 'symptomMatrix': symptomMatrix,
      if (dailyMood != null) 'dailyMood': dailyMood,
      if (diaryNote != null) 'diaryNote': diaryNote,
      if (cbtCompletionRate != null) 'cbtCompletionRate': cbtCompletionRate,
      if (unlockedAnimalToday != null)
        'unlockedAnimalToday': unlockedAnimalToday,
      if (isRestDay != null) 'isRestDay': isRestDay,
      if (isSosTriggered != null) 'isSosTriggered': isSosTriggered,
      if (periodDays != null) 'periodDays': periodDays,
      if (date != null) 'date': date.toIso8601String(),
      if (startDate != null) 'startDate': startDate.toIso8601String(),
      if (endDate != null) 'endDate': endDate.toIso8601String(),
    };

    final response = await _sendWithRetry(
      () => _http.post(
        ApiConfig.reportsUri(),
        headers: {
          'accept': 'application/json',
          'content-type': 'application/json',
        },
        body: jsonEncode(body),
      ),
      timeout: _standardWriteTimeout,
    );

    final report = await _decodeJsonObject(
      response,
      (json) => ReportEntry.fromJson(json),
      'Create report failed',
    );
    _invalidateUserCaches();
    return report;
  }

  Future<List<BackendUser>> fetchUsersOrSeed() async {
    final users = await fetchUsers();
    if (users.isNotEmpty) {
      return users;
    }
    throw StateError('No users found. Create a user first.');
  }

  Future<T> _decodeJsonObject<T>(
    http.Response response,
    T Function(Map<String, dynamic> json) builder,
    String errorPrefix,
  ) async {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        '$errorPrefix with ${response.statusCode}: ${response.body}',
        response.request?.url,
      );
    }

    final jsonBody = jsonDecode(response.body);
    if (jsonBody is! Map<String, dynamic>) {
      throw const FormatException('Invalid response format');
    }

    return builder(jsonBody);
  }

  Future<List<T>> _decodeJsonList<T>(
    http.Response response,
    T Function(Map<String, dynamic> json) builder,
    String errorPrefix,
  ) async {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        '$errorPrefix with ${response.statusCode}: ${response.body}',
        response.request?.url,
      );
    }

    final jsonBody = jsonDecode(response.body);
    if (jsonBody is! List) {
      throw const FormatException('Invalid response format');
    }

    return jsonBody
        .whereType<Map>()
        .map((item) => builder(Map<String, dynamic>.from(item)))
        .toList();
  }

  void dispose() {
    if (_ownsHttpClient) {
      _http.close();
    }
  }

  final bool _ownsHttpClient;
}

ClinicalProfilePayload _demoClinicalProfile({
  required bool isDoctor,
  required String email,
  required bool onboardingComplete,
}) {
  final now = DateTime.now();
  final user = BackendUser(
    id: isDoctor ? 'demo-doctor-local' : 'RJ-D0001',
    email: email,
    role: isDoctor ? 'doctor' : 'patient',
    firstName: isDoctor ? 'หมอ Demo' : 'Demo',
    surname: 'ReJoy',
    age: isDoctor ? 34 : 16,
    allergies: const ['ข้อมูลจำลอง: ยังไม่มีข้อมูลแพ้ยาระบุ'],
    medicalHistory:
        'ข้อมูลจำลองสำหรับสาธิต: ผู้ใช้มีแนวโน้มซึมเศร้าระดับสูง ใช้เพื่อโชว์ workflow รายงานแพทย์เท่านั้น',
    emergencyContactNumbers: const ['ข้อมูลจำลอง: 08X-XXX-XXXX'],
    currentMedications: const ['ข้อมูลจำลอง: อยู่ระหว่างติดตามโดยผู้เชี่ยวชาญ'],
    symptomClusteringMatrix: const ['Mood', 'Somatic', 'Behavioral'],
    completedQuestsCount: 5,
    unlockedAnimals: const ['bear-11', 'deer-05', 'owl-04'],
    animalNicknames: const {'bear-11': 'เพื่อนบนเกาะ'},
    currentEnergyLevel: 'low',
    selectedQuestsToday: const ['local-low-01', 'local-low-02', 'local-low-03'],
    completedQuestsToday: const ['local-low-01'],
    onboardingComplete: onboardingComplete,
  );

  final phq9Scores = [19, 21, 22, 23, 23];
  final moods = [
    'ข้อมูลจำลอง: หม่นมาก',
    'ข้อมูลจำลอง: เหนื่อยล้า',
    'ข้อมูลจำลอง: โดดเดี่ยว',
    'ข้อมูลจำลอง: หนักมาก',
    'ข้อมูลจำลอง: ซึมเศร้ารุนแรง',
  ];
  final cbtRates = ['1/5', '0/5', '1/5', '0/5', '1/5'];

  final reports = <ReportEntry>[
    for (var index = 0; index < 5; index++)
      ReportEntry(
        id: 'demo-report-$index',
        reportId: 'RJ-DEMO-R$index',
        userId: user.id,
        date: now.subtract(Duration(days: 4 - index)),
        phq9Score: phq9Scores[index],
        symptomMatrix: const ReportSymptomMatrix(
          moodScore: 9,
          somaticScore: 8,
          behavioralScore: 7,
        ),
        dailyMood: moods[index],
        diaryNote:
            'ข้อมูลจำลองสำหรับสาธิต: วันนี้รู้สึกหนัก เหนื่อยง่าย นอนหลับยาก และไม่ค่อยอยากทำกิจกรรม ต้องการให้แพทย์เห็นแนวโน้มโดยไม่ต้องเล่าย้อนหลังทั้งหมด',
        cbtCompletionRate: cbtRates[index],
        unlockedAnimalToday: index >= 2 ? 'owl-urgent-demo' : 'otter-care-demo',
        isRestDay: index == 1 || index == 3,
        isSosTriggered: index >= 2,
        periodDays: 14,
      ),
  ];

  return ClinicalProfilePayload(user: user, reports: reports.reversed.toList());
}

Map<String, dynamic> _demoClinicalDashboard({String? note}) {
  final now = DateTime.now().toIso8601String();
  return {
    'generatedAt': now,
    'scope': 'demo-fallback',
    'totals': {
      'patients': 3,
      'stable': 1,
      'watch': 1,
      'urgent': 1,
      'alerts': 4,
    },
    'patients': [
      {
        'userId': 'demo-heavy',
        'patientCode': 'RJ-DEMO1',
        'displayName': 'Demo Patient 1',
        'initials': 'D1',
        'age': 16,
        'riskStatus': 'Urgent',
        'latestPhq9': 22,
        'latestMood': 'หม่นมาก',
        'averagePhq9': 20.8,
        'cbtCompletionAverage': 28,
        'sosFlags14d': 1,
        'activeCarePlanCount': 1,
        'lastReportAt': now,
      },
      {
        'userId': 'demo-watch',
        'patientCode': 'RJ-DEMO2',
        'displayName': 'Demo Patient 2',
        'initials': 'D2',
        'age': 17,
        'riskStatus': 'Watch',
        'latestPhq9': 15,
        'latestMood': 'เหนื่อย',
        'averagePhq9': 14.4,
        'cbtCompletionAverage': 46,
        'sosFlags14d': 0,
        'activeCarePlanCount': 1,
        'lastReportAt': now,
      },
      {
        'userId': 'demo-stable',
        'patientCode': 'RJ-DEMO3',
        'displayName': 'Demo Patient 3',
        'initials': 'D3',
        'age': 16,
        'riskStatus': 'Stable',
        'latestPhq9': 7,
        'latestMood': 'พอไหว',
        'averagePhq9': 6.9,
        'cbtCompletionAverage': 82,
        'sosFlags14d': 0,
        'activeCarePlanCount': 0,
        'lastReportAt': now,
      },
    ],
    'alerts': [
      {
        'severity': 'red',
        'type': 'PHQ9_HIGH',
        'patientCode': 'RJ-DEMO1',
        'title': 'PHQ-9 severe range',
        'message': 'Latest PHQ-9 = 22. Prioritize clinician review.',
        'createdAt': now,
      },
      {
        'severity': 'red',
        'type': 'SOS_TRIGGERED',
        'patientCode': 'RJ-DEMO1',
        'title': 'SOS used recently',
        'message': 'Review safety plan and support contact.',
        'createdAt': now,
      },
      {
        'severity': 'orange',
        'type': 'PHQ9_WATCH',
        'patientCode': 'RJ-DEMO2',
        'title': 'Mood trend needs follow-up',
        'message': 'PHQ-9 remains moderately severe.',
        'createdAt': now,
      },
      {
        'severity': 'yellow',
        'type': 'LOW_ACTIVITY',
        'patientCode': 'RJ-DEMO2',
        'title': 'CBT quest participation dropped',
        'message': 'Consider low-energy care plan.',
        'createdAt': now,
      },
    ],
    'privacy': {
      'diaryTextHidden': true,
      'deidentifiedPatientCodes': true,
      'note':
          note ??
          'Demo dashboard uses de-identified summary signals only. Raw diary text is hidden.',
    },
  };
}
