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
          _pageGuard(170),
          _clinicalQuestions(periodReports),
          pw.SizedBox(height: 10),
          _pageGuard(190),
          _trendTable(periodReports),
          pw.SizedBox(height: 10),
          _pageGuard(130),
          _matrixSummary(matrixAverage),
          pw.SizedBox(height: 10),
          _pageGuard(160),
          _treatmentPrompts(user, periodReports),
          pw.SizedBox(height: 10),
          _pageGuard(260),
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
          'รายงานสรุปสุขภาพใจ ReJoy',
          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Clinical Summary Report | สรุปก่อนพบแพทย์จากข้อมูลที่ผู้ใช้บันทึกในแอป และควรยืนยันซ้ำระหว่างการพูดคุย',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 8),
        _demoBadge(),
        pw.SizedBox(height: 8),
        _keyValueTable([
          [
            'ผู้ใช้ / Patient',
            user.fullName.isEmpty ? user.email : user.fullName,
          ],
          ['บันทึกล่าสุด / Latest log', _formatDate(latestDate)],
          [
            'ช่วงข้อมูล / Report window',
            '${reports.length} รายการล่าสุดในช่วง 14 วันเท่าที่มีข้อมูล',
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
      urgent
          ? 'สรุปด่วนสำหรับแพทย์: ควรทบทวนก่อนพบผู้ใช้'
          : 'สรุปด่วนสำหรับแพทย์',
      subtitle:
          'อ่านภายใน 60 วินาทีเพื่อจัดลำดับคำถามก่อนคุย ไม่ใช่การวินิจฉัยอัตโนมัติ',
      children: [
        _keyValueTable([
          [
            'PHQ-9 ล่าสุด',
            '${latest.phq9Score}/27 | ${_phq9Band(latest.phq9Score)}',
          ],
          ['เปลี่ยนจากครั้งก่อน', _formatDelta(phqDelta)],
          ['ค่าเฉลี่ย PHQ-9', avgPhq9.toStringAsFixed(1)],
          [
            'อารมณ์ล่าสุด',
            latest.dailyMood.isEmpty ? '-' : _cleanDemoText(latest.dailyMood),
          ],
          ['ความร่วมมือ CBT เฉลี่ย', '${avgCbt.toStringAsFixed(0)}%'],
          ['วันพัก/ฟื้นตัว', '$restDays วัน'],
          ['การกด SOS', '$sosFlags ครั้ง'],
          [
            'ควรถามก่อนเป็นอันดับแรก',
            urgent
                ? 'เริ่มจากความปลอดภัยวันนี้ แผนรับมือ ความคิดทำร้ายตัวเอง ผู้ช่วยเหลือใกล้ตัว และช่องทางช่วยเหลือฉุกเฉิน'
                : 'ยืนยันเรื่องอารมณ์ การนอน ความอยากอาหาร พลังงาน การใช้ชีวิต การกินยา และผลข้างเคียง',
          ],
        ]),
      ],
    );
  }

  pw.Widget _medicalBackground(BackendUser user) {
    return _section(
      '1. ข้อมูลพื้นฐานทางการแพทย์ที่ควรยืนยัน',
      subtitle:
          'ข้อมูลนี้ช่วยเตรียมคำถามก่อนพบผู้ใช้ และควรยืนยันกับผู้ใช้โดยตรง',
      children: [
        _keyValueTable([
          ['อายุ', user.age == 0 ? '-' : '${user.age}'],
          ['ประวัติแพ้ยา/อาหาร', _joinOrDash(user.allergies)],
          ['ยาที่ใช้อยู่', _joinOrDash(user.currentMedications)],
          [
            'ประวัติการรักษา',
            user.medicalHistory.isEmpty
                ? '-'
                : _cleanDemoText(user.medicalHistory),
          ],
          ['เบอร์ติดต่อฉุกเฉิน', _joinOrDash(user.emergencyContactNumbers)],
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
      '2. ประเด็นสำคัญที่ควรถามวันนี้',
      subtitle: 'ช่วยให้แพทย์ถามตรงจุด ลดการพึ่งความจำย้อนหลังของผู้ใช้',
      children: [
        _keyValueTable([
          [
            'ความปลอดภัย / SOS',
            sosDays > 0
                ? 'พบการกด SOS $sosDays ครั้ง ควรถามเรื่องความปลอดภัยวันนี้ แผนรับมือ ความตั้งใจ วิธีที่เข้าถึงได้ และคนช่วยเหลือ'
                : 'ไม่พบ SOS ในช่วงรายงานนี้',
          ],
          [
            'PHQ-9 สูงต่อเนื่อง',
            '$highPhqDays วันอยู่ระดับ >=15 และ $severeDays วันอยู่ระดับ >=20 ควรยืนยันความรุนแรงกับผู้ใช้',
          ],
          [
            'PHQ-9 ข้อ 9 / ความปลอดภัย',
            (sosDays > 0 || severeDays > 0)
                ? 'ควรถามแยกอย่างอ่อนโยนเรื่องความคิดทำร้ายตัวเองหรือไม่อยากมีชีวิตอยู่ แม้ระบบยังไม่มีคะแนนข้อ 9 แยก'
                : 'ยังไม่มีสัญญาณข้อ 9 แยกในรายงานนี้ แต่ควรถามตามดุลยพินิจแพทย์',
          ],
          [
            'การใช้ชีวิต / กิจกรรม',
            '$lowCbtDays วันมีการทำกิจกรรมต่ำ ควรถามเรื่องเรียน/บ้าน การแยกตัว และอุปสรรคในการเริ่มกิจกรรม',
          ],
          [
            'วันพักฟื้น',
            '${reports.where((item) => item.isRestDay).length} วัน ควรถามว่าการพักช่วยให้ปลอดภัยขึ้น หรือเป็นการหลีกเลี่ยงกิจกรรม',
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
        item.dailyMood.isEmpty ? '-' : _cleanDemoText(item.dailyMood),
        markers.isEmpty ? '-' : markers,
      ];
    }).toList();

    return _section(
      '3. สรุปแนวโน้มล่าสุด',
      subtitle:
          'Latest logs first. PHQ-9 = 0-27 คะแนน, CBT = สัดส่วนภารกิจที่ทำสำเร็จ',
      children: [
        _trendOneLine(reports),
        pw.SizedBox(height: 6),
        if (rows.isEmpty)
          pw.Text(
            'ยังไม่มีข้อมูลแนวโน้ม',
            style: const pw.TextStyle(fontSize: 10.5),
          )
        else
          _dataTable(
            headers: ['วันที่', 'PHQ-9', 'CBT', 'อารมณ์', 'หมายเหตุ'],
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
      '4. Symptom Matrix: Mood / Somatic / Behavioral',
      subtitle: 'สรุปสัญญาณ 3 แกนเพื่อใช้เป็นคำถามนำ ไม่ใช่ผลวินิจฉัย',
      children: [
        _keyValueTable([
          [
            'Mood axis / อารมณ์',
            '${matrix.moodScore} | ถามเรื่องความสิ้นหวัง ความรู้สึกผิด สมาธิ และความหงุดหงิด',
          ],
          [
            'Somatic axis / อาการทางกาย',
            '${matrix.somaticScore} | ถามเรื่องการนอน ความอยากอาหาร ความเหนื่อยล้า และการเคลื่อนไหวช้าลง/กระสับกระส่าย',
          ],
          [
            'Behavioral axis / พฤติกรรม',
            '${matrix.behavioralScore} | ถามเรื่องการแยกตัว กิจวัตรประจำวัน และการใช้ชีวิตที่บ้าน/โรงเรียน',
          ],
        ]),
      ],
    );
  }

  pw.Widget _treatmentPrompts(BackendUser user, List<ReportEntry> reports) {
    final avgCbt = _averageCbtRate(reports);
    return _section(
      '5. คำถามประกอบการประเมินและปรับแผนดูแล',
      subtitle: 'ใช้เตรียมข้อมูลก่อนแพทย์ประเมิน ไม่ใช่คำสั่งจ่ายยาอัตโนมัติ',
      children: [
        _keyValueTable([
          ['ยาที่ควรยืนยัน', _joinOrDash(user.currentMedications)],
          ['ประวัติแพ้ที่ควรถามซ้ำ', _joinOrDash(user.allergies)],
          [
            'การกินยา / ผลข้างเคียง',
            'ถามเรื่องลืมกินยา ง่วงซึม คลื่นไส้ การนอนเปลี่ยน ความอยากอาหารเปลี่ยน หรือกระสับกระส่ายที่กระทบชีวิตประจำวัน',
          ],
          [
            'เบาะแสด้านกิจกรรม',
            avgCbt < 40
                ? 'การทำภารกิจต่ำ ควรถามเรื่องพลังงาน แรงจูงใจ โครงสร้างวัน และอุปสรรค'
                : 'การทำกิจกรรมค่อนข้างสม่ำเสมอ ควรถามว่าปัจจัยใดช่วยให้ทำได้',
          ],
        ]),
      ],
    );
  }

  pw.Widget _diaryNotes(List<ReportEntry> reports) {
    final notes = reports
        .where((item) => item.diaryNote.trim().isNotEmpty)
        .take(5)
        .map(
          (item) => [
            _formatDate(item.date),
            _cleanDemoText(item.diaryNote.trim()),
          ],
        )
        .toList();

    return _section(
      '6. บันทึกจากผู้ใช้ / Diary notes',
      subtitle:
          'ข้อความนี้เป็นบริบทจากผู้ใช้ ควรถามยืนยันความหมายโดยตรง ไม่ควรตีความแทนผู้ใช้เพียงอย่างเดียว',
      children: [
        if (notes.isEmpty)
          pw.Text(
            'ยังไม่มีบันทึกความในใจ',
            style: const pw.TextStyle(fontSize: 10.5),
          )
        else
          _dataTable(
            headers: ['วันที่', 'ข้อความจากผู้ใช้'],
            rows: notes,
            widths: const {0: pw.FixedColumnWidth(76), 1: pw.FlexColumnWidth()},
          ),
      ],
    );
  }

  pw.Widget _pageGuard(double minimumFreeSpace) {
    return pw.NewPage(freeSpace: minimumFreeSpace);
  }

  pw.Widget _safetyNote() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'หมายเหตุด้านความปลอดภัย',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          'ReJoy เป็นเครื่องมือช่วยติดตามและเตรียมข้อมูลประกอบการดูแล ไม่ใช่เครื่องมือวินิจฉัยโรค ไม่จ่ายยา ไม่แทนดุลยพินิจแพทย์ และไม่ใช่ระบบเฝ้าระวังฉุกเฉิน 24 ชั่วโมง หากมีภาวะวิกฤตควรติดต่อ 1323, 1669 หรือผู้เชี่ยวชาญทันที',
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

  pw.Widget _demoBadge() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFFFF4E7),
        border: pw.Border.all(color: PdfColor.fromInt(0xFFE0A23A), width: 0.8),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Text(
        'ข้อมูลจำลองสำหรับสาธิต: ใช้แสดง workflow รายงานแพทย์ ไม่ใช่ข้อมูลผู้ป่วยจริง',
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromInt(0xFF8A4A12),
        ),
      ),
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

  pw.Widget _trendOneLine(List<ReportEntry> reports) {
    if (reports.isEmpty) {
      return pw.Text(
        'สรุปแนวโน้ม: ยังไม่มีข้อมูลเพียงพอสำหรับสรุปแนวโน้ม',
        style: const pw.TextStyle(fontSize: 10),
      );
    }

    final highPhqDays = reports.where((item) => item.phq9Score >= 15).length;
    final severeDays = reports.where((item) => item.phq9Score >= 20).length;
    final sosDays = reports.where((item) => item.isSosTriggered).length;
    final lowCbtDays = reports
        .where(
          (item) =>
              !item.isRestDay && _parseCbtRate(item.cbtCompletionRate) < 50,
        )
        .length;

    final parts = <String>[
      if (severeDays > 0)
        'PHQ-9 อยู่ระดับรุนแรง $severeDays วัน'
      else if (highPhqDays > 0)
        'PHQ-9 อยู่ระดับเฝ้าระวัง $highPhqDays วัน'
      else
        'PHQ-9 ยังไม่อยู่ระดับสูงในช่วงนี้',
      if (lowCbtDays > 0) 'CBT ต่ำ $lowCbtDays วัน' else 'CBT ค่อนข้างสม่ำเสมอ',
      if (sosDays > 0) 'มี SOS $sosDays ครั้ง' else 'ไม่พบ SOS',
    ];

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFF4FBFA),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text(
        'สรุปแนวโน้ม ${reports.length} รายการล่าสุด: ${parts.join(', ')}',
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
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

  String _formatDelta(int value) {
    if (value == 0) return 'No change from prior log';
    final sign = value > 0 ? '+' : '';
    final direction = value > 0
        ? 'higher risk than prior log'
        : 'lower than prior log';
    return '$sign$value point(s), $direction';
  }

  String _joinOrDash(List<String> values) {
    final cleaned = values
        .map(_cleanDemoText)
        .where((item) => item.trim().isNotEmpty)
        .toList();
    return cleaned.isEmpty ? '-' : cleaned.join(', ');
  }

  String _cleanDemoText(String value) {
    return value
        .replaceFirst(RegExp(r'^ข้อมูลจำลองสำหรับสาธิต:\s*'), '')
        .replaceFirst(RegExp(r'^ข้อมูลจำลอง:\s*'), '')
        .trim();
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
