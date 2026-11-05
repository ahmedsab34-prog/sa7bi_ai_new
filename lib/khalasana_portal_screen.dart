import 'package:flutter/material.dart';

import 'chat_screen.dart';
import 'config/service_keys.dart';
import 'secure_venting_screen.dart';
import 'service_config.dart';
import 'widgets/sa7bi_subpage_app_bar.dart';

/// الشاشة الرئيسية لخلصانة AI.
///
/// تجمع المحادثة العامة والخدمات العشرة في شاشة واحدة:
/// - المحادثة العامة هي الوضع الافتراضي.
/// - الخدمات تظهر في ألسنة جانبية صغيرة.
/// - كل خدمة لها سجل مستقل.
/// - IndexedStack يحافظ على حالة الخدمات التي فتحها المستخدم.
/// - الفضفضة لا تُنشأ داخل شجرة الواجهة إلا بعد فتح القفل المحلي.
/// - لا نعرض هيدرًا ثانيًا داخل ChatScreen.
class KhalasanaPortalScreen extends StatefulWidget {
  const KhalasanaPortalScreen({super.key});

  static const String contextText = '''
أنت خلصانة AI، المساعد الشامل داخل تطبيق صاحبي.

ساعد المستخدم مباشرة في أي موضوع، حتى إذا لم يختر مجالًا من التبويبات.

يمكن للمستخدم:
- الكتابة والمحادثة في أي موضوع.
- إرسال صورة واحدة أو أكثر لتحليلها.
- إرسال فيديو لتحليل الإطارات المتاحة منه.
- استخدام تحويل الكلام إلى نص والاستماع إلى الرد بالصوت.
- طلب إنشاء صورة جديدة.
- طلب تعديل صورة موجودة عندما تكون أداة التعديل المناسبة متاحة.

إذا أرسل المستخدم صورة، حلل ما يظهر فيها فقط ولا تخمن التفاصيل غير الواضحة.
إذا طلب إنشاء صورة، استخدم مسار إنشاء الصور الموجود في التطبيق.
إذا لم تتوفر أداة أو خدمة فعلية، وضح ذلك ولا تدّع تنفيذها.

عندما يختار المستخدم مجالًا من التبويبات، استخدم سياق المجال لتحسين الإجابة،
لكن أجب أيضًا عن الأسئلة الخارجة عن المجال كمساعد عام دون إجبار المستخدم
على تغيير التبويب.

كن واضحًا ومفيدًا ومباشرًا، وحافظ على سياق المحادثة الخاص بكل مجال.
''';

  /// التعريف الثابت لوضع المحادثة العامة داخل خلصانة.
  static const Sa7biService khalasanaService = Sa7biService(
    serviceKey: ServiceKeys.khalasana,
    title: 'خلصانة AI',
    description: 'المساعد الشامل بكل أدوات صاحبي AI',
    icon: Icons.auto_awesome_rounded,
    color: Color(0xFF8EA8FF),
    aiRole: contextText,
  );

  @override
  State<KhalasanaPortalScreen> createState() =>
      _KhalasanaPortalScreenState();
}

class _KhalasanaPortalScreenState extends State<KhalasanaPortalScreen> {
  static const Color _background = Color(0xFF070A12);
  static const double _railWidth = 47;
  static const double _minimumWidthForTwoRails = 840;
  static const double _mobileTabsBreakpoint = 640;

  static final List<_KhalasanaTarget> _targets = <_KhalasanaTarget>[
    _KhalasanaTarget(
      serviceKey: ServiceKeys.khalasana,
      title: KhalasanaPortalScreen.khalasanaService.title,
      context: KhalasanaPortalScreen.contextText,
      service: KhalasanaPortalScreen.khalasanaService,
      isGeneral: true,
    ),
    for (final service in sa7biServices)
      _KhalasanaTarget(
        serviceKey: service.serviceKey,
        title: service.title,
        context: service.aiRole,
        service: service,
      ),
  ];

  String _selectedServiceKey = ServiceKeys.khalasana;

  /// Store widgets rather than ChatScreen objects because the venting entry
  /// is a lock wrapper. Its ChatScreen child is not mounted while locked.
  final Map<String, Widget> _chatScreens = <String, Widget>{};

  final GlobalKey<SecureVentingScreenState> _ventingKey =
      GlobalKey<SecureVentingScreenState>();

  _KhalasanaTarget get _activeTarget {
    for (final target in _targets) {
      if (target.serviceKey == _selectedServiceKey) return target;
    }
    return _targets.first;
  }

  void _selectTarget(_KhalasanaTarget target) {
    if (_selectedServiceKey == target.serviceKey) return;

    // Remove the decrypted data key and unmount the private ChatScreen before
    // changing tabs. The secure wrapper remains cached but shows its lock UI.
    if (_selectedServiceKey == ServiceKeys.venting &&
        target.serviceKey != ServiceKeys.venting) {
      _ventingKey.currentState?.lock();
    }

    setState(() => _selectedServiceKey = target.serviceKey);
  }

  Widget _createChatScreen(_KhalasanaTarget target) {
    final contextText = target.isGeneral
        ? KhalasanaPortalScreen.contextText
        : '${KhalasanaPortalScreen.contextText}\n\n'
            'السياق الإضافي للمجال المختار (${target.title}):\n'
            '${target.context}\n\n'
            'أجب عن الأسئلة الخارجة عن هذا المجال كمساعد عام أيضًا. '
            'لا تجبر المستخدم على تغيير التبويب، وتظل أدوات النص والصور '
            'والصوت والفيديو متاحة حسب إمكانات التطبيق.';

    final chat = ChatScreen(
      key: ValueKey<String>('khalasana-chat-${target.serviceKey}'),
      serviceKey: target.serviceKey,
      serviceTitle: target.title,
      serviceContext: contextText,
      embedded: true,
    );

    if (target.serviceKey == ServiceKeys.venting) {
      return SecureVentingScreen(
        key: _ventingKey,
        child: chat,
      );
    }

    return chat;
  }

  Widget _buildChatStack() {
    final active = _activeTarget;

    _chatScreens.putIfAbsent(
      active.serviceKey,
      () => _createChatScreen(active),
    );

    final activeIndex = _targets.indexWhere(
      (target) => target.serviceKey == active.serviceKey,
    );

    return IndexedStack(
      index: activeIndex < 0 ? 0 : activeIndex,
      sizing: StackFit.expand,
      children: <Widget>[
        for (final target in _targets)
          _chatScreens[target.serviceKey] ?? const SizedBox.shrink(),
      ],
    );
  }

  bool _useTwoRails(double availableWidth) =>
      availableWidth >= _minimumWidthForTwoRails;

  Widget _buildHorizontalServiceTabs() {
    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        reverse: true,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        itemCount: _targets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final target = _targets[index];
          return _KhalasanaMobileServiceTab(
            title: target.isGeneral ? 'عام' : target.title,
            icon: target.service.icon,
            color: target.isGeneral
                ? const Color(0xFF63E6FF)
                : target.service.color,
            selected: _selectedServiceKey == target.serviceKey,
            onTap: () => _selectTarget(target),
          );
        },
      ),
    );
  }

  String _shortServiceName(String key) {
    switch (key) {
      case ServiceKeys.kitchen:
        return 'مطبخ';
      case ServiceKeys.merchant:
        return 'تجارة';
      case ServiceKeys.pharmacy:
        return 'صيدلية';
      case ServiceKeys.tradesperson:
        return 'حرف';
      case ServiceKeys.worship:
        return 'عبادة';
      case ServiceKeys.shopping:
        return 'تسوق';
      case ServiceKeys.social:
        return 'تواصل';
      case ServiceKeys.venting:
        return 'فضفضة';
      case ServiceKeys.hobbiesSports:
        return 'هوايات';
      case ServiceKeys.podcasts:
        return 'بودكاست';
      default:
        return 'خدمة';
    }
  }

  Widget _buildServiceRail({
    required List<_KhalasanaTarget> targets,
    required bool showGeneralTab,
  }) {
    return SizedBox(
      width: _railWidth,
      child: Column(
        children: [
          if (showGeneralTab) ...[
            _GeneralModeTab(
              selected: _selectedServiceKey == ServiceKeys.khalasana,
              onTap: () => _selectTarget(_targets.first),
            ),
            const SizedBox(height: 6),
          ],
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 3),
              itemCount: targets.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final target = targets[index];
                final service = target.service;

                return _KhalasanaServiceTab(
                  service: service,
                  shortName: _shortServiceName(target.serviceKey),
                  selected: _selectedServiceKey == target.serviceKey,
                  onTap: () => _selectTarget(target),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: Sa7biSubpageAppBar(
        title: _activeTarget.title,
        subtitle: _activeTarget.service.description,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final mobileLayout =
                constraints.maxWidth < _mobileTabsBreakpoint;
            final splitRails = _useTwoRails(constraints.maxWidth);

            if (mobileLayout) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(5, 4, 5, 7),
                child: Column(
                  children: [
                    _buildHorizontalServiceTabs(),
                    const SizedBox(height: 3),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(17),
                        child: _buildChatStack(),
                      ),
                    ),
                  ],
                ),
              );
            }

            final rightTargets = splitRails
                ? _targets.skip(1).take(5).toList(growable: false)
                : _targets.skip(1).toList(growable: false);
            final leftTargets = splitRails
                ? _targets.skip(6).toList(growable: false)
                : const <_KhalasanaTarget>[];

            return Padding(
              padding: const EdgeInsets.fromLTRB(5, 5, 5, 7),
              child: Row(
                textDirection: TextDirection.rtl,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildServiceRail(
                    targets: rightTargets,
                    showGeneralTab: true,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(17),
                      child: _buildChatStack(),
                    ),
                  ),
                  if (splitRails) ...[
                    const SizedBox(width: 4),
                    _buildServiceRail(
                      targets: leftTargets,
                      showGeneralTab: false,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _KhalasanaTarget {
  const _KhalasanaTarget({
    required this.serviceKey,
    required this.title,
    required this.context,
    required this.service,
    this.isGeneral = false,
  });

  final String serviceKey;
  final String title;
  final String context;
  final Sa7biService service;
  final bool isGeneral;
}

class _KhalasanaMobileServiceTab extends StatelessWidget {
  const _KhalasanaMobileServiceTab({
    required this.title,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : const Color(0xFFCBD5E1);

    return Semantics(
      button: true,
      selected: selected,
      label: title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 78,
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
            decoration: BoxDecoration(
              color: selected
                  ? color.withValues(alpha: 0.20)
                  : const Color(0xCC151D2A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? color.withValues(alpha: 0.95)
                    : const Color(0x553F536B),
                width: selected ? 1.3 : 0.8,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 21),
                const SizedBox(height: 3),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GeneralModeTab extends StatelessWidget {
  const _GeneralModeTab({
    required this.selected,
    required this.onTap,
  });

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? const Color(0xFF07111E)
        : const Color(0xFFFFD76A);

    return Tooltip(
      message: 'المحادثة العامة',
      child: Semantics(
        button: true,
        selected: selected,
        label: 'المحادثة العامة',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(13),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 170),
              width: 43,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                color: selected
                    ? const Color(0xFF63E6FF)
                    : const Color(0xCC151D2A),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF63E6FF)
                      : const Color(0x553F536B),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 19,
                    color: foreground,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'عام',
                    style: TextStyle(
                      color: foreground,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KhalasanaServiceTab extends StatelessWidget {
  const _KhalasanaServiceTab({
    required this.service,
    required this.shortName,
    required this.selected,
    required this.onTap,
  });

  final Sa7biService service;
  final String shortName;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = service.color;

    return Tooltip(
      message: '${service.title} — ${service.description}',
      child: Semantics(
        button: true,
        selected: selected,
        label: service.title,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(13),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 170),
              curve: Curves.easeOut,
              width: 43,
              height: 56,
              padding: const EdgeInsets.fromLTRB(2, 5, 2, 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                color: selected
                    ? color.withValues(alpha: 0.19)
                    : const Color(0xCC151D2A),
                border: Border.all(
                  color: selected
                      ? color.withValues(alpha: 0.9)
                      : const Color(0x553F536B),
                  width: selected ? 1.3 : 0.8,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.20),
                          blurRadius: 11,
                          spreadRadius: 0.5,
                        ),
                      ]
                    : const <BoxShadow>[],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    service.icon,
                    color: color,
                    size: selected ? 21 : 19,
                  ),
                  const SizedBox(height: 3),
                  SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        shortName,
                        maxLines: 1,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : const Color(0xFFCDD6E2),
                          fontSize: 8,
                          fontWeight: selected
                              ? FontWeight.w900
                              : FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
