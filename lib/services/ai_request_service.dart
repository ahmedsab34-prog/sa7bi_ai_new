import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

/// طبقة الاتصال الوحيدة المستخدمة في المحادثة مع Worker.
///
/// مهم جدًا:
/// - لا يوجد OpenAI API Key داخل التطبيق.
/// - التطبيق يتصل فقط بـ Cloudflare Worker.
/// - الـWorker هو المسؤول عن الاتصال بـ OpenAI.
/// - يوجد Retry تلقائي للأخطاء المؤقتة.
/// - يوجد دعم للنص وتحليل الصور.
class AiRequestService {
  AiRequestService._();

  static const String base =
      'https://sa7bi-ai-new.ahmedsab34.workers.dev';

  static const String chatEndpoint =
      '$base/v1/chat';

  static const int maxHistory = 8;

  static const Duration chatTimeout =
      Duration(seconds: 90);

  static const Duration imageTimeout =
      Duration(seconds: 120);

  static const int maxImageBytes =
      5 * 1024 * 1024;

  static const int maxAttempts = 3;

  // ============================================================
  // CHAT
  // ============================================================

  static Future<String> getResponse({
    required String prompt,
    String? serviceContext,
    String? serviceTitle,
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
              (item['content'] ?? '')
                  .trim()
                  .isNotEmpty,
        )
        .toList();

    final start =
        validHistory.length > maxHistory
            ? validHistory.length - maxHistory
            : 0;

    final messages =
        <Map<String, String>>[];

    for (final item
        in validHistory.sublist(start)) {
      final role = item['role'];
      final content =
          item['content']?.trim();

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

    // الرسالة الحالية تأتي دائمًا في النهاية.
    messages.add({
      'role': 'user',
      'content': text,
    });

    final body =
        <String, dynamic>{
      'messages': messages,
    };

    final cleanTitle =
        serviceTitle?.trim();

    final cleanContext =
        serviceContext?.trim();

    if (cleanTitle != null &&
        cleanTitle.isNotEmpty) {
      body['serviceTitle'] =
          cleanTitle;
    }

    if (cleanContext != null &&
        cleanContext.isNotEmpty) {
      body['serviceContext'] =
          cleanContext;
    }

    final response = await _postWithRetry(
      chatEndpoint,
      body: body,
      timeout: chatTimeout,
    );

    final data =
        _decodeMap(response.body);

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw AiRequestException(
        _serverError(
          response.statusCode,
          data,
        ),
        statusCode:
            response.statusCode,
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
          fallback:
              'صاحبي مش قادر يرد دلوقتي. جرّب تاني.',
        ),
        statusCode:
            response.statusCode,
      );
    }

    final answer =
        data['answer']
            ?.toString()
            .trim();

    if (answer == null ||
        answer.isEmpty) {
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
    String? serviceTitle,
  }) async {
    final bytes =
        await file.readAsBytes();

    if (bytes.isEmpty) {
      throw const AiRequestException(
        'الصورة لم يتم قراءتها.',
      );
    }

    if (bytes.length >
        maxImageBytes) {
      throw const AiRequestException(
        'الصورة كبيرة جدًا. ابعت صورة أصغر من 5 ميجابايت.',
      );
    }

    var finalPrompt =
        prompt.trim();

    if (serviceContext != null &&
        serviceContext.trim().isNotEmpty) {
      finalPrompt =
          'سياق الخدمة:\n'
          '${serviceContext.trim()}\n\n'
          'طلب المستخدم:\n'
          '$finalPrompt';
    }

    if (finalPrompt.isEmpty) {
      finalPrompt =
          'حلل الصورة المرسلة بدقة وباختصار.';
    }

    final mime =
        _mime(file.name);

    final body =
        <String, dynamic>{
      'messages': [
        {
          'role': 'user',
          'content': finalPrompt,
        },
      ],
      'imageDataUrl':
          'data:$mime;base64,'
          '${base64Encode(bytes)}',
    };

    final cleanTitle =
        serviceTitle?.trim();

    if (cleanTitle != null &&
        cleanTitle.isNotEmpty) {
      body['serviceTitle'] =
          cleanTitle;
    }

    final response = await _postWithRetry(
      chatEndpoint,
      body: body,
      timeout: imageTimeout,
    );

    final data =
        _decodeMap(response.body);

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw AiRequestException(
        _serverError(
          response.statusCode,
          data,
        ),
        statusCode:
            response.statusCode,
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
          fallback:
              'الصورة وصلت، لكن التحليل لم يكتمل.',
        ),
        statusCode:
            response.statusCode,
      );
    }

    final answer =
        data['answer']
            ?.toString()
            .trim();

    if (answer == null ||
        answer.isEmpty) {
      throw const AiRequestException(
        'الخادم لم يرجع نتيجة لتحليل الصورة.',
      );
    }

    return answer;
  }

  // ============================================================
  // HTTP WITH RETRY
  // ============================================================

  static Future<http.Response> _postWithRetry(
    String endpoint, {
    required Map<String, dynamic> body,
    required Duration timeout,
  }) async {
    Object? lastError;

    for (int attempt = 1;
        attempt <= maxAttempts;
        attempt++) {
      try {
        final response =
            await _post(
          endpoint,
          body: body,
          timeout: timeout,
        );

        if (!_shouldRetry(
          response.statusCode,
        )) {
          return response;
        }

        if (attempt >= maxAttempts) {
          return response;
        }

        await Future<void>.delayed(
          Duration(
            seconds: attempt * 2,
          ),
        );
      } catch (error) {
        lastError = error;

        if (attempt >= maxAttempts) {
          rethrow;
        }

        await Future<void>.delayed(
          Duration(
            seconds: attempt * 2,
          ),
        );
      }
    }

    throw AiRequestException(
      _connectionError(
        lastError ?? 'Unknown error',
      ),
    );
  }

  static bool _shouldRetry(
    int statusCode,
  ) {
    return statusCode == 408 ||
        statusCode == 425 ||
        statusCode == 429 ||
        statusCode == 500 ||
        statusCode == 502 ||
        statusCode == 503 ||
        statusCode == 504;
  }

  // ============================================================
  // HTTP POST
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
              'Content-Type':
                  'application/json',
              'Cache-Control':
                  'no-cache',
              'Pragma':
                  'no-cache',
            },
            body:
                jsonEncode(body),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const AiRequestException(
        'الاتصال بالخادم استغرق وقتًا أطول من اللازم.',
      );
    } on http.ClientException catch (
        error) {
      throw AiRequestException(
        'تعذر الاتصال بالخادم: '
        '${error.message}',
      );
    } on FormatException {
      throw const AiRequestException(
        'تعذر تجهيز طلب الذكاء الاصطناعي.',
      );
    } on AiRequestException {
      rethrow;
    } catch (error) {
      throw AiRequestException(
        _connectionError(error),
      );
    }
  }

  // ============================================================
  // JSON
  // ============================================================

  static Map<String, dynamic>?
      _decodeMap(String body) {
    try {
      final decoded =
          jsonDecode(body);

      if (decoded is Map) {
        return Map<String, dynamic>.from(
          decoded,
        );
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // SERVER ERRORS
  // ============================================================

  static String _errorFromData(
    Map<String, dynamic> data, {
    required String fallback,
  }) {
    final error =
        data['error']
            ?.toString()
            .trim();

    if (error != null &&
        error.isNotEmpty) {
      return _friendlyError(error);
    }

    return fallback;
  }

  static String _serverError(
    int statusCode,
    Map<String, dynamic>? data,
  ) {
    final serverMessage =
        data?['error']
            ?.toString()
            .trim();

    if (serverMessage != null &&
        serverMessage.isNotEmpty) {
      return _friendlyError(
        serverMessage,
      );
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
        return 'الخدمة مشغولة حاليًا. حاول بعد لحظات.';

      case 500:
        return 'حصل خطأ داخل الخادم.';

      case 502:
        return 'خدمة الذكاء الاصطناعي لم ترجع ردًا صحيحًا.';

      case 503:
        return 'الخدمة غير متاحة مؤقتًا.';

      case 504:
        return 'الخدمة استغرقت وقتًا أطول من اللازم.';

      default:
        return 'حصل خطأ في الاتصال بالخادم.';
    }
  }

  // ============================================================
  // FRIENDLY ERRORS
  // ============================================================

  static String _friendlyError(
    String value,
  ) {
    final error =
        value.trim();

    switch (error) {
      case 'OPENAI_API_KEY_MISSING':
        return 'خدمة الذكاء الاصطناعي غير مُعدة حاليًا.';

      case 'EMPTY_AI_RESPONSE':
        return 'الذكاء الاصطناعي لم يرجع ردًا. جرّب تاني.';

      case 'EMPTY_MESSAGE':
        return 'لم يتم إرسال رسالة.';

      case 'INVALID_IMAGE':
        return 'الصورة المرسلة غير صالحة أو كبيرة جدًا.';

      case 'BODY_TOO_LARGE':
        return 'البيانات المرسلة كبيرة جدًا.';

      case 'NOT_FOUND':
        return 'خدمة الذكاء الاصطناعي غير موجودة حاليًا.';

      case 'NO_IMAGE_RESULT':
        return 'خدمة الصور لم ترجع نتيجة.';

      case 'IMAGE_FORMAT_NOT_SUPPORTED':
        return 'صيغة الصورة التي رجعتها الخدمة غير مدعومة.';

      default:
        if (error.isEmpty) {
          return 'حصل خطأ غير معروف.';
        }

        return error;
    }
  }

  // ============================================================
  // CONNECTION ERROR
  // ============================================================

  static String _connectionError(
    Object error,
  ) {
    final value =
        error.toString().toLowerCase();

    if (value.contains('timeout') ||
        value.contains('timed out')) {
      return 'الاتصال بالخادم استغرق وقتًا أطول من اللازم.';
    }

    if (value.contains('socket') ||
        value.contains('network') ||
        value.contains('connection')) {
      return 'تأكد من اتصال الإنترنت وحاول مرة أخرى.';
    }

    return 'تعذر الاتصال بخدمة صاحبي حاليًا.';
  }

  // ============================================================
  // MIME
  // ============================================================

  static String _mime(
    String name,
  ) {
    final lower =
        name.toLowerCase();

    if (lower.endsWith('.png')) {
      return 'image/png';
    }

    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }

    if (lower.endsWith('.gif')) {
      return 'image/gif';
    }

    if (lower.endsWith('.bmp')) {
      return 'image/bmp';
    }

    if (lower.endsWith('.heic') ||
        lower.endsWith('.heif')) {
      return 'image/heic';
    }

    return 'image/jpeg';
  }
}

/// خطأ خاص بطلبات الذكاء الاصطناعي.
class AiRequestException
    implements Exception {
  final String message;
  final int? statusCode;

  const AiRequestException(
    this.message, {
    this.statusCode,
  });

  @override
  String toString() =>
      'AiRequestException: $message';
}
