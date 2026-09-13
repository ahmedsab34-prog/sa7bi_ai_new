import 'package:flutter/material.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({Key? key}) : super(key: key);

  final List<Map<String, dynamic>> categories = const [
    {'title': 'المطبخ والبيت', 'icon': Icons.kitchen, 'color': Colors.orange},
    {'title': 'التاجر', 'icon': Icons.store, 'color': Colors.amber},
    {'title': 'الصيدلية والأعشاب', 'icon': Icons.medical_services, 'color': Colors.green},
    {'title': 'الصنايعي', 'icon': Icons.build, 'color': Colors.blueGrey},
    {'title': 'العبادات', 'icon': Icons.mosque, 'color': Colors.teal},
    {'title': 'الشراء والتسوق', 'icon': Icons.shopping_cart, 'color': Colors.pink},
    {'title': 'التواصل الاجتماعي', 'icon': Icons.chat, 'color': Colors.purple},
    {'title': 'الفضفضة الخاصة', 'icon': Icons.psychology, 'color': Colors.indigo},
    {'title': 'الهوايات والرياضة', 'icon': Icons.sports_soccer, 'color': Colors.red},
    {'title': 'البودكاست', 'icon': Icons.podcasts, 'color': Colors.cyan},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('أقسام صاحبي AI العشرة'),
        backgroundColor: const Color(0xFF1E293B),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: GridView.builder(
          itemCount: categories.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.1,
          ),
          itemBuilder: (context, index) {
            final cat = categories[index];
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cat['color'].withOpacity(0.5), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: cat['color'].withOpacity(0.1),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(cat['icon'], size: 40, color: cat['color']),
                  const SizedBox(height: 12),
                  Text(
                    cat['title'],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
