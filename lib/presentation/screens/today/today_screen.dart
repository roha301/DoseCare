import 'package:flutter/material.dart';
import 'package:medimate/core/constants/app_colors.dart';
import 'package:medimate/core/constants/app_typography.dart';
import 'package:medimate/data/models/medicine_model.dart';
import 'package:medimate/presentation/controllers/app_controller.dart';
import 'package:medimate/presentation/screens/profile/profile_screen.dart';
import 'package:medimate/presentation/widgets/pill_visualizer.dart';
import 'package:medimate/presentation/widgets/radial_adherence_arc.dart';
import 'package:medimate/presentation/widgets/weekly_calendar_strip.dart';
import 'package:medimate/presentation/widgets/skip_reason_dialog.dart';
import 'package:medimate/presentation/widgets/dosecare_logo.dart';

class TodayScreen extends StatefulWidget {
  final VoidCallback? onNavigateToAdd;
  final VoidCallback? onNavigateToMeds;
  final VoidCallback? onNavigateToProfile;

  const TodayScreen({
    super.key,
    this.onNavigateToAdd,
    this.onNavigateToMeds,
    this.onNavigateToProfile,
  });

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  final AppController _controller = AppController.instance;
  final Set<int> _takingDoseIds = {};
  final Map<int, String> _snoozeLabels = {};

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

  void _showNotificationDetailsModal(BuildContext context, List<ScheduledDoseItem> timeline) {
    final pendingItems = timeline.where((t) => t.isPending).toList();
    final takenItems = timeline.where((t) => t.isTaken).toList();
    final skippedItems = timeline.where((t) => t.isSkipped).toList();
    final lowStockMeds = _controller.medicines.where((m) => m.isLowStock).toList();
    final totalAlerts = pendingItems.length + lowStockMeds.length;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.78,
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
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.notifications_active_rounded, color: AppColors.primary, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Notification Details',
                                  style: AppTypography.headlineSm(color: AppColors.onSurface).copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                Text(
                                  totalAlerts > 0
                                      ? '$totalAlerts active medication alerts today'
                                      : 'All reminders up to date',
                                  style: AppTypography.labelSm(color: AppColors.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Content
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      children: [
                        // 1. Low Stock Alerts (if any)
                        if (lowStockMeds.isNotEmpty) ...[
                          Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: AppColors.alertCoral, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'Low Supply Warnings (${lowStockMeds.length})',
                                style: AppTypography.labelMd(color: AppColors.alertCoral).copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...lowStockMeds.map((med) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.alertCoralBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.alertCoral.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              children: [
                                PillVisualizer(
                                  shape: med.type,
                                  colorName: med.pillColor,
                                  imprintCode: med.imprintCode,
                                  width: 28,
                                  height: 28,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        med.name,
                                        style: AppTypography.labelMd(color: AppColors.onSurface).copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        'Only ${med.remainingQuantity} pills left (Alert at ${med.lowStockThreshold})',
                                        style: AppTypography.bodySm(color: AppColors.alertCoral),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    widget.onNavigateToMeds?.call();
                                  },
                                  child: const Text('Refill', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                                ),
                              ],
                            ),
                          )),
                          const SizedBox(height: 16),
                        ],

                        // 2. Scheduled Dose Reminders
                        Row(
                          children: [
                            const Icon(Icons.alarm_rounded, color: AppColors.primary, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'Scheduled Reminders for Today',
                              style: AppTypography.labelMd(color: AppColors.onSurface).copyWith(fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: pendingItems.isNotEmpty ? AppColors.primaryContainer : AppColors.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${pendingItems.length} pending',
                                style: AppTypography.labelSm(
                                  color: pendingItems.isNotEmpty ? AppColors.onPrimaryContainer : AppColors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        if (timeline.isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Column(
                                children: [
                                  const Icon(Icons.notifications_off_outlined, size: 36, color: AppColors.outline),
                                  const SizedBox(height: 10),
                                  Text(
                                    'No Notifications Scheduled',
                                    style: AppTypography.headlineSm(color: AppColors.onSurface).copyWith(fontSize: 16),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Add medications to set alarm reminders and dose alerts.',
                                    style: AppTypography.bodySm(color: AppColors.onSurfaceVariant),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 14),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      widget.onNavigateToAdd?.call();
                                    },
                                    icon: const Icon(Icons.add_rounded, size: 18),
                                    label: const Text('Add Medication'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else ...[
                          // Pending list
                          ...pendingItems.map((item) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                            ),
                            child: Row(
                              children: [
                                PillVisualizer(
                                  shape: item.medicine.type,
                                  colorName: item.medicine.pillColor,
                                  imprintCode: item.medicine.imprintCode,
                                  width: 32,
                                  height: 32,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.medicine.name,
                                        style: AppTypography.headlineSm(color: AppColors.onSurface).copyWith(fontSize: 15, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${item.schedule.timeOfDay} (${item.schedule.periodLabel}) • ${item.medicine.dosage} • ${item.medicine.foodInstruction}',
                                        style: AppTypography.bodySm(color: AppColors.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () async {
                                    if (item.medicine.id != null && item.schedule.id != null) {
                                      await _controller.takeDose(
                                        medicineId: item.medicine.id!,
                                        scheduleId: item.schedule.id!,
                                        doseCount: item.schedule.doseCount,
                                      );
                                      if (mounted) {
                                        setState(() {});
                                        setModalState(() {});
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.adherenceGreen,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    visualDensity: VisualDensity.compact,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Take'),
                                ),
                              ],
                            ),
                          )),

                          // Taken/Skipped summary
                          if (takenItems.isNotEmpty || skippedItems.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Completed Reminders Today (${takenItems.length + skippedItems.length})',
                              style: AppTypography.labelSm(color: AppColors.onSurfaceVariant).copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            ...takenItems.map((item) => Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.adherenceGreenLight.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: AppColors.adherenceGreen, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '${item.medicine.name} (${item.schedule.timeOfDay}) - Taken ✓',
                                      style: AppTypography.bodySm(color: AppColors.adherenceGreenText),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                            ...skippedItems.map((item) => Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.cancel_outlined, color: AppColors.outline, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '${item.medicine.name} (${item.schedule.timeOfDay}) - Skipped',
                                      style: AppTypography.bodySm(color: AppColors.onSurfaceVariant),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                          ],
                        ],

                        const SizedBox(height: 20),
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

  String _formatActionTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      final min = dt.minute.toString().padLeft(2, '0');
      return '$hour:$min $period';
    } catch (_) {
      return 'Today';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    final lowStockMeds = _controller.medicines.where((m) => m.isLowStock).toList();
    final timeline = _controller.todayTimeline;

    return Scaffold(
      appBar: _buildAppBar(timeline),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => _controller.refreshData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Greeting & Header
              _buildGreeting(),
              const SizedBox(height: 16),

              // 2. Adherence Tracker Card with Radial Arc & Weekly Strip
              _buildAdherenceCard(timeline),
              const SizedBox(height: 20),

              // 3. Urgent Alert Banner (if low stock exists)
              if (lowStockMeds.isNotEmpty) ...[
                _buildRefillAlertBanner(lowStockMeds.first),
                const SizedBox(height: 20),
              ],

              // 4. Medication Pill Visualizer Preview
              _buildPillVisualizerSection(),
              const SizedBox(height: 24),

              // 5. Timeline Schedule
              _buildTimelineSection(timeline),
              const SizedBox(height: 20),

              // 6. PRN Rescue / As-Needed Action Box
              _buildPrnActionCard(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _openProfile(BuildContext context) {
    if (widget.onNavigateToProfile != null) {
      widget.onNavigateToProfile!();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
    }
  }

  PreferredSizeWidget _buildAppBar(List<ScheduledDoseItem> timeline) {
    final pendingCount = timeline.where((t) => t.isPending).length;
    final user = _controller.user;
    final hasName = user?.name != null && user!.name.trim().isNotEmpty && user.name != 'User';
    final userFirstName = hasName ? user.name.trim().split(' ').first : null;

    return AppBar(
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
                hasName ? 'Hi, $userFirstName' : 'Daily Care',
                style: AppTypography.labelSm(color: AppColors.onSurfaceVariant),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
      actions: [
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded, color: AppColors.onSurface),
              onPressed: () => _showNotificationDetailsModal(context, timeline),
            ),
            if (pendingCount > 0)
              Positioned(
                top: 10,
                right: 12,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: AppColors.alertCoral,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: InkWell(
            onTap: () => _openProfile(context),
            borderRadius: BorderRadius.circular(20),
            child: CircleAvatar(
              radius: 17,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: hasName && userFirstName != null && userFirstName.isNotEmpty
                  ? Text(
                      userFirstName[0].toUpperCase(),
                      style: AppTypography.labelMd(color: AppColors.primary).copyWith(fontWeight: FontWeight.bold),
                    )
                  : const Icon(Icons.person_rounded, color: AppColors.primary, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGreeting() {
    final now = DateTime.now();
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dateStr = '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';

    final greetingPrefix = now.hour < 12 ? 'Good Morning' : (now.hour < 17 ? 'Good Afternoon' : 'Good Evening');
    final user = _controller.user;
    final hasName = user?.name != null && user!.name.trim().isNotEmpty && user.name != 'User';
    final userName = hasName ? user.name.trim() : null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateStr,
                style: AppTypography.labelSm(color: AppColors.primary).copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 2),
              if (userName != null) ...[
                Text(
                  '$greetingPrefix,',
                  style: AppTypography.headlineLg(color: AppColors.onSurface),
                ),
                Text(
                  '$userName 👋',
                  style: AppTypography.headlineLg(color: AppColors.onSurface),
                  maxLines: 2,
                  softWrap: true,
                ),
              ] else
                Text(
                  '$greetingPrefix! 👋',
                  style: AppTypography.headlineLg(color: AppColors.onSurface),
                ),
              if (userName == null) ...[
                const SizedBox(height: 4),
                InkWell(
                  onTap: () => _openProfile(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_add_rounded, size: 14, color: AppColors.primary),
                        const SizedBox(width: 5),
                        Text(
                          'Add your name to profile →',
                          style: AppTypography.labelSm(color: AppColors.primary).copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: AppColors.secondaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            now.hour < 17 ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded,
            color: AppColors.onSecondaryContainer,
            size: 26,
          ),
        ),
      ],
    );
  }

  Widget _buildAdherenceCard(List<ScheduledDoseItem> timeline) {
    final totalCount = timeline.length;
    final takenCount = timeline.where((t) => t.isTaken).length;
    final percentage = totalCount > 0 ? ((takenCount / totalCount) * 100).round() : 0;

    String headline;
    String subline;

    if (totalCount == 0) {
      headline = 'No Doses Scheduled';
      subline = 'Tap "+" below to add your medications and track your routine.';
    } else if (takenCount == totalCount) {
      headline = '$takenCount of $totalCount doses taken (100%)';
      subline = 'Fantastic job! All scheduled doses completed for today. 🎉';
    } else {
      headline = '$takenCount of $totalCount doses taken ($percentage%)';
      final nextPending = timeline.firstWhere((t) => t.isPending);
      subline = 'Next up: ${nextPending.medicine.name} at ${nextPending.schedule.timeOfDay}.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              RadialAdherenceArc(percentage: percentage.toDouble(), size: 62, strokeWidth: 5.5),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          takenCount == totalCount && totalCount > 0
                              ? Icons.verified_rounded
                              : Icons.schedule_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            headline,
                            style: AppTypography.labelLg(color: AppColors.onSurface).copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subline,
                      style: AppTypography.bodySm(color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const WeeklyCalendarStrip(),
        ],
      ),
    );
  }

  Widget _buildRefillAlertBanner(MedicineModel lowMed) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.error,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Refill Notice',
                      style: AppTypography.labelMd(color: AppColors.onErrorContainer).copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${lowMed.remainingQuantity} LEFT',
                        style: AppTypography.labelSm(color: AppColors.error).copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${lowMed.name} is running low (${lowMed.remainingQuantity} doses left). Request refill now to avoid missing scheduled doses.',
                  style: AppTypography.bodySm(color: AppColors.onErrorContainer),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () async {
                    if (lowMed.id != null) {
                      await _controller.refillMedicine(lowMed.id!, 30);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Added 30 doses to ${lowMed.name}.'),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Add 30 doses',
                          style: AppTypography.labelMd(color: Colors.white),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillVisualizerSection() {
    final previewMeds = _controller.medicines.take(6).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pill Visualizer',
                style: AppTypography.headlineSm(color: AppColors.onSurface),
              ),
              Text(
                "Cabinet (${previewMeds.length})",
                style: AppTypography.labelSm(color: AppColors.primary).copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (previewMeds.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.outline),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No medications added yet. Added pills will appear here with color & shape identifiers.',
                      style: AppTypography.bodySm(color: AppColors.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: previewMeds.map((med) {
                  return Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        PillVisualizer(
                          shape: med.type,
                          colorName: med.pillColor,
                          imprintCode: med.imprintCode,
                          width: 32,
                          height: 32,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              med.name,
                              style: AppTypography.labelSm(color: AppColors.onSurface).copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              med.dosage,
                              style: AppTypography.bodySm(color: AppColors.onSurfaceVariant).copyWith(
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection(List<ScheduledDoseItem> timeline) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Timeline Schedule',
              style: AppTypography.headlineSm(color: AppColors.onSurface),
            ),
            Text(
              'Realtime Auto-Sync',
              style: AppTypography.labelSm(color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Empty state when no doses scheduled
        if (timeline.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.calendar_month_rounded, size: 30, color: AppColors.primary),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'No Doses Scheduled for Today',
                    style: AppTypography.headlineSm(color: AppColors.onSurface).copyWith(fontSize: 17),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your daily dose schedule is clear. Add your first medication to enable timely reminders and adherence tracking.',
                    style: AppTypography.bodySm(color: AppColors.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: () => widget.onNavigateToAdd?.call(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Add Medication'),
                  ),
                ],
              ),
            ),
          )
        else
          // Dynamic list of scheduled doses
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: timeline.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (ctx, idx) {
              final item = timeline[idx];
              return _buildDynamicTimelineNode(item);
            },
          ),
      ],
    );
  }

  Widget _buildDynamicTimelineNode(ScheduledDoseItem item) {
    final isDone = item.isTaken;
    final isSkipped = item.isSkipped;
    final isSnoozed = item.isSnoozed;
    final isPending = item.isPending;

    final scheduleId = item.schedule.id ?? 0;
    final isBusy = _takingDoseIds.contains(scheduleId);
    final snoozeText = _snoozeLabels[scheduleId] ?? 'Snooze 15m';

    // Status styling
    Color nodeColor;
    IconData nodeIcon;
    String tagText;
    Color tagColor;
    Color tagTextColor;
    IconData? tagIcon;

    if (isDone) {
      nodeColor = AppColors.adherenceGreen;
      nodeIcon = Icons.check_rounded;
      final actionTimeStr = item.todayLog?.actionTime != null
          ? 'Taken at ${_formatActionTime(item.todayLog!.actionTime!)}'
          : 'Taken';
      tagText = actionTimeStr;
      tagColor = AppColors.adherenceGreenLight;
      tagTextColor = AppColors.adherenceGreenText;
      tagIcon = Icons.task_alt_rounded;
    } else if (isSkipped) {
      nodeColor = AppColors.alertCoral;
      nodeIcon = Icons.close_rounded;
      tagText = 'Skipped: ${item.todayLog?.skipReason ?? "Not taken"}';
      tagColor = const Color(0xFFFFDAD6);
      tagTextColor = AppColors.alertCoral;
      tagIcon = Icons.cancel_outlined;
    } else if (isSnoozed) {
      nodeColor = AppColors.secondary;
      nodeIcon = Icons.snooze_rounded;
      tagText = 'Snoozed 15m';
      tagColor = AppColors.secondaryContainer;
      tagTextColor = AppColors.onSecondaryContainer;
      tagIcon = Icons.snooze_rounded;
    } else {
      nodeColor = AppColors.primary;
      nodeIcon = Icons.circle;
      tagText = 'Due Now';
      tagColor = AppColors.primaryContainer;
      tagTextColor = AppColors.onPrimaryContainer;
    }

    final timeLabel = '${item.schedule.periodLabel} • ${item.schedule.timeOfDay}';

    return Stack(
      children: [
        Positioned(
          left: 10,
          top: 20,
          bottom: 0,
          child: Container(
            width: 2,
            color: AppColors.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: nodeColor,
                shape: BoxShape.circle,
                border: isPending
                    ? Border.all(color: AppColors.primaryFixed, width: 3)
                    : null,
              ),
              child: Icon(nodeIcon, size: 12, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          timeLabel,
                          style: AppTypography.headlineSm(
                            color: isPending ? AppColors.primary : AppColors.onSurface,
                          ).copyWith(fontSize: 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: tagColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (tagIcon != null) ...[
                              Icon(tagIcon, size: 13, color: tagTextColor),
                              const SizedBox(width: 4),
                            ],
                            Flexible(
                              child: Text(
                                tagText,
                                style: AppTypography.labelSm(color: tagTextColor).copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Dose Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: isPending
                              ? AppColors.primary.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.03),
                          blurRadius: isPending ? 10 : 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: PillVisualizer(
                                  shape: item.medicine.type,
                                  colorName: item.medicine.pillColor,
                                  imprintCode: item.medicine.imprintCode,
                                  width: 32,
                                  height: 32,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${item.medicine.name} ${item.medicine.dosage}',
                                    style: AppTypography.headlineSm(color: AppColors.onSurface).copyWith(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    item.medicine.foodInstruction.isNotEmpty
                                        ? item.medicine.foodInstruction
                                        : 'Take with full glass of water',
                                    style: AppTypography.bodySm(color: AppColors.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            if (isDone)
                              Container(
                                width: 34,
                                height: 34,
                                decoration: const BoxDecoration(
                                  color: AppColors.surfaceContainerHigh,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.done_all_rounded,
                                  color: AppColors.adherenceGreen,
                                  size: 20,
                                ),
                              ),
                          ],
                        ),

                        // Action Buttons if dose is Pending or Snoozed
                        if (isPending || isSnoozed) ...[
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: isBusy
                                  ? null
                                  : () async {
                                      if (item.medicine.id == null || item.schedule.id == null) return;
                                      setState(() => _takingDoseIds.add(scheduleId));
                                      await _controller.takeDose(
                                        medicineId: item.medicine.id!,
                                        scheduleId: item.schedule.id!,
                                        doseCount: item.schedule.doseCount,
                                      );
                                      if (mounted) {
                                        setState(() => _takingDoseIds.remove(scheduleId));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Dose recorded for ${item.medicine.name} ✓'),
                                            backgroundColor: AppColors.primary,
                                          ),
                                        );
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                minimumSize: const Size(0, 50),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: isBusy
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Icon(Icons.check_circle_rounded, size: 20),
                              label: Text(
                                isBusy ? 'Recording Dose...' : 'Take Dose (${item.medicine.dosage})',
                                style: AppTypography.labelLg(color: Colors.white).copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    if (item.medicine.id != null) {
                                      _controller.snoozeDose(
                                        medicineId: item.medicine.id!,
                                        scheduleId: item.schedule.id,
                                        medicineName: item.medicine.name,
                                        dosage: item.medicine.dosage,
                                        minutes: 15,
                                      );
                                      setState(() => _snoozeLabels[scheduleId] = 'Snoozed 15m ✓');
                                      Future.delayed(const Duration(seconds: 3), () {
                                        if (mounted) {
                                          setState(() => _snoozeLabels.remove(scheduleId));
                                        }
                                      });
                                    }
                                  },
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: AppColors.surfaceContainer,
                                    side: BorderSide.none,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    minimumSize: const Size(0, 42),
                                  ),
                                  icon: const Icon(Icons.snooze_rounded, size: 18, color: AppColors.onSurface),
                                  label: Text(
                                    snoozeText,
                                    style: AppTypography.labelMd(color: AppColors.onSurface),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final reason = await SkipReasonSheet.show(
                                      context,
                                      medicineName: item.medicine.name,
                                    );
                                    if (reason != null && item.medicine.id != null && item.schedule.id != null) {
                                      await _controller.skipDose(
                                        medicineId: item.medicine.id!,
                                        scheduleId: item.schedule.id!,
                                        reason: reason,
                                      );
                                    }
                                  },
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: AppColors.surfaceContainer,
                                    side: BorderSide.none,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    minimumSize: const Size(0, 42),
                                  ),
                                  icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.onSurfaceVariant),
                                  label: Text(
                                    'Skip with Note',
                                    style: AppTypography.labelMd(color: AppColors.onSurfaceVariant),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrnActionCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.medical_services_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Need an extra pill?',
                  style: AppTypography.headlineSm(color: AppColors.onSurface).copyWith(
                    fontSize: 15,
                  ),
                ),
                Text(
                  'Log PRN or rescue inhalers anytime',
                  style: AppTypography.bodySm(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (_controller.medicines.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please add a medication first before logging PRN doses.'),
                    backgroundColor: AppColors.primary,
                  ),
                );
                return;
              }

              // Show modal to pick medicine
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (ctx) {
                  return SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Log PRN / Extra Dose',
                            style: AppTypography.headlineSm(color: AppColors.onSurface).copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Select which medication you took as-needed:',
                            style: AppTypography.bodySm(color: AppColors.onSurfaceVariant),
                          ),
                          const SizedBox(height: 14),
                          ..._controller.medicines.map((m) {
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              leading: PillVisualizer(
                                shape: m.type,
                                colorName: m.pillColor,
                                imprintCode: m.imprintCode,
                                width: 34,
                                height: 34,
                              ),
                              title: Text(m.name, style: AppTypography.labelLg(color: AppColors.onSurface)),
                              subtitle: Text(m.dosage, style: AppTypography.bodySm(color: AppColors.onSurfaceVariant)),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  if (m.id != null) {
                                    await _controller.takeDose(
                                      medicineId: m.id!,
                                      scheduleId: 0,
                                      doseCount: 1,
                                    );
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Extra dose of ${m.name} recorded in history ✓'),
                                          backgroundColor: AppColors.adherenceGreen,
                                        ),
                                      );
                                    }
                                  }
                                },
                                child: const Text('Log 1 Dose', style: TextStyle(color: Colors.white)),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryFixed,
              foregroundColor: AppColors.onPrimaryFixed,
              minimumSize: const Size(90, 36),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Text(
              '+ Log PRN',
              style: AppTypography.labelSm(color: AppColors.onPrimaryFixed).copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
