import 'package:flutter_test/flutter_test.dart';
import 'package:sa7bi_ai/config/service_keys.dart';
import 'package:sa7bi_ai/service_config.dart';

void main() {
  group('Khalasana service configuration', () {
    test('the shared application registry keeps all ten services', () {
      expect(sa7biServices, hasLength(10));

      final keys = sa7biServices
          .map((service) => service.serviceKey)
          .toList(growable: false);

      expect(keys.toSet(), hasLength(10));

      expect(keys, contains(ServiceKeys.social));
      expect(keys, contains(ServiceKeys.venting));

      expect(keys, isNot(contains(ServiceKeys.khalasana)));
      expect(keys, isNot(contains(ServiceKeys.general)));
    });

    test('Khalasana displays exactly eight integrated service tabs', () {
      expect(khalasanaVisibleServices, hasLength(8));

      final visibleKeys = khalasanaVisibleServices
          .map((service) => service.serviceKey)
          .toList(growable: false);

      expect(visibleKeys, hasLength(8));
      expect(visibleKeys.toSet(), hasLength(8));

      expect(visibleKeys, isNot(contains(ServiceKeys.social)));
      expect(visibleKeys, isNot(contains(ServiceKeys.venting)));
    });

    test('every shared service has a usable title, description, and AI role',
        () {
      for (final service in sa7biServices) {
        expect(service.title.trim(), isNotEmpty);
        expect(service.description.trim(), isNotEmpty);
        expect(service.aiRole.trim(), isNotEmpty);
        expect(ServiceKeys.isValid(service.serviceKey), isTrue);
      }
    });

    test('the eight visible service identifiers match the portal sections', () {
      expect(
        khalasanaVisibleServices
            .map((service) => service.serviceKey)
            .toList(),
        <String>[
          ServiceKeys.kitchen,
          ServiceKeys.merchant,
          ServiceKeys.pharmacy,
          ServiceKeys.tradesperson,
          ServiceKeys.worship,
          ServiceKeys.shopping,
          ServiceKeys.hobbiesSports,
          ServiceKeys.podcasts,
        ],
      );
    });
  });
}
