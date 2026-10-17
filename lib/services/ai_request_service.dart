import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import 'sa7bi_network_client.dart';

/// نقطة الاتصال الموحدة بخدمات الذكاء الاصطناعي.
class AiRequestService {
  AiRequestService._();

  static const String base = AppConfig.backendBaseUrl;
  static const String chatEndpoint = AppConfig.aiChatEndpoint;
  static const String imageEndpoint = AppConfig.imageGenerationEndpoint;
  static const String creditsEndpoint = '$base/v1/credits';

  static const String deviceIdHeader = 'X-Sa7bi-Device-Id';
  static const String requestIdHeader = 'X-Sa7bi-Request-Id';
  static const String _deviceIdStorageKey = 'sa7bi_ai_device_id';

  static Future<String>? _deviceIdFuture;

  static const int maxHistory = AppConfig.maximumContextMessages;
  static const int maxImageBytes =
      AppConfig.maximumImageSizeMb * 1024 * 1024;
  static const int maxVideoFrames = AppConfig.maximumVideoFrames;
  static const int maxVideoTotalBytes = 5 * 1024 * 1024;
  static const int maxImageGenerationTotalBytes = 6 * 1024 * 1024;
  static const int maxImageGenerationImages = 4;

  static const Duration connectionTimeout =
      Duration(seconds: AppConfig.networkTimeoutSeconds);

  // مهلة أطول للشبكات البطيئة دون إعادة إرسال طلب AI تلقائيًا.
  static const Duration chatTimeout = Duration(seconds: 150);
  static const Duration imageTimeout = Duration(seconds: 240);

  static Future<String> getDeviceId() async {
    final existingFuture = _deviceIdFuture;
    if (existingFuture != null) return existingFuture;

    final future = _loadOrCreateDeviceId();
    _deviceIdFuture = future;

    try {
      return await future;
    } catch (_) {
      _deviceIdFuture = null;
      rethrow;
    }
  }

  static Future<String> _loadOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdStorageKey);

    if (existing != null && existing.trim().isNotEmpty) {
      return existing.trim();
    }

    final generated = _generateId(prefix: 'sa7bi_device');
    await prefs.setString(_deviceIdStorageKey, generated);
    return generated;
  }

  static String _generateId({required String prefix}) {
    final random = Random.secure();
    final timestamp = DateTime.now()
        .toUtc()
        .microsecondsSinceEpoch
        .toRadixString(16);

    final randomPart = List<String>.generate(
      5,
      (_) => random
          .nextInt(0x1000000)
          .toRadixString(16)
          .padLeft(6, '0'),
    ).join();

    return '$prefix-$timestamp-$randomPart';
  }

  static String _newRequestId() =>
      _generateId(prefix: 'sa7bi_request');

  static Future<BackendConnectionResult> checkBackend() async {
    try {
      final response = await Sa7biNetworkClient.client
          .get(
            Uri.parse(AppConfig.backendHealthEndpoint),
            headers: const {
              'Cache-Control': 'no-cache',
              'Pragma': 'no-cache',
            },
          )
          .timeout(connectionTimeout);

      final data = _decodeMap(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return BackendConnectionResult.failure(
          'الخادم رجع حالة HTTP ${response.statusCode}.',
          statusCode: response.statusCode,
        );
      }

      if (data == null) {
        return const BackendConnectionResult.failure(
          'الخادم رجع ردًا غير مفهوم.',
        );
      }

      if (data['ok'] != true) {
        return BackendConnectionResult.failure(
          data['error']?.toString() ?? 'الخادم غير جاهز حاليًا.',
          statusCode: response.statusCode,
        );
      }

      return BackendConnectionResult.success(
        version: data['backendVersion']?.toString(),
        statusCode: response.statusCode,
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
      return BackendConnectionResult.failure(_connectionError(error));
    }
  }

  static Future<ServerCreditsResult> getCredits() async {
    final deviceId = await getDeviceId();

    try {
      final response = await Sa7biNetworkClient.client
          .get(
            Uri.parse(creditsEndpoint),
            headers: {
              'Accept': 'application/json',
              'Cache-Control': 'no-cache',
              'Pragma': 'no-cache',
              deviceIdHeader: deviceId,
            },
          )
          .timeout(connectionTimeout);

      final data = _decodeMap(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AiRequestException(
          _serverError(response.statusCode, data),
          statusCode: response.statusCode,
        );
      }

      if (data == null) {
        throw const AiRequestException(
          'رد خدمة الرصيد غير مفهوم.',
        );
      }

      if (data['ok'] != true) {
        throw AiRequestException(
          _errorFromData(
            data,
            fallback: 'تعذر قراءة رصيد صاحبي حاليًا.',
          ),
          statusCode: response.statusCode,
        );
      }

      return ServerCreditsResult.fromMap(
        _extractCreditMap(data),
        deviceId: deviceId,
      );
    } on AiRequestException {
      rethrow;
    } on TimeoutException {
      throw const AiRequestException(
        'الاتصال بخدمة الرصيد استغرق وقتًا أطول من اللازم.',
      );
    } on http.ClientException catch (error) {
      throw AiRequestException(
        'تعذر الاتصال بخدمة الرصيد: ${error.message}',
      );
    } catch (error) {
      throw AiRequestException(_connectionError(error));
    }
  }

  static Map<String, dynamic> _extractCreditMap(
    Map<String, dynamic> data,
  ) {
    final direct = data['credits'];
    if (direct is Map) {
      return Map<String, dynamic>.from(direct);
    }
    return data;
  }

  static Future<String> getResponse({
    required String prompt,
    String? serviceContext,
    String? serviceTitle,
    List<Map<String, String>> history = const [],
  }) async {
    final text = prompt.trim();

    if (text.isEmpty) return 'قول لي يا صاحبي 😊';

    if (text.length > AppConfig.maximumMessageCharacters) {
      throw const AiRequestException(
        'الرسالة طويلة جدًا. حاول تقسيمها إلى أكثر من رسالة.',
      );
    }

    final validHistory = history.where(
      (item) =>
          (item['role'] == 'user' ||
              item['role'] == 'assistant') &&
          (item['content'] ?? '').trim().isNotEmpty,
    ).toList();

    final start = validHistory.length > maxHistory
        ? validHistory.length - maxHistory
        : 0;

    final messages = <Map<String, String>>[];

    for (final item in validHistory.sublist(start)) {
      final role = item['role'];
      final content = item['content']?.trim();

      if (role == null || content == null || content.isEmpty) {
        continue;
      }

      messages.add({'role': role, 'content': content});
    }

    messages.add({'role': 'user', 'content': text});

    final body = <String, dynamic>{'messages': messages};
    _addServiceData(
      body,
      serviceTitle: serviceTitle,
      serviceContext: serviceContext,
    );

    final response = await _post(
      chatEndpoint,
      body: body,
      timeout: chatTimeout,
    );

    return _readAnswer(response);
  }

  static Future<String> analyzeImage({
    required XFile file,
    String prompt =
        'حلل الصورة المرسلة بدقة وباختصار، واذكر الأشياء المهمة الظاهرة فيها.',
    String? serviceContext,
    String? serviceTitle,
  }) async {
    final bytes = await file.readAsBytes();

    if (bytes.isEmpty) {
      throw const AiRequestException('الصورة لم يتم قراءتها.');
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

  static Future<String> analyzeImageBytes(
    Uint8List bytes, {
    String prompt = 'حلل الصورة المرسلة بدقة وباختصار.',
    String? serviceContext,
    String? serviceTitle,
  }) async {
    if (bytes.isEmpty) {
      throw const AiRequestException('الصورة فارغة.');
    }

    if (bytes.length > maxImageBytes) {
      throw const AiRequestException('الصورة كبيرة جدًا.');
    }

    return analyzeImages(
      <Uint8List>[bytes],
      prompt: prompt,
      serviceContext: serviceContext,
      serviceTitle: serviceTitle,
    );
  }

  static Future<String> analyzeImages(
    List<Uint8List> images, {
    String prompt =
        'حلل الصور المرفقة معًا بدقة. اشرح ما يظهر فيها، واذكر أي نصوص أو أشخاص أو أدوات أو أشياء مهمة. لا تخمن ما لا يظهر بوضوح.',
    String? serviceContext,
    String? serviceTitle,
  }) async {
    return _analyzeImageCollection(
      images,
      prompt: prompt,
      serviceContext: serviceContext,
      serviceTitle: serviceTitle,
      isVideoAnalysis: false,
    );
  }

  static Future<String> analyzeVideoFrames(
    List<Uint8List> frames, {
    String prompt =
        'هذه لقطات مستخرجة من فيديو أرسله المستخدم. حلل اللقطات معًا وحاول فهم تسلسل ما يحدث بينها. اذكر الأشياء والأشخاص والأدوات والنصوص الظاهرة. إذا كانت معلومة غير واضحة، صرّح بذلك ولا تخمن.',
    String? serviceContext,
    String? serviceTitle,
  }) async {
    return _analyzeImageCollection(
      frames,
      prompt: prompt,
      serviceContext: serviceContext,
      serviceTitle: serviceTitle,
      isVideoAnalysis: true,
    );
  }

  static Future<String> _analyzeImageCollection(
    List<Uint8List> images, {
    required String prompt,
    required String? serviceContext,
    required String? serviceTitle,
    required bool isVideoAnalysis,
  }) async {
    if (images.isEmpty) {
      throw AiRequestException(
        isVideoAnalysis
            ? 'لم يتم استخراج أي صورة للتحليل.'
            : 'لم يتم إرسال أي صورة للتحليل.',
      );
    }

    final selected = images
        .where((image) => image.isNotEmpty)
        .take(maxVideoFrames)
        .toList();

    if (selected.isEmpty) {
      throw const AiRequestException(
        'لم نستطع تجهيز الصور للتحليل.',
      );
    }

    var totalBytes = 0;
    for (final image in selected) {
      if (image.length > maxImageBytes) {
        throw const AiRequestException('إحدى الصور كبيرة جدًا.');
      }

      totalBytes += image.length;
      if (totalBytes > maxVideoTotalBytes) {
        throw const AiRequestException(
          'حجم البيانات المرسلة كبير جدًا. حاول إرسال صور أقل أو فيديو أقصر.',
        );
      }
    }

    final imageDataUrls = <String>[];
    for (final image in selected) {
      imageDataUrls.add(
        'data:image/jpeg;base64,${base64Encode(image)}',
      );
    }

    var finalPrompt = prompt.trim();
    if (finalPrompt.isEmpty) {
      finalPrompt = isVideoAnalysis
          ? 'حلل لقطات الفيديو المرفقة بدقة.'
          : 'حلل
