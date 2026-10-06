import 'package:flutter/material.dart';

import 'services/app_diagnostics_service.dart';

class AppDiagnosticsScreen extends StatefulWidget {
  const AppDiagnosticsScreen({super.key});

  @override
  State<AppDiagnosticsScreen> createState() => _AppDiagnosticsScreenState();
}

class _AppDiagnosticsScreenState extends State<AppDiagnosticsScreen> {
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

    final report = await _service.runFullDiagnostics();

    if (!mounted) {
      return;
    }

    setState(() {
      _report = report;
      _running = false;
    });
  }

  Color _statusColor(DiagnosticResult result) {
    if (result.success) {
      return Colors.green;
    }

    if (result.status == 'TIMEOUT') {
      return Colors.orange;
    }

    return Colors.red;
  }

  IconData _statusIcon(DiagnosticResult result) {
    if (result.success) {
      return Icons.check_circle;
    }

    if (result.status == 'TIMEOUT') {
      return Icons.timer_off;
    }

    return Icons.error;
  }

  Future<void> _showDetails(DiagnosticResult result) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(result.name),
          content: SingleChildScrollView(
            child: SelectableText(
              [
                'Category: ${result.category}',
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
              onPressed: () => Navigator.of(context).pop(),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ملخص التشخيص',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
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
                    title: 'فشل',
                    value: '${report.failed}',
                    icon: Icons.error,
                    color: Colors.red,
                  ),
                ),
                Expanded(
                  child: _SummaryItem(
                    title: 'الإجمالي',
                    value: '${report.results.length}',
                    icon: Icons.analytics,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(
              'بدأ: ${report.startedAt.toLocal()}\n'
              'انتهى: ${report.finishedAt.toLocal()}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultCard(DiagnosticResult result) {
    final color = _statusColor(result);

    return Card(
      child: InkWell(
        onTap: () => _showDetails(result),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                _statusIcon(result),
                color: color,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${result.category} • ${result.status} • ${result.durationMs} ms',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      result.details,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left),
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
              size: 56,
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
              'اضغط على "ابدأ التشخيص" لفحص الاتصال والـWorker '
              'والـAI والمحتوى والصوت والتنزيل وغيرها.',
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
        title: const Text('تشخيص صاحبي AI'),
        actions: [
          if (report != null)
            IconButton(
              tooltip: 'تشغيل مرة أخرى',
              onPressed: _running ? null : _runDiagnostics,
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'أداة تشخيص شاملة',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'هذه الشاشة لا تصلح أي شيء ولا تغيّر إعدادات التطبيق. '
                        'وظيفتها فقط اختبار المسارات وتسجيل النتيجة.',
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        'Worker:\n${_service.workerBaseUrl}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _running ? null : _runDiagnostics,
                          icon: _running
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.play_arrow),
                          label: Text(
                            _running
                                ? 'جاري التشخيص...'
                                : 'ابدأ التشخيص',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (report == null) _emptyState(),
              if (report != null) ...[
                _summaryCard(),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  child: Text(
                    'نتائج الاختبارات',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...report.results.map(_resultCard),
                const SizedBox(height: 16),
                Card(
                  child: ExpansionTile(
                    title: const Text('التقرير الكامل JSON'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: SelectableText(
                          report.toPrettyJson(),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
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
        Icon(icon, color: color),
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
          style: const TextStyle(fontSize: 11),
        ),
      ],
    );
  }
}
