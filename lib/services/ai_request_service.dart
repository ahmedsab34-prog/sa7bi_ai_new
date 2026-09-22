import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

/// طبقة طلبات AI التي تُرجع أخطاء حقيقية بدل تحويلها إلى
/// رسالة نصية ناجحة.
///
/// الهدف منها أن يعرف ChatScreen هل الطلب:
/// - نجح فعلًا.
/// - فشل بسبب الخادم.
/// - فشل بسبب الاتصال.
/// - فشل بسبب الطلب نفسه.
///
/// وده مهم جدًا مع نظام الـCredits:
/// النجاح = نحتفظ بالـCredit.
/// الفشل = ChatScreen يستطيع عمل Refund.
class AiRequestService {
  AiRequestService._();

  static const String base =
      'https://sa7bi-ai-new.ahmedsab34.workers.dev';

  static const String chatEndpoint =
      '$base/v1/chat';

  static const int maxHistory = 8;

  // ============================================================
  // CHAT
  // ============================================================

  static Future<String> getResponse({
    required String prompt,
    String? serviceContext,
    List<Map<String, String>> history = const [],
  }) async {
    final text = prompt.trim();

    if (text.isEmpty) {
      return 'قول لي يا صاحبي 😊';
    }

    final validHistory = history
        .where(
          (item) =>
              (item['role'] == 'user' ||
                  item['role'] == 'assistant') &&
              (item['content'] ?? '').trim().isNotEmpty,
        )
        .toList();

    final start = validHistory.length > maxHistory
        ? validHistory.length - maxHistory
        : 0;

    final messages = <Map<String, String>>[];

    for (final item in validHistory.sublist(start)) {
      final role = item['role'];
      final content = item['content']?.trim();

      if (role == null ||
          content == null ||
          content.isEmpty) {
        continue;
      }

      messages.add({
        'role': role,
        'content': content,
      });
    }

    String current = text;

    if (serviceContext != null &&
        serviceContext.trim().isNotEmpty) {
      current =
          'سياق الخدمة:\n'
          '${serviceContext.trim()}\n\n'
          'رسالة المستخدم:\n'
          '$text';
    }

    messages.add({
      'role': 'user',
      'content': current,
    });

    final response = await _post(
      chatEndpoint,
      body: {
        'messages': messages,
      },
      timeout: const Duration(seconds: 60),
    );

    final data = _decodeMap(response.body);

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw AiRequestException(
        _serverError(
          response.statusCode,
          data,
        ),
        statusCode: response.statusCode,
      );
    }

    if (data == null) {
      throw const AiRequestException(
        'رد الخادم غير مفهوم.',
      );
    }

    if (data['ok'] != true) {
      throw AiRequestException(
        _errorFromData(
          data,
          fallback: 'صاحبي مش قادر يرد دلوقتي. جرّب تاني.',
        ),
        statusCode: response.statusCode,
      );
    }

    final answer = data['answer']?.toString().trim();

    if (answer == null || answer.isEmpty) {
      throw const AiRequestException(
        'الخادم لم يرجع ردًا من الذكاء الاصطناعي.',
      );
    }

    return answer;
  }

  // ============================================================
  // IMAGE ANALYSIS
  // ============================================================

  static Future<String> analyzeImage({
    required XFile file,
    String prompt =
        'حلل الصورة المرسلة بدقة وباختصار، واذكر الأشياء المهمة الظاهرة فيها.',
    String? serviceContext,
  }) async {
    final bytes = await file.readAsBytes();

    if (bytes.isEmpty) {
      throw const AiRequestException(
        'الصورة لم يتم قراءتها.',
      );
    }

    if (bytes.length > 5 * 1024 * 1024) {
      throw const AiRequestException(
        'الصورة كبيرة جدًا. ابعت صورة أصغر من 5 ميجابايت.',
      );
    }

    String finalPrompt = prompt.trim();

    if (serviceContext != null &&
        serviceContext.trim().isNotEmpty) {
      finalPrompt =
          'سياق الخدمة:\n'
          '${serviceContext.trim()}\n\n'
          'طلب المستخدم:\n'
          '$finalPrompt';
    }

    final mime = _mime(file.name);

    final response = await _post(
      chatEndpoint,
      body: {
        'messages': [
          {
            'role': 'user',
            'content': finalPrompt,
          },
        ],
        'imageDataUrl':
            'data:$mime;base64,${base64Encode(bytes)}',
      },
      timeout: const Duration(seconds: 90),
    );

    final data = _decodeMap(response.body);

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw AiRequestException(
        _serverError(
          response.statusCode,
          data,
        ),
        statusCode: response.statusCode,
      );
    }

    if (data == null) {
      throw const AiRequestException(
        'رد تحليل الصورة غير مفهوم.',
      );
    }

    if (data['ok'] != true) {
      throw AiRequestException(
        _errorFromData(
          data,
          fallback: 'الصورة وصلت، لكن التحليل لم يكتمل.',
        ),
        statusCode: response.statusCode,
      );
    }

    final answer = data['answer']?.toString().trim();

    if (answer == null || answer.isEmpty) {
      throw const AiRequestException(
        'الخادم لم يرجع نتيجة لتحليل الصورة.',
      );
    }

    return answer;
  }

  // ============================================================
  // HTTP
  // ============================================================

  static Future<http.Response> _post(
    String endpoint, {
    required Map<String, dynamic> body,
    required Duration timeout,
  }) async {
    try {
      return await http
          .post(
            Uri.parse(endpoint),
            headers: const {
              'Content-Type': 'application/json',
              'Cache-Control': 'no-cache',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on http.ClientException catch (error) {
      throw AiRequestException(
        'تعذر الاتصال بالخادم: ${error.message}',
      );
    } on FormatException {
      throw const AiRequestException(
        'تعذر تجهيز طلب الذكاء الاصطناعي.',
      );
    } catch (error) {
      throw AiRequestException(
        _connectionError(error),
      );
    }
  }

  // ============================================================
  // RESPONSE HELPERS
  // ============================================================

  static Map<String, dynamic>? _decodeMap(
    String body,
  ) {
    try {
      final decoded = jsonDecode(body);

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  static String _errorFromData(
    Map<String, dynamic> data, {
    required String fallback,
  }) {
    final error = data['error']?.toString().trim();

    if (error != null && error.isNotEmpty) {
      return _friendlyError(error);
    }

    return fallback;
  }

  static String _serverError(
    int statusCode,
    Map<String, dynamic>? data,
  ) {
    final serverMessage =
        data?['error']?.toString().trim();

    if (serverMessage != null &&
        serverMessage.isNotEmpty) {
      return _friendlyError(serverMessage);
    }

    switch (statusCode) {
      case 400:
        return 'الطلب غير صحيح.';

      case 401:
      case 403:
        return 'خدمة الذكاء الاصطناعي تحتاج إعداد صلاحية صحيح.';

      case 408:
        return 'الطلب استغرق وقتًا أطول من اللازم.';

      case 413:
        return 'البيانات المرسلة كبيرة جدًا.';

      case 429:
        return 'الخدمة مشغولة حاليًا. جرّب بعد لحظات.';

      case 500:
      case 502:
      case 503:
      case 504:
        return 'الخادم مشغول أو الخدمة غير متاحة حاليًا.';

      default:
        return 'حصل خطأ في الاتصال بالخادم.';
    }
  }

  static String _friendlyError(
    String value,
  ) {
    final error = value.trim();

    switch (error) {
      case 'OPENAI_API_KEY_MISSING':
        return 'خدمة الذكاء الاصطناعي غير مُعدة حاليًا.';

      case 'EMPTY_AI_RESPONSE':
        return 'الذكاء الاصطناعي لم يرجع ردًا. جرّب تاني.';

      case 'BODY_TOO_LARGE':
        return 'البيانات المرسلة كبيرة جدًا.';

      case 'NOT_FOUND':
        return 'خدمة الذكاء الاصطناعي غير موجودة حاليًا.';

      default:
        return error.isEmpty
            ? 'حصل خطأ غير معروف.'
            : error;
    }
  }

  static String _connectionError(
    Object error,
  ) {
    final value = error.toString().toLowerCase();

    if (value.contains('timeout')) {
      return 'الاتصال بخدمة الذكاء الاصطناعي استغرق وقتًا طويلًا.';
    }

    if (value.contains('socket') ||
        value.contains('network') ||
        value.contains('connection')) {
      return 'مفيش اتصال مستقر بخدمة الذكاء الاصطناعي.';
    }

    return 'حصل تأخير في الاتصال بصاحبي. جرّب تاني.';
  }

  // ============================================================
  // MIME
  // ============================================================

  static String _mime(
    String name,
  ) {
    final value = name.toLowerCase();

    if (value.endsWith('.png')) {
      return 'image/png';
    }

    if (value.endsWith('.webp')) {
      return 'image/webp';
    }

    if (value.endsWith('.gif')) {
      return 'image/gif';
    }

    if (value.endsWith('.heic') ||
        value.endsWith('.heif')) {
      return 'image/heic';
    }

    return 'image/jpeg';
  }
}

/// خطأ معروف في طلبات AI.
///
/// ChatScreen يستطيع الإمساك به والتعامل معه
/// بدون اعتبار رسالة الخطأ ردًا ناجحًا من AI.
class AiRequestException implements Exception {
  final String message;
  final int? statusCode;

  const AiRequestException(
    this.message, {
    this.statusCode,
  });

  @override
  String toString() => message;
}
