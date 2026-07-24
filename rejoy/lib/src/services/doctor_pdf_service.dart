import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'rejoy_api_client.dart';

class DoctorPdfService {
  const DoctorPdfService();

  Future<Uint8List> buildDoctorReportPdf({
    required BackendUser user,
    required ReportEntry report,
    List<ReportEntry> reports = const [],
  }) async {
    final regularFont = await PdfGoogleFonts.notoSansThaiRegular();
    final boldFont = await PdfGoogleFonts.notoSansThaiBold();
    final document = pw.Document();
    final periodReports = _last14Days(reports.isEmpty ? [report] : reports);
    final latest = periodReports.isEmpty ? report : periodReports.first;
    final previous = periodReports.length > 1 ? periodReports[1] : null;
    final avgPhq9 = _averagePhq9(periodReports);
    final avgCbt = _averageCbtRate(periodReports);
    final matrixAverage = _averageMatrix(periodReports);
    final phqDelta = previous == null
        ? 0
        : latest.phq9Score - previous.phq9Score;
    final sosFlags = periodReports.where((item) => item.isSosTriggered).length;
    final restDays = periodReports.where((item) => item.isRestDay).length;

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 24),
        theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
        build: (context) => [
          _header(user, periodReports),
          pw.SizedBox(height: 10),
          _quickRead(
            latest: latest,
            phqDelta: phqDelta,
            avgPhq9: avgPhq9,
            avgCbt: avgCbt,
            restDays: restDays,
            sosFlags: sosFlags,
          ),
          pw.SizedBox(height: 10),
          _medicalBackground(user),
          pw.SizedBox(height: 10),
          _clinicalQuestions(periodReports),
          pw.SizedBox(height: 10),
          _trendTable(periodReports),
          pw.SizedBox(height: 10),
          _matrixSummary(matrixAverage),
          pw.SizedBox(height: 10),
          _treatmentPrompts(user, periodReports),
          pw.SizedBox(height: 10),
          _diaryNotes(periodReports),
          pw.SizedBox(height: 10),
          _safetyNote(),
        ],
      ),
    );

    return document.save();
  }

  Future<void> printDoctorReportPdf({
    required BackendUser user,
    required ReportEntry report,
    List<ReportEntry> reports = const [],
  }) async {
    final bytes = await buildDoctorReportPdf(
      user: user,
      report: report,
      reports: reports,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'rejoy-clinical-summary-report.pdf',
    );
  }

  pw.Widget _header(BackendUser user, List<ReportEntry> reports) {
    final latestDate = reports.isEmpty ? null : reports.first.date;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'ReJoy Clinical Summary Report',
          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Pre-visit handoff for clinician review. Data comes from patient-entered app logs and must be verified in consultation.',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 8),
        _keyValueTable([
          ['Patient', user.fullName.isEmpty ? user.email : user.fullName],
          ['Latest log', _formatDate(latestDate)],
          [
            'Report window',
            '${reports.length} log(s), latest 14 days if available',
          ],
        ]),
        pw.SizedBox(height: 8),
        pw.Divider(thickness: 1.2, color: PdfColor.fromInt(0xFF17343C)),
      ],
    );
  }

  pw.Widget _quickRead({
    required ReportEntry latest,
    required int phqDelta,
    required double avgPhq9,
    required double avgCbt,
    required int restDays,
    required int sosFlags,
  }) {
    final urgent = latest.phq9Score >= 20 || sosFlags > 0;
    return _section(
      urgent ? 'Doctor Quick Read - priority review' : 'Doctor Quick Read',
      subtitle:
          '60-second summary. Use this to decide what to ask first, not as an automated diagnosis.',
      children: [
        _keyValueTable([
          [
            'Latest PHQ-9',
            '${latest.phq9Score}/27 | ${_phq9Band(latest.phq9Score)}',
          ],
          ['Change vs prior log', _formatDelta(phqDelta)],
          ['Average PHQ-9', avgPhq9.toStringAsFixed(1)],
          [
            'Latest mood label',
            latest.dailyMood.isEmpty ? '-' : latest.dailyMood,
          ],
          ['CBT participation avg.', '${avgCbt.toStringAsFixed(0)}%'],
          ['Rest / recovery days', '$restDays day(s)'],
          ['SOS flags', '$sosFlags time(s)'],
          [
            'First clinical check',
            urgent
                ? 'Start with safety plan, self-harm thoughts, support person, and crisis resources.'
                : 'Confirm mood, sleep, appetite, energy, functioning, medication adherence, and side effects.',
          ],
        ]),
      ],
    );
  }

  pw.Widget _medicalBackground(BackendUser user) {
    return _section(
      '1. Medical background to verify',
      subtitle:
          'Basic information that should be confirmed directly with the patient.',
      children: [
        _keyValueTable([
          ['Age', user.age == 0 ? '-' : '${user.age}'],
          ['Allergies', _joinOrDash(user.allergies)],
          ['Current medications', _joinOrDash(user.currentMedications)],
          [
            'Medical history',
            user.medicalHistory.isEmpty ? '-' : user.medicalHistory,
          ],
          ['Emergency contacts', _joinOrDash(user.emergencyContactNumbers)],
        ]),
      ],
    );
  }

  pw.Widget _clinicalQuestions(List<ReportEntry> reports) {
    final highPhqDays = reports.where((item) => item.phq9Score >= 15).length;
    final severeDays = reports.where((item) => item.phq9Score >= 20).length;
    final sosDays = reports.where((item) => item.isSosTriggered).length;
    final lowCbtDays = reports
        .where(
          (item) =>
              !item.isRestDay && _parseCbtRate(item.cbtCompletionRate) < 50,
        )
        .length;

    return _section(
      '2. Clinical flags to ask today',
      subtitle:
          'Question prompts designed to save time and reduce recall bias.',
      children: [
        _keyValueTable([
          [
            'Safety / SOS',
            sosDays > 0
                ? '$sosDays SOS flag(s). Ask about current safety, plan, intent, means, and support.'
                : 'No SOS flag in this report window.',
          ],
          [
            'PHQ-9 elevation',
            '$highPhqDays day(s) >= 15, $severeDays day(s) >= 20. Verify severity and PHQ-9 item 9.',
          ],
          [
            'Function / activity',
            '$lowCbtDays low-activity day(s). Ask about school/home functioning, withdrawal, and barriers.',
          ],
          [
            'Recovery days',
            '${reports.where((item) => item.isRestDay).length} rest day(s). Confirm whether rest was protective or avoidance.',
          ],
        ]),
      ],
    );
  }

  pw.Widget _trendTable(List<ReportEntry> reports) {
    final rows = reports.take(14).map((item) {
      final markers = [
        if (item.isRestDay) 'REST',
        if (item.isSosTriggered) 'SOS',
      ].join(', ');
      return [
        _formatDateShort(item.date),
        '${item.phq9Score}',
        '${_parseCbtRate(item.cbtCompletionRate).round()}%',
        item.dailyMood.isEmpty ? '-' : item.dailyMood,
        markers.isEmpty ? '-' : markers,
      ];
    }).toList();

    return _section(
      '3. Trend summary',
      subtitle:
          'Latest logs first. PHQ-9 uses 0-27 scale; CBT uses completion percentage.',
      children: [
        if (rows.isEmpty)
          pw.Text(
            'No trend data available.',
            style: const pw.TextStyle(fontSize: 10.5),
          )
        else
          _dataTable(
            headers: ['Date', 'PHQ-9', 'CBT', 'Mood label', 'Marker'],
            rows: rows,
            widths: const {
              0: pw.FixedColumnWidth(54),
              1: pw.FixedColumnWidth(42),
              2: pw.FixedColumnWidth(42),
              3: pw.FlexColumnWidth(),
              4: pw.FixedColumnWidth(62),
            },
          ),
      ],
    );
  }

  pw.Widget _matrixSummary(ReportSymptomMatrix matrix) {
    return _section(
      '4. Symptom matrix',
      subtitle:
          'Mood, somatic, and behavioral signals from app logs. Use as interview prompts.',
      children: [
        _keyValueTable([
          [
            'Mood axis',
            '${matrix.moodScore} | ask hopelessness, guilt, concentration, irritability.',
          ],
          [
            'Somatic axis',
            '${matrix.somaticScore} | ask sleep, appetite, fatigue, psychomotor change.',
          ],
          [
            'Behavioral axis',
            '${matrix.behavioralScore} | ask withdrawal, daily routine, school/home function.',
          ],
        ]),
      ],
    );
  }

  pw.Widget _treatmentPrompts(BackendUser user, List<ReportEntry> reports) {
    final latest = reports.isEmpty ? null : reports.first;
    final avgCbt = _averageCbtRate(reports);
    return _section(
      '5. Medication & treatment discussion prompts',
      subtitle:
          'Useful questions before medication discussion or care-plan adjustment.',
      children: [
        _keyValueTable([
          [
            'Current medications to confirm',
            _joinOrDash(user.currentMedications),
          ],
          ['Allergy check', _joinOrDash(user.allergies)],
          [
            'Adherence / side effects',
            'Ask whether missed doses, sedation, nausea, sleep change, appetite change, or agitation affected routine.',
          ],
          [
            'Activity clue',
            avgCbt < 40
                ? 'Low CBT completion. Ask about energy, motivation, daily structure, and barriers.'
                : 'Activity participation appears relatively consistent.',
          ],
          [
            'Latest animal/rest context',
            latest == null
                ? '-'
                : latest.isRestDay
                ? 'Rest day logged'
                : latest.unlockedAnimalToday.isEmpty
                ? '-'
                : latest.unlockedAnimalToday,
          ],
        ]),
      ],
    );
  }

  pw.Widget _diaryNotes(List<ReportEntry> reports) {
    final notes = reports
        .where((item) => item.diaryNote.trim().isNotEmpty)
        .take(8)
        .map((item) => [_formatDate(item.date), item.diaryNote.trim()])
        .toList();

    return _section(
      '6. Diary notes / patient words',
      subtitle:
          'Patient-entered notes are included as context. Confirm meaning directly and avoid interpreting them alone.',
      children: [
        if (notes.isEmpty)
          pw.Text(
            'No diary note submitted.',
            style: const pw.TextStyle(fontSize: 10.5),
          )
        else
          _dataTable(
            headers: ['Date', 'Patient note'],
            rows: notes,
            widths: const {0: pw.FixedColumnWidth(76), 1: pw.FlexColumnWidth()},
          ),
      ],
    );
  }

  pw.Widget _safetyNote() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Important safety note',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          'ReJoy supports tracking and preparation for care. It does not diagnose, prescribe, replace clinical judgment, or provide 24/7 emergency monitoring.',
          style: const pw.TextStyle(fontSize: 9.5),
        ),
      ],
    );
  }

  pw.Widget _section(
    String title, {
    String? subtitle,
    required List<pw.Widget> children,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        if (subtitle != null) ...[
          pw.SizedBox(height: 2),
          pw.Text(subtitle, style: const pw.TextStyle(fontSize: 9.4)),
        ],
        pw.SizedBox(height: 5),
        pw.Divider(color: PdfColor.fromInt(0xFFD7E6E3)),
        pw.SizedBox(height: 5),
        ...children,
      ],
    );
  }

  pw.Widget _keyValueTable(List<List<String>> rows) {
    return pw.Table(
      columnWidths: const {
        0: pw.FixedColumnWidth(150),
        1: pw.FlexColumnWidth(),
      },
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(
          color: PdfColor.fromInt(0xFFE7EFED),
          width: 0.5,
        ),
      ),
      children: rows.map((row) {
        return pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(0, 4, 8, 4),
              child: pw.Text(row[0], style: const pw.TextStyle(fontSize: 10)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Text(
                row[1],
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  pw.Widget _dataTable({
    required List<String> headers,
    required List<List<String>> rows,
    required Map<int, pw.TableColumnWidth> widths,
  }) {
    return pw.Table(
      columnWidths: widths,
      border: pw.TableBorder(
        top: pw.BorderSide(color: PdfColor.fromInt(0xFFBFD6D1)),
        bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFBFD6D1)),
        horizontalInside: pw.BorderSide(
          color: PdfColor.fromInt(0xFFE7EFED),
          width: 0.5,
        ),
      ),
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFF4FBFA)),
          children: headers
              .map(
                (header) => pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text(
                    header,
                    style: pw.TextStyle(
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        ...rows.map(
          (row) => pw.TableRow(
            children: row
                .map(
                  (cell) => pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(
                      cell,
                      style: const pw.TextStyle(fontSize: 9.2),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  List<ReportEntry> _last14Days(List<ReportEntry> reports) {
    final cutoff = DateTime.now().subtract(const Duration(days: 14));
    final filtered =
        reports
            .where(
              (report) => report.date == null || report.date!.isAfter(cutoff),
            )
            .toList()
          ..sort((a, b) {
            final aDate = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });

    return filtered.take(14).toList();
  }

  ReportSymptomMatrix _averageMatrix(List<ReportEntry> reports) {
    if (reports.isEmpty) {
      return const ReportSymptomMatrix(
        moodScore: 0,
        somaticScore: 0,
        behavioralScore: 0,
      );
    }
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
    return ReportSymptomMatrix(
      moodScore: (mood / reports.length).round(),
      somaticScore: (somatic / reports.length).round(),
      behavioralScore: (behavioral / reports.length).round(),
    );
  }

  double _averagePhq9(List<ReportEntry> reports) {
    if (reports.isEmpty) return 0;
    return reports.fold<int>(0, (sum, item) => sum + item.phq9Score) /
        reports.length;
  }

  double _averageCbtRate(List<ReportEntry> reports) {
    if (reports.isEmpty) return 0;
    final rates = reports
        .map((item) => _parseCbtRate(item.cbtCompletionRate))
        .toList();
    return rates.fold<double>(0, (sum, item) => sum + item) / rates.length;
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

  String _phq9Band(int score) {
    if (score <= 4) return 'Minimal (0-4)';
    if (score <= 9) return 'Mild (5-9)';
    if (score <= 14) return 'Moderate (10-14)';
    if (score <= 19) return 'Moderately severe (15-19)';
    return 'Severe (20-27)';
  }

  String _formatDelta(int value) {
    if (value == 0) return 'No change from prior log';
    final sign = value > 0 ? '+' : '';
    final direction = value > 0
        ? 'higher risk than prior log'
        : 'lower than prior log';
    return '$sign$value point(s), $direction';
  }

  String _joinOrDash(List<String> values) {
    final cleaned = values.where((item) => item.trim().isNotEmpty).toList();
    return cleaned.isEmpty ? '-' : cleaned.join(', ');
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDateShort(DateTime? date) {
    if (date == null) return '-';
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
}
