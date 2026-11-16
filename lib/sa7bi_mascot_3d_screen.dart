import 'package:flutter/material.dart';

import 'theme/sa7bi_theme.dart';
import 'widgets/sa7bi_mascot_3d.dart';
import 'widgets/sa7bi_subpage_app_bar.dart';

/// Full-screen viewer for the locally bundled Sa7bi AI 3D companion.
class Sa7biMascot3DScreen extends StatelessWidget {
  const Sa7biMascot3DScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Sa7biTheme.background,
        appBar: const Sa7biSubpageAppBar(
          title: 'شخصية صاحبي 3D',
          subtitle: 'مجسم ثلاثي الأبعاد تقدر تلفه وتقرّب عليه',
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(13, 12, 13, 24),
            children: [
              Container(
                height: 430,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1323),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Sa7biTheme.cyan.withValues(alpha: 0.38),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Sa7biTheme.cyan.withValues(alpha: 0.08),
                      blurRadius: 22,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Sa7biMascot3D(),
              ),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Sa7biTheme.surface,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: Sa7biTheme.border),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'اتحكم في المجسم',
                      style: TextStyle(
                        color: Sa7biTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 9),
                    _ControlHint(
                      icon: Icons.pan_tool_alt_rounded,
                      text: 'اسحب بإصبعك علشان تلف المجسم.',
                    ),
                    SizedBox(height: 7),
                    _ControlHint(
                      icon: Icons.pinch_rounded,
                      text: 'استخدم إصبعين للتقريب والتبعيد.',
                    ),
                    SizedBox(height: 7),
                    _ControlHint(
                      icon: Icons.autorenew_rounded,
                      text:
                          'الكاميرا بتلف حوالين المجسم تلقائيًا؛ ده دوران للكاميرا مش حركة جسم حقيقية.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Sa7biTheme.surfaceRaised,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'المجسم الحالي شخصية ثلاثية الأبعاد ثابتة قابلة للدوران والتقريب. '
                  'هو ليس نموذجًا متحركًا بعظام أو تعبيرات وجه في هذه المرحلة.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Sa7biTheme.textSecondary,
                    fontSize: 10,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlHint extends StatelessWidget {
  const _ControlHint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Sa7biTheme.cyan, size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Sa7biTheme.textSecondary,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
