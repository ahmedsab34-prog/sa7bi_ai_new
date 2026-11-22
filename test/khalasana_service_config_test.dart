import 'package:flutter_test/flutter_test.dart';
import 'package:sa7bi_ai/config/service_keys.dart';
import 'package:sa7bi_ai/service_config.dart';

void main() {
  group('Sa7bi AI service configuration', () {
    test('the visible category registry contains exactly thirteen services', () {
      expect(sa7biServices, hasLength(13));

      final keys = sa7biServices
          .map((service) => service.serviceKey)
          .toList(growable: false);

      expect(keys.toSet(), hasLength(13));

      expect(keys, isNot(contains(ServiceKeys.social)));
      expect(keys, isNot(contains(ServiceKeys.venting)));

      expect(keys, isNot(contains(ServiceKeys.khalasana)));
      expect(keys, isNot(contains(ServiceKeys.general)));
    });

    test('Khalasana displays exactly the same thirteen services', () {
      expect(khalasanaVisibleServices, hasLength(13));

      expect(
        khalasanaVisibleServices
            .map((service) => service.serviceKey)
            .toList(),
        sa7biServices
            .map((service) => service.serviceKey)
            .toList(),
      );
    });

    test('all thirteen services have valid content and unique keys', () {
      for (final service in sa7biServices) {
        expect(service.title.trim(), isNotEmpty);
        expect(service.description.trim(), isNotEmpty);
        expect(service.aiRole.trim(), isNotEmpty);
        expect(ServiceKeys.isValid(service.serviceKey), isTrue);
      }
    });

    test('the thirteen service identifiers match the intended categories', () {
      expect(
        sa7biServices.map((service) => service.serviceKey).toList(),
        <String>[
          ServiceKeys.kitchen,
          ServiceKeys.merchant,
          ServiceKeys.pharmacy,
          ServiceKeys.tradesperson,
          ServiceKeys.worship,
          ServiceKeys.shopping,
          ServiceKeys.hobbiesSports,
          ServiceKeys.sportsNews,
          ServiceKeys.entertainment,
          ServiceKeys.technology,
          ServiceKeys.podcasts,
          ServiceKeys.education,
          ServiceKeys.career,
        ],
      );
    });

    test('legacy social and venting identifiers remain valid internally', () {
      // لا تظهر الخدمتان كبطاقات تصنيف،
      // لكننا لا نكسر مفاتيح المحادثات والسجلات القديمة.
      expect(ServiceKeys.isValid(ServiceKeys.social), isTrue);
      expect(ServiceKeys.isValid(ServiceKeys.venting), isTrue);
    });
  });
}
