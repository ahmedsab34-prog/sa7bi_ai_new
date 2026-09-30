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
/// - التطبيق لا يقرر وحده السماح النهائي للطلب.
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
                Uri.parse(
                  AppConfig.backendHealthEndpoint,
                ),
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
    List<Map<String, String>> history = const
