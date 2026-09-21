import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';

class DateRangeCalendarView extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;
  final ValueChanged<DateTimeRange> onRangeChanged;

  const DateRangeCalendarView({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.onRangeChanged,
  });

  @override
  State<DateRangeCalendarView> createState() => _DateRangeCalendarViewState();
}

class _DateRangeCalendarViewState extends State<DateRangeCalendarView> {
  late DateTime _displayedMonth;
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    _startDate = DateTime(widget.startDate.year, widget.startDate.month, widget.startDate.day);
    _endDate = DateTime(widget.endDate.year, widget.endDate.month, widget.endDate.day);
    _displayedMonth = DateTime(_startDate.year, _startDate.month, 1);
  }

  @override
  void didUpdateWidget(covariant DateRangeCalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startDate != widget.startDate || oldWidget.endDate != widget.endDate) {
      _startDate = DateTime(widget.startDate.year, widget.startDate.month, widget.startDate.day);
      _endDate = DateTime(widget.endDate.year, widget.endDate.month, widget.endDate.day);
    }
  }

  String _formatMonthYear(DateTime dt) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }

  String _formatDateShort(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  void _onDayTapped(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    setState(() {
      if (_startDate == _endDate) {
        if (normalizedDay.isBefore(_startDate)) {
          _startDate = normalizedDay;
        } else {
          _endDate = normalizedDay;
        }
      } else {
        // If already a range, start a fresh range from tapped date
        _startDate = normalizedDay;
        _endDate = normalizedDay;
      }
    });
    widget.onRangeChanged(DateTimeRange(start: _startDate, end: _endDate));
  }

  void _applyPresetDays(int days) {
    setState(() {
      _endDate = _startDate.add(Duration(days: days - 1));
    });
    widget.onRangeChanged(DateTimeRange(start: _startDate, end: _endDate));
  }

  Future<void> _pickDateRangeDialog() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surfaceContainerLowest,
              onSurface: AppColors.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = DateTime(picked.start.year, picked.start.month, picked.start.day);
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day);
        _displayedMonth = DateTime(_startDate.year, _startDate.month, 1);
      });
      widget.onRangeChanged(DateTimeRange(start: _startDate, end: _endDate));
    }
  }

  @override
  Widget build(BuildContext context) {
    final durationDays = _endDate.difference(_startDate).inDays + 1;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header with Range summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.date_range_rounded, size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Specific Dates Course',
                    style: AppTypography.headlineSm(color: AppColors.onSurface).copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$durationDays ${durationDays == 1 ? "Day" : "Days"}',
                  style: AppTypography.labelSm(color: AppColors.onPrimaryContainer).copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Start Date & End Date Cards
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _displayedMonth = DateTime(_startDate.year, _startDate.month, 1);
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'START DATE',
                          style: AppTypography.labelSm(color: AppColors.onSurfaceVariant).copyWith(
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDateShort(_startDate),
                          style: AppTypography.labelMd(color: AppColors.primary).copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.outline),
              ),
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _displayedMonth = DateTime(_endDate.year, _endDate.month, 1);
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'END DATE',
                          style: AppTypography.labelSm(color: AppColors.onSurfaceVariant).copyWith(
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDateShort(_endDate),
                          style: AppTypography.labelMd(color: AppColors.primary).copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3. Quick Duration Presets
          Text(
            'Quick Duration Presets',
            style: AppTypography.labelSm(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPresetChip(3, '3 Days', durationDays == 3),
                _buildPresetChip(5, '5 Days', durationDays == 5),
                _buildPresetChip(7, '7 Days (1 Wk)', durationDays == 7),
                _buildPresetChip(10, '10 Days', durationDays == 10),
                _buildPresetChip(14, '14 Days (2 Wks)', durationDays == 14),
                _buildPresetChip(30, '30 Days (1 Mo)', durationDays == 30),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 4. Calendar Month Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () {
                  setState(() {
                    _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month - 1, 1);
                  });
                },
              ),
              Text(
                _formatMonthYear(_displayedMonth),
                style: AppTypography.headlineSm(color: AppColors.onSurface).copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () {
                  setState(() {
                    _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 1);
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 6),

          // 5. Weekday Labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const [
              _WeekdayLabel('M'),
              _WeekdayLabel('T'),
              _WeekdayLabel('W'),
              _WeekdayLabel('T'),
              _WeekdayLabel('F'),
              _WeekdayLabel('S'),
              _WeekdayLabel('S'),
            ],
          ),
          const SizedBox(height: 6),

          // 6. Calendar Days Grid
          _buildMonthGrid(today),
          const SizedBox(height: 10),

          // 7. Full Dialog Button
          Center(
            child: TextButton.icon(
              onPressed: _pickDateRangeDialog,
              icon: const Icon(Icons.calendar_month_outlined, size: 16, color: AppColors.primary),
              label: Text(
                'Open Full Calendar Dialog',
                style: AppTypography.labelSm(color: AppColors.primary).copyWith(fontWeight: FontWeight.bold),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(int days, String label, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => _applyPresetDays(days),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: AppTypography.labelSm(
              color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
            ).copyWith(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthGrid(DateTime today) {
    final firstDayOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    final daysInMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;
    // DateTime.weekday: Mon is 1, Sun is 7. Convert to 0-indexed where Mon is 0.
    final startOffset = (firstDayOfMonth.weekday - 1) % 7;

    final totalSlots = startOffset + daysInMonth;
    final rowCount = (totalSlots / 7).ceil();

    return Column(
      children: List.generate(rowCount, (rowIndex) {
        return Row(
          children: List.generate(7, (colIndex) {
            final slotIndex = rowIndex * 7 + colIndex;
            final dayNumber = slotIndex - startOffset + 1;

            if (dayNumber < 1 || dayNumber > daysInMonth) {
              return const Expanded(child: SizedBox(height: 36));
            }

            final dayDate = DateTime(_displayedMonth.year, _displayedMonth.month, dayNumber);
            final isStart = dayDate.isAtSameMomentAs(_startDate);
            final isEnd = dayDate.isAtSameMomentAs(_endDate);
            final isInRange = dayDate.isAfter(_startDate) && dayDate.isBefore(_endDate);
            final isToday = dayDate.isAtSameMomentAs(today);

            BorderRadius? rangeRadius;
            if (isStart && isEnd) {
              rangeRadius = BorderRadius.circular(18);
            } else if (isStart) {
              rangeRadius = const BorderRadius.horizontal(left: Radius.circular(18));
            } else if (isEnd) {
              rangeRadius = const BorderRadius.horizontal(right: Radius.circular(18));
            }

            return Expanded(
              child: GestureDetector(
                onTap: () => _onDayTapped(dayDate),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: isInRange
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : (isStart || isEnd)
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : Colors.transparent,
                    borderRadius: rangeRadius,
                  ),
                  child: Center(
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: (isStart || isEnd) ? AppColors.primary : Colors.transparent,
                        shape: BoxShape.circle,
                        border: isToday && !(isStart || isEnd)
                            ? Border.all(color: AppColors.primary, width: 1.5)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '$dayNumber',
                          style: AppTypography.labelSm(
                            color: (isStart || isEnd)
                                ? Colors.white
                                : isToday
                                    ? AppColors.primary
                                    : AppColors.onSurface,
                          ).copyWith(
                            fontWeight: (isStart || isEnd || isToday)
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      }),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  final String label;
  const _WeekdayLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: AppTypography.labelSm(color: AppColors.onSurfaceVariant).copyWith(
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
