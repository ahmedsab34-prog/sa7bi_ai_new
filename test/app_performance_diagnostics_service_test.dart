import 'package:flutter_test/flutter_test.dart';

import 'package:sa7bi_ai/services/app_performance_diagnostics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppPerformanceCachePolicy', () {
    test(
      'uses a conservative image cache on low-memory devices',
      () {
        const mib = 1024 * 1024;
        const gib = 1024 * mib;

        final policy =
            AppPerformanceCachePolicy.forDevice(
          totalMemoryBytes: 2 * gib,
          lowMemory: false,
        );

        expect(
          policy.maximumSizeBytes,
          32 * mib,
        );

        expect(
          policy.maximumCachedImages,
          60,
        );
      },
    );

    test(
      'uses a larger cache budget on high-memory devices',
      () {
        const mib = 1024 * 1024;
        const gib = 1024 * mib;

        final policy =
            AppPerformanceCachePolicy.forDevice(
          totalMemoryBytes: 8 * gib,
          lowMemory: false,
        );

        expect(
          policy.maximumSizeBytes,
          96 * mib,
        );

        expect(
          policy.maximumCachedImages,
          180,
        );
      },
    );

    test(
      'low-memory warning overrides the total RAM tier',
      () {
        const mib = 1024 * 1024;
        const gib = 1024 * mib;

        final policy =
            AppPerformanceCachePolicy.forDevice(
          totalMemoryBytes: 8 * gib,
          lowMemory: true,
        );

        expect(
          policy.maximumSizeBytes,
          32 * mib,
        );

        expect(
          policy.maximumCachedImages,
          60,
        );
      },
    );
  });

  group('AppPerformanceDiagnosticsService', () {
    test(
      'returns all four local performance observations',
      () async {
        final service =
            AppPerformanceDiagnosticsService();

        final results =
            await service.runQuickChecks();

        expect(results, hasLength(4));

        expect(
          results.map((item) => item.name),
          containsAll([
            'Android device performance profile',
            'App process memory',
            'Adaptive Flutter image cache',
            'Flutter frame smoothness',
          ]),
        );

        expect(
          results.every(
            (item) => item.category == 'PERFORMANCE',
          ),
          isTrue,
        );
      },
    );
  });
}
