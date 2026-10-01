import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dosecare/core/constants/app_colors.dart';
import 'package:dosecare/core/constants/app_typography.dart';
import 'package:dosecare/presentation/controllers/app_controller.dart';

/// Shows every caregiver alert the app has sent (automatic SMS alerts on
/// Android, plus the DOSE_SKIPPED log) and lets the patient record that they
/// have confirmed with the caregiver, since the app has no way to detect a
/// real SMS reply.
class CaregiverAlertsHistoryScreen extends StatefulWidget {
  const CaregiverAlertsHistoryScreen({super.key});

  @override
  State<CaregiverAlertsHistoryScreen> createState() => _CaregiverAlertsHistoryScreenState();
}

class _CaregiverAlertsHistoryScreenState extends State<CaregiverAlertsHistoryScreen> {
  final AppController _controller = AppController.instance;
  late Future<List<Map<String, dynamic>>> _eventsFuture;

  @override
  void initState() {
    super.initState();
    _eventsFuture = _controller.getCaregiverEvents();
  }

  void _reload() {
    setState(() => _eventsFuture = _controller.getCaregiverEvents());
  }

  String _eventLabel(String eventType) {
    switch (eventType) {
      case 'DOSE_ALERT_SMS':
        return 'Missed-dose SMS sent';
      case 'DAILY_REPORT_SMS':
        return 'Daily summary SMS sent';
      case 'DOSE_SKIPPED':
        return 'Dose skipped';
      default:
        return eventType;
    }
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    return DateFormat('MMM d, h:mm a').format(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Caregiver Alert History', style: AppTypography.headlineSm(color: AppColors.onSurface)),
        iconTheme: const IconThemeData(color: AppColors.onSurface),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _eventsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          final events = snapshot.data!;
          if (events.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No caregiver alerts have been sent yet.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMd(color: AppColors.onSurfaceVariant),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final event = events[index];
              final acknowledgedAt = event['acknowledged_at'] as String?;
              final medicineName = event['medicine_name'] as String?;
              final eventType = event['event_type'] as String;

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medicineName ?? 'Daily report',
                      style: AppTypography.labelMd(color: AppColors.onSurface).copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(_eventLabel(eventType), style: AppTypography.bodySm(color: AppColors.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text(_formatTime(event['created_at'] as String?), style: AppTypography.bodySm(color: AppColors.onSurfaceVariant)),
                    const SizedBox(height: 10),
                    if (acknowledgedAt != null)
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.adherenceGreen),
                          const SizedBox(width: 6),
                          Text(
                            'Acknowledged ${_formatTime(acknowledgedAt)}',
                            style: AppTypography.bodySm(color: AppColors.adherenceGreenText),
                          ),
                        ],
                      )
                    else
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                          ),
                          onPressed: () async {
                            final eventId = event['id'] as int;
                            await _controller.acknowledgeCaregiverEvent(eventId);
                            _reload();
                          },
                          child: const Text('Mark as acknowledged'),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
