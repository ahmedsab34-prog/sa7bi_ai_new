import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

/// نقطة الاتصال الموحدة بخدمات الذكاء الاصطناعي.
///
/// المسار:
///
/// Flutter App
///      ↓
/// Cloudflare Worker
///      ↓
/// Gemini
///      ↓
/// Workers AI كـFallback
///
/// مهم جدًا:
/// - لا يوجد أي API Key داخل التطبيق.
/// - Device ID ثابت لكل تثبيت.
/// - Request ID مختلف لكل طلب.
/// - الـBackend هو مصدر السلطة للـCredits.
/// - التطبيق لا يقرر وحده السماح النهائي بالطلب.
class AiRequestService {
  AiRequestService._();

  // ============================================================
  // BACKEND
  // ============================================================

  static const String base = AppConfig.backendBaseUrl;

  static const String chatEndpoint =
      AppConfig.aiChatEndpoint;

  static const String imageEndpoint =
      AppConfig.imageGenerationEndpoint;

  static const String creditsEndpoint =
      '$base/v1/credits';

  // ============================================================
  // CREDIT HEADERS
  // ============================================================

  static const String deviceIdHeader =
      'X-Sa7bi-Device-Id';

  static const String requestIdHeader =
      'X-Sa7bi-Request-Id';

  static const String _deviceIdStorageKey =
      'sa7bi_ai_device_id';

  static Future<String>? _deviceIdFuture;

  // ============================================================
  // LIMITS
  // ============================================================

  static const int maxHistory =
      AppConfig.maximumContextMessages;

  /// أقصى حجم للصورة الواحدة.
  static const int maxImageBytes =
      AppConfig.maximumImageSizeMb * 1024 * 1024;

  /// أقصى عدد Frames أو صور في طلب التحليل.
  static const int maxVideoFrames =
      AppConfig.maximumVideoFrames;

  /// أقصى حجم إجمالي لبيانات تحليل الصور/الفيديو.
  ///
  /// تم إبقاؤه أقل من حد جسم طلب الـWorker حتى يكون هناك
  /// مساحة كافية لـBase64 والـJSON وباقي بيانات الطلب.
  static const int maxVideoTotalBytes =
      5 * 1024 * 1024;

  /// أقصى حجم إجمالي للصور المرسلة إلى توليد/تعديل الصور.
  ///
  /// السبب:
  /// صورة 5MB تتحول إلى Base64 بحجم أكبر من حجمها الأصلي،
  /// وإرسال 4 صور × 5MB قد يتجاوز حد جسم طلب الـWorker.
  ///
  /// لذلك نضع حدًا إجماليًا آمنًا للصور الداخلة في طلب الصورة.
  static const int maxImageGenerationTotalBytes =
      6 * 1024 * 1024;

  /// أقصى عدد صور يمكن إرفاقها بتوليد/تعديل الصورة.
  static const int maxImageGenerationImages = 4;

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
  // DEVICE ID
  // ============================================================

  /// يرجع Device ID ثابتًا لهذا التثبيت.
  ///
  /// لا نستخدم Android hardware ID أو أي معلومة حساسة.
  static Future<String> getDeviceId() async {
    final existingFuture = _deviceIdFuture;

    if (existingFuture != null) {
      return existingFuture;
    }

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
    final prefs =
        await SharedPreferences.getInstance();

    final existing =
        prefs.getString(
      _deviceIdStorageKey,
    );

    if (existing != null &&
        existing.trim().isNotEmpty) {
      return existing.trim();
    }

    final generated = _generateId(
      prefix: 'sa7bi_device',
    );

    await prefs.setString(
      _deviceIdStorageKey,
      generated,
    );

    return generated;
  }

  /// ينشئ معرفًا عشوائيًا بدون Package إضافية.
  static String _generateId({
    required String prefix,
  }) {
    final random = Random.secure();

    final timestamp =
        DateTime.now()
            .toUtc()
            .microsecondsSinceEpoch
            .toRadixString(16);

    final randomPart =
        List<String>.generate(
      5,
      (_) => random
          .nextInt(0x1000000)
          .toRadixString(16)
          .padLeft(6, '0'),
    ).join();

    return '$prefix-$timestamp-$randomPart';
  }

  /// Request ID جديد لكل طلب AI.
  static String _newRequestId() {
    return _generateId(
      prefix: 'sa7bi_request',
    );
  }

  // ============================================================
  // BACKEND CONNECTION
  // ============================================================

  /// فحص اتصال التطبيق بالـWorker.
  static Future<BackendConnectionResult>
      checkBackend() async {
    try {
      final response =
          await http
              .get(
                Uri.parse(base),
                headers: const {
                  'Cache-Control': 'no-cache',
                  'Pragma': 'no-cache',
                },
              )
              .timeout(
                connectionTimeout,
              );

      final data = _decodeMap(
        response.body,
      );

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        return BackendConnectionResult.failure(
          'الخادم رجع حالة HTTP '
          '${response.statusCode}.',
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
          data['error']?.toString() ??
              'الخادم غير جاهز حاليًا.',
          statusCode: response.statusCode,
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
        'تعذر الاتصال بخادم صاحبي: '
        '${error.message}',
      );
    } catch (error) {
      return BackendConnectionResult.failure(
        _connectionError(error),
      );
    }
  }

  // ============================================================
  // SERVER CREDITS
  // ============================================================

  /// قراءة الرصيد الحقيقي من الـBackend.
  static Future<ServerCreditsResult>
      getCredits() async {
    final deviceId = await getDeviceId();

    try {
      final response =
          await http
              .get(
                Uri.parse(creditsEndpoint),
                headers: {
                  'Accept': 'application/json',
                  'Cache-Control': 'no-cache',
                  'Pragma': 'no-cache',
                  deviceIdHeader: deviceId,
                },
              )
              .timeout(
                connectionTimeout,
              );

      final data = _decodeMap(
        response.body,
      );

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
          'رد خدمة الرصيد غير مفهوم.',
        );
      }

      if (data['ok'] != true) {
        throw AiRequestException(
          _errorFromData(
            data,
            fallback:
                'تعذر قراءة رصيد صاحبي حاليًا.',
          ),
          statusCode: response.statusCode,
        );
      }

      final credits =
          _extractCreditMap(data);

      return ServerCreditsResult.fromMap(
        credits,
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
        'تعذر الاتصال بخدمة الرصيد: '
        '${error.message}',
      );
    } catch (error) {
      throw AiRequestException(
        _connectionError(error),
      );
    }
  }

  static Map<String, dynamic> _extractCreditMap(
    Map<String, dynamic> data,
  ) {
    final direct = data['credits'];

    if (direct is Map) {
      return Map<String, dynamic>.from(
        direct,
      );
    }

    return data;
  }

  // ============================================================
  // TEXT CHAT
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

    if (text.length >
        AppConfig.maximumMessageCharacters) {
      throw const AiRequestException(
        'الرسالة طويلة جدًا. حاول تقسيمها إلى أكثر من رسالة.',
      );
    }

    final validHistory =
        history.where(
      (item) =>
          (item['role'] == 'user' ||
              item['role'] == 'assistant') &&
          (item['content'] ?? '').trim().isNotEmpty,
    ).toList();

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
    final bytes = await file.readAsBytes();

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
  // MULTI IMAGE
  // ============================================================

  /// تحليل صورة واحدة أو عدة صور عادية.
  ///
  /// هذه العملية تُحسب Server-side كـ:
  ///
  /// image_analysis = 3 Credits
  ///
  /// إذا كان المحتوى فيديو، استخدم:
  /// analyzeVideoFrames()
  ///
  /// حتى يتم إرسال videoAnalysis=true للـBackend.
  static Future<String> analyzeImages(
    List<Uint8List> images, {
    String prompt =
        'حلل الصور المرفقة معًا بدقة. '
        'اشرح ما يظهر فيها، واذكر أي نصوص أو '
        'أشخاص أو أدوات أو أشياء مهمة. '
        'لا تخمن ما لا يظهر بوضوح.',
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

  // ============================================================
  // VIDEO FRAMES
  // ============================================================

  /// تحليل Frames مستخرجة من فيديو.
  ///
  /// هذه العملية تُحسب Server-side كـ:
  ///
  /// video_analysis = 5 Credits
  ///
  /// الفرق عن analyzeImages() هو إرسال:
  ///
  /// videoAnalysis: true
  ///
  /// والـBackend يعطي أولوية لهذا العلم قبل imageDataUrls.
  static Future<String> analyzeVideoFrames(
    List<Uint8List> frames, {
    String prompt =
        'هذه لقطات مستخرجة من فيديو أرسله المستخدم. '
        'حلل اللقطات معًا وحاول فهم تسلسل ما يحدث بينها. '
        'اذكر الأشياء والأشخاص والأدوات والنصوص الظاهرة. '
        'إذا كان المستخدم يحتاج معرفة شيء عملي، قدم له تفسيرًا مفيدًا. '
        'لا تقل إنك شاهدت كل ثانية من الفيديو، لأن التحليل مبني '
        'على اللقطات المستخرجة فقط. '
        'إذا كانت معلومة غير واضحة، صرّح بذلك ولا تخمن.',
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

  // ============================================================
  // SHARED IMAGE / VIDEO ANALYSIS
  // ============================================================

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
      if (image.length > maxImageBytes) {
        throw const AiRequestException(
          'إحدى الصور كبيرة جدًا.',
        );
      }

      totalBytes += image.length;

      if (totalBytes > maxVideoTotalBytes) {
        throw const AiRequestException(
          'حجم البيانات المرسلة كبير جدًا. حاول إرسال صور أقل أو فيديو أقصر.',
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

    var finalPrompt = prompt.trim();

    if (finalPrompt.isEmpty) {
      finalPrompt = isVideoAnalysis
          ? 'حلل لقطات الفيديو المرفقة بدقة.'
          : 'حلل الصور المرفقة بدقة.';
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
      'imageDataUrls': imageDataUrls,
    };

    // مهم جدًا:
    // الـBackend يميز الفيديو عن الصور من هذا العلم.
    //
    // لا نرسل videoAnalysis مع الصور العادية،
    // حتى تظل الصورة = image_analysis.
    if (isVideoAnalysis) {
      body['videoAnalysis'] = true;
    }

    _addServiceData(
      body,
      serviceTitle: serviceTitle,
      serviceContext: null,
    );

    final response = await _post(
      chatEndpoint,
      body: body,
      timeout: imageTimeout,
    );

    return _readAnswer(response);
  }

  // ============================================================
  // IMAGE GENERATION / EDITING
  // ============================================================

  /// إنشاء صورة أو تعديل صورة.
  ///
  /// نوع العملية يحدده الـBackend:
  ///
  /// بدون imageDataUrls:
  /// image_generation
  ///
  /// مع imageDataUrls:
  /// image_edit
  static Future<String> generateImage({
    required String prompt,
    String? serviceContext,
    String? serviceTitle,
    List<Uint8List> images = const [],
    String aspectRatio = '1:1',
    String imageSize = '1K',
  }) async {
    final cleanPrompt = prompt.trim();

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

    final body =
        <String, dynamic>{
      'prompt': cleanPrompt,
      'aspectRatio': aspectRatio,
      'imageSize': imageSize,
    };

    final imageDataUrls =
        <String>[];

    var totalImageBytes = 0;

    for (final image
        in images
            .where(
              (item) => item.isNotEmpty,
            )
            .take(maxImageGenerationImages)) {
      if (image.length > maxImageBytes) {
        throw const AiRequestException(
          'إحدى الصور كبيرة جدًا. الحد الأقصى للصورة الواحدة هو 5 ميجابايت.',
        );
      }

      totalImageBytes += image.length;

      if (totalImageBytes >
          maxImageGenerationTotalBytes) {
        throw const AiRequestException(
          'إجمالي حجم الصور كبير جدًا. حاول استخدام صور أقل أو صورًا بحجم أصغر.',
        );
      }

      imageDataUrls.add(
        'data:image/jpeg;base64,'
        '${base64Encode(image)}',
      );
    }

    if (imageDataUrls.isNotEmpty) {
      body['imageDataUrls'] =
          imageDataUrls;
    }

    _addServiceData(
      body,
      serviceTitle: serviceTitle,
      serviceContext: serviceContext,
    );

    final response = await _post(
      imageEndpoint,
      body: body,
      timeout: imageTimeout,
    );

    final data = _decodeMap(
      response.body,
    );

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
        statusCode: response.statusCode,
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
        statusCode: response.statusCode,
      );
    }

    if (data == null) {
      throw AiRequestException(
        'رد خادم الذكاء الاصطناعي غير مفهوم '
        '(HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    if (data['ok'] != true) {
      throw AiRequestException(
        _errorFromData(
          data,
          fallback:
              'صاحبي مش قادر يرد دلوقتي. جرّب تاني.',
        ),
        statusCode: response.statusCode,
      );
    }

    final answer =
        data['answer']
            ?.toString()
            .trim();

    if (answer == null ||
        answer.isEmpty) {
      throw AiRequestException(
        'الذكاء الاصطناعي لم يرجع نتيجة '
        '(HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    return answer;
  }

  // ============================================================
  // HTTP POST
  // ============================================================

  /// تنفيذ POST واحد فقط لكل طلب AI.
  static Future<http.Response> _post(
    String endpoint, {
    required Map<String, dynamic> body,
    required Duration timeout,
  }) async {
    try {
      final deviceId =
          await getDeviceId();

      final requestId =
          _newRequestId();

      return await http
          .post(
            Uri.parse(endpoint),
            headers: {
              'Content-Type':
                  'application/json',
              'Accept':
                  'application/json',
              'Cache-Control':
                  'no-cache',
              'Pragma':
                  'no-cache',
              deviceIdHeader:
                  deviceId,
              requestIdHeader:
                  requestId,
            },
            body:
                jsonEncode(body),
          )
          .timeout(
            timeout,
          );
    } on TimeoutException {
      throw const AiRequestException(
        'الاتصال بالخادم استغرق وقتًا أطول من اللازم. لا تعيد الطلب تلقائيًا؛ تحقق من حالة الخدمة أولًا.',
      );
    } on http.ClientException catch (error) {
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

  static Map<String, dynamic>? _decodeMap(
    String body,
  ) {
    try {
      final decoded = jsonDecode(body);

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
        return 'حصل خطأ في الاتصال بالخادم '
            '(HTTP $statusCode).';
    }
  }

  static String _friendlyError(
    String value,
  ) {
    final error = value.trim();

    switch (error) {
      case 'GEMINI_API_KEY_MISSING':
        return 'خدمة الذكاء الاصطناعي غير مُعدة حاليًا.';

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
      case 'INVALID_JSON_BODY':
        return 'البيانات المرسلة غير صحيحة.';

      case 'NOT_FOUND':
        return 'خدمة الذكاء الاصطناعي غير موجودة حاليًا.';

      case 'NO_IMAGE_RESULT':
      case 'EMPTY_IMAGE_RESPONSE':
        return 'خدمة الصور لم ترجع نتيجة.';

      case 'IMAGE_FORMAT_NOT_SUPPORTED':
        return 'صيغة الصورة التي رجعتها الخدمة غير مدعومة.';

      case 'EMPTY_PROMPT':
        return 'اكتب وصف الصورة أولًا.';

      case 'IMAGE_GENERATION_FAILED':
      case 'ALL_IMAGE_PROVIDERS_FAILED':
        return 'تعذر إنشاء الصورة حاليًا.';

      case 'ALL_AI_PROVIDERS_FAILED':
        return 'تعذر تشغيل الذكاء الاصطناعي حاليًا. حاول مرة أخرى.';

      case 'DEVICE_ID_REQUIRED':
        return 'تعذر التعرف على جهازك. اقفل التطبيق وافتحه مرة أخرى.';

      case 'REQUEST_ID_REQUIRED':
        return 'تعذر تجهيز الطلب. حاول مرة أخرى.';

      case 'INSUFFICIENT_CREDITS':
      case 'INSUFFICIENT_QUOTA':
        return 'رصيد الذكاء الاصطناعي خلص. يمكنك الحصول على رصيد إضافي من الإعلانات لاحقًا.';

      case 'CREDITS_REQUIRED':
        return 'لا يوجد رصيد كافٍ لتنفيذ طلب الذكاء الاصطناعي.';

      case 'CREDIT_RESERVATION_FAILED':
        return 'تعذر حجز رصيد الطلب. حاول مرة أخرى.';

      case 'CREDIT_COMMIT_FAILED':
        return 'تم تنفيذ الطلب، لكن تعذر تحديث الرصيد بشكل صحيح.';

      case 'SA7BI_CREDITS_BINDING_MISSING':
        return 'خدمة الرصيد غير متاحة حاليًا.';

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

    return 'تعذر الاتصال بخدمة صاحبي حاليًا: '
        '$error';
  }
}

// ============================================================
// SERVER CREDITS RESULT
// ============================================================

class ServerCreditsResult {
  final String deviceId;
  final int balance;
  final int initialCredits;
  final int rewardedAdCredits;
  final int dailyRewardedAds;
  final int dailyRewardedAdsLimit;
  final int? textCost;
  final int? imageAnalysisCost;
  final int? videoAnalysisCost;
  final int? imageGenerationCost;
  final int? imageEditCost;
  final Map<String, dynamic> raw;

  const ServerCreditsResult({
    required this.deviceId,
    required this.balance,
    required this.initialCredits,
    required this.rewardedAdCredits,
    required this.dailyRewardedAds,
    required this.dailyRewardedAdsLimit,
    required this.textCost,
    required this.imageAnalysisCost,
    required this.videoAnalysisCost,
    required this.imageGenerationCost,
    required this.imageEditCost,
    required this.raw,
  });

  factory ServerCreditsResult.fromMap(
    Map<String, dynamic> map, {
    required String deviceId,
  }) {
    final costs =
        map['costs'] is Map
            ? Map<String, dynamic>.from(
                map['costs'] as Map,
              )
            : <String, dynamic>{};

    final rewarded =
        map['rewardedAds'] is Map
            ? Map<String, dynamic>.from(
                map['rewardedAds'] as Map,
              )
            : <String, dynamic>{};

    return ServerCreditsResult(
      deviceId: deviceId,
      balance: _readInt(
        map['balance'] ??
            map['credits'] ??
            map['remaining'],
      ),
      initialCredits: _readInt(
        map['initialCredits'],
      ),
      rewardedAdCredits: _readInt(
        map['rewardedAdCredits'] ??
            map['reward'],
      ),
      dailyRewardedAds: _readInt(
        rewarded['used'] ??
            map['dailyRewardedAds'],
      ),
      dailyRewardedAdsLimit: _readInt(
        rewarded['limit'] ??
            map['dailyRewardedAdsLimit'],
      ),
      textCost: _readNullableInt(
        costs['text'] ??
            map['textCost'],
      ),
      imageAnalysisCost: _readNullableInt(
        costs['image_analysis'] ??
            map['imageAnalysisCost'],
      ),
      videoAnalysisCost: _readNullableInt(
        costs['video_analysis'] ??
            map['videoAnalysisCost'],
      ),
      imageGenerationCost: _readNullableInt(
        costs['image_generation'] ??
            map['imageGenerationCost'],
      ),
      imageEditCost: _readNullableInt(
        costs['image_edit'] ??
            map['imageEditCost'],
      ),
      raw: Map<String, dynamic>.from(map),
    );
  }

  static int _readInt(
    dynamic value,
  ) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  static int? _readNullableInt(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value.toString(),
    );
  }
}

// ============================================================
// BACKEND CONNECTION RESULT
// ============================================================

class BackendConnectionResult {
  final bool isAvailable;
  final String? error;
  final String? version;
  final int? statusCode;

  const BackendConnectionResult._({
    required this.isAvailable,
    this.error,
    this.version,
    this.statusCode,
  });

  const BackendConnectionResult.success({
    String? version,
    int? statusCode,
  }) : this._(
          isAvailable: true,
          version: version,
          statusCode: statusCode,
        );

  const BackendConnectionResult.failure(
    String error, {
    int? statusCode,
  }) : this._(
          isAvailable: false,
          error: error,
          statusCode: statusCode,
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
