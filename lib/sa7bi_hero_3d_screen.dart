
import 'package:flutter/material.dart';

import 'services/hero_face_runtime.dart';
import 'theme/sa7bi_theme.dart';
import 'widgets/sa7bi_hero_3d.dart';
import 'widgets/sa7bi_subpage_app_bar.dart';

/// عارض الشخصية الوحيدة HERO مع حركات الجسم وتعبيرات الوجه المتاحة فعليًا.
class Sa7biHero3DScreen extends StatefulWidget {
  const Sa7biHero3DScreen({super.key});

  @override
  State<Sa7biHero3DScreen> createState() => _Sa7biHero3DScreenState();
}

class _Sa7biHero3DScreenState extends State<Sa7biHero3DScreen> {
  static const String _idle = 'Hero_Idle';
  static const String _welcome = 'Hero_Welcome';
  static const String _power = 'Hero_Power';

  String _selectedAnimation = _idle;

  void _selectAnimation(String animation) {
    if (_selectedAnimation == animation) return;
    setState(() => _selectedAnimation = animation);
  }

  @override
  Widget build(BuildContext context) {
    final isWelcome = _selectedAnimation == _welcome;
    final isPower = _selectedAnimation == _power;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Sa7biTheme.background,
        appBar: const Sa7biSubpageAppBar(
          title: 'صاحبي HERO',
          subtitle: 'الشخصية الرسمية المعتمدة — بطل واحد',
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(13, 12, 13, 26),
            children: [
              Container(
                height: 440,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFF081225),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Sa7biTheme.cyan.withValues(alpha: 0.45),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Sa7biTheme.cyan.withValues(alpha: 0.10),
                      blurRadius: 24,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Sa7biHero3D(
                  animationName: _selectedAnimation,
                  cameraControls: true,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Sa7biTheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Sa7biTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'حركات الجسم الأساسية',
                      style: TextStyle(
                        color: Sa7biTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 11),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _AnimationChoiceButton(
                          label: 'الاستعداد',
                          icon: Icons.shield_rounded,
                          selected: !isWelcome && !isPower,
                          onPressed: () => _selectAnimation(_idle),
                        ),
                        _AnimationChoiceButton(
                          label: 'تحية البطل',
                          icon: Icons.waving_hand_rounded,
                          selected: isWelcome,
                          onPressed: () => _selectAnimation(_welcome),
                        ),
                        _AnimationChoiceButton(
                          label: 'وضع القوة',
                          icon: Icons.bolt_rounded,
                          selected: isPower,
                          onPressed: () => _selectAnimation(_power),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const _HintRow(
                      icon: Icons.pan_tool_alt_rounded,
                      text:
                          'اسحب بإصبعك لتدوير الشخصية، واستخدم إصبعين للتقريب.',
                    ),
                    const SizedBox(height: 7),
                    const _HintRow(
                      icon: Icons.auto_awesome_rounded,
                      text:
                          'المرجع الرسمي: وجه مكشوف بنفس الملامح والشعر، ودرع أحمر وذهبي وأزرق داكن، وخطوط طاقة سماوية، وشعار صاحبي AI في منتصف الصدر. بدون خوذة أو قناع أو عباءة.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const _FaceExpressionPanel(),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Sa7biTheme.surfaceRaised,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Sa7biTheme.border),
                ),
                child: const Text(
                  'تعبيرات الوجه وحركات الفم لا تعمل إلا بعد تضمينها فعليًا داخل ملف GLB. '
                  'أزرار الوجه تتفعّل لكل حركة عندما يعلن العارض عن اسمها داخل المجسم.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Sa7biTheme.textSecondary,
                    fontSize: 10,
                    height: 1.65,
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

class _AnimationChoiceButton extends StatelessWidget {
  const _AnimationChoiceButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return selected
        ? FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 17),
            label: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 17),
            label: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
  }
}

class _FaceExpressionPanel extends StatelessWidget {
  const _FaceExpressionPanel();

  @override
  Widget build(BuildContext context) {
    final runtime = HeroFaceRuntime.instance;

    return ValueListenableBuilder<Set<String>>(
      valueListenable: runtime.availableAnimations,
      builder: (context, animations, _) {
        final options = <_FaceExpressionOption>[
          _FaceExpressionOption(
            expression: HeroExpression.smile,
            label: 'ابتسامة',
            icon: Icons.sentiment_satisfied_alt_rounded,
          ),
          _FaceExpressionOption(
            expression: HeroExpression.sad,
            label: 'حزن',
            icon: Icons.sentiment_dissatisfied_rounded,
          ),
          _FaceExpressionOption(
            expression: HeroExpression.surprise,
            label: 'دهشة',
            icon: Icons.sentiment_very_satisfied_rounded,
          ),
          _FaceExpressionOption(
            expression: HeroExpression.angry,
            label: 'غضب',
            icon: Icons.mood_bad_rounded,
          ),
          _FaceExpressionOption(
            expression: HeroExpression.wink,
            label: 'غمزة',
            icon: Icons.visibility_off_rounded,
          ),
          _FaceExpressionOption(
            expression: HeroExpression.blink,
            label: 'رمش',
            icon: Icons.visibility_rounded,
          ),
        ];

        final missingCount = runtime.missingRequiredAnimations.length;
        final allReady = runtime.isFaceRigAvailable;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Sa7biTheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Sa7biTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'تعبيرات وجه HERO',
                style: TextStyle(
                  color: Sa7biTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => runtime.playExpression(
                      HeroExpression.neutral,
                    ),
                    icon: const Icon(
                      Icons.face_retouching_natural,
                      size: 17,
                    ),
                    label: const Text('طبيعي'),
                  ),
                  for (final option in options)
                    OutlinedButton.icon(
                      onPressed: animations.contains(
                        HeroFaceRuntime.expressionAnimationNames[
                          option.expression
                        ],
                      )
                          ? () => runtime.playExpression(option.expression)
                          : null,
                      icon: Icon(option.icon, size: 17),
                      label: Text(option.label),
                    ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                allReady
                    ? 'تم اكتشاف حركات الوجه الست والـVisemes الخمسة عشر داخل GLB.'
                    : 'Rig الوجه غير مكتمل داخل GLB بعد. الحركات المطلوبة غير المكتشفة: $missingCount من ${HeroFaceRuntime.requiredFaceAnimationNames.length}.',
                style: const TextStyle(
                  color: Sa7biTheme.textSecondary,
                  fontSize: 10,
                  height: 1.6,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FaceExpressionOption {
  const _FaceExpressionOption({
    required this.expression,
    required this.label,
    required this.icon,
  });

  final HeroExpression expression;
  final String label;
  final IconData icon;
}

class _HintRow extends StatelessWidget {
  const _HintRow({required this.icon, required this.text});

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
              fontSize: 10,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}
