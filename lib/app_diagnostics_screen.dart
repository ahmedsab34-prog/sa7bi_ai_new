import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/app_diagnostics_quick_service.dart';
import 'services/app_diagnostics_service.dart';
import 'services/app_diagnostics_v5_service.dart';

class AppDiagnosticsScreen extends StatefulWidget {
  const AppDiagnosticsScreen({super.key});

  @override
  State<AppDiagnosticsScreen> createState() =>
      _AppDiagnosticsScreenState();
}

class _AppDiagnosticsScreenState
    extends State<AppDiagnosticsScreen> {
  late final AppDiagnosticsV5Service _service;
  late final AppDiagnosticsQuickService _quickService;

  AppDiagnosticsV5Report? _report;
  AppDiagnosticsQuickReport? _quickReport;

  final List<DiagnosticResult> _liveResults = [];

  bool _running = false;
  bool _quickRunning = false;
  bool _quickCompleted = false;

  @override
  void initState() {
    super.initState();

    _service = AppDiagnosticsV5Service();
    _quickService = AppDiagnosticsQuickService();

    // يبدأ الفحص السريع تلقائيًا بعد أول إطار للشاشة.
    // الفحص الشامل v5 لا يبدأ تلقائيًا.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _runQuickDiagnostics();
      }
    });
  }

  Future<void> _runQuickDiagnostics() async {
    if (_running || _quickRunning) return;

    setState(() {
      _quickRunning = true;
      _quickCompleted = false;
      _quickReport = null;
      _report = null;
      _liveResults.clear();
    });

    try {
      final quickReport =
          await _quickService.runQuickDiagnostics(
        onResult: (result) {
          if (!mounted) return;

          setState(() {
            _liveResults.add(result);
          });
        },
      );

      if (!mounted) return;

      setState(() {
        _quickReport = quickReport;
        _quickRunning = false;
        _quickCompleted = true;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _quickRunning = false;
        _quickCompleted = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر إكمال الفحص السريع: $error'),
        ),
      );
    }
  }

  Future<void> _runDiagnostics() async {
    if (_running || _quickRunning) return;

    setState(() {
      _running = true;
      _quickReport = null;
      _quickCompleted = false;
      _report = null;
      _liveResults.clear();
    });

    try {
      final report = await _service.runFullDiagnostics(
        onResult: (result) {
          if (!mounted) return;

          setState(() {
            _liveResults.add(result);
          });
        },
      );

      if (!mounted) return;

      setState(() {
        _report = report;
        _running = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _running = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر إكمال التشخيص الشامل: $error'),
        ),
      );
    }
  }

  Future<void> _copyTextReport() async {
    final report = _report;
    if (report == null) return;

    await Clipboard.setData(
      ClipboardData(text: report.toTextReport()),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ التقرير النصي الكامل.'),
      ),
    );
  }

  Future<void> _copyJsonReport() async {
    final report = _report;
    if (report == null) return;

    await Clipboard.setData(
      ClipboardData(text: report.toPrettyJson()),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ تقرير JSON الكامل.'),
      ),
    );
  }

  bool _isNotTested(DiagnosticResult result) {
    return result.blocked ||
        result.status.startsWith('NOT_TESTED');
  }

  Color _resultColor(DiagnosticResult result) {
    if (_isNotTested(result)) {
      return Colors.blueGrey;
    }

    switch (result.severity) {
      case 'PASS':
        return Colors.green;
      case 'WARN':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  IconData _resultIcon(DiagnosticResult result) {
    if (_isNotTested(result)) {
      return Icons.help_outline_rounded;
    }

    switch (result.severity) {
      case 'PASS':
        return Icons.check_circle_rounded;
      case 'WARN':
        return Icons.warning_amber_rounded;
      default:
        return Icons.error_rounded;
    }
  }

  String _resultLabel(DiagnosticResult result) {
    if (_isNotTested(result)) return 'لم يُختبر';

    switch (result.severity) {
      case 'PASS':
        return 'ناجح';
      case 'WARN':
        return 'تحذير';
      default:
        return 'فشل';
    }
  }

  Future<void> _showDetails(DiagnosticResult result) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            result.name,
            textDirection: TextDirection.rtl,
          ),
          content: SingleChildScrollView(
            child: SelectableText(
              [
                'القسم: ${result.category}',
                'النتيجة: ${_resultLabel(result)}',
                'الحالة: ${result.status}',
                'HTTP: ${result.httpStatus ?? '-'}',
                'المدة: ${result.durationMs} ms',
                'لم يُختبر بسبب قيد آمن: ${result.blocked}',
                '',
                result.details,
              ].join('\n'),
              textDirection: TextDirection.ltr,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(),
              child: const Text('إغلاق'),
            ),
          ],
        );
      },
    );
  }

  Widget _quickSummaryCard() {
    final report = _quickReport;
    if (report == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'ملخص الفحص السريع التلقائي',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SummaryValue(
                    title: 'ناجح',
                    value: report.passed,
                    color: Colors.green,
                    icon: Icons.check_circle,
                  ),
                ),
                Expanded(
                  child: _SummaryValue(
                    title: 'تحذير',
                    value: report.warnings,
                    color: Colors.orange,
                    icon: Icons.warning_amber_rounded,
                  ),
                ),
                Expanded(
                  child: _SummaryValue(
                    title: 'فشل',
                    value: report.failed,
                    color: Colors.red,
                    icon: Icons.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'الإجمالي: ${report.total}',
              textDirection: TextDirection.rtl,
            ),
            Text(
              'المدة: ${report.duration.inSeconds} ثانية',
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 6),
            Text(
              'Root cause: ${report.rootCauseCode}',
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.blueGrey,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'هذا فحص أولي للاتصال وهوية النسخة. '
              'للتقرير الكامل شغّل الفحص الشامل v5.',
              textDirection: TextDirection.rtl,
              style: TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard() {
    final report = _report;
    if (report == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'ملخص التشخيص الشامل v5',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _SummaryValue(
                    title: 'ناجح',
                    value: report.passed,
                    color: Colors.green,
                    icon: Icons.check_circle,
                  ),
                ),
                Expanded(
                  child: _SummaryValue(
                    title: 'تحذير',
                    value: report.warnings,
                    color: Colors.orange,
                    icon: Icons.warning_amber_rounded,
                  ),
                ),
                Expanded(
                  child: _SummaryValue(
                    title: 'فشل',
                    value: report.failed,
                    color: Colors.red,
                    icon: Icons.error,
                  ),
                ),
                Expanded(
                  child: _SummaryValue(
                    title: 'لم يُختبر',
                    value: report.notTested,
                    color: Colors.blueGrey,
                    icon: Icons.help_outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'الإجمالي: ${report.total}',
              textDirection: TextDirection.rtl,
            ),
            Text(
              'مدة الفحص: ${report.duration.inSeconds} ثانية',
              textDirection: TextDirection.rtl,
            ),
            const Divider(height: 22),
            const Text(
              'المشكلة الأساسية',
              textDirection: TextDirection.rtl,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            SelectableText(
              report.primaryProblem,
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 8),
            Text(
              'Root cause: ${report.rootCauseCode}',
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.blueGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultCard(DiagnosticResult result) {
    final color = _resultColor(result);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showDetails(result),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                _resultIcon(result),
                color: color,
                size: 27,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.name,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${result.category} • '
                      '${_resultLabel(result)} • '
                      '${result.durationMs} ms',
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        fontSize: 10,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      result.details,
                      textDirection: TextDirection.rtl,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(
              Icons.health_and_safety_outlined,
              size: 56,
            ),
            SizedBox(height: 12),
            Text(
              'لم يبدأ الفحص بعد',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'عند فتح هذه الشاشة يبدأ الفحص السريع تلقائيًا. '
              'بعده يمكنك تشغيل الفحص الشامل v5 يدويًا.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _safetyNote() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.shield_outlined,
              color: Colors.blueGrey,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                'الفحص السريع والشامل لا يرسلان طلب AI مدفوعًا، '
                'ولا ينشران محتوى، ولا ينشئان مباريات، '
                'ولا يشغّلان صوتًا مسموعًا. '
                'الاختبارات التي تحتاج تفاعلًا أو رصيدًا تظهر '
                'بوضوح تحت حالة «لم يُختبر».',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final visibleResults =
        report?.results ?? _liveResults;

    final isAnyCheckRunning = _running || _quickRunning;

    final resultsTitle = _running
        ? 'نتائج الفحص الشامل المباشرة'
        : _quickRunning
            ? 'نتائج الفحص السريع المباشرة'
            : report != null
                ? 'نتائج الفحص الشامل'
                : 'نتائج الفحص السريع التلقائي';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تشخيص صاحبي AI'),
          actions: [
            if (_quickReport != null || report != null)
              IconButton(
                tooltip: report != null
                    ? 'إعادة الفحص الشامل'
                    : 'إعادة الفحص السريع',
                onPressed: isAnyCheckRunning
                    ? null
                    : report != null
                        ? _runDiagnostics
                        : _runQuickDiagnostics,
                icon: const Icon(Icons.refresh_rounded),
              ),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _runQuickDiagnostics,
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          '🛠️ فحص صاحبي AI الشامل v5',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'عند فتح الشاشة يبدأ فحص سريع تلقائي '
                          'للاتصال وهوية النسخة والخادمين. '
                          'الفحص الشامل v5 يبدأ فقط عند الضغط على الزر.',
                          textDirection: TextDirection.rtl,
                        ),
                        const SizedBox(height: 12),
                        SelectableText(
                          'Primary Worker:\n'
                          '${_service.workerBaseUrl}',
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(fontSize: 11),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'فحص تلقائي سريع',
                          key: ValueKey('automatic-quick-check'),
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (_quickRunning) ...[
                          const LinearProgressIndicator(),
                          const SizedBox(height: 5),
                          Text(
                            'تم تنفيذ ${_liveResults.length} اختبار سريع حتى الآن',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ] else if (_quickCompleted) ...[
                          const Text(
                            'اكتمل الفحص السريع التلقائي.',
                            textDirection: TextDirection.rtl,
                            style: TextStyle(fontSize: 11),
                          ),
                        ] else ...[
                          const Text(
                            'سيبدأ الفحص تلقائيًا عند فتح الشاشة.',
                            textDirection: TextDirection.rtl,
                            style: TextStyle(fontSize: 11),
                          ),
                        ],
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: isAnyCheckRunning
                                ? null
                                : _runDiagnostics,
                            icon: isAnyCheckRunning
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.play_arrow_rounded),
                            label: Text(
                              _running
                                  ? 'جاري الفحص الشامل...'
                                  : _quickRunning
                                      ? 'جاري الفحص السريع...'
                                      : 'ابدأ الفحص الشامل',
                            ),
                          ),
                        ),
                        if (_running) ...[
                          const SizedBox(height: 12),
                          const LinearProgressIndicator(),
                          const SizedBox(height: 5),
                          Text(
                            'تم تنفيذ ${_liveResults.length} اختبار حتى الآن',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                _safetyNote(),
                if (_quickReport != null && report == null) ...[
                  _quickSummaryCard(),
                ],
                if (report != null) ...[
                  _summaryCard(),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _copyTextReport,
                          icon: const Icon(Icons.copy_rounded),
                          label: const Text('نسخ التقرير'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _copyJsonReport,
                          icon: const Icon(Icons.data_object),
                          label: const Text('نسخ JSON'),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  resultsTitle,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (visibleResults.isEmpty) _emptyState(),
                ...visibleResults.map(_resultCard),
                if (report != null) ...[
                  const SizedBox(height: 10),
                  Card(
                    child: ExpansionTile(
                      title: const Text('عرض تقرير JSON'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: SelectableText(
                            report.toPrettyJson(),
                            textDirection: TextDirection.ltr,
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
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String title;
  final int value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 19),
        const SizedBox(height: 4),
        Text(
          '$value',
          style: TextStyle(
            color: color,
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          title,
          style: const TextStyle(fontSize: 10),
        ),
      ],
    );
  }
}
