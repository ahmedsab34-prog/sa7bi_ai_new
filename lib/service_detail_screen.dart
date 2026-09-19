import 'package:flutter/material.dart';

import 'chat_screen.dart';
import 'service_config.dart';

class ServiceDetailScreen extends StatelessWidget {
  final Sa7biService service;

  const ServiceDetailScreen({
    super.key,
    required this.service,
  });

  void _openChat(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          serviceTitle: service.title,
          serviceContext: service.aiRole,
        ),
      ),
    );
  }

  void _openImageAi(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          serviceTitle: '${service.title} — تحليل الصور',
          serviceContext:
              '${service.aiRole}\n'
              'هذا الوضع مخصص لتحليل الصور التي يرسلها المستخدم. '
              'صف الأشياء الظاهرة فقط، '
              'اذكر درجة عدم اليقين عندما تكون التفاصيل غير واضحة، '
              'ولا تخترع معلومات غير موجودة في الصورة.',
        ),
      ),
    );
  }

  List<String> _suggestions() {
    switch (service.title) {
      case 'المطبخ':
        return [
          'حلل صورة الأكل ده',
          'اقترح وصفة بالمكونات اللي عندي',
          'اعمل لي قائمة مشتريات',
        ];

      case 'التجارة':
        return [
          'اكتب إعلان للمنتج ده',
          'حلل صورة المنتج',
          'ساعدني أرتب منتجات متجري',
        ];

      case 'الصيدلية والأعشاب':
        return [
          'ما المعلومات الظاهرة على العبوة؟',
          'حلل صورة الدواء بحذر',
          'ما أهم التحذيرات العامة؟',
        ];

      case 'الحرفيين':
        return [
          'حلل صورة المشكلة دي',
          'إيه سبب العطل المحتمل؟',
          'رتب لي خطوات الفحص',
        ];

      case 'العبادة':
        return [
          'ساعدني في فهم هذه المعلومة',
          'اعرض لي أذكارًا مناسبة',
          'ساعدني في مراجعة نص ديني',
        ];

      case 'التسوق':
        return [
          'قارن لي بين منتجين',
          'ساعدني أختار حسب ميزانيتي',
          'حلل صورة المنتج',
        ];

      case 'التواصل':
        return [
          'اكتب لي رد مناسب',
          'حسن صياغة الرسالة دي',
          'ساعدني أبدأ محادثة',
        ];

      case 'فضفضة':
        return [
          'عايز أفضفض',
          'ساعدني أرتب أفكاري',
          'مش عارف أتصرف إزاي',
        ];

      case 'الهوايات والرياضة':
        return [
          'اقترح لي نشاط جديد',
          'ساعدني أتعلم مهارة',
          'نتكلم عن الرياضة والألعاب',
        ];

      case 'البودكاست':
        return [
          'اقترح فكرة حلقة',
          'اكتب لي مقدمة',
          'جهز لي أسئلة للضيف',
        ];

      default:
        return [
          'ساعدني',
          'حلل صورة',
          'اقترح لي أفكار',
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _suggestions();

    return Scaffold(
      backgroundColor: const Color(0xFF09090F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF11111A),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          service.title,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 18),
              _buildQuickSuggestions(suggestions),
              const SizedBox(height: 18),
              _buildMainButton(
                context,
                icon: Icons.auto_awesome_rounded,
                title: 'تحدث مع صَحبي AI',
                subtitle: 'نص + صوت + صور + إنشاء صور',
                onTap: () => _openChat(context),
              ),
              const SizedBox(height: 12),
              _buildMainButton(
                context,
                icon: Icons.camera_alt_rounded,
                title: 'حلل صورة بالكاميرا',
                subtitle: 'صوّر أي شيء واسأل صَحبي عنه',
                onTap: () => _openImageAi(context),
              ),
              const SizedBox(height: 12),
              _buildMainButton(
                context,
                icon: Icons.photo_library_rounded,
                title: 'حلل صورة من الهاتف',
                subtitle: 'اختر صورة من المعرض ثم اسأل AI',
                onTap: () => _openImageAi(context),
              ),
              const SizedBox(height: 12),
              _buildMainButton(
                context,
                icon: Icons.mic_rounded,
                title: 'تحدث بصوتك',
                subtitle: 'صَحبي يسمع كلامك ويرد عليك',
                onTap: () => _openChat(context),
              ),
              const SizedBox(height: 12),
              _buildMainButton(
                context,
                icon: Icons.image_rounded,
                title: 'إنشاء صورة بالـAI',
                subtitle: 'اكتب وصف الصورة وسيتم إنشاؤها',
                onTap: () => _openChat(context),
              ),
              const SizedBox(height: 22),
              _buildSafetyInfo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            service.color.withOpacity(0.30),
            const Color(0xFF171722),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        border: Border.all(
          color: service.color.withOpacity(0.35),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: service.color.withOpacity(0.18),
              border: Border.all(
                color: service.color.withOpacity(0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: service.color.withOpacity(0.18),
                  blurRadius: 22,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              service.icon,
              color: service.color,
              size: 42,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            service.title,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            service.description,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSuggestions(List<String> suggestions) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF11111A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text(
            'أفكار تبدأ بها',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: suggestions.map((suggestion) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: service.color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: service.color.withOpacity(0.25),
                  ),
                ),
                child: Text(
                  suggestion,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    color: service.color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFF11111A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.verified_user_outlined,
            color: service.color,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'صَحبي يعتمد على المعلومات المتاحة في المحادثة والصور المرسلة. '
              'لا تدّعي الخدمة تنفيذ شيء لم يحدث، '
              'ولا تعتبر الإجابات الطبية أو الفنية بديلًا عن المختص عند الحاجة.',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: Colors.white70,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFF15151F),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: service.color.withOpacity(0.14),
                  border: Border.all(
                    color: service.color.withOpacity(0.35),
                  ),
                ),
                child: Icon(
                  icon,
                  color: service.color,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      title,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_left_rounded,
                color: Colors.white38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
