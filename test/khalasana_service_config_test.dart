import 'package:flutter_test/flutter_test.dart';
import 'package:sa7bi_ai/config/service_keys.dart';
import 'package:sa7bi_ai/service_config.dart';

void main() {
  group('Khalasana service configuration', () {
    test('contains exactly ten integrated service tabs', () {
      expect(sa7biServices, hasLength(10));
    });

    test('every service has a unique stable key', () {
      final keys = sa7biServices.map((service) => service.serviceKey);

      expect(keys.toSet(), hasLength(10));
      expect(keys, isNot(contains(ServiceKeys.khalasana)));
      expect(keys, isNot(contains(ServiceKeys.general)));
    });

    test('every service has a usable title, description, and AI role', () {
      for (final service in sa7biServices) {
        expect(service.title.trim(), isNotEmpty);
        expect(service.description.trim(), isNotEmpty);
        expect(service.aiRole.trim(), isNotEmpty);
        expect(ServiceKeys.isValid(service.serviceKey), isTrue);
      }
    });

    test('the ten service identifiers match the intended portal sections', () {
      expect(
        sa7biServices.map((service) => service.serviceKey).toList(),
        <String>[
          ServiceKeys.kitchen,
          ServiceKeys.merchant,
          ServiceKeys.pharmacy,
          ServiceKeys.tradesperson,
          ServiceKeys.worship,
          ServiceKeys.shopping,
          ServiceKeys.social,
          ServiceKeys.venting,
          ServiceKeys.hobbiesSports,
          ServiceKeys.podcasts,
        ],
      );
    });
  });
}
