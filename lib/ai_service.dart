import 'dart:convert';
import 'package:http/http.dart' as http;

class AiService {
  static const String workerUrl =
      'https://sa7bi-ai-new.ahmedsab34.workers.dev/v1/chat';

  static const String statusUrl =
      'https://sa7bi-ai-new.ahmedsab34.workers.dev/';

  static Future<String> getResponse(
    String prompt, {
    String? serviceContext,
    List<Map<String, String>> history = const [],
  }) async {
    try {
      final text = prompt.trim();

      if (text.isEmpty) {
        return 'اكتب رسالتك أولاً.';
      }

      final messages = <Map<String, String>>[];

      for (final item in history) {
        final role = item['role'];
        final content = item['content'];

        if ((role == 'user' || role == 'assistant') &&
            content != null &&
            content.trim().isNotEmpty) {
          messages.add({
            'role': role!,
            'content': content.trim(),
          });
        }
      }

      var currentMessage = text;

      if (serviceContext != null &&
          serviceContext.trim().isNotEmpty) {
        currentMessage =
            'سياق القسم: ${serviceContext.trim()}\n\n'
            'رسالة المستخدم: $text';
      }

      messages.add({
        'role': 'user',
        'content': currentMessage,
      });

      final response = await http
          .post(
            Uri.parse(workerUrl),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'messages': messages,
            }),
          )
          .timeout(
            const Duration(seconds: 30),
          );

      if (response.statusCode != 200) {
        try {
          final errorData = jsonDecode(response.body);

          return errorData['error']?.toString() ??
              'حدث خطأ أثناء الاتصال بالمساعد. '
                  '(${response.statusCode})';
        } catch (_) {
          return 'حدث خطأ أثناء الاتصال بالمساعد. '
              '(${response.statusCode})';
        }
      }

      final data = jsonDecode(response.body);

      if (data['ok'] == true &&
          data['reply'] is String &&
          data['reply'].toString().trim().isNotEmpty) {
        return data['reply'].toString();
      }

      return 'عذراً، لم يتم تلقي رد من المساعد.';
    } catch (_) {
      return 'تعذر الاتصال بالمساعد. '
          'تأكد من الإنترنت ثم حاول مرة أخرى.';
    }
  }

  static Future<bool> checkConnection() async {
    try {
      final response = await http
          .get(Uri.parse(statusUrl))
          .timeout(
            const Duration(seconds: 10),
          );

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
