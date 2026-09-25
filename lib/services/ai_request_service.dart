import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../config/app_config.dart';

/// نقطة الاتصال الموحدة بخدمات الذكاء الاصطناعي.
///
/// المسار:
///
/// Flutter App
///      ↓
/// Cloudflare Worker
///      ↓
/// OpenAI
///
/// مهم جدًا:
/// لا يوجد أي OpenAI API Key داخل التطبيق.
class AiRequestService {
  AiRequestService._();

  // ============================================================
  // BACKEND
  // ============================================================

  static const String base =
      AppConfig.backendBaseUrl;

  static const String chatEndpoint =
      AppConfig.aiChatEndpoint;

  static const String imageEndpoint =
      AppConfig.imageGenerationEndpoint;

  // ============================================================
  // LIMITS
  // ============================================================

  static const int maxHistory =
      AppConfig.maximumContextMessages;

  static const int maxAttempts =
      AppConfig.maximumNetworkAttempts;

  static const int maxImageBytes =
      AppConfig.maximumImageSizeMb * 1024 * 1024;

  static const int maxVideoFrames =
      AppConfig.maximumVideoFrames;

  static const int maxVideoTotalBytes =
      5 * 1024 * 1024;

  static const Duration connectionTimeout =
      Duration(
    seconds: AppConfig.networkTimeoutSeconds,
  );

  static const Duration chatTimeout =
      Duration(
    seconds: AppConfig.chatTimeoutSeconds,
  );

  static const Duration imageTimeout =
      Duration(
    seconds: AppConfig.imageTimeoutSeconds,
  );

  // ============================================================
  // BACKEND CONNECTION
  // ============================================================

  /// فحص اتصال التطبيق بالـWorker.
  ///
  /// لا يتم إرسال أي API Key من الهاتف.
  static Future<BackendConnectionResult>
      checkBackend() async {
    try {
      final response = await http
          .get(
            Uri.parse(base),
            headers: const {
              'Cache-Control': 'no-cache',
              'Pragma': 'no-cache',
            },
          )
          .timeout(connectionTimeout);

      final data =
          _decodeMap(response.body);

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        return BackendConnectionResult.failure(
          'الخادم رجع حالة HTTP ${response.statusCode}.',
        );
      }

      if (data == null) {
        return const BackendConnectionResult.failure(
          'الخادم رجع ردًا غير مفهوم.',
        );
      }

      if (data['ok'] != true) {
        return BackendConnectionResult.failure(
          data['error']?.toString() ??
              'الخادم غير جاهز حاليًا.',
        );
      }

      return BackendConnectionResult.success(
        version:
            data['backendVersion']?.toString(),
      );
    } on TimeoutException {
      return const BackendConnectionResult.failure(
        'الاتصال بخادم صاحبي استغرق وقتًا أطول من اللازم.',
      );
    } on http.ClientException catch (error) {
      return BackendConnectionResult.failure(
        'تعذر الاتصال بخادم صاحبي: ${error.message}',
      );
    } catch (error) {
      return BackendConnectionResult.failure(
        _connectionError(error),
      );
    }
  }

  // ============================================================
  // TEXT CHAT
  // ============================================================

  /// إرسال رسالة نصية إلى صاحبي AI.
  static Future<String> getResponse({
    required String prompt,
    String? serviceContext,
    String? serviceTitle,
    List<Map<String, String>> history =
        const [],
  }) async {
    final text =
        prompt.trim();

    if (text.isEmpty) {
      return 'قول لي يا صاحبي 😊';
    }

    if (text.length >
        AppConfig.maximumMessageCharacters) {
      throw const AiRequestException(
        'الرسالة طويلة جدًا. حاول تقسيمها إلى أكثر من رسالة.',
      );
    }

    final backend =
        await checkBackend();

    if (!backend.isAvailable) {
      throw AiRequestException(
        backend.error ??
            'خدمة صاحبي غير متاحة حاليًا.',
      );
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
      final role =
          item['role'];

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

    _addServiceData(
      body,
      serviceTitle: serviceTitle,
      serviceContext: serviceContext,
    );

    final response =
        await _postWithRetry(
      chatEndpoint,
      body: body,
      timeout: chatTimeout,
    );

    return _readAnswer(response);
  }

  // ============================================================
  // IMAGE - XFILE
  // ============================================================

  static Future<String> analyzeImage({
    required XFile file,
    String prompt =
        'حلل الصورة المرسلة بدقة وباختصار، '
        'واذكر الأشياء المهمة الظاهرة فيها.',
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

    if (bytes.length > maxImageBytes) {
      throw const AiRequestException(
        'الصورة كبيرة جدًا. ابعت صورة أصغر من 5 ميجابايت.',
      );
    }

    return analyzeImageBytes(
      bytes,
      prompt: prompt,
      serviceContext: serviceContext,
      serviceTitle: serviceTitle,
    );
  }

  // ============================================================
  // IMAGE - BYTES
  // ============================================================

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

    if (bytes.length > maxImageBytes) {
      throw const AiRequestException(
        'الصورة كبيرة جدًا.',
      );
    }

    return analyzeImages(
      <Uint8List>[bytes],
      prompt: prompt,
      serviceContext: serviceContext,
      serviceTitle: serviceTitle,
    );
  }

  // ============================================================
  // MULTI IMAGE / VIDEO FRAMES
  // ============================================================

  static Future<String> analyzeImages(
    List<Uint8List> images, {
    String prompt =
        'حلل الصور المرفقة معًا باعتبارها لقطات '
        'من نفس الفيديو. اشرح ما يظهر فيها، '
        'وما الذي يحدث عبر اللقطات، واذكر أي '
        'نصوص أو أدوات أو أشخاص أو أشياء مهمة. '
        'لا تخمن ما لا يظهر بوضوح.',
    String? serviceContext,
    String? serviceTitle,
  }) async {
    if (images.isEmpty) {
      throw const AiRequestException(
        'لم يتم استخراج أي صورة للتحليل.',
      );
    }

    final selected = images
        .where(
          (image) => image.isNotEmpty,
        )
        .take(maxVideoFrames)
        .toList();

    if (selected.isEmpty) {
      throw const AiRequestException(
        'لم نستطع تجهيز الصور للتحليل.',
      );
    }

    var totalBytes = 0;

    for (final image in selected) {
      totalBytes += image.length;

      if (totalBytes >
          maxVideoTotalBytes) {
        throw const AiRequestException(
          'حجم لقطات الفيديو كبير جدًا. '
          'حاول إرسال فيديو أقصر أو بجودة أقل.',
        );
      }
    }

    final imageDataUrls =
        <String>[];

    for (final image in selected) {
      imageDataUrls.add(
        'data:image/jpeg;base64,'
        '${base64Encode(image)}',
      );
    }

    if (imageDataUrls.isEmpty) {
      throw const AiRequestException(
        'لم نستطع تجهيز الصور للتحليل.',
      );
    }

    var finalPrompt =
        prompt.trim();

    if (finalPrompt.isEmpty) {
      finalPrompt =
          'حلل الصور المرفقة بدقة.';
    }

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

    _addServiceData(
      body,
      serviceTitle: serviceTitle,
      serviceContext: null,
    );

    final backend =
        await checkBackend();

    if (!backend.isAvailable) {
      throw AiRequestException(
        backend.error ??
            'خدمة تحليل الصور غير متاحة حاليًا.',
      );
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
  // IMAGE GENERATION
  // ============================================================

  /// يطلب إنشاء صورة من الـWorker.
  ///
  /// النتيجة تكون Data URL أو رابط صورة.
  static Future<String>
      generateImage({
    required String prompt,
    String? serviceContext,
    String? serviceTitle,
  }) async {
    final cleanPrompt =
        prompt.trim();

    if (cleanPrompt.isEmpty) {
      throw const AiRequestException(
        'اكتب وصف الصورة أولًا.',
      );
    }

    if (cleanPrompt.length > 6000) {
      throw const AiRequestException(
        'وصف الصورة طويل جدًا.',
      );
    }

    final backend =
        await checkBackend();

    if (!backend.isAvailable) {
      throw AiRequestException(
        backend.error ??
            'خدمة صاحبي غير متاحة حاليًا.',
      );
    }

    final body =
        <String, dynamic>{
      'prompt': cleanPrompt,
    };

    _addServiceData(
      body,
      serviceTitle: serviceTitle,
      serviceContext: serviceContext,
    );

    final response =
        await _postWithRetry(
      imageEndpoint,
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
        'رد خدمة إنشاء الصور غير مفهوم.',
      );
    }

    if (data['ok'] != true) {
      throw AiRequestException(
        _errorFromData(
          data,
          fallback:
              'تعذر إنشاء الصورة حاليًا.',
        ),
        statusCode:
            response.statusCode,
      );
    }

    final imageDataUrl =
        data['imageDataUrl']
            ?.toString()
            .trim();

    if (imageDataUrl != null &&
        imageDataUrl.isNotEmpty) {
      return imageDataUrl;
    }

    final imageUrl =
        data['imageUrl']
            ?.toString()
            .trim();

    if (imageUrl != null &&
        imageUrl.isNotEmpty) {
      return imageUrl;
    }

    throw const AiRequestException(
      'خدمة الصور لم ترجع صورة.',
    );
  }

  // ============================================================
  // SERVICE CONTEXT
  // ============================================================

  static void _addServiceData(
    Map<String, dynamic> body, {
    String? serviceTitle,
    String? serviceContext,
  }) {
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
        'رد خادم الذكاء الاصطناعي غير مفهوم.',
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
      var attempt = 1;
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
          if (error
              is AiRequestException) {
            rethrow;
          }

          throw AiRequestException(
            _connectionError(error),
          );
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
    } on http.ClientException catch (error) {
      throw AiRequestException(
        'تعذر الاتصال بالخادم: ${error.message}',
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
  // ERROR HELPERS
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

      case 'OPENAI_REQUEST_FAILED':
        return 'خدمة الذكاء الاصطناعي لم تستطع تنفيذ الطلب حاليًا.';

      case 'OPENAI_EMPTY_RESPONSE':
      case 'EMPTY_AI_RESPONSE':
        return 'الذكاء الاصطناعي لم يرجع ردًا. جرّب تاني.';

      case 'EMPTY_MESSAGE':
        return 'لم يتم إرسال رسالة.';

      case 'INVALID_IMAGE':
      case 'INVALID_IMAGES':
        return 'الصورة أو الصور المرسلة غير صالحة أو كبيرة جدًا.';

      case 'BODY_TOO_LARGE':
        return 'البيانات المرسلة كبيرة جدًا.';

      case 'INVALID_JSON':
        return 'البيانات المرسلة غير صحيحة.';

      case 'NOT_FOUND':
        return 'خدمة الذكاء الاصطناعي غير موجودة حاليًا.';

      case 'NO_IMAGE_RESULT':
        return 'خدمة الصور لم ترجع نتيجة.';

      case 'IMAGE_FORMAT_NOT_SUPPORTED':
        return 'صيغة الصورة التي رجعتها الخدمة غير مدعومة.';

      case 'EMPTY_PROMPT':
        return 'اكتب وصف الصورة أولًا.';

      case 'IMAGE_GENERATION_FAILED':
        return 'تعذر إنشاء الصورة حاليًا.';

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

// ============================================================
// BACKEND CONNECTION RESULT
// ============================================================

class BackendConnectionResult {
  final bool isAvailable;
  final String? error;
  final String? version;

  const BackendConnectionResult._({
    required this.isAvailable,
    this.error,
    this.version,
  });

  const BackendConnectionResult.success({
    String? version,
  }) : this._(
          isAvailable: true,
          version: version,
        );

  const BackendConnectionResult.failure(
    String error,
  ) : this._(
          isAvailable: false,
          error: error,
        );
}

// ============================================================
// EXCEPTION
// ============================================================

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
