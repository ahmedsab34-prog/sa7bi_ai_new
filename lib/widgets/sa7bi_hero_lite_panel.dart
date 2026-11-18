import 'package:flutter/material.dart';

import 'sa7bi_hero_3d.dart';

/// لوحة HERO 3D Lite للصفحة الرئيسية.
///
/// تستخدم نفس ملف GLB المحلي ونفس حركات الجسم الثلاث الموجودة بالفعل.
/// لا تدّعي وجود Rig للوجه أو Lip Sync قبل توفرهما داخل ملف GLB.
class Sa7biHeroLitePanel extends StatefulWidget {
  const Sa7biHeroLitePanel({super.key});

  @override
  State<Sa7biHeroLitePanel> createState() => _Sa7biHeroLitePanelState();
}

class _Sa7biHeroLitePanelState extends State<Sa7biHeroLitePanel> {
  static const String _idleAnimation = 'Hero_Idle';
  static const String _welcomeAnimation = 'Hero_Welcome';
  static const String _powerAnimation = 'Hero_Power';

  String _selectedAnimation = _idleAnimation;

  String get _statusLabel {
    switch (_selectedAnimation) {
      case _welcomeAnimation:
        return 'هيرو بيرحب بيك';
      case _powerAnimation:
        return 'وضع الطاقة';
      default:
        return 'هيرو جاهز معاك';
    }
  }

  void _selectAnimation(String animationName) {
    if (_selectedAnimation == animationName) return;
    setState(() => _selectedAnimation = animationName);
  }

  @override
  Widget build(BuildContext context) {
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
            color: const Color(0x5572D7FF),
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x44000000),
              blurRadius: 18,
              offset: Offset(0, 7),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(11, 11, 11, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF67E8F9).withValues(alpha: 0.12),
                    border: Border.all(
                      color: const Color(0x6672D7FF),
                    ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF123D48),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: const Color(0x5572E6E8),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.circle,
                        color: Color(0xFF55E6B2),
                        size: 7,
                      ),
                      SizedBox(width: 5),
                      Text(
                        '3D',
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
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: Container(
                height: 218,
                decoration: const BoxDecoration(
                  color: Color(0xFF081225),
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
                            color: const Color(0x4472D7FF),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 6,
                          ),
                          child: Text(
                            _statusLabel,
                            style: const TextStyle(
                              color: Color(0xFFE6F7FF),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Positioned(
                      left: 9,
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
            ),
            const SizedBox(height: 10),
            Row(
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
            ),
            const SizedBox(height: 7),
            const Text(
              'نستخدم مجسم هيرو الأصلي وحركاته الحالية. تحريك تعبيرات الوجه والشفاه سيُفعّل بعد إضافة Rig الوجه الحقيقي.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF9FB2C9),
                fontSize: 9,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
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
