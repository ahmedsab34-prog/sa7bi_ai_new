import 'package:flutter/material.dart';

import 'chat_screen.dart';
import 'config/service_keys.dart';

/// شاشة خلصانة AI.
///
/// خلصانة تدخل مباشرة إلى المحادثة الحقيقية
/// بكل أدوات الشات الموجودة في ChatScreen.
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

  @override
  Widget build(BuildContext context) {
    return const ChatScreen(
      serviceKey: ServiceKeys.khalasana,
      serviceTitle: 'خلصانة AI',
      serviceContext: contextText,
    );
  }
}
