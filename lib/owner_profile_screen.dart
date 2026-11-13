
import 'package:flutter/material.dart';

import 'theme/sa7bi_theme.dart';

/// صفحة تعريف ثابتة بصاحب ومطوّر مشروع صاحبي AI.
///
/// ملاحظة: الكتابة الإنجليزية للاسم مؤقتة إلى أن تتم مطابقتها
/// مع جواز السفر أو بطاقة الرقم القومي قبل أي إيداع رسمي.
class OwnerProfileScreen extends StatelessWidget {
  const OwnerProfileScreen({super.key});

  static const String founderArabicName = 'أحمد سليمان حسين صبرة';
  static const String founderEnglishName = 'Ahmed Soliman Hussein Sabra';

  static const String arabicBio =
      'أحمد سليمان حسين صبرة، مؤسس ومطوّر مشروع صاحبي AI. '
      'أعمل على بناء تجربة عربية ذكية تجمع أدوات الذكاء الاصطناعي '
      'والمحادثة والإبداع والمحتوى الرقمي في مكان واحد، بهدف جعل '
      'التكنولوجيا أقرب وأسهل وأكثر فائدة للجميع.';

  static const String englishBio =
      'Ahmed Soliman Hussein Sabra is the Founder and Developer '
      'of Sa7bi AI, building an Arabic-first AI experience that '
      'brings intelligent assistance, conversation, creativity, '
      'and useful digital content together in one accessible place.';

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Sa7biTheme.background,
        appBar: AppBar(
          title: const Text('عن صاحبي AI'),
          backgroundColor: Sa7biTheme.background,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildIdentityCard(),
                const SizedBox(height: 16),
                _buildBioCard(
                  title: 'نبذة عن المؤسس والمطوّر',
                  text: arabicBio,
                  icon: Icons.person_rounded,
                  direction: TextDirection.rtl,
                ),
                const SizedBox(height: 12),
                _buildBioCard(
                  title: 'Founder & Developer',
                  text: englishBio,
                  icon: Icons.public_rounded,
                  direction: TextDirection.ltr,
                ),
                const SizedBox(height: 12),
                _buildMissionCard(),
                const SizedBox(height: 12),
                _buildCopyrightCard(year),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIdentityCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFF1A3154),
            Color(0xFF101B31),
            Color(0xFF160F22),
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: Sa7biTheme.cyan.withValues(alpha: 0.42),
        ),
        boxShadow: [
          BoxShadow(
            color: Sa7biTheme.blue.withValues(alpha: 0.18),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.38),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 132,
            height: 132,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: Sa7biTheme.brandGradient,
              boxShadow: [
                BoxShadow(
                  color: Sa7biTheme.cyan.withValues(alpha: 0.24),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'founder_ahmed.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Sa7biTheme.navyDeep,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.person_rounded,
                      color: Sa7biTheme.cyan,
                      size: 58,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Sa7biTheme.navyDeep,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Sa7biTheme.cyan.withValues(alpha: 0.42),
                  ),
                ),
                child: Image.asset(
                  'app_icon.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(
                    Icons.auto_awesome_rounded,
                    color: Sa7biTheme.cyan,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'صاحبي AI',
                style: TextStyle(
                  color: Sa7biTheme.textPrimary,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Text(
            'SA7BI AI',
            textDirection: TextDirection.ltr,
            style: TextStyle(
              color: Sa7biTheme.cyan,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.2,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Sa7biTheme.cyan.withValues(alpha: 0.85),
                  Sa7biTheme.wine.withValues(alpha: 0.75),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            founderArabicName,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Sa7biTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            founderEnglishName,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Sa7biTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 13),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: Sa7biTheme.cyan.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Sa7biTheme.cyan.withValues(alpha: 0.32),
              ),
            ),
            child: const Text(
              'مؤسس ومطوّر المشروع',
              style: TextStyle(
                color: Sa7biTheme.cyan,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBioCard({
    required String title,
    required String text,
    required IconData icon,
    required TextDirection direction,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Sa7biTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Sa7biTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: Sa7biTheme.brandGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: Sa7biTheme.background,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  textDirection: direction,
                  style: const TextStyle(
                    color: Sa7biTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            text,
            textDirection: direction,
            textAlign: TextAlign.start,
            style: const TextStyle(
              color: Sa7biTheme.textSecondary,
              fontSize: 13,
              height: 1.85,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionCard() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: Sa7biTheme.darkGlassGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Sa7biTheme.borderWine),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: Sa7biTheme.cyan,
              ),
              SizedBox(width: 9),
              Text(
                'رؤيتنا',
                style: TextStyle(
                  color: Sa7biTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            'تقديم مساعد عربي عملي يجمع الذكاء الاصطناعي والتعلم والإبداع '
            'والمحتوى المفيد، مع الاهتمام بسهولة الاستخدام والخصوصية '
            'وإمكانية الوصول.',
            style: TextStyle(
              color: Sa7biTheme.textSecondary,
              fontSize: 13,
              height: 1.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyrightCard(int year) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Sa7biTheme.backgroundRaised,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Sa7biTheme.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.verified_user_outlined,
            color: Sa7biTheme.cyan,
            size: 23,
          ),
          const SizedBox(height: 9),
          const Text(
            'حقوق المشروع والملكية الفكرية',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Sa7biTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '© $year Ahmed Soliman Hussein Sabra — Sa7bi AI. All Rights Reserved.',
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Sa7biTheme.textSecondary,
              fontSize: 10,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'بيان تعريفي داخل التطبيق، ولا يُعد وحده شهادة تسجيل '
            'أو إثباتًا رسميًا لتسجيل العلامة التجارية.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Sa7biTheme.textMuted,
              fontSize: 10,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
