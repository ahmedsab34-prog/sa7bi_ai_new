import 'dart:convert';
import 'dart:typed_data';

import '../config/credits_config.dart';
import 'ai_request_service.dart';
import 'credits_service.dart';

/// خدمة إنشاء وتعديل الصور داخل المحادثة.
///
/// مصدر الرصيد الحقيقي هو Cloudflare Worker.
/// التطبيق هنا:
/// - يعرض الرصيد المتاح.
/// - يفحص الرصيد محليًا قبل إرسال الطلب.
/// - يرسل الطلب إلى AiRequestService.
/// - الـBackend هو الذي يحجز ويخصم Credits.
/// - بعد انتهاء الطلب يتم تحديث الرصيد من السيرفر.
///
/// لا يوجد أي API Key داخل التطبيق.
class ChatImageService {
  ChatImageService({
    CreditsService? creditsService,
  }) : _credits =
            creditsService ?? CreditsService.instance;

  final CreditsService _credits;

  // ============================================================
  // CONFIG
  // ============================================================

  /// تكلفة إنشاء الصورة.
  int get imageGenerationCost =>
      CreditsConfig.imageGenerationCost;

  /// تكلفة تعديل الصورة.
  ///
  /// حاليًا الـBackend يستخدم نفس تكلفة إنشاء الصورة.
  int get imageEditCost =>
      CreditsConfig.imageGenerationCost;

  /// آخر رصيد معروف.
  int get credits =>
      _credits.credits;

  // ============================================================
  // CREDIT CHECK
  // ============================================================

  /// تحديث الرصيد من السيرفر ثم التحقق من إمكانية تنفيذ
  /// إنشاء صورة.
  Future<bool> canGenerate() async {
    await _credits.initialize();
    await _credits.refresh();

    return _credits.canAfford(
      imageGenerationCost,
    );
  }

  /// تحديث الرصيد من السيرفر ثم التحقق من إمكانية
  /// تعديل صورة.
  Future<bool> canEdit() async {
    await _credits.initialize();
    await _credits.refresh();

    return _credits.canAfford(
      imageEditCost,
    );
  }

  // ============================================================
  // GENERATE / EDIT
  // ============================================================

  /// إنشاء صورة جديدة أو تعديل صورة موجودة.
  ///
  /// إذا كانت images فارغة:
  ///   العملية = image_generation
  ///
  /// إذا كانت images تحتوي على صور:
  ///   العملية = image_edit
  ///
  /// الـBackend هو الذي يحدد التكلفة الفعلية ويخصمها.
  Future<ChatImageGenerationResult> generate(
    String prompt, {
    String? serviceContext,
    String? serviceTitle,
    List<Uint8List> images = const [],
    String aspectRatio = '1:1',
    String imageSize = '1K',
  }) async {
    final cleanPrompt = prompt.trim();

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

    // ----------------------------------------------------------
    // PREPARE IMAGES
    // ----------------------------------------------------------

    final usableImages = images
        .where(
          (image) => image.isNotEmpty,
        )
        .take(4)
        .toList();

    final isEditing = usableImages.isNotEmpty;

    final cost = isEditing
        ? imageEditCost
        : imageGenerationCost;

    // ----------------------------------------------------------
    // SERVER CREDIT CHECK
    // ----------------------------------------------------------

    await _credits.initialize();
    await _credits.refresh();

    final canAfford =
        await _credits.canAfford(cost);

    if (!canAfford) {
      return ChatImageGenerationResult
          .insufficientCredits(
        currentCredits: _credits.credits,
        requiredCredits: cost,
      );
    }

    // ----------------------------------------------------------
    // AI REQUEST
    // ----------------------------------------------------------

    try {
      final result =
          await AiRequestService.generateImage(
        prompt: cleanPrompt,
        serviceContext: serviceContext,
        serviceTitle: serviceTitle,
        images: usableImages,
        aspectRatio: aspectRatio,
        imageSize: imageSize,
      );

      final cleanResult =
          result.trim();

      if (cleanResult.isEmpty) {
        await _refreshCreditsSafely();

        return ChatImageGenerationResult.failure(
          'خدمة الصور لم ترجع صورة.',
          remainingCredits: _credits.credits,
        );
      }

      // --------------------------------------------------------
      // DATA IMAGE URL
      // --------------------------------------------------------

      if (_isDataImageUrl(cleanResult)) {
        try {
          final bytes =
              _decodeDataImage(cleanResult);

          if (bytes.isEmpty) {
            await _refreshCreditsSafely();

            return ChatImageGenerationResult.failure(
              'الصورة التي رجعتها الخدمة فارغة.',
              remainingCredits: _credits.credits,
            );
          }

          await _refreshCreditsSafely();

          return ChatImageGenerationResult.success(
            bytes: bytes,
            creditsUsed: cost,
            remainingCredits: _credits.credits,
          );
        } catch (_) {
          await _refreshCreditsSafely();

          return ChatImageGenerationResult.failure(
            'تعذر قراءة الصورة التي رجعتها الخدمة.',
            remainingCredits: _credits.credits,
          );
        }
      }

      // --------------------------------------------------------
      // NORMAL IMAGE URL
      // --------------------------------------------------------

      if (_isHttpUrl(cleanResult)) {
        await _refreshCreditsSafely();

        return ChatImageGenerationResult.success(
          imageUrl: cleanResult,
          creditsUsed: cost,
          remainingCredits: _credits.credits,
        );
      }

      // --------------------------------------------------------
      // UNKNOWN RESULT
      // --------------------------------------------------------

      await _refreshCreditsSafely();

      return ChatImageGenerationResult.failure(
        'خدمة الصور رجعت نتيجة غير مفهومة.',
        remainingCredits: _credits.credits,
      );
    } on AiRequestException catch (error) {
      // مهم:
      //
      // لا نضيف Credits محليًا.
      //
      // إذا كان الـBackend قد حجز الرصيد ثم فشل الطلب،
      // فالـBackend نفسه مسؤول عن release.
      await _refreshCreditsSafely();

      return ChatImageGenerationResult.failure(
        error.message,
        remainingCredits: _credits.credits,
      );
    } catch (_) {
      await _refreshCreditsSafely();

      return ChatImageGenerationResult.failure(
        'حصل خطأ أثناء إنشاء الصورة. حاول مرة أخرى.',
        remainingCredits: _credits.credits,
      );
    }
  }

  // ============================================================
  // SAFE CREDIT REFRESH
  // ============================================================

  Future<void> _refreshCreditsSafely() async {
    try {
      await _credits.refresh();
    } catch (_) {
      // لا نسقط التطبيق بسبب فشل تحديث الرصيد.
      //
      // آخر قيمة معروفة تظل متاحة للواجهة.
    }
  }

  // ============================================================
  // DATA URL
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
  // URL
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

/// نتيجة إنشاء أو تعديل صورة.
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
          remainingCredits: remainingCredits,
        );

  // ============================================================
  // FAILURE
  // ============================================================

  const ChatImageGenerationResult.failure(
    String error, {
    int remainingCredits = 0,
  }) : this._(
          error: error,
          remainingCredits: remainingCredits,
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
              'رصيدك غير كافٍ لتنفيذ العملية. '
              'تحتاج $requiredCredits Credits '
              'ولديك $currentCredits فقط.',
          remainingCredits: currentCredits,
          requiredCredits: requiredCredits,
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
