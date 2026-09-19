import 'package:flutter/material.dart';

class KhalasanaPortalScreen extends StatelessWidget {
  const KhalasanaPortalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080814),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080814),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'خلصانة AI',
          style: TextStyle(
            color: Color(0xFFFFD76A),
            fontWeight: FontWeight.w800,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),

              // Portal header.
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1E1B45),
                      Color(0xFF0E1022),
                    ],
                  ),
                  border: Border.all(
                    color: Color(0xFFFFD76A),
                    width: 0.7,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF6C63FF),
                      blurRadius: 28,
                      spreadRadius: -12,
                    ),
                  ],
                ),
                child: const Column(
                  children: [
                    Text(
                      '✨',
                      style: TextStyle(fontSize: 42),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'أهلاً بيك في خلصانة AI',
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'قول بس عايز إيه… والباقي علينا.',
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // Command field.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.12),
                  ),
                ),
                child: TextField(
                  textDirection: TextDirection.rtl,
                  textInputAction: TextInputAction.send,
                  style: const TextStyle(
                    color: Colors.white,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'قول لخلصانة تعمل إيه؟',
                    hintTextDirection: TextDirection.rtl,
                    hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                    ),
                    prefixIcon: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFFFFD76A),
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(
                        Icons.arrow_upward_rounded,
                        color: Color(0xFFFFD76A),
                      ),
                      onPressed: () {},
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'اختار بسرعة',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 14),

              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.25,
                children: const [
                  _PortalAction(
                    icon: Icons.psychology_alt_rounded,
                    title: 'اسأل AI',
                    subtitle: 'أي سؤال',
                  ),
                  _PortalAction(
                    icon: Icons.search_rounded,
                    title: 'ابحث',
                    subtitle: 'معلومات وويب',
                  ),
                  _PortalAction(
                    icon: Icons.school_rounded,
                    title: 'ذاكر',
                    subtitle: 'شرح وتلخيص واختبارات',
                  ),
                  _PortalAction(
                    icon: Icons.newspaper_rounded,
                    title: 'أخبار',
                    subtitle: 'آخر الأخبار',
                  ),
                  _PortalAction(
                    icon: Icons.sports_soccer_rounded,
                    title: 'رياضة',
                    subtitle: 'مباريات ونتائج',
                  ),
                  _PortalAction(
                    icon: Icons.movie_rounded,
                    title: 'أفلام',
                    subtitle: 'اكتشاف ومشاهدة قانونية',
                  ),
                  _PortalAction(
                    icon: Icons.image_rounded,
                    title: 'صور',
                    subtitle: 'إنشاء صور بالـAI',
                  ),
                  _PortalAction(
                    icon: Icons.shopping_bag_rounded,
                    title: 'منتجات',
                    subtitle: 'ابحث وقارن',
                  ),
                  _PortalAction(
                    icon: Icons.mic_rounded,
                    title: 'صوت',
                    subtitle: 'اتكلم مع خلصانة',
                  ),
                  _PortalAction(
                    icon: Icons.auto_awesome_rounded,
                    title: 'اعمل أي حاجة',
                    subtitle: 'خلّي AI يحدد الأداة',
                  ),
                ],
              ),

              const SizedBox(height: 22),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD76A).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFFFD76A).withOpacity(0.18),
                  ),
                ),
                child: const Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: Color(0xFFFFD76A),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'خلصانة AI هتتطور تدريجيًا لتجمع أدوات الذكاء الاصطناعي والبحث والخدمات في مكان واحد.',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          color: Colors.white70,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PortalAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PortalAction({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {},
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.10),
                Colors.white.withOpacity(0.035),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.10),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: const Color(0xFFFFD76A),
                  size: 30,
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
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
