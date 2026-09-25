import 'package:flutter/material.dart';

import 'chat_screen.dart';
import 'service_config.dart';

/// Compatibility bridge for older navigation paths.
///
/// كل خدمة تفتح محادثة AI مباشرة.
/// ChatScreen يحتوي الأدوات الفعلية:
/// - المحادثة
/// - الكاميرا
/// - الصور
/// - الفيديو وتحليله
/// - تحويل الكلام إلى نص
/// - تحويل النص إلى صوت
/// - إنشاء الصور
/// - Credits
class ServiceDetailScreen extends StatelessWidget {
  final Sa7biService service;

  const ServiceDetailScreen({
    super.key,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return ChatScreen(
      serviceKey: service.serviceKey,
      serviceTitle: service.title,
      serviceContext: service.aiRole,
    );
  }
}
