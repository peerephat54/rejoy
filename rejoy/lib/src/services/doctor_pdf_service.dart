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
    final fourteenDayReports = _last14Days(
      reports.isEmpty ? [report] : reports,
    );
    final matrixAverage = _averageMatrix(fourteenDayReports);
    final avgPhq9 = _averagePhq9(fourteenDayReports);
    final avgCbt = _averageCbtRate(fourteenDayReports);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
        build: (context) {
          return [
            _header(user, fourteenDayReports),
            pw.SizedBox(height: 16),
            _quickClinicalSummary(
              avgPhq9: avgPhq9,
              avgCbt: avgCbt,
              restDays: fourteenDayReports
                  .where((item) => item.isRestDay)
                  .length,
              sosFlags: fourteenDayReports
                  .where((item) => item.isSosTriggered)
                  .length,
            ),
            pw.SizedBox(height: 12),
            _infoCard(
              title: 'Soul Profile & Medical Background',
              rows: [
                _row('Name', user.fullName),
                _row('Age', '${user.age}'),
                _row('Allergies', _joinOrDash(user.allergies)),
                _row(
                  'Current medications',
                  _joinOrDash(user.currentMedications),
                ),
                _row(
                  'Emergency contacts',
                  _joinOrDash(user.emergencyContactNumbers),
                ),
                _row(
                  'Medical history',
                  user.medicalHistory.isEmpty ? '-' : user.medicalHistory,
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            _infoCard(
              title: '14-Day Clinical Snapshot',
              rows: [
                _row('Reports included', '${fourteenDayReports.length} day(s)'),
                _row('Average PHQ-9', avgPhq9.toStringAsFixed(1)),
                _row('Average CBT completion', '${avgCbt.toStringAsFixed(0)}%'),
                _row(
                  'Rest days',
                  '${fourteenDayReports.where((item) => item.isRestDay).length}',
                ),
                _row(
                  'SOS flags',
                  '${fourteenDayReports.where((item) => item.isSosTriggered).length}',
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            _matrixCard(matrixAverage),
            pw.SizedBox(height: 12),
            _trendTable(fourteenDayReports),
            pw.SizedBox(height: 12),
            _diaryNotes(fourteenDayReports),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF4FBFA),
                borderRadius: pw.BorderRadius.circular(16),
                border: pw.Border.all(color: PdfColor.fromInt(0xFFD7E6E3)),
              ),
              child: pw.Text(
                'Clinical note: This report summarizes user-entered logs and DSM-5-aligned symptom domains (Mood, Somatic, Behavioral) for clinician review. It is not a diagnosis and should be interpreted by a qualified professional.',
                style: const pw.TextStyle(fontSize: 10.5),
              ),
            ),
          ];
        },
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
      filename: 'rejoy-clinical-14-day-report.pdf',
    );
  }

  pw.Widget _header(BackendUser user, List<ReportEntry> reports) {
    final latestDate = reports.isEmpty ? null : reports.first.date;
    return pw.Container(
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: [PdfColor.fromInt(0xFFDDF0ED), PdfColor.fromInt(0xFFF7F2E8)],
        ),
        borderRadius: pw.BorderRadius.circular(24),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'ReJoy Clinical 14-Day Report',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'One-minute summary for doctor review and medication discussion',
            style: const pw.TextStyle(fontSize: 11.5),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            '${user.fullName} • Latest log ${_formatDate(latestDate)}',
            style: pw.TextStyle(fontSize: 12.5, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  pw.Widget _matrixCard(ReportSymptomMatrix matrix) {
    final total =
        (matrix.moodScore + matrix.somaticScore + matrix.behavioralScore).clamp(
          1,
          999,
        );

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(18),
        border: pw.Border.all(color: PdfColor.fromInt(0xFFD7E6E3)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Symptom Matrix: Mood / Somatic / Behavioral Axis',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          _axisBar(
            'Mood axis',
            matrix.moodScore,
            total,
            PdfColor.fromInt(0xFF6D9EEB),
          ),
          _axisBar(
            'Somatic axis',
            matrix.somaticScore,
            total,
            PdfColor.fromInt(0xFFF6B26B),
          ),
          _axisBar(
            'Behavioral axis',
            matrix.behavioralScore,
            total,
            PdfColor.fromInt(0xFF93C47D),
          ),
        ],
      ),
    );
  }

  pw.Widget _quickClinicalSummary({
    required double avgPhq9,
    required double avgCbt,
    required int restDays,
    required int sosFlags,
  }) {
    final risk = _phq9Band(avgPhq9.round());
    final riskColor = sosFlags > 0
        ? PdfColor.fromInt(0xFFE57373)
        : PdfColor.fromInt(0xFF62A7A5);
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFF7FBFA),
        borderRadius: pw.BorderRadius.circular(18),
        border: pw.Border.all(color: riskColor),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Doctor Quick Read',
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          _row('PHQ-9 risk band', risk),
          _row('Average CBT participation', '${avgCbt.toStringAsFixed(0)}%'),
          _row('Rest / recovery days', '$restDays day(s)'),
          _row('SOS flags', '$sosFlags time(s)'),
          pw.SizedBox(height: 6),
          pw.Text(
            'Suggested use: review trend, diary notes, rest days, and SOS flags with the patient. Do not use this report alone to diagnose or adjust medication.',
            style: const pw.TextStyle(fontSize: 10.5),
          ),
        ],
      ),
    );
  }

  pw.Widget _axisBar(String label, int value, int total, PdfColor color) {
    final width = (value / total * 250).clamp(12, 250).toDouble();
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(label, style: const pw.TextStyle(fontSize: 11)),
          ),
          pw.Container(
            width: width,
            height: 10,
            decoration: pw.BoxDecoration(
              color: color,
              borderRadius: pw.BorderRadius.circular(99),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Text(
            '$value',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  pw.Widget _trendTable(List<ReportEntry> reports) {
    return _infoCard(
      title: 'Daily Trend Table',
      rows: reports
          .take(14)
          .map(
            (report) => _row(
              _formatDate(report.date),
              'PHQ-9 ${report.phq9Score} | CBT ${report.cbtCompletionRate} | Mood ${report.dailyMood.isEmpty ? '-' : report.dailyMood}',
            ),
          )
          .toList(),
    );
  }

  pw.Widget _diaryNotes(List<ReportEntry> reports) {
    final notes = reports
        .where((item) => item.diaryNote.trim().isNotEmpty)
        .take(8)
        .map((item) => '${_formatDate(item.date)}: ${item.diaryNote}')
        .toList();

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFFDF8EC),
        borderRadius: pw.BorderRadius.circular(18),
        border: pw.Border.all(color: PdfColor.fromInt(0xFFE6D7A5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Diary Notes / ความในใจ',
            style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromInt(0xFF5D4B1D),
            ),
          ),
          pw.SizedBox(height: 8),
          if (notes.isEmpty)
            pw.Text(
              'No diary note submitted.',
              style: const pw.TextStyle(fontSize: 11.5),
            )
          else
            ...notes.map(
              (note) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Text(note, style: const pw.TextStyle(fontSize: 11.5)),
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _infoCard({required String title, required List<pw.Widget> rows}) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(18),
        border: pw.Border.all(color: PdfColor.fromInt(0xFFD7E6E3)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          ...rows,
        ],
      ),
    );
  }

  pw.Widget _row(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 132,
            child: pw.Text(label, style: const pw.TextStyle(fontSize: 11.5)),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 11.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
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

  String _joinOrDash(List<String> values) {
    final cleaned = values.where((item) => item.trim().isNotEmpty).toList();
    return cleaned.isEmpty ? '-' : cleaned.join(', ');
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
