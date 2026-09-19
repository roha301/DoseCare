import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';

class SkipReasonSheet extends StatefulWidget {
  final String medicineName;
  final Function(String reason) onReasonSelected;

  const SkipReasonSheet({
    super.key,
    required this.medicineName,
    required this.onReasonSelected,
  });

  static Future<String?> show(BuildContext context, {required String medicineName}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SkipReasonSheet(
        medicineName: medicineName,
        onReasonSelected: (reason) => Navigator.of(ctx).pop(reason),
      ),
    );
  }

  @override
  State<SkipReasonSheet> createState() => _SkipReasonSheetState();
}

class _SkipReasonSheetState extends State<SkipReasonSheet> {
  final TextEditingController _customReasonController = TextEditingController();
  String? _selectedReason;

  final List<String> _predefinedReasons = [
    'Nausea / Sick',
    'Forgot Meal',
    'Physician Order',
    'Out of Stock',
    'Adverse Reaction',
  ];

  @override
  void dispose() {
    _customReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Skip Dose with Note',
                    style: AppTypography.headlineSm(color: AppColors.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.medicineName,
                    style: AppTypography.bodySm(color: AppColors.primary),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Select clinical reason for skipping:',
            style: AppTypography.labelMd(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _predefinedReasons.map((reason) {
              final isSelected = _selectedReason == reason;
              return ChoiceChip(
                label: Text(reason),
                selected: isSelected,
                labelStyle: AppTypography.labelSm(
                  color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
                ),
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.surfaceContainerLow,
                onSelected: (selected) {
                  setState(() {
                    _selectedReason = selected ? reason : null;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _customReasonController,
            decoration: const InputDecoration(
              hintText: 'Or enter custom doctor instruction...',
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              final reason = _customReasonController.text.trim().isNotEmpty
                  ? _customReasonController.text.trim()
                  : (_selectedReason ?? 'Other reason');
              widget.onReasonSelected(reason);
            },
            child: const Text('Confirm Skip Dose'),
          ),
        ],
      ),
    );
  }
}
