import 'package:flutter/material.dart';

import '../../core/auth_session.dart';
import '../../services/rejoy_api_client.dart';

class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  final ReJoyApiClient _client = ReJoyApiClient();
  late Future<Map<String, dynamic>> _dashboardFuture;
  bool _assigning = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _client.fetchClinicalDashboard();
  }

  @override
  void dispose() {
    _client.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _message = null;
      _dashboardFuture = _client.fetchClinicalDashboard();
    });
    await _dashboardFuture;
  }

  Future<void> _assignCarePlan(List<dynamic> patients, String note) async {
    if (_assigning || patients.isEmpty) return;
    final firstPatient = Map<String, dynamic>.from(patients.first as Map);
    final userId = firstPatient['userId']?.toString();
    if (userId == null || userId.isEmpty) return;

    setState(() {
      _assigning = true;
      _message = null;
    });

    try {
      await _client.createCarePlan(
        userId: userId,
        title: 'โน้ตติดตามผู้ป่วย',
        focusArea: 'behavioral_activation',
        recommendedQuestEnergy: 'low',
        note: note,
      );
      if (!mounted) return;
      setState(() {
        _assigning = false;
        _message =
            'บันทึกโน้ตให้ ${firstPatient['patientCode'] ?? 'ผู้ป่วย'} แล้ว';
        _dashboardFuture = _client.fetchClinicalDashboard();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _assigning = false;
        _message = 'บันทึกโน้ตไม่สำเร็จ: $error';
      });
    }
  }

  Future<void> _signOut() async {
    try {
      await _client.logout();
    } catch (_) {
      // Local sign-out still matters if the cloud session is already expired.
    }
    await AuthSession.clear();
    ReJoyApiClient.clearCache();
    if (!mounted) return;
    widget.onSignedOut();
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
          child: FutureBuilder<Map<String, dynamic>>(
            future: _dashboardFuture,
            builder: (context, snapshot) {
              final data = snapshot.data ?? const <String, dynamic>{};
              final totals = data['totals'] is Map
                  ? Map<String, dynamic>.from(data['totals'] as Map)
                  : <String, dynamic>{};
              final patients = data['patients'] is List
                  ? List<dynamic>.from(data['patients'] as List)
                  : <dynamic>[];
              final alerts = data['alerts'] is List
                  ? List<dynamic>.from(data['alerts'] as List)
                  : <dynamic>[];
              final dashboardPatients = patients.isEmpty
                  ? _demoPatients
                  : patients;
              final dashboardAlerts = alerts.isEmpty ? _demoAlerts : alerts;
              final dashboardTotals = patients.isEmpty ? _demoTotals : totals;

              return ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  _Header(onRefresh: _refresh, onSignOut: _signOut),
                  const SizedBox(height: 14),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const _Panel(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Text('กำลังโหลดแดชบอร์ดคลินิก...'),
                          ],
                        ),
                      ),
                    )
                  else if (snapshot.hasError)
                    _Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ยังโหลดแดชบอร์ดไม่ได้',
                            style: TextStyle(
                              color: Color(0xFF17343C),
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            snapshot.error.toString(),
                            style: const TextStyle(color: Color(0xFF607A81)),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _refresh,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('ลองโหลดใหม่'),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    _MetricGrid(totals: dashboardTotals),
                    const SizedBox(height: 14),
                    _PatientPanel(
                      patients: dashboardPatients,
                      isDemo: patients.isEmpty,
                    ),
                    const SizedBox(height: 14),
                    _AlertPanel(
                      alerts: dashboardAlerts,
                      patients: dashboardPatients,
                      isDemo: alerts.isEmpty,
                    ),
                    const SizedBox(height: 14),
                    _CarePlanPanel(
                      assigning: _assigning,
                      hasPatient: dashboardPatients.isNotEmpty,
                      isDemo: patients.isEmpty,
                      message: _message,
                      onAssign: (note) => patients.isEmpty
                          ? setState(() {
                              _message = 'บันทึกโน้ตจำลองแล้ว: $note';
                            })
                          : _assignCarePlan(patients, note),
                    ),
                    const SizedBox(height: 14),
                    const _PrivacyNote(),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

const Map<String, dynamic> _demoTotals = {
  'stable': 1,
  'watch': 1,
  'urgent': 1,
  'alerts': 4,
};

const List<Map<String, dynamic>> _demoPatients = [
  {
    'userId': 'demo-patient-heavy-01',
    'patientCode': 'RJ-D001',
    'displayName': 'ผู้ป่วยจำลอง: น้ำฝน',
    'initials': 'นฝ',
    'age': 16,
    'riskStatus': 'Urgent',
    'latestPhq9': 23,
    'latestMood': 'ซึมเศร้ารุนแรง',
    'cbtCompletionAverage': 12,
    'sosFlags': 3,
    'lastContact': 'พบล่าสุด 23 ก.ค. 2026 เวลา 09:30 น.',
    'clinicalSummary':
        'ช่วง 5 วันล่าสุด PHQ-9 อยู่ระดับสูง นอนยาก พลังงานต่ำ และมี SOS flag ควรถามเรื่องความปลอดภัยก่อน',
    'currentMeds': 'ติดตามการใช้ยากับผู้เชี่ยวชาญ',
    'allergies': 'ยังไม่พบข้อมูลแพ้ยา',
    'emergencyContact': 'ผู้ปกครอง: 08x-xxx-xxxx',
  },
  {
    'userId': 'demo-patient-watch-02',
    'patientCode': 'RJ-D002',
    'displayName': 'ผู้ป่วยจำลอง: ภูมิ',
    'initials': 'ภ',
    'age': 17,
    'riskStatus': 'Watch',
    'latestPhq9': 14,
    'latestMood': 'เหนื่อยง่าย',
    'cbtCompletionAverage': 46,
    'sosFlags': 0,
    'lastContact': 'พบล่าสุด 21 ก.ค. 2026 เวลา 14:10 น.',
    'clinicalSummary':
        'อารมณ์ต่ำเป็นช่วง ๆ แต่ยังทำกิจกรรมได้บางส่วน ควรถามเรื่องการนอนและภาระเรียน',
    'currentMeds': 'ไม่มีข้อมูลยาปัจจุบัน',
    'allergies': 'ไม่ระบุ',
    'emergencyContact': 'ผู้ปกครอง: 08x-xxx-xxxx',
  },
  {
    'userId': 'demo-patient-stable-03',
    'patientCode': 'RJ-D003',
    'displayName': 'ผู้ป่วยจำลอง: มินท์',
    'initials': 'ม',
    'age': 15,
    'riskStatus': 'Stable',
    'latestPhq9': 6,
    'latestMood': 'พอไหว',
    'cbtCompletionAverage': 78,
    'sosFlags': 0,
    'lastContact': 'พบล่าสุด 19 ก.ค. 2026 เวลา 11:00 น.',
    'clinicalSummary':
        'แนวโน้มคงที่ ทำเควสสม่ำเสมอ ไม่มี SOS flag ในช่วงล่าสุด',
    'currentMeds': 'ไม่มีข้อมูลยาปัจจุบัน',
    'allergies': 'ไม่ระบุ',
    'emergencyContact': 'ผู้ปกครอง: 08x-xxx-xxxx',
  },
];

const List<Map<String, dynamic>> _demoAlerts = [
  {
    'patientCode': 'RJ-D001',
    'title': 'PHQ-9 อยู่ในระดับรุนแรง ควรถามเรื่องความปลอดภัยวันนี้',
  },
  {'patientCode': 'RJ-D001', 'title': 'มี SOS flag 3 ครั้งในช่วงรายงานล่าสุด'},
  {
    'patientCode': 'RJ-D001',
    'title': 'CBT completion ต่ำ ควรถามเรื่องพลังงาน นอน และแรงจูงใจ',
  },
  {
    'patientCode': 'RJ-D002',
    'title': 'Mood ต่ำต่อเนื่อง ควรติดตามก่อนถึงวันนัด',
  },
];

class _Header extends StatelessWidget {
  const _Header({required this.onRefresh, required this.onSignOut});

  final Future<void> Function() onRefresh;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF72B8AD),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF31525A).withValues(alpha: 0.14),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.health_and_safety_rounded,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'แดชบอร์ดคลินิก',
                style: TextStyle(
                  color: Color(0xFF17343C),
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'สำหรับผู้ป่วยที่หมอดูแลเท่านั้น ระบบไม่เปิดข้อความไดอารี่ดิบ',
                style: TextStyle(color: Color(0xFF607A81), height: 1.25),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: onSignOut,
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.totals});

  final Map<String, dynamic> totals;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _MetricCard('คงที่', totals['stable'], const Color(0xFF72B8AD)),
        _MetricCard('เฝ้าระวัง', totals['watch'], const Color(0xFFE2AE43)),
        _MetricCard('เร่งด่วน', totals['urgent'], const Color(0xFFDB6B5D)),
        _MetricCard('แจ้งเตือน', totals['alerts'], const Color(0xFF5D6C89)),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.label, this.value, this.color);

  final String label;
  final dynamic value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Text(
            '${value ?? 0}',
            style: TextStyle(
              color: color,
              fontSize: 27,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Color(0xFF607A81))),
        ],
      ),
    );
  }
}

class _PatientPanel extends StatefulWidget {
  const _PatientPanel({required this.patients, required this.isDemo});

  final List<dynamic> patients;
  final bool isDemo;

  @override
  State<_PatientPanel> createState() => _PatientPanelState();
}

class _PatientPanelState extends State<_PatientPanel> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredPatients = widget.patients.where((patient) {
      if (patient is! Map) return false;
      final item = Map<String, dynamic>.from(patient);
      final target = [
        item['patientCode'],
        item['displayName'],
        item['initials'],
        item['userId'],
      ].whereType<Object>().join(' ').toLowerCase();
      return target.contains(_query.toLowerCase());
    }).toList();

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelTitle(
            widget.isDemo
                ? 'ผู้ป่วยจำลองในความดูแล'
                : 'ผู้ป่วยในความดูแลของคุณ',
          ),
          if (widget.isDemo) ...[
            const SizedBox(height: 6),
            const _DemoBadge(
              text:
                  'ข้อมูลชุดนี้เป็นข้อมูลจำลองสำหรับพรีเซ็น เพื่อโชว์ workflow หมอ',
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value.trim()),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              labelText: 'ค้นหา ID หรือชื่อคนไข้',
              hintText: 'เช่น RJ-D001, น้ำฝน, ภูมิ',
              filled: true,
              fillColor: const Color(0xFFF6FBF8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFCDE2DE)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFCDE2DE)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: Color(0xFF72B8AD),
                  width: 1.6,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (widget.patients.isEmpty)
            const _EmptyState(
              text:
                  'ยังไม่มีผู้ป่วยที่ถูกมอบหมาย ในระบบจริง admin โรงพยาบาลจะเพิ่มผู้ป่วยให้บัญชีหมอแต่ละคน',
            )
          else if (filteredPatients.isEmpty)
            const _EmptyState(text: 'ไม่พบคนไข้ตามคำค้นหานี้')
          else
            ...filteredPatients.take(10).map((patient) {
              final item = Map<String, dynamic>.from(patient as Map);
              return _PatientRow(
                patient: item,
                onTap: () => _showPatientDetails(context, item),
              );
            }),
        ],
      ),
    );
  }

  void _showPatientDetails(BuildContext context, Map<String, dynamic> patient) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PatientDetailSheet(patient: patient),
    );
  }
}

class _PatientRow extends StatelessWidget {
  const _PatientRow({required this.patient, required this.onTap});

  final Map<String, dynamic> patient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = patient['riskStatus']?.toString() ?? 'Stable';
    final color = switch (status) {
      'Urgent' => const Color(0xFFDB6B5D),
      'Watch' => const Color(0xFFE2AE43),
      _ => const Color(0xFF72B8AD),
    };
    final statusLabel = switch (status) {
      'Urgent' => 'เร่งด่วน',
      'Watch' => 'เฝ้าระวัง',
      _ => 'คงที่',
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF4F1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.16),
              child: Text(
                patient['initials']?.toString() ?? 'RJ',
                style: TextStyle(color: color, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${patient['displayName'] ?? patient['patientCode'] ?? 'Patient'}',
                    style: const TextStyle(
                      color: Color(0xFF17343C),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'อายุ ${patient['age'] ?? '-'} ปี • PHQ-9 ${patient['latestPhq9'] ?? 0} • CBT ${patient['cbtCompletionAverage'] ?? 0}% • SOS ${patient['sosFlags'] ?? 0}',
                    style: const TextStyle(color: Color(0xFF607A81)),
                  ),
                  Text(
                    'อารมณ์ล่าสุด: ${patient['latestMood'] ?? 'ยังไม่มีข้อมูล'}',
                    style: const TextStyle(
                      color: Color(0xFF6F8580),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(color: color, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF607A81)),
          ],
        ),
      ),
    );
  }
}

class _PatientDetailSheet extends StatelessWidget {
  const _PatientDetailSheet({required this.patient});

  final Map<String, dynamic> patient;

  @override
  Widget build(BuildContext context) {
    final status = patient['riskStatus']?.toString() ?? 'Stable';
    final statusLabel = switch (status) {
      'Urgent' => 'เร่งด่วน',
      'Watch' => 'เฝ้าระวัง',
      _ => 'คงที่',
    };
    final statusColor = switch (status) {
      'Urgent' => const Color(0xFFDB6B5D),
      'Watch' => const Color(0xFFE2AE43),
      _ => const Color(0xFF72B8AD),
    };

    return DraggableScrollableSheet(
      initialChildSize: 0.74,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          decoration: const BoxDecoration(
            color: Color(0xFFF7FBF7),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCDE2DE),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: statusColor.withValues(alpha: 0.16),
                    child: Text(
                      patient['initials']?.toString() ?? 'RJ',
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${patient['displayName'] ?? 'ผู้ป่วย'}',
                          style: const TextStyle(
                            color: Color(0xFF17343C),
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${patient['patientCode'] ?? '-'} • อายุ ${patient['age'] ?? '-'} ปี',
                          style: const TextStyle(color: Color(0xFF607A81)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DetailCard(
                title: 'ครั้งล่าสุดที่พบ/ติดตาม',
                icon: Icons.schedule_rounded,
                child: Text(
                  patient['lastContact']?.toString() ??
                      'ยังไม่มีข้อมูลการพบล่าสุด',
                  style: const TextStyle(color: Color(0xFF31525A)),
                ),
              ),
              const SizedBox(height: 10),
              _DetailCard(
                title: 'Clinical snapshot',
                icon: Icons.monitor_heart_rounded,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MiniMetric('PHQ-9', '${patient['latestPhq9'] ?? 0}/27'),
                    _MiniMetric(
                      'CBT',
                      '${patient['cbtCompletionAverage'] ?? 0}%',
                    ),
                    _MiniMetric('SOS', '${patient['sosFlags'] ?? 0} ครั้ง'),
                    _MiniMetric(
                      'Mood',
                      patient['latestMood']?.toString() ?? 'ยังไม่มีข้อมูล',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _DetailCard(
                title: 'ประวัติย่อที่ควรถามต่อ',
                icon: Icons.fact_check_rounded,
                child: Text(
                  patient['clinicalSummary']?.toString() ??
                      'ยังไม่มีสรุปแนวโน้มล่าสุด',
                  style: const TextStyle(
                    color: Color(0xFF31525A),
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _DetailCard(
                title: 'ข้อมูลส่วนตัวทางการแพทย์',
                icon: Icons.medical_information_rounded,
                child: Column(
                  children: [
                    _InfoLine(
                      label: 'ยาที่ติดตาม',
                      value:
                          patient['currentMeds']?.toString() ??
                          'ยังไม่มีข้อมูล',
                    ),
                    _InfoLine(
                      label: 'ประวัติแพ้ยา',
                      value:
                          patient['allergies']?.toString() ?? 'ยังไม่มีข้อมูล',
                    ),
                    _InfoLine(
                      label: 'ติดต่อฉุกเฉิน',
                      value:
                          patient['emergencyContact']?.toString() ??
                          'ยังไม่มีข้อมูล',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _DoctorQuestComposer(
                patientName:
                    patient['displayName']?.toString() ?? 'ผู้ป่วยรายนี้',
                patientId: patient['userId']?.toString(),
              ),
              const SizedBox(height: 10),
              const _DetailCard(
                title: 'ขอบเขตข้อมูล',
                icon: Icons.privacy_tip_rounded,
                child: Text(
                  'แดชบอร์ดนี้แสดงเฉพาะแนวโน้มและข้อมูลสรุปเพื่อช่วยเตรียมคำถามก่อนพบผู้ป่วย โดยไม่เปิดข้อความไดอารี่ดิบ',
                  style: TextStyle(color: Color(0xFF607A81), height: 1.35),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFCDE2DE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF72B8AD), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF17343C),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _DoctorQuestComposer extends StatefulWidget {
  const _DoctorQuestComposer({required this.patientName, this.patientId});

  final String patientName;
  final String? patientId;

  @override
  State<_DoctorQuestComposer> createState() => _DoctorQuestComposerState();
}

class _DoctorQuestComposerState extends State<_DoctorQuestComposer> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  String _energyLevel = 'low';
  String? _savedTitle;
  String? _savedDescription;
  String? _savedEnergyLevel;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: 'เดินรับแสงอ่อน 5 นาที');
    _descriptionController = TextEditingController(
      text:
          'ถ้าวันนี้ยังไหว ลองออกไปยืนรับแสงหรือเปิดม่านสั้น ๆ แล้วกลับมาบันทึกความรู้สึกหนึ่งประโยค',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _sendQuestToPatient() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณาพิมพ์ชื่อเควสก่อน')));
      return;
    }
    if (_saving) return;

    final resolvedDescription = description.isEmpty
        ? 'ทำเท่าที่ไหว และหยุดพักได้ทันทีถ้าร่างกายไม่พร้อม'
        : description;

    setState(() => _saving = true);
    final client = ReJoyApiClient();
    try {
      await client.createDoctorQuestForPatient(
        userId: widget.patientId,
        title: title,
        description: resolvedDescription,
        energyLevel: _energyLevel,
      );
      if (!mounted) return;
      setState(() {
        _savedTitle = title;
        _savedDescription = resolvedDescription;
        _savedEnergyLevel = _energyLevel;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ส่งเควสให้ ${widget.patientName} แล้ว คนไข้จะเห็นในหน้า Missions ทันที',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ส่งเควสไม่สำเร็จ: $error')));
    } finally {
      client.dispose();
    }
  }

  void _saveQuest() {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณาพิมพ์ชื่อเควสก่อน')));
      return;
    }

    setState(() {
      _savedTitle = title;
      _savedDescription = description.isEmpty
          ? 'ทำเท่าที่ไหว และหยุดพักได้ทันทีถ้าร่างกายไม่พร้อม'
          : description;
      _savedEnergyLevel = _energyLevel;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('เพิ่มเควสให้ ${widget.patientName} แล้ว')),
    );
  }

  String _energyLabel(String value) {
    return switch (value) {
      'medium' => 'พลังงานปานกลาง',
      'high' => 'พลังงานสูง',
      _ => 'พลังงานต่ำ',
    };
  }

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      title: 'เควสจากหมอ',
      icon: Icons.add_task_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'เขียนภารกิจเฉพาะบุคคลให้คนไข้เห็นเป็นการ์ดในหน้าเควส ภารกิจนี้เป็นคำแนะนำเชิงพฤติกรรม ไม่ใช่คำสั่งจ่ายยา และคนไข้จะกดปฏิเสธไม่ได้',
            style: TextStyle(color: Color(0xFF607A81), height: 1.35),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            style: const TextStyle(
              color: Color(0xFF17343C),
              fontWeight: FontWeight.w800,
            ),
            decoration: _questInputDecoration(
              label: 'ชื่อเควส',
              hint: 'เช่น เดินรับแสงอ่อน 5 นาที',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _descriptionController,
            minLines: 2,
            maxLines: 4,
            style: const TextStyle(
              color: Color(0xFF17343C),
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
            decoration: _questInputDecoration(
              label: 'รายละเอียดที่คนไข้จะเห็น',
              hint: 'เขียนด้วยภาษานุ่มนวล ไม่กดดัน',
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _energyLevel,
            style: const TextStyle(
              color: Color(0xFF17343C),
              fontWeight: FontWeight.w800,
            ),
            decoration: _questInputDecoration(
              label: 'ระดับพลังงานที่เหมาะกับเควส',
              hint: '',
            ),
            items: const [
              DropdownMenuItem(value: 'low', child: Text('พลังงานต่ำ')),
              DropdownMenuItem(value: 'medium', child: Text('พลังงานปานกลาง')),
              DropdownMenuItem(value: 'high', child: Text('พลังงานสูง')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _energyLevel = value);
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _sendQuestToPatient,
              icon: Icon(_saving ? Icons.sync_rounded : Icons.lock_rounded),
              label: Text(
                _saving ? 'กำลังส่งเควสให้คนไข้...' : 'บันทึกและส่งเควสจากหมอ',
              ),
            ),
          ),
          if (_savedTitle != null) ...[
            const SizedBox(height: 12),
            _DoctorQuestPreview(
              patientName: widget.patientName,
              title: _savedTitle!,
              description: _savedDescription!,
              energyLabel: _energyLabel(_savedEnergyLevel ?? _energyLevel),
            ),
          ],
        ],
      ),
    );
  }
}

InputDecoration _questInputDecoration({
  required String label,
  required String hint,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint.isEmpty ? null : hint,
    filled: true,
    fillColor: Colors.white,
    labelStyle: const TextStyle(
      color: Color(0xFF244A50),
      fontWeight: FontWeight.w800,
    ),
    floatingLabelStyle: const TextStyle(
      color: Color(0xFF328F84),
      fontWeight: FontWeight.w900,
    ),
    hintStyle: const TextStyle(
      color: Color(0xFF6E888E),
      fontWeight: FontWeight.w700,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Color(0xFF9FCFC6), width: 1.2),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Color(0xFF58AFA3), width: 1.8),
    ),
  );
}

class _DoctorQuestPreview extends StatelessWidget {
  const _DoctorQuestPreview({
    required this.patientName,
    required this.title,
    required this.description,
    required this.energyLabel,
  });

  final String patientName;
  final String title;
  final String description;
  final String energyLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6B24D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  color: Color(0xFFE2AE43),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'การ์ดเควสสำหรับ $patientName',
                  style: const TextStyle(
                    color: Color(0xFF17343C),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF17343C),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'ปฏิเสธไม่ได้',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF17343C),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(color: Color(0xFF31525A), height: 1.35),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DoctorQuestChip(label: energyLabel),
              const _DoctorQuestChip(label: 'Doctor assigned'),
              const _DoctorQuestChip(label: 'No reject'),
            ],
          ),
        ],
      ),
    );
  }
}

class _DoctorQuestChip extends StatelessWidget {
  const _DoctorQuestChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE6D1A4)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF6F5B1E),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4F1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF607A81), fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF17343C),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF607A81)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF17343C),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertPanel extends StatelessWidget {
  const _AlertPanel({
    required this.alerts,
    required this.patients,
    required this.isDemo,
  });

  final List<dynamic> alerts;
  final List<dynamic> patients;
  final bool isDemo;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelTitle('คิวแจ้งเตือนทางคลินิก'),
          const SizedBox(height: 6),
          const Text(
            'ช่วยให้หมอเห็นเคสที่ควรถามต่อก่อน เช่น SOS, PHQ-9 สูง หรือทำกิจกรรมน้อยลง',
            style: TextStyle(color: Color(0xFF607A81), height: 1.35),
          ),
          if (isDemo) ...[
            const SizedBox(height: 8),
            const _DemoBadge(text: 'กำลังแสดง alert จำลองสำหรับการพรีเซ็น'),
          ],
          const SizedBox(height: 10),
          if (alerts.isEmpty)
            const _EmptyState(text: 'ยังไม่มีสัญญาณเร่งด่วนในตอนนี้')
          else
            ...alerts.take(6).map((alert) {
              final item = Map<String, dynamic>.from(alert as Map);
              final patientCode = item['patientCode']?.toString() ?? 'RJ';
              final patientName = _patientNameForCode(patientCode);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  '$patientName ($patientCode) • ${item['title'] ?? 'ควรตรวจสอบ'}',
                  style: const TextStyle(
                    color: Color(0xFF17343C),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  String _patientNameForCode(String patientCode) {
    for (final patient in patients) {
      if (patient is! Map) continue;
      final item = Map<String, dynamic>.from(patient);
      if (item['patientCode']?.toString() == patientCode) {
        return item['displayName']?.toString() ?? patientCode;
      }
    }
    return 'ผู้ป่วย';
  }
}

class _CarePlanPanel extends StatefulWidget {
  const _CarePlanPanel({
    required this.assigning,
    required this.hasPatient,
    required this.isDemo,
    required this.message,
    required this.onAssign,
  });

  final bool assigning;
  final bool hasPatient;
  final bool isDemo;
  final String? message;
  final ValueChanged<String> onAssign;

  @override
  State<_CarePlanPanel> createState() => _CarePlanPanelState();
}

class _CarePlanPanelState extends State<_CarePlanPanel> {
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(
      text:
          'ติดตามการนอน ความอยากอาหาร ระดับพลังงาน และถามเรื่องความปลอดภัยอย่างนุ่มนวล',
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelTitle('โน้ตหมอ'),
          const SizedBox(height: 8),
          const Text(
            'พื้นที่นี้ใช้จดโน้ตติดตามผู้ป่วยสำหรับทีมรักษา ไม่ใช่คำสั่งจ่ายยา และไม่ใช่ข้อความไดอารี่ดิบของคนไข้',
            style: TextStyle(
              color: Color(0xFF31525A),
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            minLines: 4,
            maxLines: 6,
            textInputAction: TextInputAction.newline,
            style: const TextStyle(
              color: Color(0xFF17343C),
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
            decoration: InputDecoration(
              labelText: widget.isDemo
                  ? 'พิมพ์โน้ตจำลอง'
                  : 'พิมพ์โน้ตสำหรับผู้ป่วย',
              hintText:
                  'เช่น วันนี้ควรถามเรื่องการนอน ความอยากอาหาร พลังงาน และความปลอดภัย',
              alignLabelWithHint: true,
              labelStyle: const TextStyle(
                color: Color(0xFF31525A),
                fontWeight: FontWeight.w900,
              ),
              hintStyle: const TextStyle(
                color: Color(0xFF8AA09B),
                fontWeight: FontWeight.w600,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: Color(0xFF72B8AD),
                  width: 1.4,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: Color(0xFF72B8AD),
                  width: 1.4,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: Color(0xFF72B8AD),
                  width: 1.6,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: widget.hasPatient && !widget.assigning
                ? () {
                    final note = _noteController.text.trim();
                    if (note.isEmpty) return;
                    widget.onAssign(note);
                  }
                : null,
            icon: widget.assigning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.assignment_turned_in_rounded),
            label: Text(
              widget.isDemo ? 'บันทึกโน้ตจำลอง' : 'บันทึกโน้ตผู้ป่วย',
            ),
          ),
          if (widget.message != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.message!,
              style: const TextStyle(
                color: Color(0xFF31525A),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return const _Panel(
      child: Text(
        'ขอบเขตความปลอดภัย: แดชบอร์ดนี้ช่วยคัดกรองและสรุปแนวโน้ม ไม่ใช่ระบบรับแจ้งเหตุฉุกเฉิน 24 ชั่วโมง และจะไม่แสดงข้อความไดอารี่ดิบในคิวของโรงพยาบาล',
        style: TextStyle(color: Color(0xFF607A81), height: 1.35),
      ),
    );
  }
}

class _DemoBadge extends StatelessWidget {
  const _DemoBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5DA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8C86D)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.science_rounded, size: 18, color: Color(0xFFE2AE43)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF6F5B1E),
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFCDE2DE)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF31525A).withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF17343C),
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4F1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Color(0xFF607A81), height: 1.35),
      ),
    );
  }
}
