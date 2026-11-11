
import 'package:flutter_test/flutter_test.dart';

import 'package:sa7bi_ai/services/image_intent_detector.dart';

void main() {
  group('ImageIntentDetector', () {
    test('recognizes Egyptian Arabic image creation requests', () {
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

      expect(
        ImageIntentDetector.isGenerationRequest(
          'اعمل تصميم جديد للصورة',
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

      expect(
        ImageIntentDetector.isGenerationRequest(
          'I need an image of a mountain at sunset',
        ),
        isTrue,
      );
    });

    test('does not classify ordinary image analysis as generation', () {
      const examples = <String>[
        'هل الصورة واضحة؟',
        'اشرح الصورة دي',
        'حلل الصورة واقرأ الكلام المكتوب فيها',
        'What is in this image?',
        'I need a description of this image',
        'Describe this image for me',
        'عايز وصف للصورة الموجودة',
        'عايز أعدل الصورة الموجودة',
        'عدل الصورة وخلي الخلفية زرقاء',
        'Edit this image and change the background',
      ];

      for (final example in examples) {
        expect(
          ImageIntentDetector.isGenerationRequest(example),
          isFalse,
          reason: 'Should not trigger image generation: $example',
        );
      }
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
