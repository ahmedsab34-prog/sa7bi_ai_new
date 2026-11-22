import 'package:flutter/material.dart';

import '../theme/sa7bi_theme.dart';

/// سطح زجاجي موحد لاستخدامه في شاشات صاحبي AI.
///
/// يدعم:
/// - خلفية متدرجة.
/// - إطارًا خفيفًا.
/// - ظلًا اختياريًا.
/// - حواف مستديرة.
/// - الضغط الاختياري.
class Sa7biGlassSurface extends StatelessWidget {
  const Sa7biGlassSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(15),
    this.margin = EdgeInsets.zero,
    this.radius = 20,
    this.gradient,
    this.borderColor = Sa7biTheme.border,
    this.showGlow = false,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;
  final Gradient? gradient;
  final Color borderColor;
  final bool showGlow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        gradient: gradient ?? Sa7biTheme.darkGlassGradient,
        borderRadius: borderRadius,
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
        boxShadow: showGlow
            ? <BoxShadow>[
                BoxShadow(
                  color: Sa7biTheme.violet.withValues(alpha: 0.12),
                  blurRadius: 18,
                  spreadRadius: 1,
                  offset: const Offset(0, 5),
                ),
              ]
            : const <BoxShadow>[
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(
            borderRadius: borderRadius,
          ),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
