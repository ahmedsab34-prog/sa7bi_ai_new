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

  bool get isWarning => severity == 'WARN';

  bool get isFailure => severity == 'FAIL';

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
      results.where(
        (item) => item.severity == 'PASS',
      ).length;

  int get warnings =>
      results.where(
        (item) => item.severity == 'WARN',
      ).length;

  int get failed =>
      results.where(
        (item) => item.severity == 'FAIL',
      ).length;

  int get total => results.length;

  Duration get duration =>
      finishedAt.difference(startedAt);

  bool get hasRepairableIssues =>
      results.any(
        (item) =>
            !item.success &&
            item.repairable,
      );

  DiagnosticResult? _find(String name) {
    for (final item in results) {
      if (item.name == name) {
        return item;
      }
    }

    return null;
  }

  String get rootCause {
    final dns =
        _find('Worker DNS resolution');

    final ipv4 =
        _find('Worker IPv4 socket reachability');

    final ipv6 =
        _find('Worker IPv6 socket reachability');

    final https4 =
        _find('Worker HTTPS via resolved IPv4');

    final https6 =
        _find('Worker HTTPS via resolved IPv6');

    if (dns != null && !dns.success) {
      return
          'فشل حل اسم Worker عبر DNS. '
          'المشكلة في طبقة DNS قبل الوصول إلى Worker.';
    }

    if (ipv4 != null &&
        !ipv4.success &&
        ipv6 != null &&
        !ipv6.success) {
      return
          'اسم Worker يتم حله، لكن الاتصال TCP '
          'بالمنفذ 443 غير متاح عبر IPv4 وIPv6. '
          'الاحتمال الأقوى مشكلة شبكة أو VPN أو ISP '
          'أو Firewall أو مسار Cloudflare.';
    }

    if (https4?.success == true ||
        https6?.success == true) {
      return
          'الاتصال بـWorker ينجح باستخدام عنوان IP '
          'مع الاحتفاظ باسم المضيف. '
          'هذا يوجه التشخيص إلى DNS أو hostname '
          'أو proxy أو routing.';
    }

    if (ipv4?.success == true &&
        https4 != null &&
        !https4.success) {
      return
          'اتصال TCP عبر IPv4 يعمل، لكن HTTPS/TLS '
          'عبر Worker لا يعمل. يجب فحص TLS/SNI '
          'وCloudflare routing.';
    }

    if (ipv6?.success == true &&
        https6 != null &&
        !https6.success) {
      return
          'اتصال TCP عبر IPv6 يعمل، لكن HTTPS يفشل. '
          'يجب فحص IPv6 routing أو TLS.';
    }

    final failures = results
        .where(
          (item) => item.severity == 'FAIL',
        )
        .toList();

    if (failures.isNotEmpty) {
      return failures.first.details;
    }

    final warnings = results
        .where(
          (item) => item.severity == 'WARN',
        )
        .toList();

    if (warnings.isNotEmpty) {
      return warnings.first.details;
    }

    return
        'لم يتم اكتشاف مشكلة في الاختبارات الحالية.';
  }

  String get primaryProblem => rootCause;

  List<DiagnosticResult> get slowestResults {
    final copy =
        List<DiagnosticResult>.from(results);

    copy.sort(
      (a, b) =>
          b.durationMs.compareTo(a.durationMs),
    );

    return copy.take(5).toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'reportVersion':
          AppDiagnosticsService.diagnosticVersion,
      'startedAt':
          startedAt.toIso8601String(),
      'finishedAt':
          finishedAt.toIso8601String(),
      'durationMs':
          duration.inMilliseconds,
      'passed': passed,
      'warnings': warnings,
      'failed': failed,
      'total': total,
      'primaryProblem': primaryProblem,
      'rootCause': rootCause,
      'repairableIssues': results
          .where(
            (item) =>
                !item.success &&
                item.repairable,
          )
          .map(
            (item) => item.name,
          )
          .toList(),
      'results':
          results
              .map(
                (item) => item.toJson(),
              )
              .toList(),
      'slowestTests':
          slowestResults
              .map(
                (item) => {
                  'name': item.name,
                  'durationMs':
                      item.durationMs,
                  'status': item.status,
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
    buffer.writeln('Passed: $passed');
    buffer.writeln('Warnings: $warnings');
    buffer.writeln('Failed: $failed');
    buffer.writeln('Total: $total');

    buffer.writeln();

    buffer.writeln('PRIMARY PROBLEM');
    buffer.writeln(primaryProblem);

    buffer.writeln();

    buffer.writeln('BUILD IDENTITY');

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

    buffer.writeln('RESULTS');

    buffer.writeln(
      '----------------------------------------',
    );

    for (final result in results) {
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
        'Repairable: '
        '${result.repairable}',
      );

      buffer.writeln(
        'Details: '
        '${result.details}',
      );

      buffer.writeln();
    }

    buffer.writeln('SLOWEST TESTS');

    buffer.writeln(
      '----------------------------------------',
    );

    for (final result in slowestResults) {
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

    buffer.writeln('END OF REPORT');

    buffer.writeln(
      '========================================',
    );

    return buffer.toString();
  }
}
