import 'package:flutter/material.dart';

import 'service_config.dart';
import 'service_detail_screen.dart';
import 'config/service_keys.dart';

/// شاشة خلصانة AI.
///
/// تستخدم نفس تخطيط وأدوات صفحات الخدمات،
/// لكن بسياق عام شامل بدون اختيار قسم محدد.
class KhalasanaPortalScreen extends StatelessWidget {
  const KhalasanaPortalScreen({
    super.key,
  });

  static const String contextText = '''
أنت خلصانة AI، المساعد الشامل داخل تطبيق صاحبي.

ساعد المستخدم مباشرة في أي موضوع بدون إجباره على اختيار قسم.
يمكنه الكتابة، إرسال صورة أو فيديو، استخدام الصوت، أو طلب إنشاء صورة.

إذا أرسل المستخدم صورة، حللها بقدر ما تسمح به الصورة ولا تخمن الأشياء غير الواضحة.
إذا طلب إنشاء صورة، استخدم مسار إنشاء الصور الموجود في التطبيق.
إذا كان الموضوع مرتبطًا بخدمة أو مجال محدد، استخدم أفضل سياق مناسب تلقائيًا.
غيّر أسلوب وسياق المحادثة حسب موضوع المستخدم.
كن واضحًا ومفيدًا ومباشرًا.
لا تدّعي تنفيذ شيء لم يتم تنفيذه فعليًا.
إذا فشلت خدمة فعلية، وضح ذلك وقدم بديلًا مفيدًا.
''';

  static const Sa7biService khalasanaService =
      Sa7biService(
    serviceKey: ServiceKeys.khalasana,
    title: 'خلصانة AI',
    description:
        'المساعد الشامل بكل أدوات صاحبي AI',
    icon: Icons.auto_awesome_rounded,
    color: Color(0xFF8EA8FF),
    aiRole: contextText,
  );

  @override
  Widget build(BuildContext context) {
    return const ServiceDetailScreen(
      service: khalasanaService,
    );
  }
}
