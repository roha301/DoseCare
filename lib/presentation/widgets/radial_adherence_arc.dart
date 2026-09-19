import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';

class RadialAdherenceArc extends StatelessWidget {
  final double percentage; // 0.0 to 100.0
  final double size;
  final double strokeWidth;
  final Widget? centerWidget;

  const RadialAdherenceArc({
    super.key,
    required this.percentage,
    this.size = 64,
    this.strokeWidth = 6.0,
    this.centerWidget,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _ArcPainter(
              percentage: (percentage / 100.0).clamp(0.0, 1.0),
              strokeWidth: strokeWidth,
              trackColor: AppColors.surfaceContainerHighest,
              progressColor: AppColors.primary,
            ),
          ),
          centerWidget ??
              Text(
                '${percentage.round()}%',
                style: AppTypography.headlineSm(color: AppColors.onSurface).copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: size * 0.28,
                ),
              ),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double percentage;
  final double strokeWidth;
  final Color trackColor;
  final Color progressColor;

  _ArcPainter({
    required this.percentage,
    required this.strokeWidth,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track Paint
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress Paint
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * pi * percentage;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2, // start from top
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) {
    return oldDelegate.percentage != percentage;
  }
}
