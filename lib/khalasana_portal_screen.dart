import 'package:flutter/material.dart';

import 'chat_screen.dart';
import 'config/service_keys.dart';
import 'service_config.dart';

/// شاشة خلصانة AI الرئيسية.
///
/// تجمع المحادثة العامة والخدمات العشرة في مكان واحد:
/// - المحادثة العامة هي الوضع الافتراضي.
/// - الخدمات العشرة تظهر كألسنة جانبية صغيرة.
/// - اختيار أي خدمة يفتح نفس ChatScreen بسياق الخدمة ومفتاح سجلها الخاص.
/// - لا يتم إنشاء صفحة وسيطة أو شاشة تصنيفات منفصلة.
class KhalasanaPortalScreen extends StatefulWidget {
  const KhalasanaPortalScreen({super.key});

  static const String contextText = '''
أنت خلصانة AI، المساعد الشامل داخل تطبيق صاحبي.

ساعد المستخدم مباشرة في أي موضوع بدون إجباره على اختيار قسم.

يمكنه:
- الكتابة والمحادثة.
- إرسال صورة وتحليلها.
- إرسال أكثر من صورة عند الحاجة.
- إرسال فيديو وتحليل الإطارات المتاحة.
- استخدام الصوت وتحويل الكلام إلى نص.
- الاستماع إلى الرد بالصوت.
- طلب إنشاء صورة.
- طلب تعديل أو تحسين صورة عندما تكون الأداة المناسبة متاحة.

إذا أرسل المستخدم صورة، حلل ما يظهر فيها فقط ولا تخمن التفاصيل غير الواضحة.

إذا طلب إنشاء صورة، استخدم مسار إنشاء الصور الموجود في التطبيق.

إذا كان الموضوع مرتبطًا بخدمة أو مجال محدد، استخدم أفضل سياق مناسب تلقائيًا.

غيّر أسلوب وسياق المحادثة حسب موضوع المستخدم.

كن واضحًا ومفيدًا ومباشرًا.

لا تدّعي تنفيذ شيء لم يتم تنفيذه فعليًا.

إذا فشلت خدمة فعلية، وضح ذلك وقدم بديلًا مفيدًا.
''';

  /// يحتفظ بتعريف الخدمة العامة القديم للتوافق مع أي استدعاء داخلي قائم.
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
  static const Color _cyan = Color(0xFF63E6FF);
  static const double _railWidth = 46;

  /// null تعني المحادثة العامة، وأي قيمة أخرى تعني خدمة من الخدمات العشرة.
  String? _selectedServiceKey;

  Sa7biService? get _selectedService {
    final key = _selectedServiceKey;
    if (key == null) return null;

    for (final service in sa7biServices) {
      if (service.serviceKey == key) return service;
    }

    return null;
  }

  String get _activeServiceKey =>
      _selectedService?.serviceKey ?? ServiceKeys.khalasana;

  String get _activeTitle =>
      _selectedService?.title ?? KhalasanaPortalScreen.khalasanaService.title;

  String get _activeContext {
    final service = _selectedService;
    if (service == null) return KhalasanaPortalScreen.contextText;

    return '${KhalasanaPortalScreen.contextText}\n\n'
        'السياق الإضافي للمجال المختار (${service.title}):\n'
        '${service.aiRole}\n\n'
        'إذا سأل المستخدم عن موضوع خارج المجال المختار، أجب عنه كمساعد عام ' 
        'ولا تجبره على الرجوع إلى تبويب آخر. تظل أدوات المحادثة والصور ' 
        'والصوت والفيديو متاحة حسب إمكانات التطبيق.';
  }

  void _selectService(Sa7biService service) {
    if (_selectedServiceKey == service.serviceKey) return;
    setState(() => _selectedServiceKey = service.serviceKey);
  }

  void _selectGeneral() {
    if (_selectedServiceKey == null) return;
    setState(() => _selectedServiceKey = null);
  }

  List<Widget> _buildRail(List<Sa7biService> services) {
    return [
      for (final service in services)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _KhalasanaServiceTab(
            service: service,
            selected: _selectedServiceKey == service.serviceKey,
            shortName: _shortServiceName(service.serviceKey),
            onTap: () => _selectService(service),
          ),
        ),
    ];
  }

  String _shortServiceName(String key) {
    switch (key) {
      case ServiceKeys.kitchen:
        return 'مطبخ';
      case ServiceKeys.merchant:
        return 'تجارة';
      case ServiceKeys.pharmacy:
        return 'صحة';
      case ServiceKeys.tradesperson:
        return 'صيانة';
      case ServiceKeys.worship:
        return 'عبادة';
      case ServiceKeys.shopping:
        return 'تسوق';
      case ServiceKeys.social:
        return 'تواصل';
      case ServiceKeys.venting:
        return 'فضفضة';
      case ServiceKeys.hobbiesSports:
        return 'رياضة';
      case ServiceKeys.podcasts:
        return 'بودكاست';
      default:
        return 'خدمة';
    }
  }

  Widget _buildServiceRail(List<Sa7biService> services) {
    return SizedBox(
      width: _railWidth,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _buildRail(services),
        ),
      ),
    );
  }

  Widget _buildChatPanel() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: ChatScreen(
        key: ValueKey<String>('khalasana-chat-$_activeServiceKey'),
        serviceKey: _activeServiceKey,
        serviceTitle: _activeTitle,
        serviceContext: _activeContext,
      ),
    );
  }

  Widget _buildPortalHeader() {
    final selected = _selectedService;

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFF1D3150),
            Color(0xFF151B2B),
            Color(0xFF101522),
          ],
        ),
        border: Border.all(color: const Color(0x664E83A8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 13,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            width: 37,
            height: 37,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF8EA8FF), Color(0xFF54DDF2)],
              ),
              boxShadow: [
                BoxShadow(
                  color: _cyan.withValues(alpha: 0.22),
                  blurRadius: 13,
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFF07111E),
              size: 21,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'خلصانة AI',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  selected == null
                      ? 'اسأل في أي موضوع أو اختار مجال من الجوانب'
                      : 'المجال الحالي: ${selected.title}',
                  textDirection: TextDirection.rtl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFB9C8D8),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 7),
          _GeneralModeButton(
            selected: selected == null,
            onTap: _selectGeneral,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          children: [
            _buildPortalHeader(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // على الشاشات الأضيق نستخدم شريطًا واحدًا لتظل مساحة
                  // المحادثة واسعة ومريحة، وعلى الشاشات الأعرض نقسم الخدمات
                  // إلى خمسة ألسنة يمينًا وخمسة يسارًا.
                  final useTwoRails = constraints.maxWidth >= 380;
                  final rightServices = useTwoRails
                      ? sa7biServices.take(5).toList(growable: false)
                      : sa7biServices;
                  final leftServices = useTwoRails
                      ? sa7biServices.skip(5).toList(growable: false)
                      : const <Sa7biService>[];

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(5, 0, 5, 7),
                    child: Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        _buildServiceRail(rightServices),
                        const SizedBox(width: 4),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(17),
                            child: _buildChatPanel(),
                          ),
                        ),
                        if (useTwoRails) ...[
                          const SizedBox(width: 4),
                          _buildServiceRail(leftServices),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GeneralModeButton extends StatelessWidget {
  const _GeneralModeButton({
    required this.selected,
    required this.onTap,
  });

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? const Color(0xFF06111C) : _KhalasanaColors.gold;

    return Tooltip(
      message: 'المحادثة العامة',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              color: selected
                  ? _KhalasanaColors.cyan
                  : const Color(0x332B3A52),
              border: Border.all(
                color: selected
                    ? _KhalasanaColors.cyan
                    : const Color(0x557C91AA),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded, size: 14, color: foreground),
                const SizedBox(width: 4),
                Text(
                  'عام',
                  style: TextStyle(
                    color: foreground,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
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

class _KhalasanaServiceTab extends StatelessWidget {
  const _KhalasanaServiceTab({
    required this.service,
    required this.selected,
    required this.shortName,
    required this.onTap,
  });

  final Sa7biService service;
  final bool selected;
  final String shortName;
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
                    : const [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    service.icon,
                    color: selected ? color : color.withValues(alpha: 0.88),
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
                          color: selected ? Colors.white : const Color(0xFFCDD6E2),
                          fontSize: 8,
                          fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
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

class _KhalasanaColors {
  static const Color cyan = Color(0xFF63E6FF);
  static const Color gold = Color(0xFFFFD76A);
}
