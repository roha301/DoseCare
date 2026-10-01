import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'package:dosecare/core/database/database_helper.dart';
import 'package:dosecare/core/reports/adherence_report_pdf.dart';

import 'package:http/http.dart' as http;

const String dailyEmailTask = 'dailyCaregiverEmail';
const String weeklyEmailTask = 'weeklyCaregiverEmail';

/// Brevo API Key injected at build time via --dart-define=BREVO_API_KEY=...
/// Never hardcode this value here. Pass it at build or run time.
const String _brevoApiKey = String.fromEnvironment('BREVO_API_KEY');

/// Sends a report directly to the caregiver via Brevo REST API.
Future<void> sendCaregiverReportEmail({
  required String period,
  required File pdf,
  required String caregiverEmail,
  required String patientName,
}) async {
  if (caregiverEmail.trim().isEmpty) {
    throw ArgumentError('Caregiver email address is empty.');
  }

  final attachmentBase64 = base64Encode(await pdf.readAsBytes());

  final response = await http.post(
    Uri.parse('https://api.brevo.com/v3/smtp/email'),
    headers: {
      'accept': 'application/json',
      'api-key': _brevoApiKey,
      'content-type': 'application/json',
    },
    body: jsonEncode({
      'sender': {
        'name': 'DoseCare',
        'email': 'ghugerohan13@gmail.com',
      },
      'to': [
        {'email': caregiverEmail.trim()}
      ],
      'subject': 'DoseCare $period Adherence Report — $patientName',
      'htmlContent': '<div style="font-family: Arial, sans-serif; color: #1e293b; padding: 20px;">'
          '<h2 style="color: #0284c7;">DoseCare $period Adherence Report</h2>'
          '<p>Hello,</p>'
          '<p>Attached is the <strong>$period Medication Adherence Report</strong> for <strong>${_escapeHtml(patientName)}</strong>.</p>'
          '<p style="margin-top: 20px; font-size: 12px; color: #64748b;">Sent automatically by DoseCare App.</p>'
          '</div>',
      'attachment': [
        {
          'name': 'dosecare_${period.toLowerCase()}_report.pdf',
          'content': attachmentBase64,
        }
      ],
    }),
  );

  if (response.statusCode >= 200 && response.statusCode < 300) {
    debugPrint('Caregiver report email sent successfully via Brevo API.');
  } else {
    debugPrint('Failed to send Brevo email: ${response.statusCode} - ${response.body}');
    throw Exception('Brevo email API failed with status ${response.statusCode}: ${response.body}');
  }
}

String _escapeHtml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');

/// The sender is configured once in Firebase/Brevo. Keep these compatibility
/// methods so existing controller callers do not store an app password.
Future<void> saveCaregiverEmailCredentials(String gmailAddress, String _) async {
  await saveCaregiverEmailAddress(gmailAddress);
}

Future<void> saveCaregiverEmailAddress(String address) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('caregiver_email_sender_address', address.trim());
}

Future<String?> getCaregiverEmailSenderAddress() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('caregiver_email_sender_address');
}

Future<bool> hasCaregiverEmailCredentials() async => true;

Duration delayUntilNext({required int hour, required int minute, int? weekday}) {
  final now = DateTime.now();
  var next = DateTime(now.year, now.month, now.day, hour, minute);
  if (weekday != null) {
    while (next.weekday != weekday || !next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
  } else if (!next.isAfter(now)) {
    next = next.add(const Duration(days: 1));
  }
  return next.difference(now);
}

@pragma('vm:entry-point')
void caregiverEmailCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await Firebase.initializeApp();
      final user = await DatabaseHelper.instance.getUserProfile();
      final caregiverEmail = user.caregiverEmail?.trim() ?? '';
      if (caregiverEmail.isEmpty) return true;

      final now = DateTime.now();
      final start = task == weeklyEmailTask
          ? DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6))
          : DateTime(now.year, now.month, now.day);
      final period = task == weeklyEmailTask ? 'Weekly' : 'Daily';
      final pdf = await generateAdherenceReportPdf(
        start: start,
        end: now,
        reportTitle: 'DoseCare $period Report',
      );
      await sendCaregiverReportEmail(
        period: period,
        pdf: pdf,
        caregiverEmail: caregiverEmail,
        patientName: user.name.isNotEmpty ? user.name : 'The patient',
      );
      return true;
    } catch (e) {
      debugPrint('DoseCare caregiver email task failed: $e');
      return false;
    }
  });
}
