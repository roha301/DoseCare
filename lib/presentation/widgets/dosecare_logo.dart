import 'package:flutter/material.dart';

class DoseCareLogo extends StatelessWidget {
  final double size;
  final double borderRadius;
  final bool hasShadow;

  const DoseCareLogo({
    super.key,
    this.size = 36,
    this.borderRadius = 8,
    this.hasShadow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: hasShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(
          'assets/images/dosecare_logo.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Container(
            color: const Color(0xFF0D7E8A),
            child: Icon(Icons.medication_rounded, color: Colors.white, size: size * 0.6),
          ),
        ),
      ),
    );
  }
}
