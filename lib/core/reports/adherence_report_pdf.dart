import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dosecare/core/database/database_helper.dart';

/// Builds a caregiver adherence report PDF directly from the database for an
/// arbitrary date range, with no dependency on AppController's cached,
/// all-time state. This makes it safe to call from a headless background
/// isolate (a workmanager task) where no UI or controller has been
/// initialized, unlike InsightsScreen's on-demand exporter.
Future<File> generateAdherenceReportPdf({
  required DateTime start,
  required DateTime end,
  required String reportTitle,
}) async {
  final user = await DatabaseHelper.instance.getUserProfile();
  final occurrences = await DatabaseHelper.instance.getOccurrencesInRange(start, end);
  final preferences = await SharedPreferences.getInstance();
  final conditions = preferences.getStringList('patient_conditions') ?? const <String>[];
  final allergies = preferences.getString('patient_allergies')?.trim() ?? '';
  final bloodGroup = preferences.getString('patient_blood_group')?.trim() ?? '';
  final doctorName = preferences.getString('patient_doctor_name')?.trim() ?? '';
  final doctorSpecialization = preferences.getString('patient_doctor_specialization')?.trim() ?? '';
  final doctorPhone = preferences.getString('patient_doctor_phone')?.trim() ?? '';

  var taken = 0;
  var notTaken = 0;
  for (final row in occurrences) {
    final status = row['status'] as String?;
    if (status == 'TAKEN') {
      taken++;
    } else if (status == 'SKIPPED' || status == 'MISSED' || status == 'NOT_TAKEN') {
      notTaken++;
    }
  }
  final total = occurrences.length;
  final rate = total == 0 ? 0 : ((taken / total) * 100).round();

  final pdf = pw.Document();
  final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
  final userName = user.name.isNotEmpty ? user.name : 'Patient';

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (pw.Context context) {
        return [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(reportTitle, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
                  pw.SizedBox(height: 2),
                  pw.Text('Clinical Medication Adherence & Daily Intake Log', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                ],
              ),
              pw.Text(dateStr, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Divider(),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.teal50,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(children: [
                  pw.Text('Patient Name', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  pw.SizedBox(height: 2),
                  pw.Text(userName, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                ]),
                pw.Column(children: [
                  pw.Text('Adherence Rate', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  pw.SizedBox(height: 2),
                  pw.Text('$rate%', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
                ]),
                pw.Column(children: [
                  pw.Text('Doses Taken', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  pw.SizedBox(height: 2),
                  pw.Text('$taken / $total', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                ]),
                pw.Column(children: [
                  pw.Text('Not Taken', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  pw.SizedBox(height: 2),
                  pw.Text('$notTaken', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.red700)),
                ]),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Text('Patient & Care Team Details', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['Field', 'Details'],
            data: [
              ['Age / Gender', '${user.age > 0 ? user.age : 'Not recorded'} / ${user.gender.isNotEmpty ? user.gender : 'Not recorded'}'],
              ['Blood group', bloodGroup.isEmpty ? 'Not recorded' : bloodGroup],
              ['Medical conditions', conditions.isEmpty ? 'None recorded' : conditions.join(', ')],
              ['Allergies', allergies.isEmpty ? 'None recorded' : allergies],
              ['Doctor / clinic', [doctorName, doctorSpecialization, doctorPhone].where((value) => value.isNotEmpty).join(' • ').isEmpty
                  ? 'Not recorded'
                  : [doctorName, doctorSpecialization, doctorPhone].where((value) => value.isNotEmpty).join(' • ')],
              ['Caregiver contact', user.caregiverEmail?.isNotEmpty == true
                  ? user.caregiverEmail!
                  : (user.caregiverPhone?.isNotEmpty == true ? user.caregiverPhone! : 'Not recorded')],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
          ),
          pw.SizedBox(height: 18),
          pw.Text('Dose-by-Dose Log', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          if (occurrences.isEmpty)
            pw.Paragraph(text: 'No doses were scheduled in this period.')
          else
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Time', 'Medicine', 'Dosage', 'Status', 'Recorded'],
              data: occurrences.map((row) {
                final scheduledAt = DateTime.tryParse(row['scheduled_at'] as String? ?? '');
                final date = scheduledAt != null ? DateFormat('dd MMM').format(scheduledAt) : '-';
                final time = scheduledAt != null ? DateFormat('h:mm a').format(scheduledAt) : '-';
                final status = row['status'] as String?;
                final statusLabel = status == 'TAKEN'
                    ? 'Taken'
                    : (status == 'SKIPPED' || status == 'MISSED' || status == 'NOT_TAKEN')
                        ? 'Not Taken'
                        : 'Pending';
                final actionAt = DateTime.tryParse(row['action_time'] as String? ?? '');
                final recorded = actionAt == null ? '-' : DateFormat('dd MMM, h:mm a').format(actionAt);
                return [date, time, row['name'] as String? ?? 'Medicine', row['dosage'] as String? ?? '-', statusLabel, recorded];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5))),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              cellStyle: const pw.TextStyle(fontSize: 9),
            ),
          pw.SizedBox(height: 20),
          pw.Divider(),
          pw.Text('Generated securely on-device by DoseCare. Confidential medical document.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
        ];
      },
    ),
  );

  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/DoseCare_CaregiverReport_${DateTime.now().millisecondsSinceEpoch}.pdf');
  await file.writeAsBytes(await pdf.save());
  return file;
}
