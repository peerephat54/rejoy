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

  Future<void> _assignCarePlan(List<dynamic> patients) async {
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
        title: 'Gentle 3-step recovery plan',
        focusArea: 'behavioral_activation',
        recommendedQuestEnergy: 'low',
        note:
            'Clinician demo: start with low-energy Micro-CBT quests and review sleep, appetite, medication adherence, and safety plan.',
      );
      if (!mounted) return;
      setState(() {
        _assigning = false;
        _message =
            'Care plan sent to ${firstPatient['patientCode'] ?? 'patient'}.';
        _dashboardFuture = _client.fetchClinicalDashboard();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _assigning = false;
        _message = 'Care plan failed: $error';
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
                            Text('Loading clinical dashboard...'),
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
                            'Dashboard is not available',
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
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    _MetricGrid(totals: totals),
                    const SizedBox(height: 14),
                    _PatientPanel(patients: patients),
                    const SizedBox(height: 14),
                    _AlertPanel(alerts: alerts),
                    const SizedBox(height: 14),
                    _CarePlanPanel(
                      assigning: _assigning,
                      hasPatient: patients.isNotEmpty,
                      message: _message,
                      onAssign: () => _assignCarePlan(patients),
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
                'Clinical Dashboard',
                style: TextStyle(
                  color: Color(0xFF17343C),
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'For assigned patients only. Raw diary text stays private.',
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
        _MetricCard('Stable', totals['stable'], const Color(0xFF72B8AD)),
        _MetricCard('Watch', totals['watch'], const Color(0xFFE2AE43)),
        _MetricCard('Urgent', totals['urgent'], const Color(0xFFDB6B5D)),
        _MetricCard('Alerts', totals['alerts'], const Color(0xFF5D6C89)),
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

class _PatientPanel extends StatelessWidget {
  const _PatientPanel({required this.patients});

  final List<dynamic> patients;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelTitle('Patients under your care'),
          const SizedBox(height: 10),
          if (patients.isEmpty)
            const _EmptyState(
              text:
                  'No assigned patients yet. In production, a hospital admin assigns patients to each clinician account.',
            )
          else
            ...patients.take(10).map((patient) {
              final item = Map<String, dynamic>.from(patient as Map);
              return _PatientRow(patient: item);
            }),
        ],
      ),
    );
  }
}

class _PatientRow extends StatelessWidget {
  const _PatientRow({required this.patient});

  final Map<String, dynamic> patient;

  @override
  Widget build(BuildContext context) {
    final status = patient['riskStatus']?.toString() ?? 'Stable';
    final color = switch (status) {
      'Urgent' => const Color(0xFFDB6B5D),
      'Watch' => const Color(0xFFE2AE43),
      _ => const Color(0xFF72B8AD),
    };
    return Container(
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
                  'PHQ-9 ${patient['latestPhq9'] ?? 0} • CBT ${patient['cbtCompletionAverage'] ?? 0}%',
                  style: const TextStyle(color: Color(0xFF607A81)),
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
              status,
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertPanel extends StatelessWidget {
  const _AlertPanel({required this.alerts});

  final List<dynamic> alerts;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelTitle('Clinical alert queue'),
          const SizedBox(height: 10),
          if (alerts.isEmpty)
            const _EmptyState(text: 'No urgent clinical signals right now.')
          else
            ...alerts.take(6).map((alert) {
              final item = Map<String, dynamic>.from(alert as Map);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  '${item['patientCode'] ?? 'RJ'} • ${item['title'] ?? 'Needs review'}',
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
}

class _CarePlanPanel extends StatelessWidget {
  const _CarePlanPanel({
    required this.assigning,
    required this.hasPatient,
    required this.message,
    required this.onAssign,
  });

  final bool assigning;
  final bool hasPatient;
  final String? message;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelTitle('Doctor note & care plan'),
          const SizedBox(height: 8),
          const Text(
            'Send a gentle weekly care plan back to the patient app. This is supportive guidance, not medication instruction.',
            style: TextStyle(color: Color(0xFF607A81), height: 1.35),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: hasPatient && !assigning ? onAssign : null,
            icon: assigning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.assignment_turned_in_rounded),
            label: const Text('Assign demo care plan'),
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message!,
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
        'Safety boundary: this dashboard helps triage and summarize trends. It is not a 24/7 emergency dispatch system, and raw diary text is intentionally excluded from the hospital queue.',
        style: TextStyle(color: Color(0xFF607A81), height: 1.35),
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
