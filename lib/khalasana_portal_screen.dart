
import 'package:flutter/material.dart';

import 'chat_screen.dart';
import 'config/service_keys.dart';
import 'service_config.dart';
import 'widgets/sa7bi_subpage_app_bar.dart';

const double _kKhalasanaRailWidth = 48;
const double _kKhalasanaTabWidth = 44;
const double _kKhalasanaTabHeight = 44;

/// خلصانة AI: محادثة عامة وتخصصات التطبيق.
/// لا نضع أزرار التواصل أو الفضفضة في أسفل شريط التخصصات.
class KhalasanaPortalScreen extends StatefulWidget {
  const KhalasanaPortalScreen({super.key});

  static const String contextText = '''
أنت "خلصانة AI"، المساعد الشامل داخل تطبيق صاحبي AI.

ساعد المستخدم مباشرة في أي موضوع، حتى إذا لم يختر مجالًا من التبويبات.

يمكن للمستخدم:
- الكتابة والمحادثة في أي موضوع.
- إرسال صورة واحدة أو أكثر لتحليلها.
- إرسال فيديو لتحليل الإطارات المتاحة منه.
- استخدام تحويل الكلام إلى نص والاستماع إلى الرد بالصوت.
- طلب إنشاء صورة جديدة.
- طلب تعديل صورة موجودة عندما تكون أداة التعديل المناسبة متاحة.

إذا أرسل المستخدم صورة، حلل ما يظهر فيها فقط ولا تخمن التفاصيل غير الواضحة.
إذا طلب المستخدم إنشاء صورة، استخدم مسار إنشاء الصور الموجود في التطبيق.
إذا لم تتوفر أداة أو خدمة فعلية، وضح ذلك ولا تدّع تنفيذها.

عندما يختار المستخدم مجالًا من التبويبات، استخدم سياق المجال لتحسين الإجابة،
لكن أجب أيضًا عن الأسئلة الخارجة عن المجال كمساعد عام دون إجبار المستخدم
على تغيير التبويب.

كن واضحًا ومفيدًا ومباشرًا، وحافظ على سياق المحادثة الخاص بكل مجال.
''';

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

class _KhalasanaPortalScreenState
    extends State<KhalasanaPortalScreen> {
  static const Color _background = Color(0xFF070A12);

  // المحادثة العامة + الخدمات المتخصصة.
  // التواصل والفضفضة لهما مداخل أخرى خارج هذا الشريط.
  static final List<_KhalasanaTarget> _targets =
      <_KhalasanaTarget>[
    _KhalasanaTarget(
      serviceKey: ServiceKeys.khalasana,
      title: KhalasanaPortalScreen.khalasanaService.title,
      context: KhalasanaPortalScreen.contextText,
      service: KhalasanaPortalScreen.khalasanaService,
      isGeneral: true,
    ),
    for (final service in sa7biServices)
      if (service.serviceKey != ServiceKeys.social &&
          service.serviceKey != ServiceKeys.venting)
        _KhalasanaTarget(
          serviceKey: service.serviceKey,
          title: service.title,
          context: service.aiRole,
          service: service,
        ),
  ];

  static final List<_KhalasanaTarget> _specialties =
      _targets
          .where((target) => !target.isGeneral)
          .toList(growable: false);

  String _selectedServiceKey = ServiceKeys.khalasana;

  /// الاحتفاظ بكل شاشة بعد إنشائها حتى لا تضيع المحادثة عند التبديل.
  final Map<String, Widget> _chatScreens =
      <String, Widget>{};

  _KhalasanaTarget get _activeTarget {
    for (final target in _targets) {
      if (target.serviceKey == _selectedServiceKey) {
        return target;
      }
    }

    return _targets.first;
  }

  void _selectTarget(_KhalasanaTarget target) {
    if (_selectedServiceKey == target.serviceKey) return;

    setState(() {
      _selectedServiceKey = target.serviceKey;
    });
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

    return ChatScreen(
      key: ValueKey<String>(
        'khalasana-chat-${target.serviceKey}',
      ),
      serviceKey: target.serviceKey,
      serviceTitle: target.title,
      serviceContext: contextText,
      embedded: true,
    );
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
          _chatScreens[target.serviceKey] ??
              const SizedBox.shrink(),
      ],
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
      case ServiceKeys.hobbiesSports:
        return 'هوايات';
      case ServiceKeys.podcasts:
        return 'بودكاست';
      default:
        return 'خدمة';
    }
  }

  Widget _buildServiceRail() {
    return SizedBox(
      width: _kKhalasanaRailWidth,
      child: Column(
        children: [
          _GeneralModeTab(
            selected:
                _selectedServiceKey == ServiceKeys.khalasana,
            onTap: () => _selectTarget(_targets.first),
          ),
          const SizedBox(height: 5),
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 2),
              itemCount: _specialties.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: 3),
              itemBuilder: (context, index) {
                final target = _specialties[index];

                return _KhalasanaServiceTab(
                  service: target.service,
                  shortName: _shortServiceName(
                    target.serviceKey,
                  ),
                  selected:
                      _selectedServiceKey == target.serviceKey,
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(3, 4, 3, 5),
          child: Row(
            textDirection: TextDirection.rtl,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildServiceRail(),
              const SizedBox(width: 3),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: _buildChatStack(),
                ),
              ),
            ],
          ),
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
            borderRadius: BorderRadius.circular(11),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 170),
              width: _kKhalasanaTabWidth,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
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
                    size: 16,
                    color: foreground,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'عام',
                    style: TextStyle(
                      color: foreground,
                      fontSize: 8,
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
            borderRadius: BorderRadius.circular(11),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 170),
              curve: Curves.easeOut,
              width: _kKhalasanaTabWidth,
              height: _kKhalasanaTabHeight,
              padding: const EdgeInsets.fromLTRB(1, 3, 1, 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                color: selected
                    ? color.withValues(alpha: 0.19)
                    : const Color(0xCC151D2A),
                border: Border.all(
                  color: selected
                      ? color.withValues(alpha: 0.9)
                      : const Color(0x553F536B),
                  width: selected ? 1.2 : 0.8,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.16),
                          blurRadius: 7,
                          spreadRadius: 0.3,
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
                    size: selected ? 18 : 16,
                  ),
                  const SizedBox(height: 1),
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
                          fontSize: 7.5,
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
