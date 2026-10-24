import 'package:flutter_test/flutter_test.dart';
import 'package:sa7bi_ai/services/image_intent_detector.dart';

void main() {
  group('ImageIntentDetector.isGenerationRequest', () {
    test('detects explicit Arabic image generation requests', () {
      expect(
        ImageIntentDetector.isGenerationRequest(
          'أنشئ صورة لقطة صغيرة',
        ),
        isTrue,
      );

      expect(
        ImageIntentDetector.isGenerationRequest(
          'اعمل صورة لمنظر طبيعي',
        ),
        isTrue,
      );

      expect(
        ImageIntentDetector.isGenerationRequest(
          'ارسم صورة لبيت على البحر',
        ),
        isTrue,
      );

      expect(
        ImageIntentDetector.isGenerationRequest(
          'صمم شعار لمتجر ملابس',
        ),
        isTrue,
      );
    });

    test('detects explicit English image generation requests', () {
      expect(
        ImageIntentDetector.isGenerationRequest(
          'Create an image of a cat',
        ),
        isTrue,
      );

      expect(
        ImageIntentDetector.isGenerationRequest(
          'Generate a picture of a sunset',
        ),
        isTrue,
      );

      expect(
        ImageIntentDetector.isGenerationRequest(
          'Make an image of a blue car',
        ),
        isTrue,
      );
    });

    test('does not classify ordinary image questions as generation', () {
      expect(
        ImageIntentDetector.isGenerationRequest(
          'ما رأيك في هذه الصورة؟',
        ),
        isFalse,
      );

      expect(
        ImageIntentDetector.isGenerationRequest(
          'اشرح لي محتوى الصورة',
        ),
        isFalse,
      );

      expect(
        ImageIntentDetector.isGenerationRequest(
          'I need a description of this image',
        ),
        isFalse,
      );
    });

    test('does not classify editing an existing image as generation', () {
      expect(
        ImageIntentDetector.isGenerationRequest(
          'عايز أعدل الصورة الموجودة',
        ),
        isFalse,
      );

      expect(
        ImageIntentDetector.isGenerationRequest(
          'How do I edit this image?',
        ),
        isFalse,
      );
    });

    test('returns false for empty or whitespace-only input', () {
      expect(
        ImageIntentDetector.isGenerationRequest(''),
        isFalse,
      );

      expect(
        ImageIntentDetector.isGenerationRequest('   '),
        isFalse,
      );
    });
  });
}
