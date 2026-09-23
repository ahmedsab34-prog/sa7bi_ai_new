import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

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

  static const int maxVideoFrames = 4;

  static const int maxVideoTotalBytes =
      5 * 1024 * 1024;

  static const int maxAttempts = 3;

  // ============================================================
  // TEXT
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

    final response =
        await _postWithRetry(
      chatEndpoint,
      body: body,
      timeout: chatTimeout,
    );

    return _readAnswer(response);
  }

  // ============================================================
  // IMAGE
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

    return analyzeImageBytes(
      bytes,
      prompt: prompt,
      serviceContext:
          serviceContext,
      serviceTitle:
          serviceTitle,
    );
  }

  static Future<String> analyzeImageBytes(
    Uint8List bytes, {
    String prompt =
        'حلل الصورة المرسلة بدقة وباختصار.',
    String? serviceContext,
    String? serviceTitle,
  }) async {
    if (bytes.isEmpty) {
      throw const AiRequestException(
        'الصورة فارغة.',
      );
    }

    if (bytes.length >
        maxImageBytes) {
      throw const AiRequestException(
        'الصورة كبيرة جدًا.',
      );
    }

    return analyzeImages(
      [bytes],
      prompt: prompt,
      serviceContext:
          serviceContext,
      serviceTitle:
          serviceTitle,
    );
  }

  // ============================================================
  // MULTI IMAGE / VIDEO FRAMES
  // ============================================================

  static Future<String> analyzeImages(
    List<Uint8List> images, {
    String prompt =
        'حلل الصور المرفقة معًا باعتبارها لقطات من نفس الفيديو. '
        'اشرح ما يظهر فيها، وما الذي يحدث عبر اللقطات، '
        'واذكر أي نصوص أو أدوات أو أشخاص أو أشياء مهمة. '
        'لا تخمن ما لا يظهر بوضوح.',
    String? serviceContext,
    String? serviceTitle,
  }) async {
    if (images.isEmpty) {
      throw const AiRequestException(
        'لم يتم استخراج أي صورة للتحليل.',
      );
    }

    final selected =
        images.take(maxVideoFrames).toList();

    int totalBytes = 0;

    for (final image in selected) {
      if (image.isEmpty) {
        continue;
      }

      totalBytes += image.length;
    }

    if (totalBytes >
        maxVideoTotalBytes) {
      throw const AiRequestException(
        'حجم لقطات الفيديو كبير جدًا. حاول إرسال فيديو أقصر أو بجودة أقل.',
      );
    }

    final imageDataUrls =
        <String>[];

    for (final image in selected) {
      if (image.isEmpty) {
        continue;
      }

      imageDataUrls.add(
        'data:image/jpeg;base64,'
        '${base64Encode(image)}',
      );
    }

    if (imageDataUrls.isEmpty) {
      throw const AiRequestException(
        'لم نستطع تجهيز لقطات الفيديو للتحليل.',
      );
    }

    var finalPrompt =
        prompt.trim();

    if (serviceContext != null &&
        serviceContext.trim().isNotEmpty) {
      finalPrompt =
          'سياق الخدمة:\n'
          '${serviceContext.trim()}\n\n'
          'تعليمات التحليل:\n'
          '$finalPrompt';
    }

    final body =
        <String, dynamic>{
      'messages': [
        {
          'role': 'user',
          'content': finalPrompt,
        },
      ],
      'imageDataUrls':
          imageDataUrls,
    };

    final cleanTitle =
        serviceTitle?.trim();

    if (cleanTitle != null &&
        cleanTitle.isNotEmpty) {
      body['serviceTitle'] =
          cleanTitle;
    }

    final response =
        await _postWithRetry(
      chatEndpoint,
      body: body,
      timeout: imageTimeout,
    );

    return _readAnswer(response);
  }

  // ============================================================
  // RESPONSE
  // ============================================================

  static String _readAnswer(
    http.Response response,
  ) {
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
        'الذكاء الاصطناعي لم يرجع نتيجة.',
      );
    }

    return answer;
  }

  // ============================================================
  // HTTP RETRY
  // ============================================================

  static Future<http.Response>
      _postWithRetry(
    String endpoint, {
    required Map<String, dynamic> body,
    required Duration timeout,
  }) async {
    Object? lastError;

    for (
      int attempt = 1;
      attempt <= maxAttempts;
      attempt++
    ) {
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
  // POST
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
  // ERRORS
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
      case 'INVALID_IMAGES':
        return 'الصورة أو الصور المرسلة غير صالحة أو كبيرة جدًا.';

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
}

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
