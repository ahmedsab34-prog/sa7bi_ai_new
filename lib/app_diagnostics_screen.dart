import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/app_diagnostics_service.dart';

class AppDiagnosticsScreen extends StatefulWidget {
  const AppDiagnosticsScreen({super.key});

  @override
  State<AppDiagnosticsScreen> createState() =>
      _AppDiagnosticsScreenState();
}

class _AppDiagnosticsScreenState
    extends State<AppDiagnosticsScreen> {
  late final AppDiagnosticsService _service;

  AppDiagnosticsReport? _report;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _service = AppDiagnosticsService();
  }

  Future<void> _runDiagnostics() async {
    if (_running) {
      return;
    }

    setState(() {
      _running = true;
      _report = null;
    });

    try {
      final report =
          await _service.runFullDiagnostics();

      if (!mounted) {
        return;
      }

      setState(() {
        _report = report;
        _running = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _running = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'حدث خطأ أثناء تشغيل التشخيص: $e',
          ),
        ),
      );
    }
  }

  Future<void> _copyFullReport() async {
    final report = _report;

    if (report == null) {
      return;
    }

    await Clipboard.setData(
      ClipboardData(
        text: report.toTextReport(),
      ),
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'تم نسخ التقرير الكامل. تقدر تلصقه هنا مباشرة.',
        ),
      ),
    );
  }

  Future<void> _copyJsonReport() async {
    final report = _report;

    if (report == null) {
      return;
    }

    await Clipboard.setData(
      ClipboardData(
        text: report.toPrettyJson(),
      ),
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'تم نسخ تقرير JSON الكامل.',
        ),
      ),
    );
  }

  Color _severityColor(DiagnosticResult result) {
    switch (result.severity) {
      case 'PASS':
        return Colors.green;
      case 'WARN':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  IconData _severityIcon(DiagnosticResult result) {
    switch (result.severity) {
      case 'PASS':
        return Icons.check_circle;
      case 'WARN':
        return Icons.warning_amber_rounded;
      default:
        return Icons.error;
    }
  }

  Future<void> _showDetails(
    DiagnosticResult result,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(result.name),
          content: SingleChildScrollView(
            child: SelectableText(
              [
                'Category: ${result.category}',
                'Severity: ${result.severity}',
                'Status: ${result.status}',
                'HTTP: ${result.httpStatus ?? '-'}',
                'Duration: ${result.durationMs} ms',
                '',
                result.details,
              ].join('\n'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(),
              child: const Text('إغلاق'),
            ),
          ],
        );
      },
    );
  }

  Widget _summaryCard() {
    final report = _report;

    if (report == null) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'ملخص التشخيص',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _SummaryItem(
                    title: 'ناجح',
                    value: '${report.passed}',
                    icon: Icons.check_circle,
                    color: Colors.green,
                  ),
                ),
                Expanded(
                  child: _SummaryItem(
                    title: 'تحذير',
                    value: '${report.warnings}',
                    icon: Icons.warning_amber_rounded,
                    color: Colors.orange,
                  ),
                ),
                Expanded(
                  child: _SummaryItem(
                    title: 'فشل',
                    value: '${report.failed}',
                    icon: Icons.error,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'الإجمالي: ${report.total}',
            ),
            const SizedBox(height: 4),
            Text(
              'مدة الفحص: '
              '${report.duration.inMilliseconds} ms',
            ),
            const SizedBox(height: 14),
            const Text(
              'المشكلة الأساسية:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            SelectableText(
              report.primaryProblem,
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButtons() {
    if (_report == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _copyFullReport,
            icon: const Icon(Icons.copy),
            label: const Text(
              'نسخ التقرير الكامل',
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _copyJsonReport,
            icon: const Icon(Icons.data_object),
            label: const Text(
              'نسخ تقرير JSON',
            ),
          ),
        ),
      ],
    );
  }

  Widget _resultCard(
    DiagnosticResult result,
  ) {
    final color = _severityColor(result);

    return Card(
      child: InkWell(
        onTap: () => _showDetails(result),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                _severityIcon(result),
                color: color,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${result.category} • '
                      '${result.severity} • '
                      '${result.status} • '
                      '${result.durationMs} ms',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      result.details,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_left,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: const [
            Icon(
              Icons.health_and_safety_outlined,
              size: 60,
            ),
            SizedBox(height: 12),
            Text(
              'لم يبدأ التشخيص بعد',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'الفحص الشامل يختبر التطبيق والاتصال '
              'والـWorker والـAI والصور والأخبار '
              'والقرآن والتفسير والحديث والراديو '
              'والبودكاست والتنزيل والتخزين والأداء.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'تشخيص صاحبي AI',
        ),
        actions: [
          if (report != null)
            IconButton(
              tooltip: 'إعادة الفحص',
              onPressed:
                  _running ? null : _runDiagnostics,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _runDiagnostics,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🛠️ فحص صاحبي AI الشامل',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'الفحص لا يغيّر إعدادات التطبيق ولا '
                        'ينفذ عمليات AI مدفوعة. وظيفته '
                        'اكتشاف مكان المشكلة وتسجيلها بالكامل.',
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        'Worker:\n'
                        '${_service.workerBaseUrl}',
                        style: const TextStyle(
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                              _running
                                  ? null
                                  : _runDiagnostics,
                          icon: _running
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.play_arrow,
                                ),
                          label: Text(
                            _running
                                ? 'جاري الفحص الشامل...'
                                : 'ابدأ الفحص الشامل',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (report == null)
                _emptyState(),
              if (report != null) ...[
                _summaryCard(),
                const SizedBox(height: 12),
                _actionButtons(),
                const SizedBox(height: 16),
                const Text(
                  'نتائج الفحص',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...report.results.map(
                  _resultCard,
                ),
                const SizedBox(height: 16),
                Card(
                  child: ExpansionTile(
                    title: const Text(
                      'عرض التقرير الكامل JSON',
                    ),
                    children: [
                      Padding(
                        padding:
                            const EdgeInsets.all(12),
                        child: SelectableText(
                          report.toPrettyJson(),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
