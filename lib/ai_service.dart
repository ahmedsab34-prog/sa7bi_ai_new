import 'dart:convert';
import 'package:http/http.dart' as http;

class AiService {
  static const String _workerUrl =
      'https://sa7bi-ai-new.ahmedsab34.workers.dev/v1/chat';

  static Future<String> getResponse(String prompt) async {
    try {
      if (prompt.trim().isEmpty) {
        return 'اكتب رسالتك أولاً.';
      }

      final response = await http
          .post(
            Uri.parse(_workerUrl),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'messages': [
                {
                  'role': 'user',
                  'content': prompt.trim(),
                }
              ],
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        try {
          final errorData = jsonDecode(response.body);
          return errorData['error']?.toString() ??
              'حدث خطأ أثناء الاتصال بالمساعد.';
        } catch (_) {
          return 'حدث خطأ أثناء الاتصال بالمساعد.';
        }
      }

      final data = jsonDecode(response.body);

      if (data['ok'] == true &&
          data['reply'] is String &&
          data['reply'].toString().trim().isNotEmpty) {
        return data['reply'].toString();
      }

      return 'عذراً، لم يتم تلقي رد من المساعد.';
    } catch (e) {
      return 'تعذر الاتصال بالمساعد. تأكد من اتصال الإنترنت وحاول مرة أخرى.';
    }
  }
}
