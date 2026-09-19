import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';

class PillVisualizer extends StatelessWidget {
  final String shape; // capsule, round, oval, liquid, inhaler, injection
  final String colorName; // teal, yellow, amber, white, purple, blue
  final String imprintCode;
  final double width;
  final double height;
  final bool showLabel;

  const PillVisualizer({
    super.key,
    this.shape = 'capsule',
    this.colorName = 'teal',
    this.imprintCode = '',
    this.width = 44,
    this.height = 44,
    this.showLabel = false,
  });

  Color _resolveColor() {
    switch (colorName.toLowerCase()) {
      case 'teal':
        return AppColors.primary;
      case 'yellow':
        return const Color(0xFFFACC15);
      case 'amber':
        return const Color(0xFFF59E0B);
      case 'white':
        return const Color(0xFFF8FAFC);
      case 'purple':
        return const Color(0xFF9333EA);
      case 'blue':
        return const Color(0xFF3B82F6);
      default:
        return AppColors.secondary;
    }
  }

  Color _resolveContrastColor() {
    if (colorName.toLowerCase() == 'white' || colorName.toLowerCase() == 'yellow') {
      return AppColors.onSurface;
    }
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final pillColor = _resolveColor();
    final textColor = _resolveContrastColor();

    Widget pillGraphic;

    switch (shape.toLowerCase()) {
      case 'round':
        pillGraphic = Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: pillColor,
            border: Border.all(
              color: colorName.toLowerCase() == 'white'
                  ? AppColors.outlineVariant
                  : pillColor.withValues(alpha: 0.8),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 2,
              height: height * 0.6,
              color: textColor.withValues(alpha: 0.35),
            ),
          ),
        );
        break;

      case 'oval':
        pillGraphic = Container(
          width: width,
          height: height * 0.65,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height * 0.5),
            color: pillColor,
            border: Border.all(
              color: colorName.toLowerCase() == 'white'
                  ? AppColors.outlineVariant
                  : pillColor.withValues(alpha: 0.8),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 2,
              height: height * 0.4,
              color: textColor.withValues(alpha: 0.35),
            ),
          ),
        );
        break;

      case 'liquid':
        pillGraphic = Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: pillColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.water_drop_rounded,
            color: pillColor,
            size: height * 0.65,
          ),
        );
        break;

      case 'inhaler':
        pillGraphic = Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: pillColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.air_rounded,
            color: pillColor,
            size: height * 0.65,
          ),
        );
        break;

      case 'injection':
        pillGraphic = Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: pillColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.vaccines_rounded,
            color: pillColor,
            size: height * 0.65,
          ),
        );
        break;

      case 'capsule':
      default:
        // Dual-tone or split capsule
        pillGraphic = Container(
          width: width,
          height: height * 0.55,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height * 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(height * 0.5),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    color: pillColor,
                    alignment: Alignment.center,
                    child: imprintCode.isNotEmpty && width > 60
                        ? Text(
                            imprintCode.split(' ').first,
                            style: AppTypography.labelSm(color: textColor).copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ),
                Container(
                  width: 1.5,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                Expanded(
                  child: Container(
                    color: colorName.toLowerCase() == 'teal'
                        ? AppColors.secondaryContainer
                        : pillColor.withValues(alpha: 0.8),
                    alignment: Alignment.center,
                    child: imprintCode.isNotEmpty && width > 60
                        ? Text(
                            imprintCode.split(' ').length > 1
                                ? imprintCode.split(' ')[1]
                                : '',
                            style: AppTypography.labelSm(
                              color: AppColors.onSecondaryContainer,
                            ).copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
        );
        break;
    }

    if (!showLabel) return pillGraphic;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        pillGraphic,
        if (imprintCode.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            imprintCode,
            style: AppTypography.labelSm(color: AppColors.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}
