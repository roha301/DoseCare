import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';

class WeeklyCalendarStrip extends StatelessWidget {
  final Function(String dayName)? onDaySelected;

  const WeeklyCalendarStrip({
    super.key,
    this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final currentWeekday = DateTime.now().weekday; // 1 = Mon, 7 = Sun
    final dayLabels = ['M', 'T', 'W', 'TH', 'F', 'S', 'SU'];

    final days = List.generate(7, (i) {
      final dayNum = i + 1;
      String status;
      if (dayNum == currentWeekday) {
        status = 'current';
      } else if (dayNum < currentWeekday) {
        status = 'past';
      } else {
        status = 'future';
      }
      return {'label': dayLabels[i], 'status': status};
    });

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: days.map((d) {
          final isCurrent = d['status'] == 'current';
          final isCompleted = d['status'] == 'completed';

          return InkWell(
            onTap: () => onDaySelected?.call(d['label']!),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isCurrent ? 8 : 4,
                vertical: isCurrent ? 4 : 2,
              ),
              decoration: isCurrent
                  ? BoxDecoration(
                      color: AppColors.primaryFixed,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    )
                  : null,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    d['label']!,
                    style: AppTypography.labelSm(
                      color: isCurrent
                          ? AppColors.onPrimaryFixed
                          : AppColors.onSurfaceVariant,
                    ).copyWith(
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (isCompleted)
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: AppColors.adherenceGreen,
                    )
                  else if (isCurrent)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                      ),
                    )
                  else
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.outlineVariant,
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
