import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/safety/drug_interactions.dart';

class InteractionWarningDialog extends StatelessWidget {
  final List<InteractionResult> interactions;
  final VoidCallback onProceed;

  const InteractionWarningDialog({
    super.key,
    required this.interactions,
    required this.onProceed,
  });

  static Future<bool?> show(
    BuildContext context, {
    required List<InteractionResult> interactions,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => InteractionWarningDialog(
        interactions: interactions,
        onProceed: () => Navigator.of(ctx).pop(true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppColors.surfaceContainerLowest,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppColors.alertCoralBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.alertCoral,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Safety Alert: Drug Interaction',
              style: AppTypography.headlineSm(color: AppColors.onSurface),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Potential conflict detected with your active medications:',
                style: AppTypography.bodyMd(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              ...interactions.map((interaction) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.errorContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.alertCoral.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${interaction.medicineA} + ${interaction.medicineB}',
                              style: AppTypography.labelLg(
                                color: AppColors.onErrorContainer,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                interaction.severity.toUpperCase(),
                                style: AppTypography.labelSm(
                                  color: AppColors.onError,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          interaction.description,
                          style: AppTypography.bodySm(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Advice: ${interaction.clinicalAdvice}',
                          style: AppTypography.labelSm(
                            color: AppColors.primary,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '⚠ Note: This information is for clinical awareness only and is not a substitute for advice from your doctor or pharmacist.',
                  style: AppTypography.bodySm(color: AppColors.outline),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Review / Edit',
            style: AppTypography.labelMd(color: AppColors.onSurfaceVariant),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.alertCoral,
            foregroundColor: Colors.white,
            minimumSize: const Size(120, 42),
          ),
          onPressed: onProceed,
          child: const Text('I Understand, Save'),
        ),
      ],
    );
  }
}
