import 'package:google_generative_ai/google_generative_ai.dart';

class AiService {
  // دالة لإرسال الرسالة واستقبال الرد من نموذج Gemini الفعال
  static Future<String> getGeminiResponse(String apiKey, String prompt) async {
    try {
      if (apiKey.isEmpty) {
        return 'الرجاء إدخال مفتاح API الصحيح من شاشة الإعدادات أولاً.';
      }

      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
      );

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      return response.text ?? 'عذراً، لم يتم تلقي رد من المساعد.';
    } catch (e) {
      return 'حدث خطأ أثناء الاتصال بالذكاء الاصطناعي: $e';
    }
  }
}
