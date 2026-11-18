import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/hero_face_runtime.dart';
import 'sa7bi_hero_3d.dart';

/// لوحة HERO 3D Lite للصفحة الرئيسية.
///
/// تعرض مجسم GLB الأصلي وحركات الجسم الموجودة فقط. تعبيرات HERO تظهر
/// كتفاعلات بصرية حول المجسم، ومؤشر الكلام يعرض الكلمة والرمز الصوتي
/// مع حدود الكلمات التي يرسلها TTS.
/// لا تتطلب عظام وجه أو Morph Targets أو تعديل ملف GLB.
class Sa7biHeroLitePanel extends StatefulWidget {
  const Sa7biHeroLitePanel({super.key});

  @override
  State<Sa7biHeroLitePanel> createState() => _Sa7biHeroLitePanelState();
}

class _Sa7biHeroLitePanelState extends State<Sa7biHeroLitePanel>
    with SingleTickerProviderStateMixin {
  static const String _idleAnimation = 'Hero_Idle';
  static const String _welcomeAnimation = 'Hero_Welcome';
  static const String _powerAnimation = 'Hero_Power';

  final HeroFaceRuntime _runtime = HeroFaceRuntime.instance;
  late final AnimationController _talkPulseController;

  String _selectedAnimation = _idleAnimation;

  @override
  void initState() {
    super.initState();

    _talkPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 820),
    );

    _runtime.liteStatus.addListener(_syncTalkPulse);
    _syncTalkPulse();
  }

  void _syncTalkPulse() {
    final speaking = _runtime.liteStatus.value.isSpeaking;

    if (speaking && !_talkPulseController.isAnimating) {
      _talkPulseController.repeat();
    } else if (!speaking && _talkPulseController.isAnimating) {
      _talkPulseController
        ..stop()
        ..value = 0;
    }
  }

  void _selectAnimation(String animationName) {
    if (_selectedAnimation == animationName) return;

    setState(() => _selectedAnimation = animationName);
  }

  String _statusLabel(HeroLiteStatus status) {
    if (status.isSpeaking) return 'هيرو بيتكلم معاك';

    switch (status.expression) {
      case HeroExpression.smile:
        return 'هيرو مبسوط';
      case HeroExpression.sad:
        return 'هيرو متفهم';
      case HeroExpression.surprise:
        return 'هيرو مندهش';
      case HeroExpression.angry:
        return 'هيرو حازم';
      case HeroExpression.wink:
        return 'غمزة من هيرو';
      case HeroExpression.blink:
        return 'رمشة هيرو';
      case HeroExpression.neutral:
        break;
    }

    switch (_selectedAnimation) {
      case _welcomeAnimation:
        return 'هيرو بيرحب بيك';
      case _powerAnimation:
        return 'وضع الطاقة';
      default:
        return 'هيرو جاهز معاك';
    }
  }

  Color _accentColor(HeroLiteStatus status) {
    if (status.isSpeaking) return const Color(0xFF55E6B2);

    switch (status.expression) {
      case HeroExpression.smile:
        return const Color(0xFF67E8F9);
      case HeroExpression.sad:
        return const Color(0xFF8CB8FF);
      case HeroExpression.surprise:
        return const Color(0xFFFFD166);
      case HeroExpression.angry:
        return const Color(0xFFFF7777);
      case HeroExpression.wink:
        return const Color(0xFFD6A6FF);
      case HeroExpression.blink:
        return const Color(0xFF9CE6D4);
      case HeroExpression.neutral:
        return const Color(0xFF72D7FF);
    }
  }

  @override
  void dispose() {
    _runtime.liteStatus.removeListener(_syncTalkPulse);
    _talkPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<HeroLiteStatus>(
      valueListenable: _runtime.liteStatus,
      builder: (context, status, _) {
        final accent = _accentColor(status);

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  Color(0xFF142A48),
                  Color(0xFF0B1729),
                  Color(0xFF10131F),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: accent.withValues(alpha: 0.42),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(
                    alpha: status.isSpeaking ? 0.18 : 0.08,
                  ),
                  blurRadius: status.isSpeaking ? 24 : 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(11, 11, 11, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 10),
                _buildViewerStage(status, accent),
                const SizedBox(height: 10),
                _buildBodyActions(),
                const SizedBox(height: 10),
                _buildExpressionActions(status),
                const SizedBox(height: 8),
                Text(
                  status.isSpeaking
                      ? 'مؤشر الكلمة والرمز الصوتي يتغير مع حدود الكلمات التي يرسلها محرك الصوت.'
                      : 'المجسم الأصلي وحركات الجسم تعمل كما هي، والتفاعلات تظهر حوله دون تعديل ملف 3D.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF9FB2C9),
                    fontSize: 9,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF67E8F9).withValues(alpha: 0.12),
            border: Border.all(color: const Color(0x6672D7FF)),
          ),
          child: const Icon(
            Icons.smart_toy_rounded,
            color: Color(0xFF67E8F9),
            size: 19,
          ),
        ),
        const SizedBox(width: 9),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HERO • صاحبي AI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.25,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'رفيقك الذكي',
                style: TextStyle(
                  color: Color(0xFF9BB7D4),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF123D48),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0x5572E6E8)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, color: Color(0xFF55E6B2), size: 7),
              SizedBox(width: 5),
              Text(
                '3D LITE',
                style: TextStyle(
                  color: Color(0xFFB7F7EF),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildViewerStage(HeroLiteStatus status, Color accent) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(17),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        height: 218,
        decoration: BoxDecoration(
          color: const Color(0xFF081225),
          border: Border.all(
            color: accent.withValues(alpha: status.isSpeaking ? 0.72 : 0.26),
            width: status.isSpeaking ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(17),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: Sa7biHero3D(
                key: const ValueKey<String>('sa7bi-hero-home-viewer'),
                animationName: _selectedAnimation,
                cameraControls: true,
                compact: true,
                enableFaceAnimations: false,
              ),
            ),
            Positioned(
              right: 9,
              top: 9,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xCC081225),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.55),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: const TextStyle(
                      color: Color(0xFFE6F7FF),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 9,
              bottom: 8,
              child: _buildSpeechBadge(status, accent),
            ),
            const Positioned(
              right: 9,
              bottom: 8,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xAA081225),
                    borderRadius: BorderRadius.all(
                      Radius.circular(18),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    child: Text(
                      'اسحب لتدوير هيرو',
                      style: TextStyle(
                        color: Color(0xFFB7C9DE),
                        fontSize: 9,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeechBadge(HeroLiteStatus status, Color accent) {
    final wordAndViseme = status.activeWord.isEmpty
        ? '... · ${status.activeViseme}'
        : '${status.activeWord} · ${status.activeViseme}';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xDD081225),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accent.withValues(alpha: 0.55),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 9,
          vertical: 6,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              status.isSpeaking
                  ? Icons.graphic_eq_rounded
                  : Icons.volume_up_rounded,
              color: accent,
              size: 13,
            ),
            const SizedBox(width: 5),
            Text(
              status.isSpeaking ? 'بيتكلّم' : 'جاهز للصوت',
              style: const TextStyle(
                color: Color(0xFFE6F7FF),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (status.isSpeaking) ...[
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 92),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF19364A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    child: Text(
                      wordAndViseme,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        color: Color(0xFFB7F7EF),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(width: 6),
            _SpeechPulse(
              animation: _talkPulseController,
              active: status.isSpeaking,
              color: accent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyActions() {
    return Row(
      children: [
        Expanded(
          child: _HeroActionButton(
            label: 'استعداد',
            icon: Icons.self_improvement_rounded,
            selected: _selectedAnimation == _idleAnimation,
            onTap: () => _selectAnimation(_idleAnimation),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: _HeroActionButton(
            label: 'ترحيب',
            icon: Icons.waving_hand_rounded,
            selected: _selectedAnimation == _welcomeAnimation,
            onTap: () => _selectAnimation(_welcomeAnimation),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: _HeroActionButton(
            label: 'قوة',
            icon: Icons.bolt_rounded,
            selected: _selectedAnimation == _powerAnimation,
            onTap: () => _selectAnimation(_powerAnimation),
          ),
        ),
      ],
    );
  }

  Widget _buildExpressionActions(HeroLiteStatus status) {
    const options = <_HeroExpressionOption>[
      _HeroExpressionOption(HeroExpression.neutral, 'طبيعي', '😐'),
      _HeroExpressionOption(HeroExpression.smile, 'ابتسامة', '😊'),
      _HeroExpressionOption(HeroExpression.sad, 'حزن', '😔'),
      _HeroExpressionOption(HeroExpression.surprise, 'دهشة', '😮'),
      _HeroExpressionOption(HeroExpression.angry, 'حزم', '😠'),
      _HeroExpressionOption(HeroExpression.wink, 'غمزة', '😉'),
      _HeroExpressionOption(HeroExpression.blink, 'رمشة', '👀'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'ردود فعل هيرو',
          style: TextStyle(
            color: Color(0xFFD9E8F7),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: options.map((option) {
            final selected = status.expression == option.expression;

            return ChoiceChip(
              selected: selected,
              onSelected: (_) => _runtime.playExpression(option.expression),
              label: Text(
                '${option.emoji} ${option.label}',
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF071625)
                      : const Color(0xFFD9E8F7),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
              selectedColor: const Color(0xFF67E8F9),
              backgroundColor: const Color(0xFF192A40),
              side: BorderSide(
                color: selected
                    ? const Color(0xFF9AF4FF)
                    : const Color(0x334A7198),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 2,
                vertical: 0,
              ),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            );
          }).toList(growable: false),
        ),
      ],
    );
  }
}

class _HeroExpressionOption {
  const _HeroExpressionOption(this.expression, this.label, this.emoji);

  final HeroExpression expression;
  final String label;
  final String emoji;
}

class _SpeechPulse extends StatelessWidget {
  const _SpeechPulse({
    required this.animation,
    required this.active,
    required this.color,
  });

  final Animation<double> animation;
  final bool active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        const phases = <double>[0.0, 0.8, 1.6, 2.4, 3.2];

        return SizedBox(
          width: 25,
          height: 18,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List<Widget>.generate(phases.length, (index) {
              final wave = math
                  .sin(animation.value * math.pi * 2 + phases[index])
                  .abs();

              final barHeight = active ? 4.0 + wave * 12.0 : 4.0;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: 2.5,
                height: barHeight,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

class _HeroActionButton extends StatelessWidget {
  const _HeroActionButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? const Color(0xFF061421)
        : const Color(0xFFD9E8F7);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(
            horizontal: 5,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF67E8F9)
                : const Color(0xFF192A40),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected
                  ? const Color(0xFF9AF4FF)
                  : const Color(0x334A7198),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: foreground),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
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
