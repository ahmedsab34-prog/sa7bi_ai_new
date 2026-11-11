
import 'package:flutter_test/flutter_test.dart';

import 'package:sa7bi_ai/services/image_intent_detector.dart';

void main() {
  group('ImageIntentDetector', () {
    test('recognizes common Egyptian Arabic creation requests', () {
      expect(
        ImageIntentDetector.isGenerationRequest(
          'عايز صورة لقطة لابسة نظارة',
        ),
        isTrue,
      );

      expect(
        ImageIntentDetector.isGenerationRequest(
          'عاوز صورة لوجو لتطبيق صاحبي AI',
        ),
        isTrue,
      );

      expect(
        ImageIntentDetector.isGenerationRequest(
          'ممكن تعمللي صورة بخلفية زرقاء؟',
        ),
        isTrue,
      );

      expect(
        ImageIntentDetector.isGenerationRequest(
          'محتاج تصميم إعلان لمحل ملابس',
        ),
        isTrue,
      );

      expect(
        ImageIntentDetector.isGenerationRequest(
          'ارسملي شخصية كرتونية',
        ),
        isTrue,
      );
    });

    test('recognizes explicit image editing or creation commands', () {
      expect(
        ImageIntentDetector.isGenerationRequest(
          'اعمل تصميم جديد للصورة',
        ),
        isTrue,
      );

      expect(
        ImageIntentDetector.isGenerationRequest(
          'صمملي لوجو بسيط باللون النبيتي',
        ),
        isTrue,
      );
    });

    test('recognizes English image creation requests', () {
      expect(
        ImageIntentDetector.isGenerationRequest(
          'Create an image of a blue sports car',
        ),
        isTrue,
      );

      expect(
        ImageIntentDetector.isGenerationRequest(
          'Generate a logo for my app',
        ),
        isTrue,
      );
    });

    test('does not classify ordinary image questions as generation', () {
      expect(
        ImageIntentDetector.isGenerationRequest(
          'هل الصورة واضحة؟',
        ),
        isFalse,
      );

      expect(
        ImageIntentDetector.isGenerationRequest(
          'اشرح الصورة دي',
        ),
        isFalse,
      );

      expect(
        ImageIntentDetector.isGenerationRequest(
          'حلل الصورة واقرأ الكلام المكتوب فيها',
        ),
        isFalse,
      );

      expect(
        ImageIntentDetector.isGenerationRequest(
          'What is in this image?',
        ),
        isFalse,
      );
    });

    test('does not classify an empty message as generation', () {
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
