part of '../app_diagnostics_service.dart';

extension AppDiagnosticsNetworkChecks on AppDiagnosticsService {
  // ============================================================
  // BUILD IDENTITY
  // ============================================================

  Future<DiagnosticResult> _checkRuntimeIdentity() async {
    final release = kReleaseMode;

    return DiagnosticResult(
      name: 'Runtime identity',
      category: 'BUILD',
      success: true,
      severity: 'PASS',
      status: release ? 'RELEASE' : 'DEBUG_OR_PROFILE',
      details:
          'Flutter runtime mode=${release ? 'release' : 'non-release'}.',
      durationMs: 0,
    );
  }

  Future<DiagnosticResult> _checkDiagnosticIdentity() async {
    return DiagnosticResult(
      name: 'Diagnostic engine identity',
      category: 'BUILD',
      success: true,
      severity: 'PASS',
      status: 'DIAGNOSTIC_${AppDiagnosticsService.diagnosticVersion}',
      details:
          'Diagnostic engine version '
          '${AppDiagnosticsService.diagnosticVersion}.',
      durationMs: 0,
    );
  }

  Future<DiagnosticResult> _checkBuildSourceIdentity() async {
    final buildInjected =
        AppDiagnosticsService.buildId != 'NOT_INJECTED';
    final sourceInjected =
        AppDiagnosticsService.sourceId != 'NOT_INJECTED';
    final commitInjected =
        AppDiagnosticsService.commitSha != 'NOT_INJECTED';

    final allInjected =
        buildInjected && sourceInjected && commitInjected;

    return DiagnosticResult(
      name: 'Build/source identity',
      category: 'BUILD',
      success: allInjected,
      severity: allInjected ? 'PASS' : 'WARN',
      status: allInjected ? 'INJECTED' : 'NOT_INJECTED',
      details:
          'buildId=${AppDiagnosticsService.buildId}; '
          'sourceId=${AppDiagnosticsService.sourceId}; '
          'appVersion=${AppDiagnosticsService.appVersion}; '
          'buildNumber=${AppDiagnosticsService.buildNumber}; '
          'commitSha=${AppDiagnosticsService.commitSha}.',
      durationMs: 0,
    );
  }

  // ============================================================
  // TRANSPORT IDENTITY
  // ============================================================

  Future<DiagnosticResult> _checkNetworkTransportIdentity() async {
    final name = Sa7biNetworkClient.transportName;
    final cronet = Sa7biNetworkClient.isCronet;

    return DiagnosticResult(
      name: 'Network transport identity',
      category: 'NETWORK',
      success: true,
      severity: cronet ? 'PASS' : 'WARN',
      status: name,
      details: 'networkTransport=$name; cronet=$cronet.',
      durationMs: 0,
    );
  }

  // بقية الملف موجودة كاملة في رابط الكود الخام أعلاه.
}
