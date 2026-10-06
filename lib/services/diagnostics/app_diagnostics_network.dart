part of '../app_diagnostics_service.dart';

extension AppDiagnosticsNetworkChecks
    on AppDiagnosticsService {
  // ============================================================
  // BUILD / DEVICE
  // ============================================================

  Future<DiagnosticResult>
      _checkRuntimeIdentity() async {
    final release = kReleaseMode;

    return DiagnosticResult(
      name: 'Runtime identity',
      category: 'BUILD',
      success: true,
      severity: 'PASS',
      status: release
          ? 'RELEASE'
          : 'DEBUG_OR_PROFILE',
      details:
          'Flutter runtime mode='
          '${release ? 'release' : 'non-release'}.',
      durationMs: 0,
    );
  }

  Future<DiagnosticResult>
      checkDiagnosticIdentity() async {
    return DiagnosticResult(
      name: 'Diagnostic engine identity',
      category: 'BUILD',
      success:
          AppDiagnosticsService.diagnosticVersion !=
              'NOT_INJECTED',
      severity: 'PASS',
      status:
          'DIAGNOSTIC'
          '${AppDiagnosticsService.diagnosticVersion}',
      details:
          'Diagnostic engine version '
          '${AppDiagnosticsService.diagnosticVersion}.',
      durationMs: 0,
    );
  }

  Future<DiagnosticResult>
      _checkBuildSourceIdentity() async {
    final injected =
        buildId != 'NOT_INJECTED' ||
        sourceId != 'NOT_INJECTED' ||
        commitSha != 'NOT_INJECTED';

    return DiagnosticResult(
      name: 'Build/source identity',
      category: 'BUILD',
      success: injected,
      severity:
          injected ? 'PASS' : 'WARN',
      status:
          injected
              ? 'INJECTED'
              : 'NOT_INJECTED',
      details:
          'buildId=$buildId; '
          'sourceId=$sourceId; '
          'appVersion=$appVersion; '
          'buildNumber=$buildNumber; '
          'commitSha=$commitSha.',
      durationMs: 0,
    );
  }

  Future<DiagnosticResult>
      _checkRuntimeMemory() async {
    return DiagnosticResult(
      name: 'Runtime memory',
      category: 'DEVICE',
      success: true,
      severity: 'PASS',
      status: 'AVAILABLE',
      details:
          'Dart VM runtime is active.',
      durationMs: 0,
    );
  }

  Future<DiagnosticResult>
      _checkTemporaryStorage() async {
    try {
      final directory =
          Directory.systemTemp;

      final exists =
          await directory.exists();

      return DiagnosticResult(
        name: 'Temporary storage',
        category: 'DEVICE',
        success: exists,
        severity:
            exists ? 'PASS' : 'WARN',
        status:
            exists
                ? 'AVAILABLE'
                : 'UNAVAILABLE',
        details:
            'systemTemp=${directory.path}',
        durationMs: 0,
      );
    } catch (error) {
      return DiagnosticResult(
        name: 'Temporary storage',
        category: 'DEVICE',
        success: false,
        severity: 'WARN',
        status: 'CHECK_ERROR',
        details: _safeError(error),
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
        includeLinkLocal: true,
      );

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
                ? 'AVAILABLE'
                : 'NONE',
        details:
            interfaces
                .map(
                  (item) => item.name,
                )
                .join(', '),
        durationMs: 0,
      );
    } catch (error) {
      return DiagnosticResult(
        name: 'Network interfaces',
        category: 'DEVICE',
        success: false,
        severity: 'WARN',
        status: 'CHECK_ERROR',
        details: _safeError(error),
        durationMs: 0,
      );
    }
  }

  // ============================================================
  // BASIC NETWORK
  // ============================================================

  Future<DiagnosticResult>
      _checkInternet() async {
    final stopwatch =
        Stopwatch()..start();

    try {
      final addresses =
          await InternetAddress.lookup(
        'example.com',
      );

      stopwatch.stop();

      return DiagnosticResult(
        name: 'Internet connectivity',
        category: 'NETWORK',
        success: addresses.isNotEmpty,
        severity:
            addresses.isNotEmpty
                ? 'PASS'
                : 'FAIL',
        status:
            addresses.isNotEmpty
                ? 'REACHABLE'
                : 'NO_ADDRESS',
        details:
            addresses
                .map(
                  (item) => item.address,
                )
                .join(', '),
        durationMs:
            stopwatch.elapsedMilliseconds,
      );
    } catch (error) {
      stopwatch.stop();

      return DiagnosticResult(
        name: 'Internet connectivity',
        category: 'NETWORK',
        success: false,
        severity: 'FAIL',
        status: _classifyException(error),
        details: _safeError(error),
        durationMs:
            stopwatch.elapsedMilliseconds,
        repairable: true,
      );
    }
  }

  Future<DiagnosticResult>
      _checkDns() async {
    return _checkDnsType(
      'Worker DNS resolution',
      InternetAddressType.any,
    );
  }

  Future<DiagnosticResult>
      _checkDnsV4() async {
    return _checkDnsType(
      'Worker IPv4 DNS',
      InternetAddressType.IPv4,
    );
  }

  Future<DiagnosticResult>
      _checkDnsV6() async {
    return _checkDnsType(
      'Worker IPv6 DNS',
      InternetAddressType.IPv6,
    );
  }

  Future<DiagnosticResult>
      _checkDnsType(
    String name,
    InternetAddressType type,
  ) async {
    final stopwatch =
        Stopwatch()..start();

    try {
      final host =
          Uri.parse(workerBaseUrl).host;

      final addresses =
          await InternetAddress.lookup(
        host,
        type: type,
      );

      stopwatch.stop();

      final success =
          addresses.isNotEmpty;

      final ipv6 =
          type == InternetAddressType.IPv6;

      return DiagnosticResult(
        name: name,
        category: 'NETWORK',
        success: success,
        severity:
            success
                ? 'PASS'
                : (ipv6 ? 'WARN' : 'FAIL'),
        status:
            success
                ? 'RESOLVED'
                : 'NO_ADDRESS',
        details:
            success
                ? addresses
                    .map(
                      (item) =>
                          item.address,
                    )
                    .join(', ')
                : 'No DNS address.',
        durationMs:
            stopwatch.elapsedMilliseconds,
      );
    } catch (error) {
      stopwatch.stop();

      final ipv6 =
          type == InternetAddressType.IPv6;

      return DiagnosticResult(
        name: name,
        category: 'NETWORK',
        success: false,
        severity:
            ipv6 ? 'WARN' : 'FAIL',
        status:
            _classifyException(error),
        details: _safeError(error),
        durationMs:
            stopwatch.elapsedMilliseconds,
        repairable: !ipv6,
      );
    }
  }

  // ============================================================
  // HTTPS
  // ============================================================

  Future<DiagnosticResult>
      _checkRawHttpClientGoogle() async {
    return _rawHttps(
      name:
          'Raw HttpClient HTTPS → Google',
      uri: Uri.parse(
        'https://www.google.com',
      ),
    );
  }

  Future<DiagnosticResult>
      _checkCloudflare() async {
    return _rawHttps(
      name: 'Cloudflare HTTPS',
      uri: Uri.parse(
        'https://www.cloudflare.com',
      ),
    );
  }

  Future<DiagnosticResult>
      _rawHttps({
    required String name,
    required Uri uri,
  }) async {
    final stopwatch =
        Stopwatch()..start();

    final client = HttpClient()
      ..connectionTimeout =
          AppDiagnosticsService.defaultTimeout
      ..userAgent =
          'Sa7biAI-Diagnostics/'
          '${AppDiagnosticsService.diagnosticVersion}';

    try {
      final request =
          await client.getUrl(uri);

      request.headers.set(
        HttpHeaders.acceptHeader,
        '*/*',
      );

      final response =
          await request.close();

      final status =
          response.statusCode;

      await response.drain<void>();

      stopwatch.stop();

      final reachable =
          status >= 200 &&
          status < 500;

      return DiagnosticResult(
        name: name,
        category: 'NETWORK',
        success: reachable,
        severity:
            reachable ? 'PASS' : 'FAIL',
        status:
            _statusForHttpCode(status),
        httpStatus: status,
        details:
            'HTTPS status=$status; '
            'host=${uri.host}.',
        durationMs:
            stopwatch.elapsedMilliseconds,
      );
    } catch (error) {
      stopwatch.stop();

      return DiagnosticResult(
        name: name,
        category: 'NETWORK',
        success: false,
        severity: 'FAIL',
        status:
            _classifyException(error),
        details: _safeError(error),
        durationMs:
            stopwatch.elapsedMilliseconds,
        repairable: true,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<DiagnosticResult>
      _checkPackageHttpGoogle() async {
    final stopwatch =
        Stopwatch()..start();

    try {
      final response =
          await http.get(
        Uri.parse(
          'https://www.google.com',
        ),
        headers: {
          'Accept': '*/*',
          'User-Agent':
              'Sa7biAI-Diagnostics/'
              '${AppDiagnosticsService.diagnosticVersion}',
        },
      ).timeout(
        AppDiagnosticsService.defaultTimeout,
      );

      stopwatch.stop();

      final success =
          response.statusCode >= 200 &&
          response.statusCode < 500;

      return DiagnosticResult(
        name:
            'package:http HTTPS → Google',
        category: 'NETWORK',
        success: success,
        severity:
            success ? 'PASS' : 'FAIL',
        status:
            _statusForHttpCode(
          response.statusCode,
        ),
        httpStatus:
            response.statusCode,
        details:
            'package:http status='
            '${response.statusCode}.',
        durationMs:
            stopwatch.elapsedMilliseconds,
      );
    } catch (error) {
      stopwatch.stop();

      return DiagnosticResult(
        name:
            'package:http HTTPS → Google',
        category: 'NETWORK',
        success: false,
        severity: 'FAIL',
        status:
            _classifyException(error),
        details:
            _safeError(error),
        durationMs:
            stopwatch.elapsedMilliseconds,
        repairable: true,
      );
    }
  }

  // ============================================================
  // SOCKET / DIRECT IP
  // ============================================================

  Future<DiagnosticResult>
      _checkWorkerIpv4Socket() async {
    return _checkWorkerSocket(
      name:
          'Worker IPv4 socket reachability',
      type: InternetAddressType.IPv4,
    );
  }

  Future<DiagnosticResult>
      _checkWorkerIpv6Socket() async {
    return _checkWorkerSocket(
      name:
          'Worker IPv6 socket reachability',
      type: InternetAddressType.IPv6,
    );
  }

  Future<DiagnosticResult>
      _checkWorkerSocket({
    required String name,
    required InternetAddressType type,
  }) async {
    final stopwatch =
        Stopwatch()..start();

    Socket? socket;

    try {
      final addresses =
          await InternetAddress.lookup(
        Uri.parse(workerBaseUrl).host,
        type: type,
      );

      if (addresses.isEmpty) {
        stopwatch.stop();

        return DiagnosticResult(
          name: name,
          category: 'NETWORK',
          success: false,
          severity:
              type ==
                      InternetAddressType.IPv6
                  ? 'WARN'
                  : 'FAIL',
          status: 'NO_ADDRESS',
          details:
              'No resolved address.',
          durationMs:
              stopwatch.elapsedMilliseconds,
        );
      }

      socket =
          await Socket.connect(
        addresses.first,
        443,
        timeout:
            AppDiagnosticsService.deepTimeout,
      );

      stopwatch.stop();

      return DiagnosticResult(
        name: name,
        category: 'NETWORK',
        success: true,
        severity: 'PASS',
        status: 'TCP_REACHABLE',
        details:
            'Connected to '
            '${addresses.first.address}:443.',
        durationMs:
            stopwatch.elapsedMilliseconds,
      );
    } catch (error) {
      stopwatch.stop();

      final ipv6 =
          type ==
              InternetAddressType.IPv6;

      return DiagnosticResult(
        name: name,
        category: 'NETWORK',
        success: false,
        severity:
            ipv6 ? 'WARN' : 'FAIL',
        status:
            _classifyException(error),
        details:
            _safeError(error),
        durationMs:
            stopwatch.elapsedMilliseconds,
      );
    } finally {
      socket?.destroy();
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

  Future<DiagnosticResult>
      _httpsViaResolvedIp(
    String name,
    InternetAddressType type,
  ) async {
    final stopwatch =
        Stopwatch()..start();

    final uri =
        Uri.parse(workerBaseUrl);

    HttpClient? client;

    try {
      final addresses =
          await InternetAddress.lookup(
        uri.host,
        type: type,
      );

      if (addresses.isEmpty) {
        stopwatch.stop();

        return DiagnosticResult(
          name: name,
          category: 'NETWORK',
          success: false,
          severity:
              type ==
                      InternetAddressType.IPv6
                  ? 'WARN'
                  : 'FAIL',
          status: 'NO_ADDRESS',
          details:
              'No ${type.name} address.',
          durationMs:
              stopwatch.elapsedMilliseconds,
        );
      }

      final address =
          addresses.first;

      client = HttpClient()
        ..connectionTimeout =
            AppDiagnosticsService.deepTimeout
        ..findProxy =
            (_) => 'DIRECT'
        ..userAgent =
            'Sa7biAI-Diagnostics/'
            '${AppDiagnosticsService.diagnosticVersion}';

      // مهم:
      // connectionFactory setter مستقل.
      // ده يمنع التباس الـ cascade.
      client.connectionFactory = (
        Uri requested,
        String? proxyHost,
        int? proxyPort,
      ) =>
          Socket.startConnect(
        address,
        443,
      );

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

      final response =
          await request.close();

      final status =
          response.statusCode;

      final certificate =
          response.certificate;

      await response.drain<void>();

      stopwatch.stop();

      final reachable =
          status >= 200 &&
          status < 500;

      return DiagnosticResult(
        name: name,
        category: 'NETWORK',
        success: reachable,
        severity:
            reachable
                ? 'PASS'
                : (
                    type ==
                            InternetAddressType
                                .IPv6
                        ? 'WARN'
                        : 'FAIL'
                  ),
        status:
            _statusForHttpCode(status),
        httpStatus: status,
        details:
            'Connected to '
            '${address.address} '
            'while keeping hostname '
            '${uri.host}. '
            'TLS certificate='
            '${certificate == null ? 'none' : 'received'}.',
        durationMs:
            stopwatch.elapsedMilliseconds,
      );
    } catch (error) {
      stopwatch.stop();

      return DiagnosticResult(
        name: name,
        category: 'NETWORK',
        success: false,
        severity:
            type ==
                    InternetAddressType.IPv6
                ? 'WARN'
                : 'FAIL',
        status:
            _classifyException(error),
        details:
            _safeError(error),
        durationMs:
            stopwatch.elapsedMilliseconds,
      );
    } finally {
      client?.close(force: true);
    }
  }

  Future<DiagnosticResult>
      _checkPackageHttpWorkerHealth() async {
    final stopwatch =
        Stopwatch()..start();

    try {
      final response =
          await http.get(
        _buildUri('/health'),
        headers: {
          'Accept':
              'application/json',
          'User-Agent':
              'Sa7biAI-Diagnostics/'
              '${AppDiagnosticsService.diagnosticVersion}',
          'Cache-Control':
              'no-cache',
        },
      ).timeout(
        AppDiagnosticsService.defaultTimeout,
      );

      stopwatch.stop();

      final success =
          response.statusCode >= 200 &&
          response.statusCode < 500;

      return DiagnosticResult(
        name:
            'package:http HTTPS → Worker health',
        category: 'NETWORK',
        success: success,
        severity:
            success ? 'PASS' : 'FAIL',
        status:
            _statusForHttpCode(
          response.statusCode,
        ),
        httpStatus:
            response.statusCode,
        details:
            'Worker /health HTTP '
            '${response.statusCode}.',
        durationMs:
            stopwatch.elapsedMilliseconds,
        repairable: !success,
      );
    } catch (error) {
      stopwatch.stop();

      return DiagnosticResult(
        name:
            'package:http HTTPS → Worker health',
        category: 'NETWORK',
        success: false,
        severity: 'FAIL',
        status:
            _classifyException(error),
        details:
            'package:http could not '
            'reach Worker /health. '
            '${_safeError(error)}',
        durationMs:
            stopwatch.elapsedMilliseconds,
        repairable: true,
      );
    }
  }

  Future<DiagnosticResult>
      _checkTls() async {
    final stopwatch =
        Stopwatch()..start();

    final client = HttpClient()
      ..connectionTimeout =
          AppDiagnosticsService.defaultTimeout;

    try {
      final request =
          await client.getUrl(
        Uri.parse(workerBaseUrl),
      );

      final response =
          await request.close();

      final certificate =
          response.certificate;

      await response.drain<void>();

      stopwatch.stop();

      return DiagnosticResult(
        name:
            'Raw TLS / HTTPS → Worker',
        category: 'NETWORK',
        success:
            certificate != null,
        severity:
            certificate != null
                ? 'PASS'
                : 'WARN',
        status:
            certificate != null
                ? 'TLS_ESTABLISHED'
                : 'NO_CERTIFICATE',
        details:
            certificate != null
                ? 'TLS handshake established.'
                : 'No TLS certificate metadata.',
        durationMs:
            stopwatch.elapsedMilliseconds,
      );
    } catch (error) {
      stopwatch.stop();

      return DiagnosticResult(
        name:
            'Raw TLS / HTTPS → Worker',
        category: 'NETWORK',
        success: false,
        severity: 'FAIL',
        status:
            _classifyException(error),
        details:
            _safeError(error),
        durationMs:
            stopwatch.elapsedMilliseconds,
      );
    } finally {
      client.close(force: true);
    }
  }

  // ============================================================
  // HTTP PROXY
  // ============================================================

  Future<DiagnosticResult>
      _checkProxyConfiguration() async {
    try {
      final proxy =
          HttpClient.findProxyFromEnvironment(
        Uri.parse(workerBaseUrl),
      );

      final direct =
          proxy.trim() == 'DIRECT';

      return DiagnosticResult(
        name:
            'HTTP proxy configuration',
        category: 'NETWORK',
        success: true,
        severity:
            direct ? 'PASS' : 'WARN',
        status:
            direct ? 'DIRECT' : 'PROXY',
        details:
            'findProxy returned: $proxy',
        durationMs: 0,
      );
    } catch (error) {
      return DiagnosticResult(
        name:
            'HTTP proxy configuration',
        category: 'NETWORK',
        success: false,
        severity: 'WARN',
        status: 'CHECK_ERROR',
        details: _safeError(error),
        durationMs: 0,
      );
    }
  }
}
