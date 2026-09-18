import 'package:flutter/material.dart';

import 'service_config.dart';
import 'service_detail_screen.dart';

class CategoriesScreen extends StatelessWidget {
const CategoriesScreen({super.key});

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: const Color(0xFF080A10),
appBar: AppBar(
title: const Text(
'أقسام صاحبي AI',
style: TextStyle(
fontWeight: FontWeight.w900,
),
),
backgroundColor: const Color(0xFF11141D),
foregroundColor: Colors.white,
elevation: 0,
automaticallyImplyLeading: false,
),
body: GridView.builder(
padding: const EdgeInsets.fromLTRB(
14,
16,
14,
24,
),
itemCount: sa7biServices.length,
gridDelegate:
const SliverGridDelegateWithFixedCrossAxisCount(
crossAxisCount: 2,
crossAxisSpacing: 14,
mainAxisSpacing: 14,
childAspectRatio: 0.88,
),
itemBuilder: (context, index) {
final service = sa7biServices[index];

      return _ServiceCard(
        service: service,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ServiceDetailScreen(
                service: service,
              ),
            ),
          );
        },
      );
    },
  ),
);

}
}

class _ServiceCard extends StatelessWidget {
final Sa7biService service;
final VoidCallback onTap;

const _ServiceCard({
required this.service,
required this.onTap,
});

@override
Widget build(BuildContext context) {
return Material(
color: Colors.transparent,
child: InkWell(
onTap: onTap,
borderRadius: BorderRadius.circular(26),
child: Ink(
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(26),
gradient: LinearGradient(
begin: Alignment.topLeft,
end: Alignment.bottomRight,
colors: [
service.color.withOpacity(0.28),
const Color(0xFF121620),
const Color(0xFF0D1018),
],
),
border: Border.all(
color: service.color.withOpacity(0.35),
width: 1.3,
),
boxShadow: [
BoxShadow(
color: service.color.withOpacity(0.10),
blurRadius: 18,
spreadRadius: 1,
),
const BoxShadow(
color: Color(0x33000000),
blurRadius: 10,
offset: Offset(0, 6),
),
],
),
child: Padding(
padding: const EdgeInsets.all(14),
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Container(
width: 82,
height: 82,
decoration: BoxDecoration(
shape: BoxShape.circle,
gradient: LinearGradient(
begin: Alignment.topLeft,
end: Alignment.bottomRight,
colors: [
service.color,
service.color.withOpacity(0.55),
],
),
boxShadow: [
BoxShadow(
color: service.color.withOpacity(0.30),
blurRadius: 20,
spreadRadius: 2,
),
],
),
child: Icon(
service.icon,
color: Colors.black,
size: 40,
),
),
const SizedBox(height: 15),
Text(
service.title,
textDirection: TextDirection.rtl,
textAlign: TextAlign.center,
maxLines: 2,
overflow: TextOverflow.ellipsis,
style: const TextStyle(
color: Colors.white,
fontSize: 18,
fontWeight: FontWeight.w900,
),
),
const SizedBox(height: 7),
Text(
service.description,
textDirection: TextDirection.rtl,
textAlign: TextAlign.center,
maxLines: 2,
overflow: TextOverflow.ellipsis,
style: const TextStyle(
color: Colors.white54,
fontSize: 12,
height: 1.35,
),
),
const SizedBox(height: 8),
const Text(
'اضغط للدخول',
style: TextStyle(
color: Colors.white38,
fontSize: 12,
fontWeight: FontWeight.w600,
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
