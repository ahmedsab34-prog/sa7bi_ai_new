import 'package:flutter/material.dart';

import 'chat_screen.dart';
import 'config/service_keys.dart';
import 'service_config.dart';

/// شاشة خلصانة AI.
/// تستخدم شاشة المحادثة الحالية مباشرة، من دون طبقات حركة
/// إضافية أو Scaffold متداخل.
class KhalasanaPortalScreen extends StatelessWidget {
  const KhalasanaPortalScreen({
    super.key,
  });

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

  static const Sa7biService khalasanaService = Sa7biService(
    serviceKey: ServiceKeys.khalasana,
    title: 'خلصانة AI',
    description: 'المساعد الشامل بكل أدوات صاحبي AI',
    icon: Icons.auto_awesome_rounded,
    color: Color(0xFF8EA8FF),
    aiRole: contextText,
  );

  @override
  Widget build(BuildContext context) {
    return ChatScreen(
      serviceKey: khalasanaService.serviceKey,
      serviceTitle: khalasanaService.title,
      serviceContext: khalasanaService.aiRole,
    );
  }
}
