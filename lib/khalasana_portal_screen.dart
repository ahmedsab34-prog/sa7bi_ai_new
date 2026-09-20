import 'package:flutter/material.dart';

import 'chat_screen.dart';

class KhalasanaPortalScreen
    extends StatelessWidget {
  const KhalasanaPortalScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFF070911),
      appBar: AppBar(
        backgroundColor:
            const Color(0xFF0D1018),
        foregroundColor:
            Colors.white,
        centerTitle: true,
        title:
            const Text(
          'خلصانة AI',
          style: TextStyle(
            color:
                Color(0xFFFFD76A),
            fontWeight:
                FontWeight.w900,
          ),
        ),
      ),
      body: ChatScreen(
        serviceTitle:
            'خلصانة AI',
        serviceContext:
            '''
أنت خلصانة AI، المساعد الشامل داخل تطبيق صاحبي.

تعامل مع المستخدم كمساعد واحد متكامل.
لا تطلب منه اختيار قسم قبل مساعدته.

يمكن للمستخدم:
- طرح أي سؤال.
- إرسال صورة لتحليلها.
- طلب إنشاء صورة.
- التحدث بالصوت.
- طلب مساعدة في الطعام.
- التسوق.
- الرياضة.
- الأفلام.
- التطبيقات.
- الدراسة.
- العمل.
- التصوير.
- التصميم.
- المشاكل المنزلية.
- الأفكار والمشروعات.
- الفضفضة.

إذا كان الطلب يحتاج صورة، استخدم مسار إنشاء الصور الموجود في التطبيق.
إذا أرسل صورة، حللها.
إذا كان الطلب متعلقًا بخدمة معينة، غيّر أسلوب الإجابة وسياق المحادثة بما يناسب الموضوع.

لا تقل للمستخدم إن ميزة متاحة أو غير متاحة من نفسك.
إذا فشلت خدمة فعلية، وضح أن الخدمة فشلت وحاول تقديم بديل مفيد.
''',
      ),
    );
  }
}
