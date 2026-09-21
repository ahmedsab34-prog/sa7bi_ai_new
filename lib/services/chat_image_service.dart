import 'dart:typed_data';

import '../ai_service.dart';
import '../config/credits_config.dart';
import 'credits_service.dart';

/// خدمة إنشاء الصور داخل المحادثة.
///
/// مسؤوليتها:
/// - التأكد من وجود Credits كافية.
/// - خصم تكلفة إنشاء الصورة.
/// - استدعاء AiService لتوليد الصورة.
/// - إعادة الـCredits تلقائيًا إذا فشل التوليد.
///
/// لا تحتوي على واجهة مستخدم.
class ChatImageService {
  ChatImageService({
    CreditsService? creditsService,
  }) : _credits = creditsService ?? CreditsService.instance;

  final CreditsService _credits;

  /// تكلفة إنشاء الصورة الحالية.
  int get imageGenerationCost =>
      CreditsConfig.imageGenerationCost;

  /// الرصيد الحالي.
  int get credits => _credits.credits;

  /// التأكد من وجود رصيد كافٍ.
  Future<bool> canGenerate() async {
    return _credits.canAfford(
      CreditsConfig.imageGenerationCost,
    );
  }

  /// إنشاء صورة باستخدام وصف المستخدم.
  ///
  /// يتم خصم الـCredits قبل الطلب.
  /// إذا فشل الطلب يتم إرجاع الـCredits للمستخدم.
  Future<ChatImageGenerationResult> generate(
    String prompt,
  ) async {
    final cleanPrompt = prompt.trim();

    if (cleanPrompt.isEmpty) {
      return const ChatImageGenerationResult.failure(
        'اكتب وصف الصورة الأول.',
      );
    }

    await _credits.initialize();

    final cost = CreditsConfig.imageGenerationCost;

    final canAfford = await _credits.canAfford(cost);

    if (!canAfford) {
      return ChatImageGenerationResult.insufficientCredits(
        currentCredits: _credits.credits,
        requiredCredits: cost,
      );
    }

    // نحجز التكلفة قبل إرسال الطلب.
    final spent = await _credits.spend(cost);

    if (!spent) {
      return ChatImageGenerationResult.insufficientCredits(
        currentCredits: _credits.credits,
        requiredCredits: cost,
      );
    }

    try {
      final result = await AiService.generateImage(
        cleanPrompt,
      );

      if (result.isSuccess) {
        return ChatImageGenerationResult.success(
          bytes: result.bytes,
          imageUrl: result.imageUrl,
          creditsUsed: cost,
          remainingCredits: _credits.credits,
        );
      }

      // فشل التوليد:
      // نرجع التكلفة للمستخدم حتى لا يخسر Credits
      // بسبب خطأ في الخدمة.
      await _credits.add(cost);

      return ChatImageGenerationResult.failure(
        result.error ??
            'تعذر إنشاء الصورة حاليًا. حاول مرة أخرى.',
        remainingCredits: _credits.credits,
      );
    } catch (_) {
      // في حالة حدوث خطأ غير متوقع، نعيد الرصيد.
      await _credits.add(cost);

      return ChatImageGenerationResult.failure(
        'حصل خطأ أثناء إنشاء الصورة. تم إرجاع الرصيد.',
        remainingCredits: _credits.credits,
      );
    }
  }
}

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

  const ChatImageGenerationResult.failure(
    String error, {
    int remainingCredits = 0,
  }) : this._(
          error: error,
          remainingCredits: remainingCredits,
        );

  const ChatImageGenerationResult.insufficientCredits({
    required int currentCredits,
    required int requiredCredits,
  }) : this._(
          error:
              'رصيدك غير كافٍ لإنشاء الصورة. '
              'تحتاج $requiredCredits Credits '
              'ولديك $currentCredits فقط.',
          remainingCredits: currentCredits,
          requiredCredits: requiredCredits,
        );

  bool get isSuccess =>
      (bytes != null && bytes!.isNotEmpty) ||
      (imageUrl != null && imageUrl!.isNotEmpty);

  bool get isInsufficientCredits =>
      requiredCredits != null;

  bool get hasImageBytes =>
      bytes != null && bytes!.isNotEmpty;

  bool get hasImageUrl =>
      imageUrl != null && imageUrl!.isNotEmpty;
}
