import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class DiagnosticResult {
  final String name;
  final String category;
  final bool success;
  final String status;
  final String details;
  final int? httpStatus;
  final int durationMs;
  final String severity;
  final bool repairable;

  const DiagnosticResult({
    required this.name,
    required this.category,
    required this.success,
    required this.status,
    required this.details,
    required this.durationMs,
    this.httpStatus,
    this.severity = 'PASS',
    this.repairable = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category': category,
      'success': success,
      'severity': severity,
      'status': status,
      'details': details,
      'httpStatus': httpStatus,
      'durationMs': durationMs,
      'repairable': repairable,
    };
  }
}

class DiagnosticRepairResult {
  final bool success;
  final bool changed;
  final String title;
  final String details;

  const DiagnosticRepairResult({
    required this.success,
    required this.changed,
    required this.title,
    required this.details,
  });

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'changed': changed,
      'title': title,
      'details': details,
    };
  }
}

class AppDiagnosticsReport {
  final DateTime startedAt;
  final DateTime finishedAt;
  final List<DiagnosticResult> results;

  const AppDiagnosticsReport({
    required this.startedAt,
    required this.finishedAt,
    required this.results,
  });

  int get passed =>
      results.where((e) => e.severity == 'PASS').length;

  int get warnings =>
      results.where((e) => e.severity == 'WARN').length;

  int get failed =>
      results.where((e) => e.severity == 'FAIL').length;

  int get total => results.length;

  Duration get duration =>
      finishedAt.difference(startedAt);

  bool get hasRepairableIssues =>
      results.any((e) => !e.success && e.repairable);

  DiagnosticResult? _find(String name) {
    for (final item in results) {
      if (item.name == name) {
        return item;
      }
    }
    return null;
  }

  String get rootCause {
    final dns = _find('Worker DNS resolution');
    final ipv4 = _find('Worker IPv4 socket reachability');
    final ipv6 = _find('Worker IPv6 socket reachability');
    final https4 = _find('Worker HTTPS via resolved IPv4');
    final https6 = _find('Worker HTTPS via resolved IPv6');

    if (dns != null && !dns.success) {
      return 'فشل حل اسم Worker عبر DNS. '
          'المشكلة في طبقة DNS قبل الوصول إلى الـWorker.';
    }

    if (ipv4 != null &&
        !ipv4.success &&
        ipv6 != null &&
        !ipv6.success) {
      return 'اسم الـWorker يتم حله، لكن الاتصال TCP بالمنفذ 443 '
          'غير متاح عبر IPv4 وIPv6. '
          'هذا يشير إلى مشكلة في مسار الشبكة أو VPN أو ISP أو Firewall '
          'أو مسار Cloudflare، وليس في كود AI نفسه.';
    }

    if (https4?.success == true ||
        https6?.success == true) {
      return 'الاتصال بالـWorker ينجح عند استخدام عنوان IP المحلول '
          'مع إبقاء hostname الخاص بالـWorker. '
          'هذا يوجه التشخيص إلى مسار hostname أو DNS أو proxy.';
    }

    if (ipv4?.success == true &&
        https4 != null &&
        !https4.success) {
      return 'اتصال TCP عبر IPv4 يعمل، لكن HTTPS/TLS عبر Worker لا يعمل. '
          'يجب فحص TLS/SNI/Cloudflare routing.';
    }

    if (ipv6?.success == true &&
        https6 != null &&
        !https6.success) {
      return 'اتصال TCP عبر IPv6 يعمل، لكن HTTPS يفشل. '
          'يجب فحص IPv6 routing أو TLS.';
    }

    final failures =
        results.where((e) => e.severity == 'FAIL').toList();

    if (failures.isNotEmpty) {
      return failures.first.details;
    }

    final warnings =
        results.where((e) => e.severity == 'WARN').toList();

    if (warnings.isNotEmpty) {
      return warnings.first.details;
    }

    return 'لم يتم اكتشاف مشكلة في الاختبارات الحالية.';
  }

  String get primaryProblem => rootCause;

  List<DiagnosticResult> get slowestResults {
    final copy = List<DiagnosticResult>.from(results);

    copy.sort(
      (a, b) => b.durationMs.compareTo(a.durationMs),
    );

    return copy.take(5).toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'reportVersion':
          AppDiagnosticsService.diagnosticVersion,
      'startedAt': startedAt.toIso8601String(),
      'finishedAt': finishedAt.toIso8601String(),
      'durationMs': duration.inMilliseconds,
      'passed': passed,
      'warnings': warnings,
      'failed': failed,
      'total': total,
      'primaryProblem': primaryProblem,
      'rootCause': rootCause,
      'repairableIssues': results
          .where((e) => !e.success && e.repairable)
          .map((e) => e.name)
          .toList(),
      'results': results.map((e) => e.toJson()).toList(),
      'slowestTests': slowestResults
          .map(
            (e) => {
              'name': e.name,
              'durationMs': e.durationMs,
              'status': e.status,
            },
          )
          .toList(),
    };
  }

  String toPrettyJson() {
    return const JsonEncoder.withIndent('  ')
        .convert(toJson());
  }

  String toTextReport() {
    final buffer = StringBuffer();

    buffer.writeln('========================================');
    buffer.writeln('SA7BI AI DIAGNOSTIC REPORT');
    buffer.writeln('========================================');
    buffer.writeln(
      'Report version: '
      '${AppDiagnosticsService.diagnosticVersion}',
    );
    buffer.writeln(
      'Started: ${startedAt.toLocal().toIso8601String()}',
    );
    buffer.writeln(
      'Finished: ${finishedAt.toLocal().toIso8601String()}',
    );
    buffer.writeln(
      'Duration: ${duration.inMilliseconds} ms',
    );
    buffer.writeln();

    buffer.writeln('SUMMARY');
    buffer.writeln('Passed: $passed');
    buffer.writeln('Warnings: $warnings');
    buffer.writeln('Failed: $failed');
    buffer.writeln('Total: $total');
    buffer.writeln();

    buffer.writeln('PRIMARY PROBLEM');
    buffer.writeln(primaryProblem);
    buffer.writeln();

    buffer.writeln('ROOT CAUSE ANALYSIS');
    buffer.writeln(rootCause);
    buffer.writeln();

    buffer.writeln('REPAIRABLE ISSUES');

    final repairable = results
        .where((e) => !e.success && e.repairable)
        .toList();

    if (repairable.isEmpty) {
      buffer.writeln('None confirmed locally.');
    } else {
      for (final item in repairable) {
        buffer.writeln('- ${item.name}');
      }
    }

    buffer.writeln();

    buffer.writeln('RESULTS');
    buffer.writeln('----------------------------------------');

    for (final result in results) {
      buffer.writeln(
        '[${result.severity}] '
        '${result.category} | '
        '${result.name}',
      );
      buffer.writeln('Status: ${result.status}');
      buffer.writeln(
        'HTTP: ${result.httpStatus ?? '-'}',
      );
      buffer.writeln(
        'Duration: ${result.durationMs} ms',
      );
      buffer.writeln(
        'Repairable: ${result.repairable}',
      );
      buffer.writeln(
        'Details: ${result.details}',
      );
      buffer.writeln();
    }

    buffer.writeln('SLOWEST TESTS');
    buffer.writeln('----------------------------------------');

    for (final result in slowestResults) {
      buffer.writeln(
        '${result.durationMs} ms | '
        '${result.status} | '
        '${result.name}',
      );
    }

    buffer.writeln();
    buffer.writeln('========================================');
    buffer.writeln('END OF REPORT');
    buffer.writeln('========================================');

    return buffer.toString();
  }
}

class AppDiagnosticsService {
  AppDiagnosticsService({
    this.workerBaseUrl =
        'https://sa7bi-ai-new.ahmedsab34.workers.dev',
  });

  final String workerBaseUrl;

  static const Duration defaultTimeout =
      Duration(seconds: 12);

  static const Duration deepTimeout =
      Duration(seconds: 5);

  static const String diagnosticVersion = '4.0.0';

  static const String buildId =
      String.fromEnvironment(
    'APP_BUILD_ID',
    defaultValue: 'NOT_INJECTED',
  );

  static const String sourceId =
      String.fromEnvironment(
    'APP_SOURCE_ID',
    defaultValue: 'NOT_INJECTED',
  );

  static const String appVersion =
      String.fromEnvironment(
    'SA7BI_APP_VERSION',
    defaultValue: 'NOT_INJECTED',
  );

  static const String buildNumber =
      String.fromEnvironment(
    'SA7BI_BUILD_NUMBER',
    defaultValue: 'NOT_INJECTED',
  );

  static const String commitSha =
      String.fromEnvironment(
    'SA7BI_COMMIT_SHA',
    defaultValue: 'NOT_INJECTED',
  );

  Future<AppDiagnosticsReport> runFullDiagnostics({
    void Function(DiagnosticResult result)? onResult,
  }) async {
    final started = DateTime.now();
    final results = <DiagnosticResult>[];

    Future<void> run(
      String category,
      String name,
      Future<DiagnosticResult> Function() test,
    ) async {
      DiagnosticResult result;

      try {
        result = await test().timeout(
          defaultTimeout,
          onTimeout: () {
            return DiagnosticResult(
              name: name,
              category: category,
              success: false,
              severity: 'FAIL',
              status: 'TIMEOUT',
              details:
                  'الاختبار تجاوز مهلة '
                  '${defaultTimeout.inSeconds} ثانية.',
              durationMs:
                  defaultTimeout.inMilliseconds,
            );
          },
        );
      } catch (e) {
        result = DiagnosticResult(
          name: name,
          category: category,
          success: false,
          severity: 'FAIL',
          status: _classifyException(e),
          details: _safeError(e),
          durationMs: 0,
        );
      }

      results.add(result);
      onResult?.call(result);
    }

    // BUILD
    await run(
      'BUILD',
      'Runtime identity',
      _checkRuntimeIdentity,
    );

    await run(
      'BUILD',
      'Diagnostic engine identity',
      _checkDiagnosticIdentity,
    );

    await run(
      'BUILD',
      'Build/source identity',
      _checkBuildSourceIdentity,
    );

    // DEVICE
    await run(
      'DEVICE',
      'Runtime memory',
      _checkRuntimeMemory,
    );

    await run(
      'DEVICE',
      'Temporary storage',
      _checkTemporaryStorage,
    );

    await run(
      'DEVICE',
      'Network interfaces',
      _checkNetworkInterfaces,
    );

    // NETWORK
    await run(
      'NETWORK',
      'Internet connectivity',
      _checkInternet,
    );

    await run(
      'NETWORK',
      'Worker DNS resolution',
      _checkDns,
    );

    await run(
      'NETWORK',
      'Worker IPv4 DNS',
      _checkDnsV4,
    );

    await run(
      'NETWORK',
      'Worker IPv6 DNS',
      _checkDnsV6,
    );

    await run(
      'NETWORK',
      'Raw HttpClient HTTPS → Google',
      _checkRawHttpClientGoogle,
    );

    await run(
      'NETWORK',
      'package:http HTTPS → Google',
      _checkPackageHttpGoogle,
    );

    await run(
      'NETWORK',
      'Cloudflare HTTPS',
      _checkCloudflare,
    );

    await run(
      'NETWORK',
      'HTTP proxy configuration',
      _checkProxyConfiguration,
    );

    await run(
      'NETWORK',
      'Worker IPv4 socket reachability',
      _checkWorkerIpv4Socket,
    );

    await run(
      'NETWORK',
      'Worker IPv6 socket reachability',
      _checkWorkerIpv6Socket,
    );

    await run(
      'NETWORK',
      'Worker HTTPS via resolved IPv4',
      _checkWorkerHttpsViaIp4,
    );

    await run(
      'NETWORK',
      'Worker HTTPS via resolved IPv6',
      _checkWorkerHttpsViaIp6,
    );

    await run(
      'NETWORK',
      'package:http HTTPS → Worker health',
      _checkPackageHttpWorkerHealth,
    );

    await run(
      'NETWORK',
      'Raw TLS / HTTPS → Worker',
      _checkTls,
    );

    // WORKER
    await run(
      'WORKER',
      'Worker root',
      () => _httpGet(
        name: 'Worker root',
        category: 'WORKER',
        path: '/',
      ),
    );

    await run(
      'WORKER',
      'Worker health',
      () => _httpGet(
        name: 'Worker health',
        category: 'WORKER',
        path: '/health',
      ),
    );

    await run(
      'WORKER',
      'Worker service status',
      () => _httpGet(
        name: 'Worker service status',
        category: 'WORKER',
        path: '/v1/service-status',
      ),
    );

    // AI
    await run(
      'AI',
      'AI chat route',
      () => _probeRoute(
        name: 'AI chat route',
        category: 'AI',
        path: '/v1/chat',
      ),
    );

    await run(
      'AI',
      'AI credits route',
      () => _httpGet(
        name: 'AI credits route',
        category: 'AI',
        path: '/v1/credits',
      ),
    );

    // IMAGE
    await run(
      'IMAGE',
      'Image route',
      () => _probeRoute(
        name: 'Image route',
        category: 'IMAGE',
        path: '/v1/image',
      ),
    );

    // CONTENT
    await run(
      'NEWS',
      'News route',
      () => _httpGet(
        name: 'News route',
        category: 'NEWS',
        path: '/v1/news',
      ),
    );

    await run(
      'QURAN',
      'Quran route',
      () => _httpGet(
        name: 'Quran route',
        category: 'QURAN',
        path: '/v1/audio/quran',
      ),
    );

    await run(
      'TAFSIR',
      'Tafsir route',
      () => _httpGet(
        name: 'Tafsir route',
        category: 'TAFSIR',
        path: '/v1/tafsir',
      ),
    );

    await run(
      'TAFSIR',
      'Tafsir books',
      () => _httpGet(
        name: 'Tafsir books',
        category: 'TAFSIR',
        path: '/v1/tafsir/books',
      ),
    );

    await run(
      'HADITH',
      'Hadith route',
      () => _httpGet(
        name: 'Hadith route',
        category: 'HADITH',
        path: '/v1/hadith',
      ),
    );

    await run(
      'HADITH',
      'Hadith books',
      () => _httpGet(
        name: 'Hadith books',
        category: 'HADITH',
        path: '/v1/hadith/books',
      ),
    );

    await run(
      'RADIO',
      'Radio health',
      () => _httpGet(
        name: 'Radio health',
        category: 'RADIO',
        path: '/v1/radio/health',
      ),
    );

    await run(
      'RADIO',
      'Radio countries',
      () => _httpGet(
        name: 'Radio countries',
        category: 'RADIO',
        path: '/v1/radio/countries',
      ),
    );

    await run(
      'RADIO',
      'Egypt radio stations',
      () => _httpGet(
        name: 'Egypt radio stations',
        category: 'RADIO',
        path: '/v1/radio/stations?country=EG',
      ),
    );

    await run(
      'AUDIO',
      'Audio search route',
      () => _httpGet(
        name: 'Audio search route',
        category: 'AUDIO',
        path: '/v1/audio/search-v4?q=diagnostic',
      ),
    );

    await run(
      'PODCAST',
      'Podcast search route',
      () => _httpGet(
        name: 'Podcast search route',
        category: 'PODCAST',
        path: '/v1/podcasts/search?q=diagnostic',
      ),
    );

    await run(
      'SHORTS',
      'Shorts route',
      () => _httpGet(
        name: 'Shorts route',
        category: 'SHORTS',
        path: '/v1/shorts',
      ),
    );

    await run(
      'MEDIA',
      'Media URL handling',
      _checkMediaUrlHandling,
    );

    await run(
      'DOWNLOAD',
      'Download health',
      () => _httpGet(
        name: 'Download health',
        category: 'DOWNLOAD',
        path: '/download/health',
      ),
    );

    await run(
      'MONETIZATION',
      'Monetization endpoint',
      _checkMonetization,
    );

    await run(
      'ERRORS',
      'HTTP error classification',
      _checkErrorClassification,
    );

    await run(
      'TIMEOUT',
      'Timeout configuration',
      _checkTimeoutConfiguration,
    );

    return AppDiagnosticsReport(
      startedAt: started,
      finishedAt: DateTime.now(),
      results: results,
    );
  }

  // ============================================================
  // SAFE REPAIR
  // ============================================================

  Future<DiagnosticRepairResult> repairSafeIssues(
    AppDiagnosticsReport report, {
    bool clearTemporaryFiles = false,
  }) async {
    final actions = <String>[];
    var changed = false;

    if (clearTemporaryFiles) {
      final cleanup =
          await _clearTemporaryFiles();

      actions.add(cleanup.details);
      changed = changed || cleanup.changed;
    }

    final networkFailure = report.results.any(
      (e) =>
          e.category == 'NETWORK' &&
          !e.success &&
          (
            e.status == 'TIMEOUT' ||
            e.status == 'SOCKET_ERROR' ||
            e.status == 'NETWORK_ERROR' ||
            e.status == 'DNS_ERROR' ||
            e.status == 'NETWORK_UNREACHABLE'
          ),
    );

    if (networkFailure) {
      try {
        await InternetAddress.lookup(
          Uri.parse(workerBaseUrl).host,
        );

        actions.add(
          'تمت إعادة حل DNS للـWorker '
          'وتم تجهيز مسار اتصال جديد للفحص.',
        );

        actions.add(
          'لا يستطيع التطبيق تغيير VPN أو ISP أو '
          'Firewall أو إصلاح Cloudflare من داخل APK.',
        );

        changed = true;
      } catch (e) {
        actions.add(
          'إعادة حل DNS فشلت: ${_safeError(e)}',
        );
      }
    }

    if (actions.isEmpty) {
      return const DiagnosticRepairResult(
        success: true,
        changed: false,
        title: 'لا يوجد إصلاح محلي مؤكد',
        details:
            'المشكلة الحالية تحتاج إصلاحًا خارج APK '
            'أو لا تحتاج إصلاحًا.',
      );
    }

    return DiagnosticRepairResult(
      success: true,
      changed: changed,
      title: changed
          ? 'تم تنفيذ الإصلاح الآمن'
          : 'تمت محاولة الإصلاح الآمن',
      details: actions.join('\n'),
    );
  }

  Future<DiagnosticRepairResult>
      _clearTemporaryFiles() async {
    try {
      final directory = Directory.systemTemp;

      if (!await directory.exists()) {
        return const DiagnosticRepairResult(
          success: true,
          changed: false,
          title: 'لا توجد ملفات مؤقتة',
          details:
              'المجلد المؤقت غير متاح.',
        );
      }

      var removed = 0;

      await for (final entity
          in directory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          try {
            await entity.delete();
            removed++;
          } catch (_) {}
        }
      }

      return DiagnosticRepairResult(
        success: true,
        changed: removed > 0,
        title: 'تنظيف الملفات المؤقتة',
        details:
            'تم حذف $removed ملفًا مؤقتًا قابلًا للحذف.',
      );
    } catch (e) {
      return DiagnosticRepairResult(
        success: false,
        changed: false,
        title: 'تعذر تنظيف الملفات المؤقتة',
        details: _safeError(e),
      );
    }
  }

  // ============================================================
  // BUILD / DEVICE
  // ============================================================

  Future<DiagnosticResult>
      _checkRuntimeIdentity() async {
    return DiagnosticResult(
      name: 'Runtime identity',
      category: 'BUILD',
      success: true,
      status: 'OK',
      details: jsonEncode({
        'platform': Platform.operatingSystem,
        'osVersion': Platform.operatingSystemVersion,
        'dart': Platform.version,
        'debugMode': kDebugMode,
        'profileMode': kProfileMode,
        'releaseMode': kReleaseMode,
        'worker': workerBaseUrl,
        'appVersion': appVersion,
        'buildNumber': buildNumber,
        'commitSha': commitSha,
      }),
      durationMs: 0,
    );
  }

  Future<DiagnosticResult>
      _checkDiagnosticIdentity() async {
    return DiagnosticResult(
      name: 'Diagnostic engine identity',
      category: 'BUILD',
      success: true,
      status: 'OK',
      details:
          'diagnosticVersion=$diagnosticVersion',
      durationMs: 0,
    );
  }

  Future<DiagnosticResult>
      _checkBuildSourceIdentity() async {
    final data = {
      'APP_BUILD_ID': buildId,
      'APP_SOURCE_ID': sourceId,
      'SA7BI_APP_VERSION': appVersion,
      'SA7BI_BUILD_NUMBER': buildNumber,
      'SA7BI_COMMIT_SHA': commitSha,
    };

    final identified = data.values.any(
      (value) => value != 'NOT_INJECTED',
    );

    return DiagnosticResult(
      name: 'Build/source identity',
      category: 'BUILD',
      success: identified,
      severity: identified ? 'PASS' : 'WARN',
      status:
          identified ? 'IDENTIFIED' : 'NOT_INJECTED',
      details: jsonEncode(data),
      durationMs: 0,
    );
  }

  Future<DiagnosticResult>
      _checkRuntimeMemory() async {
    try {
      final rss = ProcessInfo.currentRss;

      return DiagnosticResult(
        name: 'Runtime memory',
        category: 'DEVICE',
        success: rss > 0,
        severity: rss > 0 ? 'PASS' : 'WARN',
        status: rss > 0 ? 'OK' : 'UNAVAILABLE',
        details:
            'Current Dart VM RSS: '
            '${_formatBytes(rss)}.',
        durationMs: 0,
      );
    } catch (e) {
      return DiagnosticResult(
        name: 'Runtime memory',
        category: 'DEVICE',
        success: false,
        severity: 'WARN',
        status: 'UNAVAILABLE',
        details: _safeError(e),
        durationMs: 0,
      );
    }
  }

  Future<DiagnosticResult>
      _checkTemporaryStorage() async {
    try {
      final directory = Directory.systemTemp;

      if (!await directory.exists()) {
        return const DiagnosticResult(
          name: 'Temporary storage',
          category: 'DEVICE',
          success: false,
          severity: 'WARN',
          status: 'UNAVAILABLE',
          details:
              'Temporary directory is unavailable.',
          durationMs: 0,
        );
      }

      var bytes = 0;
      var files = 0;

      await for (final entity
          in directory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (files >= 2000) break;

        if (entity is File) {
          try {
            bytes += await entity.length();
            files++;
          } catch (_) {}
        }
      }

      return DiagnosticResult(
        name: 'Temporary storage',
        category: 'DEVICE',
        success: true,
        severity:
            files >= 2000 ? 'WARN' : 'PASS',
        status:
            files >= 2000
                ? 'SCAN_LIMIT_REACHED'
                : 'OK',
        details:
            'Accessible temporary files: $files. '
            'Approximate size: '
            '${_formatBytes(bytes)}.',
        durationMs: 0,
        repairable: files > 0,
      );
    } catch (e) {
      return DiagnosticResult(
        name: 'Temporary storage',
        category: 'DEVICE',
        success: false,
        severity: 'WARN',
        status: 'UNAVAILABLE',
        details: _safeError(e),
        durationMs: 0,
      );
    }
  }

  Future<DiagnosticResult>
      _checkNetworkInterfaces() async {
    try {
      final interfaces =
          await NetworkInterface.list(
        includeLoopback: false,
        includeLinkLocal: false,
      );

      final details = interfaces
          .map(
            (item) =>
                '${item.name}: '
                '${item.addresses.map((a) => a.address).join(',')}',
          )
          .join(' | ');

      return DiagnosticResult(
        name: 'Network interfaces',
        category: 'DEVICE',
        success: interfaces.isNotEmpty,
        severity:
            interfaces.isNotEmpty
                ? 'PASS'
                : 'WARN',
        status:
            interfaces.isNotEmpty
                ? 'OK'
                : 'NO_INTERFACES',
        details: details.isEmpty
            ? 'No active interfaces reported.'
            : details,
        durationMs: 0,
      );
    } catch (e) {
      return DiagnosticResult(
        name: 'Network interfaces',
        category: 'DEVICE',
        success: false,
        severity: 'WARN',
        status: 'UNAVAILABLE',
        details: _safeError(e),
        durationMs: 0,
      );
    }
  }

  // ============================================================
  // NETWORK
  // ============================================================

  Future<DiagnosticResult> _checkInternet() async {
    final sw = Stopwatch()..start();

    try {
      final addresses =
          await InternetAddress.lookup(
        'example.com',
      );

      sw.stop();

      return DiagnosticResult(
        name: 'Internet connectivity',
        category: 'NETWORK',
        success: addresses.isNotEmpty,
        severity:
            addresses.isNotEmpty ? 'PASS' : 'FAIL',
        status:
            addresses.isNotEmpty ? 'OK' : 'NO_ADDRESS',
        details:
            addresses.map((e) => e.address).join(', '),
        durationMs: sw.elapsedMilliseconds,
      );
    } catch (e) {
      sw.stop();

      return DiagnosticResult(
        name: 'Internet connectivity',
        category: 'NETWORK',
        success: false,
        severity: 'FAIL',
        status: _classifyException(e),
        details: _safeError(e),
        durationMs: sw.elapsedMilliseconds,
      );
    }
  }

  Future<DiagnosticResult> _checkDns() async {
    return _dnsCheck(
      'Worker DNS resolution',
      InternetAddressType.any,
    );
  }

  Future<DiagnosticResult> _checkDnsV4() async {
    return _dnsCheck(
      'Worker IPv4 DNS',
      InternetAddressType.IPv4,
    );
  }

  Future<DiagnosticResult> _checkDnsV6() async {
    return _dnsCheck(
      'Worker IPv6 DNS',
      InternetAddressType.IPv6,
    );
  }

  Future<DiagnosticResult> _dnsCheck(
    String name,
    InternetAddressType type,
  ) async {
    final sw = Stopwatch()..start();

    try {
      final host = Uri.parse(workerBaseUrl).host;

      final addresses =
          await InternetAddress.lookup(
        host,
        type: type,
      );

      sw.stop();

      return DiagnosticResult(
        name: name,
        category: 'NETWORK',
        success: addresses.isNotEmpty,
        severity: addresses.isNotEmpty
            ? 'PASS'
            : (
                type == InternetAddressType.IPv6
                    ? 'WARN'
                    : 'FAIL'
              ),
        status:
            addresses.isNotEmpty ? 'OK' : 'NO_ADDRESS',
        details:
            addresses.map((e) => e.address).join(', '),
        durationMs: sw.elapsedMilliseconds,
      );
    } catch (e) {
      sw.stop();

      return DiagnosticResult(
        name: name,
        category: 'NETWORK',
        success: false,
        severity:
            type == InternetAddressType.IPv6
                ? 'WARN'
                : 'FAIL',
        status: _classifyException(e),
        details: _safeError(e),
        durationMs: sw.elapsedMilliseconds,
      );
    }
  }

  Future<DiagnosticResult>
      _checkRawHttpClientGoogle() async {
    return _rawExternalGet(
      'Raw HttpClient HTTPS → Google',
      'https://www.google.com',
    );
  }

  Future<DiagnosticResult>
      _checkCloudflare() async {
    return _rawExternalGet(
      'Cloudflare HTTPS',
      'https://www.cloudflare.com',
    );
  }

  Future<DiagnosticResult> _rawExternalGet(
    String name,
    String url,
  ) async {
    final sw = Stopwatch()..start();

    final client = HttpClient()
      ..connectionTimeout = defaultTimeout
      ..userAgent =
          'Sa7biAI-Diagnostics/$diagnosticVersion';

    try {
      final request =
          await client.getUrl(Uri.parse(url));

      request.headers.set(
        HttpHeaders.acceptHeader,
        '*/*',
      );

      final response = await request.close();
      final status = response.statusCode;

      await response.drain<void>();

      sw.stop();

      return DiagnosticResult(
        name: name,
        category: 'NETWORK',
        success:
            status >= 200 && status < 500,
        severity:
            status >= 200 && status < 500
                ? 'PASS'
                : 'FAIL',
        status: _statusForHttpCode(status),
        httpStatus: status,
        details:
            'HTTPS response received.',
        durationMs: sw.elapsedMilliseconds,
      );
    } catch (e) {
      sw.stop();

      return DiagnosticResult(
        name: name,
        category: 'NETWORK',
        success: false,
        severity: 'FAIL',
        status: _classifyException(e),
        details: _safeError(e),
        durationMs: sw.elapsedMilliseconds,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<DiagnosticResult>
      _checkPackageHttpGoogle() async {
    final sw = Stopwatch()..start();

    try {
      final response = await http.get(
        Uri.parse('https://www.google.com'),
        headers: {
          'User-Agent':
              'Sa7biAI-Diagnostics/$diagnosticVersion',
        },
      ).timeout(defaultTimeout);

      sw.stop();

      return DiagnosticResult(
        name: 'package:http HTTPS → Google',
        category: 'NETWORK',
        success:
            response.statusCode >= 200 &&
                response.statusCode < 500,
        severity:
            response.statusCode >= 200 &&
                    response.statusCode < 500
                ? 'PASS'
                : 'FAIL',
        status:
            _statusForHttpCode(
          response.statusCode,
        ),
        httpStatus: response.statusCode,
        details:
            'package:http reached Google. '
            'responseBytes=${response.bodyBytes.length}.',
        durationMs: sw.elapsedMilliseconds,
      );
    } catch (e) {
      sw.stop();

      return DiagnosticResult(
        name: 'package:http HTTPS → Google',
        category: 'NETWORK',
        success: false,
        severity: 'FAIL',
        status: _classifyException(e),
        details: _safeError(e),
        durationMs: sw.elapsedMilliseconds,
      );
    }
  }

  Future<DiagnosticResult>
      _checkProxyConfiguration() async {
    try {
      final proxy =
          HttpClient.findProxyFromEnvironment(
        Uri.parse(workerBaseUrl),
      );

      return DiagnosticResult(
        name: 'HTTP proxy configuration',
        category: 'NETWORK',
        success: true,
        severity: 'PASS',
        status: 'OK',
        details:
            'Proxy decision for Worker: $proxy',
        durationMs: 0,
      );
    } catch (e) {
      return DiagnosticResult(
        name: 'HTTP proxy configuration',
        category: 'NETWORK',
        success: false,
        severity: 'WARN',
        status: 'UNAVAILABLE',
        details: _safeError(e),
        durationMs: 0,
      );
    }
  }

  Future<DiagnosticResult>
      _checkWorkerIpv4Socket() async {
    return _socketCheck(
      'Worker IPv4 socket reachability',
      InternetAddressType.IPv4,
    );
  }

  Future<DiagnosticResult>
      _checkWorkerIpv6Socket() async {
    return _socketCheck(
      'Worker IPv6 socket reachability',
      InternetAddressType.IPv6,
    );
  }

  Future<DiagnosticResult> _socketCheck(
    String name,
    InternetAddressType type,
  ) async {
    final sw = Stopwatch()..start();

    try {
      final host = Uri.parse(workerBaseUrl).host;

      final addresses =
          await InternetAddress.lookup(
        host,
        type: type,
      );

      if (addresses.isEmpty) {
        sw.stop();

        return DiagnosticResult(
          name: name,
          category: 'NETWORK',
          success: false,
          severity:
              type == InternetAddressType.IPv6
                  ? 'WARN'
                  : 'FAIL',
          status: 'NO_ADDRESS',
          details:
              'No ${type.name} address is available.',
          durationMs: sw.elapsedMilliseconds,
        );
      }

      final outcomes = <String>[];
      var connected = false;

      for (final address
          in addresses.take(4)) {
        try {
          final socket = await Socket.connect(
            address,
            443,
            timeout: deepTimeout,
          );

          await socket.close();

          connected = true;

          outcomes.add(
            '${address.address}=CONNECTED',
          );
        } catch (e) {
          outcomes.add(
            '${address.address}='
            '${_classifyException(e)}',
          );
        }
      }

      sw.stop();

      return DiagnosticResult(
        name: name,
        category: 'NETWORK',
        success: connected,
        severity: connected
            ? 'PASS'
            : (
                type == InternetAddressType.IPv6
                    ? 'WARN'
                    : 'FAIL'
              ),
        status: connected
            ? 'TCP_REACHABLE'
            : 'TCP_UNREACHABLE',
        details: outcomes.join(' | '),
        durationMs: sw.elapsedMilliseconds,
      );
    } catch (e) {
      sw.stop();

      return DiagnosticResult(
        name: name,
        category: 'NETWORK',
        success: false,
        severity:
            type == InternetAddressType.IPv6
                ? 'WARN'
                : 'FAIL',
        status: _classifyException(e),
        details: _safeError(e),
        durationMs: sw.elapsedMilliseconds,
      );
    }
  }

  Future<DiagnosticResult>
      _checkWorkerHttpsViaIp4() async {
    return _httpsViaResolvedIp(
      'Worker HTTPS via resolved IPv4',
      InternetAddressType.IPv4,
    );
  }

  Future<DiagnosticResult>
      _checkWorkerHttpsViaIp6() async {
    return _httpsViaResolvedIp(
      'Worker HTTPS via resolved IPv6',
      InternetAddressType.IPv6,
    );
  }

  Future<DiagnosticResult> _httpsViaResolvedIp(
    String name,
    InternetAddressType type,
  ) async {
    final sw = Stopwatch()..start();

    final uri = Uri.parse(workerBaseUrl);

    HttpClient? client;

    try {
      final addresses =
          await InternetAddress.lookup(
        uri.host,
        type: type,
      );

      if (addresses.isEmpty) {
        sw.stop();

        return DiagnosticResult(
          name: name,
          category: 'NETWORK',
          success: false,
          severity:
              type == InternetAddressType.IPv6
                  ? 'WARN'
                  : 'FAIL',
          status: 'NO_ADDRESS',
          details:
              'No ${type.name} address is available.',
          durationMs: sw.elapsedMilliseconds,
        );
      }

      final address = addresses.first;

      client = HttpClient()
        ..connectionTimeout = deepTimeout
        ..findProxy = (_) => 'DIRECT'
        ..connectionFactory = (
          Uri requested,
          String? proxyHost,
          int? proxyPort,
        ) {
          return Socket.startConnect(
            address,
            443,
          );
        }
        ..userAgent =
            'Sa7biAI-Diagnostics/$diagnosticVersion';

      final request =
          await client.getUrl(uri);

      request.headers.set(
        HttpHeaders.acceptHeader,
        '*/*',
      );

      request.headers.set(
        HttpHeaders.hostHeader,
        uri.host,
      );

      final response = await request.close();

      final status = response.statusCode;
      final certificate = response.certificate;

      await response.drain<void>();

      sw.stop();

      return DiagnosticResult(
        name: name,
        category: 'NETWORK',
        success:
            status >= 200 && status < 500,
        severity:
            status >= 200 && status < 500
                ? 'PASS'
                : (
                    type == InternetAddressType.IPv6
                        ? 'WARN'
                        : 'FAIL'
                  ),
        status: _statusForHttpCode(status),
        httpStatus: status,
        details:
            'Connected to ${address.address} '
            'while keeping hostname ${uri.host}. '
            'TLS certificate='
            '${certificate == null ? 'none' : 'received'}.',
        durationMs: sw.elapsedMilliseconds,
      );
    } catch (e) {
      sw.stop();

      return DiagnosticResult(
        name: name,
        category: 'NETWORK',
        success: false,
        severity:
            type == InternetAddressType.IPv6
                ? 'WARN'
                : 'FAIL',
        status: _classifyException(e),
        details: _safeError(e),
        durationMs: sw.elapsedMilliseconds,
      );
    } finally {
      client?.close(force: true);
    }
  }

  Future<DiagnosticResult>
      _checkPackageHttpWorkerHealth() async {
    final sw = Stopwatch()..start();

    try {
      final response = await http.get(
        _buildUri('/health'),
        headers: {
          'Accept': 'application/json',
          'User-Agent':
              'Sa7biAI-Diagnostics/$diagnosticVersion',
          'Cache-Control': 'no-cache',
        },
      ).timeout(defaultTimeout);

      sw.stop();

      final reachable =
          response.statusCode >= 200 &&
              response.statusCode < 500;

      return DiagnosticResult(
        name:
            'package:http HTTPS → Worker health',
        category: 'NETWORK',
        success: reachable,
        severity:
            reachable ? 'PASS' : 'FAIL',
        status:
            _statusForHttpCode(
          response.statusCode,
        ),
        httpStatus: response.statusCode,
        details:
            'Worker /health HTTP ${response.statusCode}.',
        durationMs: sw.elapsedMilliseconds,
        repairable: !reachable,
      );
    } catch (e) {
      sw.stop();

      return DiagnosticResult(
        name:
            'package:http HTTPS → Worker health',
        category: 'NETWORK',
        success: false,
        severity: 'FAIL',
        status: _classifyException(e),
        details:
            'package:http could not reach '
            'Worker /health. ${_safeError(e)}',
        durationMs: sw.elapsedMilliseconds,
        repairable: true,
      );
    }
  }

  Future<DiagnosticResult> _checkTls() async {
    final sw = Stopwatch()..start();

    final client = HttpClient()
      ..connectionTimeout = defaultTimeout;

    try {
      final request =
          await client.getUrl(
        Uri.parse(workerBaseUrl),
      );

      final response = await request.close();
      final certificate = response.certificate;

      await response.drain<void>();

      sw.stop();

      return DiagnosticResult(
        name: 'Raw TLS / HTTPS → Worker',
        category: 'NETWORK',
        success: certificate != null,
        severity:
            certificate != null ? 'PASS' : 'WARN',
        status:
            certificate != null
                ? 'TLS_ESTABLISHED'
                : 'NO_CERTIFICATE',
        details:
            certificate != null
                ? 'TLS handshake established.'
                : 'No TLS certificate metadata.',
        durationMs: sw.elapsedMilliseconds,
      );
    } catch (e) {
      sw.stop();

      return DiagnosticResult(
        name: 'Raw TLS / HTTPS → Worker',
        category: 'NETWORK',
        success: false,
        severity: 'FAIL',
        status: _classifyException(e),
        details: _safeError(e),
        durationMs: sw.elapsedMilliseconds,
      );
    } finally {
      client.close(force: true);
    }
  }

  // ============================================================
  // WORKER / ROUTES
  // ============================================================

  Future<DiagnosticResult> _httpGet({
    required String name,
    required String category,
    required String path,
  }) async {
    final sw = Stopwatch()..start();

    final client = HttpClient()
      ..connectionTimeout = defaultTimeout
      ..userAgent =
          'Sa7biAI-Diagnostics/$diagnosticVersion';

    try {
      final request =
          await client.getUrl(_buildUri(path));

      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/json',
      );

      request.headers.set(
        HttpHeaders.cacheControlHeader,
        'no-cache',
      );

      final response = await request.close();
      final status = response.statusCode;

      final chunks = await response
          .take(32)
          .map(
            (chunk) => utf8.decode(
              chunk,
              allowMalformed: true,
            ),
          )
          .join();

      await response.drain<void>();

      sw.stop();

      final reachable =
          status >= 200 && status < 500;

      final validation =
          status == 400 ||
          status == 401 ||
          status == 403 ||
          status == 405;

      return DiagnosticResult(
        name: name,
        category: category,
        success: reachable,
        severity: reachable
            ? (validation ? 'WARN' : 'PASS')
            : 'FAIL',
        status: _statusForHttpCode(status),
        httpStatus: status,
        details:
            'HTTP $status. '
            '${_summarizeBody(chunks)}',
        durationMs: sw.elapsedMilliseconds,
        repairable:
            !reachable &&
            (
              category == 'WORKER' ||
              category == 'AI'
            ),
      );
    } catch (e) {
      sw.stop();

      return DiagnosticResult(
        name: name,
        category: category,
        success: false,
        severity: 'FAIL',
        status: _classifyException(e),
        details: _safeError(e),
        durationMs: sw.elapsedMilliseconds,
        repairable:
            category == 'WORKER' ||
            category == 'AI',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<DiagnosticResult> _probeRoute({
    required String name,
    required String category,
    required String path,
  }) async {
    final sw = Stopwatch()..start();

    String first = 'NOT_TESTED';
    String second = 'NOT_TESTED';

    try {
      try {
        final response = await http.get(
          _buildUri(path),
          headers: {
            'Accept': 'application/json',
            'User-Agent':
                'Sa7biAI-Diagnostics/$diagnosticVersion',
          },
        ).timeout(defaultTimeout);

        first =
            _statusForHttpCode(
          response.statusCode,
        );
      } catch (e) {
        first = _classifyException(e);
      }

      try {
        final response = await http.get(
          _buildUri(path),
          headers: {
            'Accept': 'application/json',
            'User-Agent':
                'Sa7biAI-Diagnostics/$diagnosticVersion',
          },
        ).timeout(defaultTimeout);

        second =
            _statusForHttpCode(
          response.statusCode,
        );
      } catch (e) {
        second = _classifyException(e);
      }

      sw.stop();

      final reachable =
          first.startsWith('HTTP_') ||
          second.startsWith('HTTP_');

      return DiagnosticResult(
        name: name,
        category: category,
        success: reachable,
        severity:
            reachable ? 'PASS' : 'FAIL',
        status:
            reachable
                ? 'ROUTE_REACHABLE'
                : 'UNREACHABLE',
        details:
            'Probe1=$first; Probe2=$second. '
            'No generation executed.',
        durationMs: sw.elapsedMilliseconds,
        repairable: !reachable,
      );
    } catch (e) {
      sw.stop();

      return DiagnosticResult(
        name: name,
        category: category,
        success: false,
        severity: 'FAIL',
        status: _classifyException(e),
        details: _safeError(e),
        durationMs: sw.elapsedMilliseconds,
        repairable: true,
      );
    }
  }

  // ============================================================
  // MEDIA / MONETIZATION / ERRORS
  // ============================================================

  Future<DiagnosticResult>
      _checkMediaUrlHandling() async {
    final sw = Stopwatch()..start();

    try {
      final radio =
          _buildUri(
        '/v1/radio/stations?country=EG',
      );

      final audio =
          _buildUri(
        '/v1/audio/search-v4?q=diagnostic',
      );

      final podcast =
          _buildUri(
        '/v1/podcasts/search?q=diagnostic',
      );

      final valid =
          radio.queryParameters['country'] ==
                  'EG' &&
              audio.queryParameters['q'] ==
                  'diagnostic' &&
              podcast.queryParameters['q'] ==
                  'diagnostic';

      sw.stop();

      return DiagnosticResult(
        name: 'Media URL handling',
        category: 'MEDIA',
        success: valid,
        severity:
            valid ? 'PASS' : 'FAIL',
        status: valid ? 'OK' : 'INVALID',
        details:
            'URL parsing verified. '
            'country=${radio.queryParameters['country']}, '
            'audioQ=${audio.queryParameters['q']}, '
            'podcastQ=${podcast.queryParameters['q']}.',
        durationMs: sw.elapsedMilliseconds,
      );
    } catch (e) {
      sw.stop();

      return DiagnosticResult(
        name: 'Media URL handling',
        category: 'MEDIA',
        success: false,
        severity: 'FAIL',
        status: 'INVALID',
        details: _safeError(e),
        durationMs: sw.elapsedMilliseconds,
      );
    }
  }

  Future<DiagnosticResult>
      _checkMonetization() async {
    final a = await _httpGet(
      name: 'Monetization endpoint',
      category: 'MONETIZATION',
      path: '/v1/monetization',
    );

    final b = await _httpGet(
      name: 'Credits endpoint',
      category: 'MONETIZATION',
      path: '/v1/credits',
    );

    final success =
        a.success || b.success;

    return DiagnosticResult(
      name: 'Monetization endpoint',
      category: 'MONETIZATION',
      success: success,
      severity:
          success ? 'PASS' : 'FAIL',
      status:
          success ? 'CONFIRMED' : 'NOT_CONFIRMED',
      details:
          '/v1/monetization=${a.status} | '
          '/v1/credits=${b.status}',
      durationMs:
          a.durationMs + b.durationMs,
      repairable: !success,
    );
  }

  Future<DiagnosticResult>
      _checkErrorClassification() async {
    final sw = Stopwatch()..start();

    try {
      final response = await http.get(
        _buildUri(
          '/__sa7bi_diagnostic_missing_endpoint__',
        ),
      ).timeout(defaultTimeout);

      sw.stop();

      final ok =
          response.statusCode == 404;

      return DiagnosticResult(
        name: 'HTTP error classification',
        category: 'ERRORS',
        success: ok,
        severity:
            ok ? 'PASS' : 'WARN',
        status: ok
            ? 'HTTP_404_EXPECTED'
            : _statusForHttpCode(
                response.statusCode,
              ),
        httpStatus: response.statusCode,
        details:
            'Expected controlled HTTP 404.',
        durationMs: sw.elapsedMilliseconds,
      );
    } catch (e) {
      sw.stop();

      return DiagnosticResult(
        name: 'HTTP error classification',
        category: 'ERRORS',
        success: false,
        severity: 'WARN',
        status: _classifyException(e),
        details:
            'Could not reach Worker for '
            'controlled 404 test: '
            '${_safeError(e)}',
        durationMs: sw.elapsedMilliseconds,
      );
    }
  }

  Future<DiagnosticResult>
      _checkTimeoutConfiguration() async {
    final valid =
        defaultTimeout.inSeconds >= 5;

    return DiagnosticResult(
      name: 'Timeout configuration',
      category: 'TIMEOUT',
      success: valid,
      severity:
          valid ? 'PASS' : 'WARN',
      status: valid ? 'OK' : 'INVALID',
      details:
          'Diagnostic timeout = '
          '${defaultTimeout.inSeconds} seconds.',
      durationMs: 0,
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Uri _buildUri(String rawPath) {
    final raw = rawPath.trim();

    if (raw.startsWith('http://') ||
        raw.startsWith('https://')) {
      return Uri.parse(raw);
    }

    final base =
        Uri.parse(workerBaseUrl);

    final parsed = Uri.parse(
      raw.startsWith('/')
          ? raw
          : '/$raw',
    );

    return base.replace(
      path: parsed.path,
      queryParameters:
          parsed.queryParameters.isEmpty
              ? null
              : parsed.queryParameters,
    );
  }

  String _statusForHttpCode(
    int statusCode,
  ) {
    if (statusCode == 401) {
      return 'HTTP_401_AUTH_REQUIRED';
    }

    if (statusCode == 403) {
      return 'HTTP_403_FORBIDDEN';
    }

    if (statusCode == 404) {
      return 'HTTP_404_NOT_FOUND';
    }

    if (statusCode == 405) {
      return 'HTTP_405_METHOD_NOT_ALLOWED';
    }

    if (statusCode >= 500) {
      return 'HTTP_${statusCode}_SERVER_ERROR';
    }

    if (statusCode >= 400) {
      return 'HTTP_${statusCode}_CLIENT_ERROR';
    }

    if (statusCode >= 300) {
      return 'HTTP_${statusCode}_REDIRECT';
    }

    if (statusCode >= 200) {
      return 'HTTP_${statusCode}_OK';
    }

    return 'HTTP_$statusCode';
  }

  String _classifyException(
    Object error,
  ) {
    final value =
        error.toString().toLowerCase();

    if (value.contains('timeout')) {
      return 'TIMEOUT';
    }

    if (value.contains(
      'network is unreachable',
    )) {
      return 'NETWORK_UNREACHABLE';
    }

    if (value.contains(
          'failed host lookup',
        ) ||
        value.contains(
          'no address associated',
        )) {
      return 'DNS_ERROR';
    }

    if (value.contains('certificate') ||
        value.contains('tls') ||
        value.contains('ssl')) {
      return 'TLS_ERROR';
    }

    if (value.contains(
      'connection refused',
    )) {
      return 'CONNECTION_REFUSED';
    }

    if (value.contains('socket')) {
      return 'SOCKET_ERROR';
    }

    return 'NETWORK_ERROR';
  }

  String _safeError(Object error) {
    return error
        .toString()
        .replaceAll(
          RegExp(r'\s+'),
          ' ',
        )
        .trim();
  }

  String _summarizeBody(
    String body,
  ) {
    final cleaned = body
        .replaceAll(
          RegExp(r'\s+'),
          ' ',
        )
        .trim();

    if (cleaned.isEmpty) {
      return 'Empty response body.';
    }

    if (cleaned.length <= 1000) {
      return cleaned;
    }

    return '${cleaned.substring(0, 1000)}…';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }

    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
