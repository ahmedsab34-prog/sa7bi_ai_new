part of '../app_diagnostics_service.dart';

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

  /// true عندما يكون الفشل نتيجة مباشرة لفشل
  /// طبقة أعلى، وليس خطأ مستقلًا في هذه الخدمة.
  final bool blocked;

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
    this.blocked = false,
  });

  bool get isWarning =>
      severity == 'WARN';

  bool get isFailure =>
      severity == 'FAIL';

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
      'blocked': blocked,
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
      results
          .where(
            (item) =>
                item.severity == 'PASS',
          )
          .length;

  int get warnings =>
      results
          .where(
            (item) =>
                item.severity == 'WARN',
          )
          .length;

  int get failed =>
      results
          .where(
            (item) =>
                item.severity == 'FAIL',
          )
          .length;

  int get blocked =>
      results
          .where(
            (item) => item.blocked,
          )
          .length;

  int get total =>
      results.length;

  Duration get duration =>
      finishedAt.difference(
        startedAt,
      );

  bool get hasRepairableIssues =>
      results.any(
        (item) =>
            !item.success &&
            item.repairable &&
            !item.blocked,
      );

  DiagnosticResult? _find(
    String name,
  ) {
    for (final item in results) {
      if (item.name == name) {
        return item;
      }
    }

    return null;
  }

  // ============================================================
  // ROOT CAUSE
  // ============================================================

  String get rootCauseCode {
    final transport =
        _find(
      'Network transport identity',
    );

    final internet =
        _find(
      'Internet HTTPS control',
    );

    final dns =
        _find(
      'Worker DNS resolution',
    );

    final worker =
        _find(
      'Worker HTTPS health',
    );

    final build =
        _find(
      'Build/source identity',
    );

    if (build != null &&
        !build.success) {
      return 'BUILD_IDENTITY';
    }

    if (transport != null &&
        transport.severity == 'WARN') {
      return 'NETWORK_TRANSPORT_FALLBACK';
    }

    if (internet != null &&
        !internet.success) {
      return 'NETWORK_INTERNET_HTTPS';
    }

    if (dns != null &&
        !dns.success) {
      return 'NETWORK_DNS';
    }

    if (worker != null &&
        !worker.success) {
      final status =
          worker.status;

      if (status == 'TIMEOUT') {
        return 'NETWORK_WORKER_TIMEOUT';
      }

      if (status == 'TLS_ERROR') {
        return 'NETWORK_TLS';
      }

      if (status == 'DNS_ERROR') {
        return 'NETWORK_DNS';
      }

      return 'NETWORK_WORKER_HTTPS';
    }

    final workerFailures =
        results.where(
      (item) =>
          item.category == 'WORKER' &&
          !item.success &&
          !item.blocked,
    );

    if (workerFailures.isNotEmpty) {
      return 'BACKEND_WORKER';
    }

    final aiFailures =
        results.where(
      (item) =>
          item.category == 'AI' &&
          !item.success &&
          !item.blocked,
    );

    if (aiFailures.isNotEmpty) {
      return 'FEATURE_AI';
    }

    final featureFailures =
        results.where(
      (item) =>
          !item.success &&
          !item.blocked &&
          (
            item.category == 'NEWS' ||
            item.category == 'QURAN' ||
            item.category == 'TAFSIR' ||
            item.category == 'HADITH' ||
            item.category == 'RADIO' ||
            item.category == 'AUDIO' ||
            item.category == 'PODCAST' ||
            item.category == 'SHORTS'
          ),
    );

    if (featureFailures.isNotEmpty) {
      return 'FEATURE_SERVICE';
    }

    return 'NO_ROOT_FAILURE';
  }

  String get rootCause {
    switch (rootCauseCode) {
      case 'BUILD_IDENTITY':
        return
            'هوية النسخة غير مكتملة. '
            'لا يمكن إثبات أن الـAPK مبني من المصدر '
            'والـcommit المقصودين.';

      case 'NETWORK_TRANSPORT_FALLBACK':
        return
            'التطبيق يعمل بدون Network transport '
            'المطلوب. راجع Sa7biNetworkClient.';

      case 'NETWORK_INTERNET_HTTPS':
        return
            'طبقة HTTPS العامة نفسها فاشلة. '
            'قبل فحص Worker يجب إصلاح مسار الشبكة '
            'على الجهاز أو النقل المستخدم.';

      case 'NETWORK_DNS':
        return
            'اسم Worker لا يتم حله عبر DNS. '
            'المشكلة قبل الوصول إلى Cloudflare.';

      case 'NETWORK_WORKER_TIMEOUT':
        return
            'HTTPS إلى Worker انتهى بمهلة. '
            'هذا يثبت مشكلة في مسار HTTPS/الشبكة، '
            'وليس دليلًا على أن كود AI نفسه هو السبب.';

      case 'NETWORK_TLS':
        return
            'الاتصال بـWorker يصل إلى مرحلة TLS '
            'لكن المصافحة لا تكتمل.';

      case 'NETWORK_WORKER_HTTPS':
        return
            'تعذر الوصول إلى Worker عبر HTTPS '
            'من Network Client المستخدم فعليًا.';

      case 'BACKEND_WORKER':
        return
            'الاتصال بالـWorker يعمل، لكن route '
            'من routes الخاصة بالـbackend فاشل.';

      case 'FEATURE_AI':
        return
            'الشبكة والـWorker يعملان، لكن route '
            'خاص بالـAI فاشل.';

      case 'FEATURE_SERVICE':
        return
            'الشبكة والـWorker يعملان، لكن إحدى '
            'خدمات التطبيق نفسها لا تستجيب.';

      default:
        return
            'لم يتم اكتشاف Root Failure '
            'في الاختبارات الحالية.';
    }
  }

  String get primaryProblem =>
      rootCause;

  List<DiagnosticResult>
      get slowestResults {
    final copy =
        List<DiagnosticResult>.from(
      results,
    );

    copy.sort(
      (a, b) =>
          b.durationMs.compareTo(
        a.durationMs,
      ),
    );

    return copy.take(5).toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'reportVersion':
          AppDiagnosticsService
              .diagnosticVersion,

      'startedAt':
          startedAt.toIso8601String(),

      'finishedAt':
          finishedAt.toIso8601String(),

      'durationMs':
          duration.inMilliseconds,

      'passed': passed,
      'warnings': warnings,
      'failed': failed,
      'blocked': blocked,
      'total': total,

      'rootCauseCode':
          rootCauseCode,

      'primaryProblem':
          primaryProblem,

      'repairableIssues':
          results
              .where(
                (item) =>
                    !item.success &&
                    item.repairable &&
                    !item.blocked,
              )
              .map(
                (item) => item.name,
              )
              .toList(),

      'buildIdentity': {
        'appBuildId':
            AppDiagnosticsService
                .buildId,
        'sourceId':
            AppDiagnosticsService
                .sourceId,
        'appVersion':
            AppDiagnosticsService
                .appVersion,
        'buildNumber':
            AppDiagnosticsService
                .buildNumber,
        'commitSha':
            AppDiagnosticsService
                .commitSha,
      },

      'networkTransport':
          Sa7biNetworkClient
              .transportName,

      'results':
          results
              .map(
                (item) =>
                    item.toJson(),
              )
              .toList(),

      'slowestTests':
          slowestResults
              .map(
                (item) => {
                  'name':
                      item.name,
                  'durationMs':
                      item.durationMs,
                  'status':
                      item.status,
                },
              )
              .toList(),
    };
  }

  String toPrettyJson() {
    return const JsonEncoder
        .withIndent('  ')
        .convert(
      toJson(),
    );
  }

  String toTextReport() {
    final buffer =
        StringBuffer();

    buffer.writeln(
      '========================================',
    );
    buffer.writeln(
      'SA7BI AI DIAGNOSTIC REPORT',
    );
    buffer.writeln(
      '========================================',
    );

    buffer.writeln(
      'Report version: '
      '${AppDiagnosticsService.diagnosticVersion}',
    );

    buffer.writeln(
      'Started: '
      '${startedAt.toLocal().toIso8601String()}',
    );

    buffer.writeln(
      'Finished: '
      '${finishedAt.toLocal().toIso8601String()}',
    );

    buffer.writeln(
      'Duration: '
      '${duration.inMilliseconds} ms',
    );

    buffer.writeln();

    buffer.writeln('SUMMARY');
    buffer.writeln(
      'Passed: $passed',
    );
    buffer.writeln(
      'Warnings: $warnings',
    );
    buffer.writeln(
      'Failed: $failed',
    );
    buffer.writeln(
      'Blocked: $blocked',
    );
    buffer.writeln(
      'Total: $total',
    );

    buffer.writeln();

    buffer.writeln(
      'ROOT CAUSE CODE',
    );
    buffer.writeln(
      rootCauseCode,
    );

    buffer.writeln();

    buffer.writeln(
      'PRIMARY PROBLEM',
    );
    buffer.writeln(
      primaryProblem,
    );

    buffer.writeln();

    buffer.writeln(
      'BUILD IDENTITY',
    );

    buffer.writeln(
      'APP_BUILD_ID: '
      '${AppDiagnosticsService.buildId}',
    );

    buffer.writeln(
      'APP_SOURCE_ID: '
      '${AppDiagnosticsService.sourceId}',
    );

    buffer.writeln(
      'SA7BI_APP_VERSION: '
      '${AppDiagnosticsService.appVersion}',
    );

    buffer.writeln(
      'SA7BI_BUILD_NUMBER: '
      '${AppDiagnosticsService.buildNumber}',
    );

    buffer.writeln(
      'SA7BI_COMMIT_SHA: '
      '${AppDiagnosticsService.commitSha}',
    );

    buffer.writeln();

    buffer.writeln(
      'NETWORK TRANSPORT',
    );

    buffer.writeln(
      Sa7biNetworkClient
          .transportName,
    );

    buffer.writeln();

    buffer.writeln(
      'RESULTS',
    );

    buffer.writeln(
      '----------------------------------------',
    );

    for (final result
        in results) {
      buffer.writeln(
        '[${result.severity}] '
        '${result.category} | '
        '${result.name}',
      );

      buffer.writeln(
        'Status: ${result.status}',
      );

      buffer.writeln(
        'HTTP: '
        '${result.httpStatus ?? '-'}',
      );

      buffer.writeln(
        'Duration: '
        '${result.durationMs} ms',
      );

      buffer.writeln(
        'Blocked: '
        '${result.blocked}',
      );

      buffer.writeln(
        'Repairable: '
        '${result.repairable}',
      );

      buffer.writeln(
        'Details: '
        '${result.details}',
      );

      buffer.writeln();
    }

    buffer.writeln(
      'SLOWEST TESTS',
    );

    buffer.writeln(
      '----------------------------------------',
    );

    for (final result
        in slowestResults) {
      buffer.writeln(
        '${result.durationMs} ms | '
        '${result.status} | '
        '${result.name}',
      );
    }

    buffer.writeln();

    buffer.writeln(
      '========================================',
    );

    buffer.writeln(
      'END OF REPORT',
    );

    buffer.writeln(
      '========================================',
    );

    return buffer.toString();
  }
}
