import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:medimate/core/constants/app_colors.dart';
import 'package:medimate/core/constants/app_typography.dart';
import 'package:medimate/presentation/controllers/app_controller.dart';
import 'package:medimate/presentation/widgets/radial_adherence_arc.dart';
import 'package:medimate/presentation/widgets/dosecare_logo.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  final AppController _controller = AppController.instance;
  String _activeTab = 'week'; // week, month, 90days
  // Retained only while the legacy helper remains in this file; it is no
  // longer rendered on the Insights screen.
  bool _isOptimizationDismissed = false;
  bool _isTimeShifted = false;
  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onStateChange);
  }

  @override
  void dispose() {
    _controller.removeListener(_onStateChange);
    super.dispose();
  }

  void _onStateChange() {
    if (mounted) setState(() {});
  }

  String _formatLogDate(String? isoString) {
    if (isoString == null) return 'Today';
    try {
      final dt = DateTime.parse(isoString);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day} ${months[dt.month - 1]}';
    } catch (_) {
      return 'Today';
    }
  }

  String _formatLogTimeOnly(String? isoString) {
    if (isoString == null) return '--:--';
    try {
      final dt = DateTime.parse(isoString);
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      final min = dt.minute.toString().padLeft(2, '0');
      return '$hour:$min $period';
    } catch (_) {
      return '--:--';
    }
  }

  @override
  Widget build(BuildContext context) {
    final streakDays = _controller.adherenceStats['streakDays'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const DoseCareLogo(
              size: 34,
              borderRadius: 8,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'DoseCare',
                  style: AppTypography.headlineSm(color: AppColors.primary).copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Insights',
                  style: AppTypography.labelSm(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header Context & Streak Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ROUTINE INTELLIGENCE',
                        style: AppTypography.labelSm(color: AppColors.secondary).copyWith(
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Health Insights',
                        style: AppTypography.headlineLg(color: AppColors.onSurface),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: streakDays > 0 ? AppColors.adherenceGreenLight : AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.local_fire_department_rounded, color: streakDays > 0 ? AppColors.adherenceGreen : AppColors.outline, size: 18),
                          const SizedBox(width: 4),
                          Text('$streakDays-Day Streak', style: AppTypography.labelMd(color: streakDays > 0 ? AppColors.adherenceGreenText : AppColors.outline).copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 2. Segmented Time Tabs
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _buildTab('week', 'This Week'),
                  _buildTab('month', 'This Month'),
                  _buildTab('90days', 'Last 90 Days'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 3. Hero Adherence Bento Card
            _buildHeroAdherenceBento(),
            const SizedBox(height: 24),

            // 4. Weekly Performance Visual Columns (7 Days)
            _buildWeeklyPerformanceSection(),
            const SizedBox(height: 24),

            // 5. Medication Adherence Breakdown
            _buildMedicationBreakdownSection(),
            const SizedBox(height: 24),

            // 6. Dose Log History Activity Stream
            _buildDoseLogHistorySection(),
            const SizedBox(height: 24),

            // 7. Care Team & Export Section
            _buildCareTeamAndExportSection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String key, String label) {
    final isSelected = _activeTab == key;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeTab = key),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surfaceContainerLowest : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: AppTypography.labelMd(
                color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
              ).copyWith(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroAdherenceBento() {
    final stats = _controller.adherenceStats;
    final rate = stats['adherenceRate'] ?? 0;
    final taken = stats['dosesTaken'] ?? 0;
    final total = stats['totalLogged'] ?? 0;

    String description;
    if (total == 0) {
      description = 'Start logging doses from your daily schedule to generate adherence reports and consistency metrics.';
    } else if (rate >= 90) {
      description = 'Outstanding consistency! Keep taking medications at your scheduled times to maintain high clinical adherence.';
    } else if (rate >= 70) {
      description = 'Good routine! A few doses were missed or delayed. Set alerts to keep your consistency on track.';
    } else {
      description = 'Several doses were skipped or missed. Follow your schedule closely for best health outcomes.';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Overall Adherence Rate',
                    style: AppTypography.labelMd(color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '$rate%',
                        style: AppTypography.displayLg(color: AppColors.primary).copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (total > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: rate >= 80 ? AppColors.adherenceGreenLight : AppColors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                rate >= 80 ? Icons.trending_up_rounded : Icons.trending_flat_rounded,
                                size: 14,
                                color: rate >= 80 ? AppColors.adherenceGreen : AppColors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                rate >= 80 ? 'Optimal' : 'Active',
                                style: AppTypography.labelSm(
                                  color: rate >= 80 ? AppColors.adherenceGreenText : AppColors.onSurfaceVariant,
                                ).copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              RadialAdherenceArc(
                percentage: rate.toDouble(),
                size: 64,
                strokeWidth: 6,
                centerWidget: Icon(
                  rate >= 80 ? Icons.verified_rounded : Icons.insights_rounded,
                  color: AppColors.primary,
                  size: 26,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: AppTypography.bodySm(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),

          // Micro Metric Grid
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Doses Taken', style: AppTypography.labelSm(color: AppColors.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '$taken ',
                              style: AppTypography.headlineSm(color: AppColors.onSurface).copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text: '/ $total logged',
                              style: AppTypography.bodySm(color: AppColors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cabinet Size', style: AppTypography.labelSm(color: AppColors.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Text(
                        '${_controller.medicines.length} Prescriptions',
                        style: AppTypography.headlineSm(color: AppColors.primary).copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyPerformanceSection() {
    final now = DateTime.now();
    final dayLabels = ['M', 'T', 'W', 'TH', 'F', 'S', 'SU'];
    final currentWeekday = now.weekday; // 1=Mon, 7=Sun

    // Build per-day adherence from history
    final history = _controller.doseHistory;
    final Map<int, Map<String, int>> dayStats = {};
    for (int i = 1; i <= 7; i++) {
      dayStats[i] = {'taken': 0, 'total': 0};
    }

    for (final log in history) {
      final timeStr = log['scheduled_time'] as String? ?? log['action_time'] as String?;
      if (timeStr == null) continue;
      try {
        final dt = DateTime.parse(timeStr);
        // Only count the current week (Mon-Sun)
        final diff = now.difference(DateTime(dt.year, dt.month, dt.day)).inDays;
        if (diff >= 0 && diff < 7) {
          final weekday = dt.weekday; // 1=Mon, 7=Sun
          dayStats[weekday]!['total'] = (dayStats[weekday]!['total'] ?? 0) + 1;
          if ((log['status'] as String?) == 'TAKEN') {
            dayStats[weekday]!['taken'] = (dayStats[weekday]!['taken'] ?? 0) + 1;
          }
        }
      } catch (_) {}
    }

    final hasAnyData = dayStats.values.any((d) => (d['total'] ?? 0) > 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Weekly Performance',
              style: AppTypography.headlineSm(color: AppColors.onSurface).copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'This Week',
              style: AppTypography.labelSm(color: AppColors.secondary).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: !hasAnyData
              ? Column(
                  children: [
                    const SizedBox(height: 12),
                    Icon(Icons.bar_chart_rounded, size: 40, color: AppColors.outline.withValues(alpha: 0.4)),
                    const SizedBox(height: 8),
                    Text(
                      'No doses logged this week yet',
                      style: AppTypography.labelMd(color: AppColors.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Start taking doses from the Today tab to see your weekly chart.',
                      style: AppTypography.bodySm(color: AppColors.outline),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                  ],
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(7, (i) {
                    final dayIndex = i + 1; // 1=Mon
                    final isToday = dayIndex == currentWeekday;
                    final isFuture = dayIndex > currentWeekday;
                    final stats = dayStats[dayIndex]!;
                    final total = stats['total'] ?? 0;
                    final taken = stats['taken'] ?? 0;
                    final rate = total > 0 ? taken / total : 0.0;

                    Color col;
                    double heightFactor;

                    if (isFuture) {
                      col = AppColors.surfaceContainerHighest;
                      heightFactor = 0.1;
                    } else if (total == 0) {
                      col = AppColors.surfaceContainerHigh;
                      heightFactor = 0.15;
                    } else if (rate >= 0.8) {
                      col = AppColors.adherenceGreen;
                      heightFactor = 0.7 + rate * 0.3;
                    } else if (rate >= 0.5) {
                      col = AppColors.secondary;
                      heightFactor = 0.4 + rate * 0.3;
                    } else {
                      col = AppColors.alertCoral;
                      heightFactor = 0.2 + rate * 0.2;
                    }

                    if (isToday && total == 0) {
                      col = AppColors.primary.withValues(alpha: 0.3);
                      heightFactor = 0.15;
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (total > 0 && !isFuture)
                          Text(
                            '${(rate * 100).round()}%',
                            style: AppTypography.labelSm(
                              color: isToday ? AppColors.primary : AppColors.onSurfaceVariant,
                            ).copyWith(fontSize: 9, fontWeight: FontWeight.bold),
                          )
                        else
                          const SizedBox(height: 13),
                        const SizedBox(height: 4),
                        Container(
                          width: 30,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.bottomCenter,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOut,
                            width: 30,
                            height: 80 * heightFactor.clamp(0.05, 1.0),
                            decoration: BoxDecoration(
                              color: col,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dayLabels[i],
                          style: AppTypography.labelSm(
                            color: isToday ? AppColors.primary : AppColors.onSurfaceVariant,
                          ).copyWith(fontWeight: isToday ? FontWeight.bold : FontWeight.normal),
                        ),
                        const SizedBox(height: 4),
                        Icon(
                          isToday
                              ? Icons.radio_button_checked_rounded
                              : (isFuture
                                  ? Icons.circle_outlined
                                  : (total == 0
                                      ? Icons.remove_circle_outline_rounded
                                      : (rate >= 0.8 ? Icons.check_circle_rounded : Icons.warning_amber_rounded))),
                          size: 14,
                          color: isFuture
                              ? AppColors.outline.withValues(alpha: 0.3)
                              : (total == 0
                                  ? AppColors.outline.withValues(alpha: 0.5)
                                  : col),
                        ),
                      ],
                    );
                    }),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildMedicationBreakdownSection() {
    final meds = _controller.medicines;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Medication Breakdown',
                style: AppTypography.headlineSm(color: AppColors.onSurface).copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${meds.length} Active',
                style: AppTypography.labelSm(color: AppColors.primary).copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (meds.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'No medications added yet.',
                  style: AppTypography.bodySm(color: AppColors.onSurfaceVariant),
                ),
              ),
            )
          else
            ...meds.map((m) {
              final percent = m.stockPercentage;
              final rate = (percent * 100).round();
              final col = m.isLowStock ? AppColors.alertCoral : AppColors.primary;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${m.name} (${m.dosage})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyMd(color: AppColors.onSurface),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '${m.remainingQuantity} left ($rate%)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: AppTypography.labelMd(color: col).copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percent,
                        minHeight: 6,
                        backgroundColor: AppColors.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(col),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildScheduleOptimizationSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AppColors.secondary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Schedule Optimization',
                style: AppTypography.headlineSm(color: AppColors.onSurface).copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.alarm_on_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Timing Recommendation',
                      style: AppTypography.labelMd(color: AppColors.onSurface).copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Setting morning doses right after breakfast improves adherence by 24% according to clinical guidelines.',
                      style: AppTypography.bodySm(color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isTimeShifted
                      ? null
                      : () {
                          setState(() => _isTimeShifted = true);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Optimal reminders configured ✓'),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text(_isTimeShifted ? 'Optimal Reminders Active' : 'Optimize Reminders'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => setState(() => _isOptimizationDismissed = true),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<File> _generatePdfReport() async {
    final pdf = pw.Document();
    final historyLogs = _controller.allHistoryLogs;
    final userName = _controller.user?.name ?? 'Patient';
    final rate = _controller.adherenceStats['adherenceRate'] ?? 0;
    final taken = _controller.adherenceStats['dosesTaken'] ?? 0;
    final total = _controller.adherenceStats['totalLogged'] ?? 0;
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('DoseCare Adherence Report', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
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

            // Patient & Stats Summary Card
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
                    pw.Text('Active Meds', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.SizedBox(height: 2),
                    pw.Text('${_controller.medicines.length}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                  ]),
                ],
              ),
            ),
            pw.SizedBox(height: 18),

            // Daily Meds Table
            pw.Text('Daily Medication Log History', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),

            if (historyLogs.isEmpty)
              pw.Paragraph(text: 'No medication intake records found.')
            else
              pw.TableHelper.fromTextArray(
                headers: ['Date', 'Medicine', 'Dosage', 'Time', 'Status'],
                data: historyLogs.map((log) {
                  final status = (log['status'] as String? ?? 'TAKEN') == 'TAKEN' ? 'Taken' : 'Not Taken';
                  final medName = log['medicine_name'] as String? ?? 'Medicine';
                  final dosage = log['dosage'] as String? ?? '-';
                  final actionTime = log['action_time'] as String? ?? log['scheduled_time'] as String?;
                  final date = _formatLogDate(actionTime);
                  final time = _formatLogTimeOnly(actionTime);
                  return [date, medName, dosage, time, status];
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
            pw.Text('Generated securely on-device by DoseCare Medication Assistant. Confidential medical document.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
          ];
        },
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/DoseCare_Report_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  void _shareLogViaApps() async {
    final userName = _controller.user?.name ?? 'User';
    final historyLogs = _controller.allHistoryLogs;
    final rate = _controller.adherenceStats['adherenceRate'] ?? 0;
    final taken = _controller.adherenceStats['dosesTaken'] ?? 0;
    final total = _controller.adherenceStats['totalLogged'] ?? 0;
    final nowFormatted = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    final buffer = StringBuffer();
    buffer.writeln('📋 *DoseCare Medication Adherence Report*');
    buffer.writeln('👤 Patient: $userName');
    buffer.writeln('📅 Date: $nowFormatted');
    buffer.writeln('📈 Overall Adherence: $rate% ($taken of $total doses taken)');
    buffer.writeln('💊 Active Prescriptions: ${_controller.medicines.length}');
    buffer.writeln('');
    buffer.writeln('📊 *Daily Medication Intake History:*');

    if (historyLogs.isEmpty) {
      buffer.writeln('No dose history recorded yet.');
    } else {
      for (final log in historyLogs.take(25)) {
        final med = log['medicine_name'] ?? 'Medicine';
        final dose = log['dosage'] ?? '';
        final status = (log['status'] == 'TAKEN') ? '✅ Taken' : '❌ Not Taken';
        final actionTime = log['action_time'] ?? log['scheduled_time'];
        final date = _formatLogDate(actionTime);
        final time = _formatLogTimeOnly(actionTime);
        buffer.writeln('• $date $time | $med ($dose): $status');
      }
    }
    buffer.writeln('');
    buffer.writeln('Generated with DoseCare — AI Assisted Medication Management');

    await SharePlus.instance.share(
      ShareParams(
        text: buffer.toString(),
        subject: 'DoseCare Adherence Report - $userName',
      ),
    );
  }

  void _showViewReportModal() {
    final userName = _controller.user?.name ?? 'Patient';
    final historyLogs = _controller.allHistoryLogs;
    final rate = _controller.adherenceStats['adherenceRate'] ?? 0;
    final taken = _controller.adherenceStats['dosesTaken'] ?? 0;
    final total = _controller.adherenceStats['totalLogged'] ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Medication Adherence Report',
                                style: AppTypography.headlineSm(color: AppColors.onSurface).copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Daily medication intake history & compliance',
                                style: AppTypography.labelSm(color: AppColors.onSurfaceVariant),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                                   // Summary metrics
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Flexible(
                            child: Column(
                              children: [
                                Text('Patient', style: AppTypography.labelSm(color: AppColors.outline)),
                                const SizedBox(height: 2),
                                Text(
                                  userName.isNotEmpty ? userName : 'You',
                                  style: AppTypography.labelMd(color: AppColors.onSurface).copyWith(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 30, color: AppColors.divider),
                          Column(
                            children: [
                              Text('Adherence', style: AppTypography.labelSm(color: AppColors.outline)),
                              const SizedBox(height: 2),
                              Text('$rate%', style: AppTypography.labelMd(color: AppColors.primary).copyWith(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Container(width: 1, height: 30, color: AppColors.divider),
                          Column(
                            children: [
                              Text('Doses Taken', style: AppTypography.labelSm(color: AppColors.outline)),
                              const SizedBox(height: 2),
                              Text('$taken / $total', style: AppTypography.labelMd(color: AppColors.onSurface).copyWith(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Tabular daily meds report
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Daily Meds Report Table',
                        style: AppTypography.labelMd(color: AppColors.onSurface).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Expanded(
                    child: historyLogs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.table_rows_rounded, size: 40, color: AppColors.outline),
                                const SizedBox(height: 8),
                                Text('No Daily Logs Recorded', style: AppTypography.headlineSm(color: AppColors.onSurface).copyWith(fontSize: 16)),
                                const SizedBox(height: 4),
                                Text('Intake records will show here in tabular form.', style: AppTypography.bodySm(color: AppColors.onSurfaceVariant)),
                              ],
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.vertical,
                                    child: DataTable(
                                      headingRowColor: WidgetStateProperty.all(AppColors.surfaceContainerLow),
                                      columnSpacing: 18,
                                      horizontalMargin: 12,
                                      columns: [
                                        DataColumn(label: Text('Date', style: AppTypography.labelSm(color: AppColors.primary).copyWith(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Medicine', style: AppTypography.labelSm(color: AppColors.primary).copyWith(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Dosage', style: AppTypography.labelSm(color: AppColors.primary).copyWith(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Time', style: AppTypography.labelSm(color: AppColors.primary).copyWith(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Status', style: AppTypography.labelSm(color: AppColors.primary).copyWith(fontWeight: FontWeight.bold))),
                                      ],
                                      rows: historyLogs.map((log) {
                                        final isTaken = (log['status'] as String? ?? 'TAKEN') == 'TAKEN';
                                        final med = log['medicine_name'] as String? ?? 'Medicine';
                                        final dosage = log['dosage'] as String? ?? '-';
                                        final actionTime = log['action_time'] as String? ?? log['scheduled_time'] as String?;
                                        final date = _formatLogDate(actionTime);
                                        final time = _formatLogTimeOnly(actionTime);

                                        return DataRow(
                                          cells: [
                                            DataCell(Text(date, style: AppTypography.labelSm(color: AppColors.onSurfaceVariant))),
                                            DataCell(Text(med, style: AppTypography.labelMd(color: AppColors.onSurface).copyWith(fontWeight: FontWeight.w600))),
                                            DataCell(Text(dosage, style: AppTypography.bodySm(color: AppColors.onSurfaceVariant))),
                                            DataCell(Text(time, style: AppTypography.bodySm(color: AppColors.onSurfaceVariant))),
                                            DataCell(
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: isTaken ? AppColors.adherenceGreenLight : AppColors.alertCoralBg,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  isTaken ? 'Taken ✓' : 'Not Taken',
                                                  style: AppTypography.labelSm(color: isTaken ? AppColors.adherenceGreenText : AppColors.alertCoral).copyWith(fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),

                  // Bottom action buttons (Download PDF & Share)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isGeneratingPdf
                                ? null
                                : () async {
                                    setModalState(() => _isGeneratingPdf = true);
                                    try {
                                      final pdfFile = await _generatePdfReport();
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('✓ PDF Report saved to: ${pdfFile.path.split('/').last}'),
                                            backgroundColor: AppColors.primary,
                                            action: SnackBarAction(
                                              label: 'Share PDF',
                                              textColor: Colors.white,
                                              onPressed: () {
                                                SharePlus.instance.share(
                                                  ShareParams(
                                                    files: [XFile(pdfFile.path)],
                                                    text: 'DoseCare Medication Adherence Report for $userName',
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        );
                                      }
                                      // Do not leave the report-saved SnackBar visible beneath the
                                      // native sheet when the user returns to the app.
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                      }
                                      await SharePlus.instance.share(
                                        ShareParams(
                                          files: [XFile(pdfFile.path)],
                                          text: 'DoseCare Medication Adherence Report for $userName',
                                        ),
                                      );
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error generating PDF: $e'), backgroundColor: AppColors.error),
                                        );
                                      }
                                    } finally {
                                      setModalState(() => _isGeneratingPdf = false);
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: _isGeneratingPdf
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.download_rounded, size: 20),
                            label: Text(
                              _isGeneratingPdf ? 'Generating PDF...' : 'Download PDF',
                              style: AppTypography.labelMd(color: Colors.white).copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _shareLogViaApps();
                          },
                          icon: const Icon(Icons.share_rounded, color: AppColors.primary),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                            padding: const EdgeInsets.all(12),
                          ),
                          tooltip: 'Share via WhatsApp / Other Apps',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDoseLogHistorySection() {
    final historyLogs = _controller.allHistoryLogs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Dose Log History',
              style: AppTypography.headlineSm(color: AppColors.onSurface).copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${historyLogs.length} Records',
                style: AppTypography.labelSm(color: AppColors.primary).copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (historyLogs.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.table_chart_outlined, size: 36, color: AppColors.outline),
                  const SizedBox(height: 10),
                  Text(
                    'No Doses Logged Yet',
                    style: AppTypography.headlineSm(color: AppColors.onSurface).copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'As you take or log your daily medications, real-time tabular records will appear here.',
                    style: AppTypography.bodySm(color: AppColors.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: DataTable(
                  horizontalMargin: 16,
                  columnSpacing: 20,
                  headingRowHeight: 44,
                  dataRowMinHeight: 48,
                  dataRowMaxHeight: 56,
                  headingRowColor: WidgetStateProperty.all(AppColors.surfaceContainerLow),
                  columns: [
                    DataColumn(
                      label: Text('Date', style: AppTypography.labelSm(color: AppColors.primary).copyWith(fontWeight: FontWeight.bold)),
                    ),
                    DataColumn(
                      label: Text('Medicine', style: AppTypography.labelSm(color: AppColors.primary).copyWith(fontWeight: FontWeight.bold)),
                    ),
                    DataColumn(
                      label: Text('Dosage', style: AppTypography.labelSm(color: AppColors.primary).copyWith(fontWeight: FontWeight.bold)),
                    ),
                    DataColumn(
                      label: Text('Time', style: AppTypography.labelSm(color: AppColors.primary).copyWith(fontWeight: FontWeight.bold)),
                    ),
                    DataColumn(
                      label: Text('Status', style: AppTypography.labelSm(color: AppColors.primary).copyWith(fontWeight: FontWeight.bold)),
                    ),
                  ],
                  rows: historyLogs.map((log) {
                    final status = log['status'] as String? ?? 'TAKEN';
                    final medName = log['medicine_name'] as String? ?? 'Medicine';
                    final dosage = log['dosage'] as String? ?? '-';
                    final actionTime = log['action_time'] as String? ?? log['scheduled_time'] as String?;
                    final date = _formatLogDate(actionTime);
                    final time = _formatLogTimeOnly(actionTime);

                    final isTaken = status == 'TAKEN';
                    final chipBg = isTaken ? AppColors.adherenceGreenLight : AppColors.alertCoralBg;
                    final chipColor = isTaken ? AppColors.adherenceGreenText : AppColors.alertCoral;
                    final chipText = isTaken ? 'Taken ✓' : 'Not Taken';

                    return DataRow(
                      cells: [
                        DataCell(
                          Text(date, style: AppTypography.labelSm(color: AppColors.onSurfaceVariant)),
                        ),
                        DataCell(
                          Text(medName, style: AppTypography.labelMd(color: AppColors.onSurface).copyWith(fontWeight: FontWeight.w600)),
                        ),
                        DataCell(
                          Text(dosage.isNotEmpty ? dosage : '-', style: AppTypography.bodySm(color: AppColors.onSurfaceVariant)),
                        ),
                        DataCell(
                          Text(time, style: AppTypography.bodySm(color: AppColors.onSurfaceVariant)),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: chipBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isTaken ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                  size: 12,
                                  color: chipColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  chipText,
                                  style: AppTypography.labelSm(color: chipColor).copyWith(fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCareTeamAndExportSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Care Team & Export',
          style: AppTypography.headlineSm(color: AppColors.onSurface).copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Export Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showViewReportModal,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 18, color: AppColors.primary),
                      label: Text(
                        'View Report',
                        style: AppTypography.labelMd(color: AppColors.onSurface).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _shareLogViaApps,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: Text(
                        'Share Log',
                        style: AppTypography.labelMd(color: Colors.white).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
