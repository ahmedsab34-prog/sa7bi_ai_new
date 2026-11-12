import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show FrameTiming;

import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'app_diagnostics_service.dart';

/// يجمع أزمنة الإطارات الحقيقية أثناء استخدام التطبيق.
/// لا ينفذ CPU benchmark ثقيلًا ولا يوقف واجهة المستخدم.
class AppPerformanceFrameMonitor {
  AppPerformanceFrameMonitor._();

  static const int _maximumSamples = 180;

  static bool _started = false;

  static final List<double> _recentFrameTimesMs = [];

  static void start() {
    if (_started) return;

    WidgetsFlutterBinding.ensureInitialized();

    SchedulerBinding.instance.addTimingsCallback(
      _onFrameTimings,
    );

    _started = true;
  }

  static void _onFrameTimings(
    List<FrameTiming> timings,
  ) {
    for (final timing in timings) {
      final durationMs =
          timing.totalSpan.inMicroseconds / 1000.0;

      if (!durationMs.isFinite ||
          durationMs <= 0 ||
          durationMs > 5000) {
        continue;
      }

      _recentFrameTimesMs.add(durationMs);

      if (_recentFrameTimesMs.length >
          _maximumSamples) {
        final excess =
            _recentFrameTimesMs.length -
                _maximumSamples;

        _recentFrameTimesMs.removeRange(
          0,
          excess,
        );
      }
    }
  }

  static List<double> get recentFrameTimesMs {
    return List<double>.unmodifiable(
      _recentFrameTimesMs,
    );
  }
}

/// سياسة متكيفة لتحديد ميزانية ذاكرة صور Flutter.
/// لا تغيّر ذاكرة أندرويد العامة ولا إعدادات المعالج.
class AppPerformanceCachePolicy {
  const AppPerformanceCachePolicy({
    required this.maximumSizeBytes,
    required this.maximumCachedImages,
  });

  final int maximumSizeBytes;
  final int maximumCachedImages;

  static AppPerformanceCachePolicy forDevice({
    required int totalMemoryBytes,
    required bool lowMemory,
  }) {
    const mib = 1024 * 1024;
    const gib = 1024 * mib;

    if (lowMemory ||
        totalMemoryBytes <= 3 * gib) {
      return const AppPerformanceCachePolicy(
        maximumSizeBytes: 32 * mib,
        maximumCachedImages: 60,
      );
    }

    if (totalMemoryBytes <= 4 * gib) {
      return const AppPerformanceCachePolicy(
        maximumSizeBytes: 48 * mib,
        maximumCachedImages: 90,
      );
    }

    if (totalMemoryBytes <= 6 * gib) {
      return const AppPerformanceCachePolicy(
        maximumSizeBytes: 64 * mib,
        maximumCachedImages: 120,
      );
    }

    return const AppPerformanceCachePolicy(
      maximumSizeBytes: 96 * mib,
      maximumCachedImages: 180,
    );
  }
}

class AppPerformanceDiagnosticsService {
  AppPerformanceDiagnosticsService({
    MethodChannel? channel,
  }) : _channel = channel ?? _defaultChannel;

  static const MethodChannel _defaultChannel =
      MethodChannel('sa7bi_ai/performance');

  static const int _mib = 1024 * 1024;

  final MethodChannel _channel;

  /// الفحص السريع للأداء.
  ///
  /// 1. قراءة بيانات الجهاز المحلية.
  /// 2. قياس ذاكرة التطبيق.
  /// 3. تطبيق سياسة ذاكرة الصور المتكيفة.
  /// 4. تحليل سلاسة الإطارات التي تم جمعها.
  ///
  /// لا يرسل أي طلب إلى Worker ولا يستهلك رصيد AI.
  Future<List<DiagnosticResult>> runQuickChecks({
    void Function(DiagnosticResult result)? onResult,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();

    AppPerformanceFrameMonitor.start();

    final results = <DiagnosticResult>[];

    void emit(DiagnosticResult result) {
      results.add(result);
      onResult?.call(result);
    }

    final deviceMetrics = await _readDeviceMetrics();

    emit(
      _checkDeviceProfile(deviceMetrics),
    );

    emit(
      _checkAppMemory(),
    );

    emit(
      _applyAdaptiveImageCache(deviceMetrics),
    );

    emit(
      _checkFramePerformance(),
    );

    return List<DiagnosticResult>.unmodifiable(
      results,
    );
  }

  Future<_DevicePerformanceMetrics>
      _readDeviceMetrics() async {
    try {
      final data = await _channel
          .invokeMapMethod<String, dynamic>(
        'getDevicePerformanceInfo',
      )
          .timeout(
        const Duration(seconds: 2),
      );

      if (data == null) {
        return _fallbackMetrics();
      }

      final totalMemory = _readInt(
        data['totalMemoryBytes'],
        0,
      );

      final availableMemory = _readInt(
        data['availableMemoryBytes'],
        0,
      );

      final processors = _readInt(
        data['logicalProcessors'],
        Platform.numberOfProcessors,
      );

      return _DevicePerformanceMetrics(
        logicalProcessors: processors,
        totalMemoryBytes: totalMemory,
        availableMemoryBytes: availableMemory,
        lowMemory: data['lowMemory'] == true,
        nativeAvailable: totalMemory > 0,
      );
    } catch (_) {
      return _fallbackMetrics();
    }
  }

  _DevicePerformanceMetrics _fallbackMetrics() {
    return _DevicePerformanceMetrics(
      logicalProcessors: Platform.numberOfProcessors,
      totalMemoryBytes: 0,
      availableMemoryBytes: 0,
      lowMemory: false,
      nativeAvailable: false,
    );
  }

  int _readInt(
    Object? value,
    int fallback,
  ) {
    if (value is num) {
      return value.toInt();
    }

    return fallback;
  }

  DiagnosticResult _checkDeviceProfile(
    _DevicePerformanceMetrics metrics,
  ) {
    if (!metrics.nativeAvailable) {
      return DiagnosticResult(
        name: 'Android device performance profile',
        category: 'PERFORMANCE',
        success: false,
        severity: 'WARN',
        status: 'DEVICE_PROFILE_PARTIAL',
        details:
            'logicalProcessors=${metrics.logicalProcessors}; '
            'totalRam=unavailable; '
            'availableRam=unavailable. '
            'تعذر قراءة بيانات الذاكرة الأصلية من أندرويد. '
            'لم يتم تطبيق تحسين يعتمد على تخمين الذاكرة.',
        durationMs: 0,
        blocked: true,
      );
    }

    final totalMiB =
        metrics.totalMemoryBytes / _mib;

    final availableMiB =
        metrics.availableMemoryBytes / _mib;

    final severity =
        metrics.lowMemory ? 'WARN' : 'PASS';

    return DiagnosticResult(
      name: 'Android device performance profile',
      category: 'PERFORMANCE',
      success: !metrics.lowMemory,
      severity: severity,
      status: metrics.lowMemory
          ? 'ANDROID_LOW_MEMORY'
          : 'DEVICE_PROFILE_OK',
      details:
          'logicalProcessors=${metrics.logicalProcessors}; '
          'totalRamMiB=${totalMiB.toStringAsFixed(0)}; '
          'availableRamMiB=${availableMiB.toStringAsFixed(0)}; '
          'lowMemory=${metrics.lowMemory}. '
          'عدد الأنوية لا يعبّر عن تردد المعالج.',
      durationMs: 0,
    );
  }

  DiagnosticResult _checkAppMemory() {
    try {
      final rssBytes = ProcessInfo.currentRss;

      if (rssBytes <= 0) {
        return const DiagnosticResult(
          name: 'App process memory',
          category: 'PERFORMANCE',
          success: false,
          severity: 'WARN',
          status: 'APP_MEMORY_UNAVAILABLE',
          details:
              'تعذر قياس الذاكرة المقيمة التي يستخدمها التطبيق.',
          durationMs: 0,
          blocked: true,
        );
      }

      final rssMiB = rssBytes / _mib;

      // حد إرشادي للمراقبة، وليس حدًا ثابتًا لكل الأجهزة.
      final highMemory =
          rssBytes >= 512 * _mib;

      return DiagnosticResult(
        name: 'App process memory',
        category: 'PERFORMANCE',
        success: !highMemory,
        severity: highMemory ? 'WARN' : 'PASS',
        status: highMemory
            ? 'APP_MEMORY_HIGH'
            : 'APP_MEMORY_MEASURED',
        details:
            'residentMemoryMiB=${rssMiB.toStringAsFixed(1)}; '
            'advisoryThresholdMiB=512. '
            'هذه ذاكرة التطبيق نفسه وليست إجمالي ذاكرة الهاتف.',
        durationMs: 0,
      );
    } catch (error) {
      return DiagnosticResult(
        name: 'App process memory',
        category: 'PERFORMANCE',
        success: false,
        severity: 'WARN',
        status: 'APP_MEMORY_UNAVAILABLE',
        details: _safeError(error),
        durationMs: 0,
        blocked: true,
      );
    }
  }

  DiagnosticResult _applyAdaptiveImageCache(
    _DevicePerformanceMetrics metrics,
  ) {
    if (!metrics.nativeAvailable) {
      return const DiagnosticResult(
        name: 'Adaptive Flutter image cache',
        category: 'PERFORMANCE',
        success: false,
        severity: 'WARN',
        status: 'IMAGE_CACHE_TUNING_SKIPPED',
        details:
            'لم يتم تغيير ميزانية ذاكرة الصور لأن معلومات '
            'ذاكرة الجهاز غير متاحة. تجنبًا لاختيار حد غير مناسب.',
        durationMs: 0,
        blocked: true,
      );
    }

    try {
      final policy =
          AppPerformanceCachePolicy.forDevice(
        totalMemoryBytes: metrics.totalMemoryBytes,
        lowMemory: metrics.lowMemory,
      );

      final imageCache =
          PaintingBinding.instance.imageCache;

      final previousBytes =
          imageCache.maximumSizeBytes;

      final previousImages =
          imageCache.maximumSize;

      // لا نرفع حدودًا موجودة بالفعل.
      // نخفض الحدود فقط عندما تكون أكبر من السياسة المتكيفة.
      final nextBytes = math.min(
        previousBytes,
        policy.maximumSizeBytes,
      );

      final nextImages = math.min(
        previousImages,
        policy.maximumCachedImages,
      );

      imageCache.maximumSizeBytes = nextBytes;
      imageCache.maximumSize = nextImages;

      final changed =
          previousBytes != nextBytes ||
          previousImages != nextImages;

      return DiagnosticResult(
        name: 'Adaptive Flutter image cache',
        category: 'PERFORMANCE',
        success: true,
        severity: 'PASS',
        status: changed
            ? 'IMAGE_CACHE_POLICY_APPLIED'
            : 'IMAGE_CACHE_ALREADY_ADAPTIVE',
        details:
            'changed=$changed; '
            'previousMaximumBytes=$previousBytes; '
            'newMaximumBytes=$nextBytes; '
            'previousMaximumImages=$previousImages; '
            'newMaximumImages=$nextImages; '
            'currentCacheBytes=${imageCache.currentSizeBytes}; '
            'currentCachedImages=${imageCache.currentSize}. '
            'تم ضبط ذاكرة الصور داخل التطبيق فقط.',
        durationMs: 0,
      );
    } catch (error) {
      return DiagnosticResult(
        name: 'Adaptive Flutter image cache',
        category: 'PERFORMANCE',
        success: false,
        severity: 'WARN',
        status: 'IMAGE_CACHE_TUNING_ERROR',
        details: _safeError(error),
        durationMs: 0,
      );
    }
  }

  DiagnosticResult _checkFramePerformance() {
    final samples =
        AppPerformanceFrameMonitor.recentFrameTimesMs;

    if (samples.length < 20) {
      return DiagnosticResult(
        name: 'Flutter frame smoothness',
        category: 'PERFORMANCE',
        success: false,
        severity: 'WARN',
        status: 'NOT_TESTED_FRAME_SAMPLE_TOO_SMALL',
        details:
            'عدد الإطارات المسجلة=${samples.length}. '
            'نحتاج 20 إطارًا على الأقل. '
            'استخدم التطبيق بين الشاشات ثم افتح التشخيص مرة أخرى.',
        durationMs: 0,
        blocked: true,
      );
    }

    final average = samples.reduce(
          (a, b) => a + b,
        ) /
        samples.length;

    final sorted = List<double>.from(samples)
      ..sort();

    final p95Index =
        ((sorted.length - 1) * 0.95).ceil();

    final p95 = sorted[p95Index];

    const targetFrameMs = 16.7;

    final slowFrames = samples.where(
      (value) => value > targetFrameMs,
    ).length;

    final slowPercentage =
        slowFrames * 100 / samples.length;

    final jankDetected =
        slowPercentage >= 20;

    return DiagnosticResult(
      name: 'Flutter frame smoothness',
      category: 'PERFORMANCE',
      success: !jankDetected,
      severity: jankDetected ? 'WARN' : 'PASS',
      status: jankDetected
          ? 'UI_FRAME_JANK_DETECTED'
          : 'UI_FRAME_TIMING_OK',
      details:
          'sampledFrames=${samples.length}; '
          'averageFrameMs=${average.toStringAsFixed(2)}; '
          'p95FrameMs=${p95.toStringAsFixed(2)}; '
          'slowFrames=$slowFrames; '
          'slowPercentage=${slowPercentage.toStringAsFixed(1)}; '
          'targetFrameMs=$targetFrameMs. '
          'القياس مبني على الإطارات الفعلية المسجلة أثناء الاستخدام.',
      durationMs: 0,
    );
  }

  String _safeError(Object error) {
    final value = error
        .toString()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (value.length <= 400) {
      return value;
    }

    return '${value.substring(0, 400)}…';
  }
}

class _DevicePerformanceMetrics {
  const _DevicePerformanceMetrics({
    required this.logicalProcessors,
    required this.totalMemoryBytes,
    required this.availableMemoryBytes,
    required this.lowMemory,
    required this.nativeAvailable,
  });

  final int logicalProcessors;
  final int totalMemoryBytes;
  final int availableMemoryBytes;
  final bool lowMemory;
  final bool nativeAvailable;
}
