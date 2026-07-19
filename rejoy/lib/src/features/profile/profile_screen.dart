import 'package:flutter/material.dart';

import '../../core/api_config.dart';
import '../../core/auth_session.dart';
import '../../core/rejoy_session.dart';
import '../../services/doctor_pdf_service.dart';
import '../../services/audit_log_service.dart';
import '../../services/explainable_scoring_service.dart';
import '../../services/performance_telemetry_service.dart';
import '../../services/rejoy_api_client.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.session,
    required this.onSignedOut,
  });

  final ReJoySession session;
  final VoidCallback onSignedOut;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ReJoyApiClient _client;
  final DoctorPdfService _pdfService = const DoctorPdfService();
  final AuditLogService _auditLog = const AuditLogService();
  final ExplainableScoringService _explainableScoring =
      const ExplainableScoringService();

  Future<_ProfileData>? _profileFuture;
  bool _exportingPdf = false;
  bool _showApiSettings = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _client = ReJoyApiClient();
    _profileFuture = _loadProfile();
  }

  @override
  void dispose() {
    _client.dispose();
    super.dispose();
  }

  Future<_ProfileData> _loadProfile() async {
    final payload = await _client.fetchActiveClinicalProfile();
    final sorted = payload.reports.toList()
      ..sort((a, b) {
        final aDate = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
    final cutoff = DateTime.now().subtract(const Duration(days: 14));
    final recent = sorted
        .where((report) => report.date == null || report.date!.isAfter(cutoff))
        .take(14)
        .toList();
    return _ProfileData(user: payload.user, reports: recent);
  }

  Future<void> _refresh() async {
    setState(() {
      _profileFuture = _loadProfile();
    });
    await _profileFuture;
  }

  Future<void> _exportDoctorPdf(_ProfileData data) async {
    if (_exportingPdf) return;

    setState(() {
      _exportingPdf = true;
      _statusMessage = 'กำลังเตรียม Clinical PDF สำหรับแพทย์...';
    });

    try {
      var reports = data.reports;
      if (reports.isEmpty) {
        await _client.generateReportForUser(data.user.id);
        reports = await _client.fetchReports(userId: data.user.id);
      }
      if (reports.isEmpty) {
        throw StateError('ยังไม่มี report สำหรับ export');
      }

      final sorted = reports.toList()
        ..sort((a, b) {
          final aDate = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });

      await _pdfService.printDoctorReportPdf(
        user: data.user,
        report: sorted.first,
        reports: sorted.take(14).toList(),
      );
      await _auditLog.record(type: 'PDF_EXPORTED', detail: 'doctor_report');

      if (!mounted) return;
      setState(() {
        _statusMessage = 'Export PDF สำหรับแพทย์เรียบร้อย';
        _exportingPdf = false;
        _profileFuture = _loadProfile();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Export PDF ไม่สำเร็จ: $error';
        _exportingPdf = false;
      });
    }
  }

  Future<void> _openEditSoulProfile(BackendUser user) async {
    final firstName = TextEditingController(text: user.firstName);
    final surname = TextEditingController(text: user.surname);
    final age = TextEditingController(text: '${user.age}');
    final allergies = TextEditingController(text: user.allergies.join(', '));
    final medications = TextEditingController(
      text: user.currentMedications.join(', '),
    );
    final emergencyContacts = TextEditingController(
      text: user.emergencyContactNumbers.join(', '),
    );
    final medicalHistory = TextEditingController(text: user.medicalHistory);

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Soul Profile'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: firstName,
                    decoration: const InputDecoration(labelText: 'First name'),
                  ),
                  TextField(
                    controller: surname,
                    decoration: const InputDecoration(labelText: 'Surname'),
                  ),
                  TextField(
                    controller: age,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Age'),
                  ),
                  TextField(
                    controller: allergies,
                    decoration: const InputDecoration(
                      labelText: 'Allergies',
                      helperText: 'Separate items with commas',
                    ),
                  ),
                  TextField(
                    controller: medications,
                    decoration: const InputDecoration(
                      labelText: 'Current medications',
                      helperText: 'Separate items with commas',
                    ),
                  ),
                  TextField(
                    controller: emergencyContacts,
                    decoration: const InputDecoration(
                      labelText: 'Emergency contacts',
                      helperText: 'Separate items with commas',
                    ),
                  ),
                  TextField(
                    controller: medicalHistory,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Medical history',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (saved != true) {
      firstName.dispose();
      surname.dispose();
      age.dispose();
      allergies.dispose();
      medications.dispose();
      emergencyContacts.dispose();
      medicalHistory.dispose();
      return;
    }

    try {
      await _client.updateUserProfile(
        userId: user.id,
        firstName: firstName.text.trim().isEmpty
            ? user.firstName
            : firstName.text.trim(),
        surname: surname.text.trim().isEmpty
            ? user.surname
            : surname.text.trim(),
        age: int.tryParse(age.text.trim()) ?? user.age,
        allergies: _splitProfileList(allergies.text),
        currentMedications: _splitProfileList(medications.text),
        emergencyContactNumbers: _splitProfileList(emergencyContacts.text),
        medicalHistory: medicalHistory.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Soul Profile updated.';
        _profileFuture = _loadProfile();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Could not update Soul Profile: $error';
      });
    } finally {
      firstName.dispose();
      surname.dispose();
      age.dispose();
      allergies.dispose();
      medications.dispose();
      emergencyContacts.dispose();
      medicalHistory.dispose();
    }
  }

  List<String> _splitProfileList(String value) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE8F6F4), Color(0xFFFFF8EC)],
        ),
      ),
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<_ProfileData>(
            future: _profileFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _LoadingList();
              }
              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    _ApiSettingsCard(
                      onSaved: _refresh,
                      onSignedOut: widget.onSignedOut,
                      initiallyExpanded: true,
                    ),
                    const SizedBox(height: 14),
                    _StatusCard(
                      title: 'โหลดข้อมูลโปรไฟล์ไม่สำเร็จ',
                      subtitle: snapshot.error.toString(),
                    ),
                  ],
                );
              }

              final data = snapshot.data!;
              final summary = _ClinicalSummary.fromReports(data.reports);

              return ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton.filledTonal(
                      tooltip: 'ตั้งค่า API',
                      onPressed: () {
                        setState(() {
                          _showApiSettings = !_showApiSettings;
                        });
                      },
                      icon: Icon(
                        _showApiSettings
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.tune_rounded,
                      ),
                    ),
                  ),
                  if (_showApiSettings) ...[
                    const SizedBox(height: 10),
                    _ApiSettingsCard(
                      onSaved: _refresh,
                      onSignedOut: widget.onSignedOut,
                      initiallyExpanded: true,
                    ),
                  ],
                  const SizedBox(height: 10),
                  _HeroCard(
                    user: data.user,
                    reportCount: data.reports.length,
                    onExportPdf: () => _exportDoctorPdf(data),
                    exportingPdf: _exportingPdf,
                  ),
                  const SizedBox(height: 14),
                  const _TictaReadinessCard(),
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 12),
                    _StatusCard(title: 'สถานะ', subtitle: _statusMessage!),
                  ],
                  const SizedBox(height: 14),
                  _SoulProfileCard(
                    user: data.user,
                    onEdit: () => _openEditSoulProfile(data.user),
                  ),
                  const SizedBox(height: 14),
                  _ClinicalSnapshotCard(summary: summary),
                  const SizedBox(height: 14),
                  _ExplainableScoringCard(
                    explanation: _explainableScoring.explain(
                      averagePhq9: summary.averagePhq9,
                      moodScore: summary.averageMatrix.moodScore,
                      somaticScore: summary.averageMatrix.somaticScore,
                      behavioralScore: summary.averageMatrix.behavioralScore,
                      cbtRate: summary.averageCbtRate,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _TrendChartCard(reports: data.reports),
                  const SizedBox(height: 14),
                  _MatrixCard(summary: summary),
                  const SizedBox(height: 14),
                  const _AuditLogCard(),
                  const SizedBox(height: 14),
                  const _TelemetryCard(),
                  const SizedBox(height: 14),
                  const _ClinicalDisclaimerCard(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ApiSettingsCard extends StatefulWidget {
  const _ApiSettingsCard({
    required this.onSaved,
    required this.onSignedOut,
    this.initiallyExpanded = false,
  });

  final Future<void> Function() onSaved;
  final VoidCallback onSignedOut;
  final bool initiallyExpanded;

  @override
  State<_ApiSettingsCard> createState() => _ApiSettingsCardState();
}

class _ApiSettingsCardState extends State<_ApiSettingsCard> {
  late final TextEditingController _controller;
  final ReJoyApiClient _client = ReJoyApiClient();
  late bool _expanded;
  bool _testing = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _controller = TextEditingController(text: ApiConfig.configuredBaseUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    _client.dispose();
    super.dispose();
  }

  Future<void> _testAndSave() async {
    final value = _controller.text.trim();
    if (value.isEmpty || !value.startsWith(RegExp(r'https?://'))) {
      setState(() {
        _message = 'ใส่ URL แบบ http:// หรือ https:// ก่อนนะ';
      });
      return;
    }

    setState(() {
      _testing = true;
      _message = 'กำลังทดสอบ backend...';
    });

    try {
      await ApiConfig.saveBaseUrlOverride(value);
      ReJoyApiClient.clearCache();
      final health = await _client.fetchHealth();
      await widget.onSaved();
      if (!mounted) return;
      setState(() {
        _testing = false;
        _message = 'เชื่อมต่อสำเร็จ: ${health.service} / DB ${health.database}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _message = 'ยังเชื่อมไม่ได้: $error';
      });
    }
  }

  Future<void> _reset() async {
    await ApiConfig.clearBaseUrlOverride();
    ReJoyApiClient.clearCache();
    _controller.text = ApiConfig.configuredBaseUrl;
    await widget.onSaved();
    if (!mounted) return;
    setState(() {
      _message = 'ล้างค่า override แล้ว ใช้ค่า default ของ build';
    });
  }

  Future<void> _signOut() async {
    final client = ReJoyApiClient();
    try {
      await client.logout();
    } catch (_) {
      // Local sign-out should still work if the backend is offline.
    } finally {
      client.dispose();
    }
    await AuthSession.clear();
    ReJoyApiClient.clearCache();
    if (!mounted) return;
    widget.onSignedOut();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDCEFEB)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5F9B91).withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_sync_rounded, color: Color(0xFF5F9B91)),
              const SizedBox(width: 8),
              Expanded(
                child: const Text(
                  'Backend / Cloud API',
                  style: TextStyle(
                    color: Color(0xFF17343C),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton.filledTonal(
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.tune_rounded,
                ),
                tooltip: _expanded ? 'ซ่อนการตั้งค่า' : 'ตั้งค่า API',
              ),
            ],
          ),
          if (AuthSession.email != null) ...[
            const SizedBox(height: 8),
            Text(
              'ล็อกอินอยู่: ${AuthSession.email}',
              style: const TextStyle(
                color: Color(0xFF31525A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (!_expanded) ...[
            const SizedBox(height: 8),
            const Text(
              'แตะปุ่มด้านขวาเมื่อจำเป็นต้องเปลี่ยน backend หรือออกจากระบบ',
              style: TextStyle(color: Color(0xFF607A81), height: 1.35),
            ),
          ],
          if (_expanded) ...[
            const SizedBox(height: 12),
            const Text(
              'ใช้ตั้ง URL backend จากมือถือได้เลย เช่น URL cloud หรือ IP คอมในวง Wi-Fi เดียวกัน',
              style: TextStyle(color: Color(0xFF607A81), height: 1.35),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'API Base URL',
                hintText: 'https://rejoy-api.onrender.com',
                filled: true,
                fillColor: const Color(0xFFF8FCFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _testing ? null : _testAndSave,
                    icon: _testing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_rounded),
                    label: Text(_testing ? 'Testing...' : 'Test & Save'),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  onPressed: _testing ? null : _reset,
                  tooltip: 'Reset',
                  icon: const Icon(Icons.restart_alt_rounded),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: _testing ? null : _signOut,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('ออกจากระบบ'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 10),
              Text(
                _message!,
                style: const TextStyle(
                  color: Color(0xFF31525A),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _TictaReadinessCard extends StatelessWidget {
  const _TictaReadinessCard();

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'TICTA Readiness',
      subtitle: 'สรุประบบระดับซอฟต์แวร์จริงที่ ReJoy ใช้โชว์ต่อกรรมการได้ทันที',
      child: const Column(
        children: [
          _ReadinessItem(
            icon: Icons.shield_rounded,
            title: 'Red-Flag Safety',
            detail: 'สแกนคำเสี่ยงก่อนส่ง AI และพาเข้า SOS เมื่อเป็นระดับวิกฤต',
          ),
          _ReadinessItem(
            icon: Icons.verified_user_rounded,
            title: 'Consent & PDPA Gate',
            detail: 'แจ้งข้อจำกัดทางการแพทย์และขอ consent ก่อนเริ่มใช้งาน',
          ),
          _ReadinessItem(
            icon: Icons.psychology_alt_rounded,
            title: 'Explainable Scoring',
            detail: 'อธิบายคะแนน PHQ-9 และ Matrix แบบเข้าใจง่าย ไม่ทำให้ตกใจ',
          ),
          _ReadinessItem(
            icon: Icons.route_rounded,
            title: 'Offline SOS',
            detail: 'คำนวณโรงพยาบาลใกล้สุดด้วย Haversine บนเครื่อง',
          ),
          _ReadinessItem(
            icon: Icons.science_rounded,
            title: 'Demo Sandbox',
            detail: 'จำลองเกาะพายุ เควส สัตว์ และ SOS ให้กรรมการเห็นเร็ว',
          ),
        ],
      ),
    );
  }
}

class _ReadinessItem extends StatelessWidget {
  const _ReadinessItem({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF6F3),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF5F9B91), size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF17343C),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: const TextStyle(color: Color(0xFF607A81), height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.user,
    required this.reportCount,
    required this.onExportPdf,
    required this.exportingPdf,
  });

  final BackendUser user;
  final int reportCount;
  final VoidCallback onExportPdf;
  final bool exportingPdf;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFFCFEDE8), Color(0xFFFFF4DA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5F9B91).withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: Color(0xFF72B8AD),
                child: Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Soul Profile',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF17343C),
                      ),
                    ),
                    Text(
                      '${user.fullName} • อายุ ${user.age} ปี • $reportCount report(s)',
                      style: const TextStyle(color: Color(0xFF547077)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'รวมข้อมูลยา ประวัติแพ้ยา อาการล่าสุด และบันทึกความในใจ เพื่อให้แพทย์ประเมินเร็วขึ้นและลด Recall Bias',
            style: TextStyle(color: Color(0xFF284B52), height: 1.45),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: exportingPdf ? null : onExportPdf,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDCA543),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: exportingPdf
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_rounded),
              label: const Text('พิมพ์ให้หมอ / Export PDF'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoulProfileCard extends StatelessWidget {
  const _SoulProfileCard({required this.user, required this.onEdit});

  final BackendUser user;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '1. ข้อมูลโปรไฟล์ทางการแพทย์',
      subtitle: 'ข้อมูลพื้นฐานที่แพทย์ต้องเห็นก่อนอ่านกราฟ',
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('Edit Soul Profile'),
            ),
          ),
          const SizedBox(height: 8),
          _InfoRow(label: 'ชื่อ', value: user.fullName),
          _InfoRow(label: 'อายุ', value: '${user.age} ปี'),
          _InfoRow(label: 'ยา/อาหารที่แพ้', value: _joinOrDash(user.allergies)),
          _InfoRow(
            label: 'ยาที่ใช้อยู่',
            value: _joinOrDash(user.currentMedications),
          ),
          _InfoRow(
            label: 'ประวัติการรักษา',
            value: user.medicalHistory.isEmpty ? '-' : user.medicalHistory,
          ),
          _InfoRow(
            label: 'เบอร์ติดต่อฉุกเฉิน',
            value: _joinOrDash(user.emergencyContactNumbers),
          ),
        ],
      ),
    );
  }
}

class _ClinicalSnapshotCard extends StatelessWidget {
  const _ClinicalSnapshotCard({required this.summary});

  final _ClinicalSummary summary;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '2. Clinical Snapshot ล่าสุด',
      subtitle: 'สรุปตัวเลขเร็วสำหรับแพทย์ก่อนดูรายละเอียด',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _MetricTile(
            label: 'Avg PHQ-9',
            value: summary.averagePhq9.toStringAsFixed(1),
          ),
          _MetricTile(
            label: 'CBT Rate',
            value: '${summary.averageCbtRate.toStringAsFixed(0)}%',
          ),
          _MetricTile(label: 'Rest days', value: '${summary.restDays}'),
          _MetricTile(label: 'SOS flags', value: '${summary.sosFlags}'),
        ],
      ),
    );
  }
}

class _ExplainableScoringCard extends StatelessWidget {
  const _ExplainableScoringCard({required this.explanation});

  final String explanation;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '3. Explainable Scoring',
      subtitle: 'อธิบายที่มาของคะแนนแบบไม่ทำให้ผู้ใช้ตื่นตระหนก',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF7F4),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFCFE7E1)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.psychology_alt_rounded, color: Color(0xFF5F9B91)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                explanation,
                style: const TextStyle(
                  color: Color(0xFF31525A),
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendChartCard extends StatelessWidget {
  const _TrendChartCard({required this.reports});

  final List<ReportEntry> reports;

  @override
  Widget build(BuildContext context) {
    final chartReports = reports.reversed.toList();
    return _SectionCard(
      title: '3. กราฟเส้นใยอารมณ์ล่าสุด',
      subtitle: 'พล็อต PHQ-9, Mood และความร่วมมือ CBT เพื่อดูแนวโน้ม',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (chartReports.isEmpty)
            const _EmptyState(text: 'ยังไม่มีข้อมูลรายวันพอสำหรับสร้างกราฟ')
          else
            SizedBox(
              height: 210,
              width: double.infinity,
              child: CustomPaint(painter: _ClinicalTrendPainter(chartReports)),
            ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _LegendDot(color: Color(0xFFEF6B7A), label: 'PHQ-9'),
              _LegendDot(color: Color(0xFF62A7A5), label: 'Mood score'),
              _LegendDot(color: Color(0xFFDCA543), label: 'CBT completion'),
            ],
          ),
        ],
      ),
    );
  }
}

class _AuditLogCard extends StatefulWidget {
  const _AuditLogCard();

  @override
  State<_AuditLogCard> createState() => _AuditLogCardState();
}

class _AuditLogCardState extends State<_AuditLogCard> {
  final AuditLogService _auditLog = const AuditLogService();
  late Future<List<AuditEvent>> _eventsFuture;

  @override
  void initState() {
    super.initState();
    _eventsFuture = _auditLog.load();
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '6. Anonymous Audit Log',
      subtitle: 'บันทึก event สำคัญโดยไม่เก็บข้อความดิบหรือข้อมูลระบุตัวตน',
      child: FutureBuilder<List<AuditEvent>>(
        future: _eventsFuture,
        builder: (context, snapshot) {
          final events = snapshot.data ?? [];
          if (events.isEmpty) {
            return const _EmptyState(text: 'ยังไม่มี event สำคัญในเครื่องนี้');
          }
          return Column(
            children: events.take(6).map((event) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FCFB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFDCEFEB)),
                ),
                child: Row(
                  children: [
                    Icon(
                      event.riskLevel == 'red'
                          ? Icons.warning_rounded
                          : Icons.verified_user_rounded,
                      color: event.riskLevel == 'red'
                          ? const Color(0xFFE86A5A)
                          : const Color(0xFF5F9B91),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.type,
                            style: const TextStyle(
                              color: Color(0xFF17343C),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '${event.timestamp.hour.toString().padLeft(2, '0')}:${event.timestamp.minute.toString().padLeft(2, '0')} • risk=${event.riskLevel}',
                            style: const TextStyle(color: Color(0xFF607A81)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _TelemetryCard extends StatefulWidget {
  const _TelemetryCard();

  @override
  State<_TelemetryCard> createState() => _TelemetryCardState();
}

class _TelemetryCardState extends State<_TelemetryCard> {
  final PerformanceTelemetryService _telemetry =
      const PerformanceTelemetryService();
  late Future<List<TelemetryEvent>> _eventsFuture;

  @override
  void initState() {
    super.initState();
    _eventsFuture = _telemetry.load();
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '7. Local Performance Telemetry',
      subtitle:
          'วัดเวลาประมวลผลบนเครื่อง เช่น Haversine offline route เพื่อใช้ยืนยันว่าแอปไม่อืดบนมือถือ',
      child: FutureBuilder<List<TelemetryEvent>>(
        future: _eventsFuture,
        builder: (context, snapshot) {
          final events = snapshot.data ?? [];
          if (events.isEmpty) {
            return const _EmptyState(
              text:
                  'ยังไม่มี telemetry ให้ลองเปิดหน้า SOS เพื่อทดสอบ Haversine',
            );
          }

          return Column(
            children: events.take(5).map((event) {
              final isFast = event.elapsedMs <= 16;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FCFB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFDCEFEB)),
                ),
                child: Row(
                  children: [
                    Icon(
                      isFast ? Icons.speed_rounded : Icons.memory_rounded,
                      color: isFast
                          ? const Color(0xFF5F9B91)
                          : const Color(0xFFDCA543),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.name,
                            style: const TextStyle(
                              color: Color(0xFF17343C),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '${event.elapsedMs} ms • ${event.detail}',
                            style: const TextStyle(color: Color(0xFF607A81)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _MatrixCard extends StatelessWidget {
  const _MatrixCard({required this.summary});

  final _ClinicalSummary summary;

  @override
  Widget build(BuildContext context) {
    final matrix = summary.averageMatrix;
    return _SectionCard(
      title: '4. Symptom Matrix 3 แกน',
      subtitle:
          'Mood / Somatic / Behavioral domains สำหรับให้แพทย์อ่านแนวโน้ม ไม่ใช่คำวินิจฉัย',
      child: Column(
        children: [
          _AxisBar(
            label: 'Mood Axis',
            value: matrix.moodScore,
            color: const Color(0xFF6D9EEB),
          ),
          _AxisBar(
            label: 'Somatic Axis',
            value: matrix.somaticScore,
            color: const Color(0xFFF6B26B),
          ),
          _AxisBar(
            label: 'Behavioral Axis',
            value: matrix.behavioralScore,
            color: const Color(0xFF93C47D),
          ),
        ],
      ),
    );
  }
}

class _ClinicalDisclaimerCard extends StatelessWidget {
  const _ClinicalDisclaimerCard();

  @override
  Widget build(BuildContext context) {
    return const _StatusCard(
      title: 'หมายเหตุทางคลินิก',
      subtitle:
          'รายงานนี้เป็นข้อมูลสนับสนุนแพทย์จาก log ของผู้ใช้ ไม่ใช่การวินิจฉัย และไม่ควรใช้ปรับยาเองโดยไม่ปรึกษาผู้เชี่ยวชาญ',
    );
  }
}

class _ClinicalTrendPainter extends CustomPainter {
  _ClinicalTrendPainter(this.reports);

  final List<ReportEntry> reports;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFD7E6E3)
      ..strokeWidth = 1;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final chartRect = Rect.fromLTWH(26, 8, size.width - 38, size.height - 34);

    for (var i = 0; i <= 4; i++) {
      final y = chartRect.top + chartRect.height * i / 4;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
    }

    void drawLine(List<double> values, Color color, double maxValue) {
      if (values.isEmpty) return;
      final paint = Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final pointPaint = Paint()..color = color;
      final path = Path();

      for (var i = 0; i < values.length; i++) {
        final x = values.length == 1
            ? chartRect.center.dx
            : chartRect.left + chartRect.width * i / (values.length - 1);
        final normalized = (values[i] / maxValue).clamp(0.0, 1.0);
        final y = chartRect.bottom - chartRect.height * normalized;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
        canvas.drawCircle(Offset(x, y), 3.6, pointPaint);
      }
      canvas.drawPath(path, paint);
    }

    drawLine(
      reports.map((item) => item.phq9Score.toDouble()).toList(),
      const Color(0xFFEF6B7A),
      27,
    );
    drawLine(
      reports.map((item) => _moodValue(item.dailyMood).toDouble()).toList(),
      const Color(0xFF62A7A5),
      10,
    );
    drawLine(
      reports
          .map((item) => _parseCbtRate(item.cbtCompletionRate) / 10)
          .toList(),
      const Color(0xFFDCA543),
      10,
    );

    textPainter.text = const TextSpan(
      text: 'latest',
      style: TextStyle(fontSize: 11, color: Color(0xFF6A8387)),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(chartRect.right - textPainter.width, chartRect.bottom + 8),
    );
  }

  @override
  bool shouldRepaint(covariant _ClinicalTrendPainter oldDelegate) {
    return oldDelegate.reports != reports;
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FCFB),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFD5E6E3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF17343C),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF5D757B), height: 1.35),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 126,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF6A8387)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF20383F),
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

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF6F3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD2E6E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF607A81), fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF17343C),
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _AxisBar extends StatelessWidget {
  const _AxisBar({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final normalized = (value / 12).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF20383F),
                  ),
                ),
              ),
              Text('$value', style: const TextStyle(color: Color(0xFF607A81))),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: normalized,
              minHeight: 12,
              backgroundColor: const Color(0xFFE8F1EF),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF607A81), fontSize: 12),
        ),
      ],
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF7F5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(text, style: const TextStyle(color: Color(0xFF607A81))),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FCFB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD5E6E3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF17343C),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF5D757B), height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: const [
        _StatusCard(
          title: 'กำลังโหลด Soul Profile',
          subtitle: 'กำลังดึงข้อมูลจาก backend และรายงานล่าสุด...',
        ),
      ],
    );
  }
}

class _ProfileData {
  const _ProfileData({required this.user, required this.reports});

  final BackendUser user;
  final List<ReportEntry> reports;
}

class _ClinicalSummary {
  const _ClinicalSummary({
    required this.averagePhq9,
    required this.averageCbtRate,
    required this.restDays,
    required this.sosFlags,
    required this.averageMatrix,
  });

  final double averagePhq9;
  final double averageCbtRate;
  final int restDays;
  final int sosFlags;
  final ReportSymptomMatrix averageMatrix;

  factory _ClinicalSummary.fromReports(List<ReportEntry> reports) {
    if (reports.isEmpty) {
      return const _ClinicalSummary(
        averagePhq9: 0,
        averageCbtRate: 0,
        restDays: 0,
        sosFlags: 0,
        averageMatrix: ReportSymptomMatrix(
          moodScore: 0,
          somaticScore: 0,
          behavioralScore: 0,
        ),
      );
    }

    final phq9 =
        reports.fold<int>(0, (sum, item) => sum + item.phq9Score) /
        reports.length;
    final cbt =
        reports.fold<double>(
          0,
          (sum, item) => sum + _parseCbtRate(item.cbtCompletionRate),
        ) /
        reports.length;
    final mood = reports.fold<int>(
      0,
      (sum, item) => sum + item.symptomMatrix.moodScore,
    );
    final somatic = reports.fold<int>(
      0,
      (sum, item) => sum + item.symptomMatrix.somaticScore,
    );
    final behavioral = reports.fold<int>(
      0,
      (sum, item) => sum + item.symptomMatrix.behavioralScore,
    );

    return _ClinicalSummary(
      averagePhq9: phq9,
      averageCbtRate: cbt,
      restDays: reports.where((item) => item.isRestDay).length,
      sosFlags: reports.where((item) => item.isSosTriggered).length,
      averageMatrix: ReportSymptomMatrix(
        moodScore: (mood / reports.length).round(),
        somaticScore: (somatic / reports.length).round(),
        behavioralScore: (behavioral / reports.length).round(),
      ),
    );
  }
}

double _parseCbtRate(String value) {
  final normalized = value.trim();
  if (normalized.toLowerCase() == 'resting') return 0;
  if (normalized.contains('/')) {
    final parts = normalized.split('/');
    final done = double.tryParse(parts.first.trim()) ?? 0;
    final total = double.tryParse(parts.last.trim()) ?? 0;
    if (total <= 0) return 0;
    return (done / total * 100).clamp(0, 100);
  }
  return double.tryParse(normalized.replaceAll('%', '').trim()) ?? 0;
}

int _moodValue(String value) {
  final normalized = value.toLowerCase();
  if (normalized.contains('crisis')) return 1;
  if (normalized.contains('heavy')) return 2;
  if (normalized.contains('tired')) return 4;
  if (normalized.contains('hopeful')) return 7;
  if (normalized.contains('calm')) return 8;
  final parsed = int.tryParse(value);
  return parsed?.clamp(0, 10) ?? 5;
}

String _joinOrDash(List<String> values) {
  final cleaned = values.where((item) => item.trim().isNotEmpty).toList();
  return cleaned.isEmpty ? '-' : cleaned.join(', ');
}
