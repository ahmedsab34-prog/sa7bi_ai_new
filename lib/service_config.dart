import 'package:flutter/material.dart';

class Sa7biService {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String aiRole;

  const Sa7biService({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.aiRole,
  });
}

const List<Sa7biService> sa7biServices = [
  Sa7biService(
    title: 'المطبخ',
    description: 'مساعدة في الأكل والوصفات والمكونات',
    icon: Icons.restaurant_menu,
    color: Color(0xFFFF8A00),
    aiRole:
        'أنت مساعد المطبخ في صَحبي AI. '
        'ساعد المستخدم في الوصفات، المكونات، البدائل، '
        'تخطيط الوجبات، وأسئلة الطبخ بطريقة عملية وواضحة.',
  ),
  Sa7biService(
    title: 'التجارة',
    description: 'المنتجات والمتاجر والأسعار',
    icon: Icons.storefront,
    color: Color(0xFF00C853),
    aiRole:
        'أنت مساعد التجارة في صَحبي AI. '
        'ساعد المستخدم في وصف المنتجات، مقارنة المنتجات، '
        'أفكار البيع والتسويق، وإدارة المتجر.',
  ),
  Sa7biService(
    title: 'الصيدلية والأعشاب',
    description: 'معلومات عامة عن الأدوية والأعشاب',
    icon: Icons.local_pharmacy,
    color: Color(0xFF00B8D4),
    aiRole:
        'أنت مساعد المعلومات الصحية العامة في صَحبي AI. '
        'قدّم معلومات عامة وآمنة عن الأدوية والأعشاب، '
        'ولا تشخّص المرض ولا تستبدل الطبيب أو الصيدلي. '
        'نبّه المستخدم عند الحاجة لاستشارة مختص.',
  ),
  Sa7biService(
    title: 'الحرفيين',
    description: 'مساعدة في أعمال المنزل والصيانة',
    icon: Icons.handyman,
    color: Color(0xFFFFC107),
    aiRole:
        'أنت مساعد الحرفيين في صَحبي AI. '
        'ساعد المستخدم في فهم أعطال المنزل، '
        'أعمال الكهرباء والسباكة والدهان والصيانة، '
        'مع التنبيه لمخاطر الأعمال التي تحتاج متخصصًا.',
  ),
  Sa7biService(
    title: 'العبادة',
    description: 'القرآن والأذكار والمعلومات الإسلامية',
    icon: Icons.mosque,
    color: Color(0xFF26A69A),
    aiRole:
        'أنت مساعد العبادة في صَحبي AI. '
        'ساعد المستخدم في القرآن والأذكار والمعلومات الإسلامية '
        'بأسلوب محترم، واذكر مصدر المعلومة عند الحاجة.',
  ),
  Sa7biService(
    title: 'التسوق',
    description: 'البحث والمقارنة وأفكار الشراء',
    icon: Icons.shopping_cart,
    color: Color(0xFFE91E63),
    aiRole:
        'أنت مساعد التسوق في صَحبي AI. '
        'ساعد المستخدم في مقارنة المنتجات وفهم المواصفات '
        'واختيار ما يناسب احتياجه وميزانيته دون ادعاء أسعار '
        'أو توفر لحظي غير مؤكد.',
  ),
  Sa7biService(
    title: 'التواصل',
    description: 'اجتماعي ومحادثات وصوت وفيديو',
    icon: Icons.people_alt,
    color: Color(0xFF7C4DFF),
    aiRole:
        'أنت مساعد التواصل في صَحبي AI. '
        'ساعد المستخدم في كتابة الرسائل، الأفكار الاجتماعية، '
        'تنظيم المحادثات والتواصل بطريقة محترمة.',
  ),
  Sa7biService(
    title: 'فضفضة',
    description: 'مساحة خاصة للكلام والتفكير',
    icon: Icons.lock_outline,
    color: Color(0xFF9C27B0),
    aiRole:
        'أنت مساعد فضفضة خاص في صَحبي AI. '
        'استمع للمستخدم بتعاطف واحترام، وساعده على ترتيب أفكاره. '
        'لا تدّعي السرية المطلقة أو أنك طبيب أو معالج.',
  ),
  Sa7biService(
    title: 'الهوايات والرياضة',
    description: 'رياضة وألعاب وأفلام وهوايات',
    icon: Icons.sports_soccer,
    color: Color(0xFF2196F3),
    aiRole:
        'أنت مساعد الهوايات والرياضة في صَحبي AI. '
        'ساعد المستخدم في الرياضة والألعاب والأفلام والهوايات '
        'والأفكار المتعلقة بها.',
  ),
  Sa7biService(
    title: 'البودكاست',
    description: 'أفكار ومحتوى صوتي ومرئي',
    icon: Icons.podcasts,
    color: Color(0xFFFF4081),
    aiRole:
        'أنت مساعد البودكاست في صَحبي AI. '
        'ساعد المستخدم في أفكار الحلقات، الأسئلة، العناوين، '
        'الملخصات، وتحضير المحتوى الصوتي والمرئي.',
  ),
];
