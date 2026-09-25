import 'dart:convert';
import 'dart:typed_data';

import '../config/credits_config.dart';
import 'ai_request_service.dart';
import 'credits_service.dart';

/// خدمة إنشاء الصور داخل المحادثة.
///
/// المسؤوليات:
/// - التأكد من وجود Credits كافية.
/// - خصم تكلفة إنشاء الصورة.
/// - إرسال الطلب من خلال AiRequestService.
/// - الاتصال بالـCloudflare Worker فقط.
/// - تحويل نتيجة الصورة إلى bytes أو الاحتفاظ بالرابط.
/// - إعادة Credits تلقائيًا عند فشل الطلب.
///
/// لا تحتوي هذه الخدمة على أي API Key.
class ChatImageService {
  ChatImageService({
    CreditsService? creditsService,
  }) : _credits =
            creditsService ?? CreditsService.instance;

  final CreditsService _credits;

  // ============================================================
  // CONFIG
  // ============================================================

  /// تكلفة إنشاء الصورة الحالية.
  int get imageGenerationCost =>
      CreditsConfig.imageGenerationCost;

  /// الرصيد الحالي.
  int get credits =>
      _credits.credits;

  // ============================================================
  // CREDIT CHECK
  // ============================================================

  /// التأكد من وجود رصيد كافٍ لإنشاء صورة.
  Future<bool> canGenerate() async {
    await _credits.initialize();

    return _credits.canAfford(
      CreditsConfig.imageGenerationCost,
    );
  }

  // ============================================================
  // IMAGE GENERATION
  // ============================================================

  /// إنشاء صورة باستخدام وصف المستخدم.
  ///
  /// المسار:
  ///
  /// ChatImageService
  ///       ↓
  /// AiRequestService
  ///       ↓
  /// Cloudflare Worker
  ///       ↓
  /// OpenAI
  ///
  /// لا يوجد أي مفتاح OpenAI داخل التطبيق.
  Future<ChatImageGenerationResult> generate(
    String prompt, {
    String? serviceContext,
    String? serviceTitle,
  }) async {
    final cleanPrompt =
        prompt.trim();

    if (cleanPrompt.isEmpty) {
      return const ChatImageGenerationResult.failure(
        'اكتب وصف الصورة الأول.',
      );
    }

    if (cleanPrompt.length > 6000) {
      return const ChatImageGenerationResult.failure(
        'وصف الصورة طويل جدًا. حاول تختصر الوصف قليلًا.',
      );
    }

    await _credits.initialize();

    final cost =
        CreditsConfig.imageGenerationCost;

    // ----------------------------------------------------------
    // CHECK CREDITS
    // ----------------------------------------------------------

    final canAfford =
        await _credits.canAfford(cost);

    if (!canAfford) {
      return ChatImageGenerationResult
          .insufficientCredits(
        currentCredits:
            _credits.credits,
        requiredCredits:
            cost,
      );
    }

    // ----------------------------------------------------------
    // SPEND
    // ----------------------------------------------------------

    final spent =
        await _credits.spend(cost);

    if (!spent) {
      return ChatImageGenerationResult
          .insufficientCredits(
        currentCredits:
            _credits.credits,
        requiredCredits:
            cost,
      );
    }

    // ----------------------------------------------------------
    // AI REQUEST
    // ----------------------------------------------------------

    try {
      final result =
          await AiRequestService.generateImage(
        prompt: cleanPrompt,
        serviceContext:
            serviceContext,
        serviceTitle:
            serviceTitle,
      );

      if (result.trim().isEmpty) {
        await _refund(cost);

        return ChatImageGenerationResult.failure(
          'خدمة الصور لم ترجع صورة.',
          remainingCredits:
              _credits.credits,
        );
      }

      // --------------------------------------------------------
      // DATA URL
      // --------------------------------------------------------

      if (_isDataImageUrl(result)) {
        try {
          final bytes =
              _decodeDataImage(result);

          if (bytes.isEmpty) {
            await _refund(cost);

            return ChatImageGenerationResult.failure(
              'الصورة التي رجعتها الخدمة فارغة.',
              remainingCredits:
                  _credits.credits,
            );
          }

          return ChatImageGenerationResult.success(
            bytes: bytes,
            creditsUsed: cost,
            remainingCredits:
                _credits.credits,
          );
        } catch (_) {
          await _refund(cost);

          return ChatImageGenerationResult.failure(
            'تعذر قراءة الصورة التي رجعتها الخدمة.',
            remainingCredits:
                _credits.credits,
          );
        }
      }

      // --------------------------------------------------------
      // NORMAL URL
      // --------------------------------------------------------

      if (_isHttpUrl(result)) {
        return ChatImageGenerationResult.success(
          imageUrl: result,
          creditsUsed: cost,
          remainingCredits:
              _credits.credits,
        );
      }

      // --------------------------------------------------------
      // UNKNOWN RESULT
      // --------------------------------------------------------

      await _refund(cost);

      return ChatImageGenerationResult.failure(
        'خدمة الصور رجعت نتيجة غير مفهومة.',
        remainingCredits:
            _credits.credits,
      );
    } on AiRequestException catch (error) {
      await _refund(cost);

      return ChatImageGenerationResult.failure(
        error.message,
        remainingCredits:
            _credits.credits,
      );
    } catch (_) {
      await _refund(cost);

      return ChatImageGenerationResult.failure(
        'حصل خطأ أثناء إنشاء الصورة. تم إرجاع الرصيد.',
        remainingCredits:
            _credits.credits,
      );
    }
  }

  // ============================================================
  // REFUND
  // ============================================================

  Future<void> _refund(
    int amount,
  ) async {
    if (amount <= 0) {
      return;
    }

    try {
      await _credits.add(amount);
    } catch (_) {
      // لا نسمح بفشل عملية الإرجاع
      // بإسقاط التطبيق.
    }
  }

  // ============================================================
  // DATA URL HELPERS
  // ============================================================

  static bool _isDataImageUrl(
    String value,
  ) {
    final clean =
        value.trim().toLowerCase();

    return clean.startsWith(
      'data:image/',
    );
  }

  static Uint8List _decodeDataImage(
    String value,
  ) {
    final clean =
        value.trim();

    final comma =
        clean.indexOf(',');

    if (comma == -1) {
      throw const FormatException(
        'Invalid image data URL.',
      );
    }

    final encoded =
        clean.substring(
      comma + 1,
    );

    if (encoded.trim().isEmpty) {
      throw const FormatException(
        'Empty image data.',
      );
    }

    return base64Decode(
      encoded,
    );
  }

  // ============================================================
  // URL HELPERS
  // ============================================================

  static bool _isHttpUrl(
    String value,
  ) {
    final uri =
        Uri.tryParse(
      value.trim(),
    );

    if (uri == null) {
      return false;
    }

    return uri.scheme == 'https' ||
        uri.scheme == 'http';
  }
}

// ============================================================
// RESULT
// ============================================================

/// نتيجة إنشاء صورة داخل المحادثة.
class ChatImageGenerationResult {
  final Uint8List? bytes;
  final String? imageUrl;
  final String? error;

  final int creditsUsed;
  final int remainingCredits;

  final int? requiredCredits;

  const ChatImageGenerationResult._({
    this.bytes,
    this.imageUrl,
    this.error,
    this.creditsUsed = 0,
    this.remainingCredits = 0,
    this.requiredCredits,
  });

  // ============================================================
  // SUCCESS
  // ============================================================

  const ChatImageGenerationResult.success({
    Uint8List? bytes,
    String? imageUrl,
    required int creditsUsed,
    required int remainingCredits,
  }) : this._(
          bytes: bytes,
          imageUrl: imageUrl,
          creditsUsed: creditsUsed,
          remainingCredits:
              remainingCredits,
        );

  // ============================================================
  // FAILURE
  // ============================================================

  const ChatImageGenerationResult.failure(
    String error, {
    int remainingCredits = 0,
  }) : this._(
          error: error,
          remainingCredits:
              remainingCredits,
        );

  // ============================================================
  // INSUFFICIENT CREDITS
  // ============================================================

  const ChatImageGenerationResult
      .insufficientCredits({
    required int currentCredits,
    required int requiredCredits,
  }) : this._(
          error:
              'رصيدك غير كافٍ لإنشاء الصورة. '
              'تحتاج $requiredCredits Credits '
              'ولديك $currentCredits فقط.',
          remainingCredits:
              currentCredits,
          requiredCredits:
              requiredCredits,
        );

  // ============================================================
  // STATUS
  // ============================================================

  bool get isSuccess =>
      (bytes != null &&
          bytes!.isNotEmpty) ||
      (imageUrl != null &&
          imageUrl!.isNotEmpty);

  bool get isInsufficientCredits =>
      requiredCredits != null;

  bool get hasImageBytes =>
      bytes != null &&
      bytes!.isNotEmpty;

  bool get hasImageUrl =>
      imageUrl != null &&
      imageUrl!.isNotEmpty;

  bool get hasError =>
      error != null &&
      error!.trim().isNotEmpty;
}
