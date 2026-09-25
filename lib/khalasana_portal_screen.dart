import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'chat_screen.dart';
import 'service_config.dart';
import 'config/service_keys.dart';

/// شاشة خلصانة AI.
///
/// تفتح المحادثة مباشرة بدون صفحة وسيطة.
/// أدوات المحادثة كلها موجودة داخل ChatScreen.
class KhalasanaPortalScreen extends StatefulWidget {
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
  State<KhalasanaPortalScreen> createState() =>
      _KhalasanaPortalScreenState();
}

class _KhalasanaPortalScreenState
    extends State<KhalasanaPortalScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    _animationController =
        AnimationController(
      vsync: this,
      duration:
          const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFF070910),
      body: Stack(
        children: [
          // ==================================================
          // MAIN AI CHAT
          // ==================================================

          const Positioned.fill(
            child: ChatScreen(
              serviceKey:
                  khalasanaService.serviceKey,
              serviceTitle:
                  khalasanaService.title,
              serviceContext:
                  khalasanaService.aiRole,
            ),
          ),

          // ==================================================
          // SUBTLE KHALASANA ANIMATION
          //
          // IgnorePointer مهم جدًا:
          // الأنيميشن لا يمنع الكتابة أو الضغط أو
          // التعامل مع الصور والكاميرا والأدوات.
          // ==================================================

          Positioned(
            top: 56,
            right: 10,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation:
                    _animationController,
                builder: (
                  context,
                  child,
                ) {
                  final wave =
                      (math.sin(
                                _animationController
                                        .value *
                                    math.pi *
                                    2,
                              ) +
                              1) /
                          2;

                  return Opacity(
                    opacity:
                        0.16 +
                            wave * 0.10,
                    child:
                        Transform.scale(
                      scale:
                          0.94 +
                              wave * 0.08,
                      child:
                          Container(
                        width: 42,
                        height: 42,
                        decoration:
                            BoxDecoration(
                          shape:
                              BoxShape
                                  .circle,
                          border:
                              Border.all(
                            color:
                                const Color(
                              0xFF8EA8FF,
                            ),
                            width:
                                1.4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  const Color(
                                0xFF8EA8FF,
                              ).withOpacity(
                                0.18 +
                                    wave *
                                        0.16,
                              ),
                              blurRadius:
                                  12 +
                                      wave *
                                          8,
                            ),
                          ],
                        ),
                        child:
                            const Icon(
                          Icons
                              .auto_awesome_rounded,
                          color:
                              Color(
                            0xFFB9C8FF,
                          ),
                          size: 21,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
