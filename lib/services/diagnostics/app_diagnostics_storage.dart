part of '../app_diagnostics_service.dart';

extension AppDiagnosticsStorageChecks
on AppDiagnosticsService {
/// يختبر التخزين المحلي فعليًا:
/// كتابة قيمة تجريبية، قراءتها، ثم حذفها.
///
/// يستخدم مفتاحًا فريدًا للاختبار ولا يمسح بيانات المستخدم.
Future<DiagnosticResult>
_checkLocalStorageRoundTrip() async {
final stopwatch = Stopwatch()..start();

final preferences =
    await SharedPreferences.getInstance();

final key =
    '__sa7bi_diagnostic_storage_${DateTime.now().microsecondsSinceEpoch}';

const value =
    'sa7bi_storage_test_v1';

var writeSucceeded = false;
var readSucceeded = false;
var deleteSucceeded = false;
String? observedValue;
String? errorMessage;

try {
  writeSucceeded =
      await preferences.setString(key, value);

  observedValue = preferences.getString(key);

  readSucceeded =
      writeSucceeded && observedValue == value;
} catch (error) {
  errorMessage = error.toString();
} finally {
  try {
    deleteSucceeded =
        await preferences.remove(key);
  } catch (error) {
    errorMessage ??= error.toString();
  }
}

stopwatch.stop();

final success = writeSucceeded &&
    readSucceeded &&
    deleteSucceeded;

final details = <String>[
  'storage=SharedPreferences',
  'write=$writeSucceeded',
  'read=$readSucceeded',
  'valueMatched=${observedValue == value}',
  'delete=$deleteSucceeded',
  if (errorMessage != null)
    'error=${errorMessage.replaceAll(RegExp(r'\s+'), ' ')}',
  success
      ? 'التخزين المحلي اجتاز اختبار الكتابة والقراءة والحذف.'
      : 'فشل جزء من اختبار التخزين المحلي؛ راجع تفاصيل النتيجة.',
  'هذا الاختبار لا يثبت أن المحتوى الإعلامي أو الصوتي محفوظ للأوفلاين.',
].join('; ');

return DiagnosticResult(
  name: 'Local storage write/read/delete',
  category: 'OFFLINE',
  success: success,
  severity: success ? 'PASS' : 'FAIL',
  status: success
      ? 'LOCAL_STORAGE_OK'
      : 'LOCAL_STORAGE_FAILED',
  details: details,
  durationMs: stopwatch.elapsedMilliseconds,
  repairable: false,
);

}
}
