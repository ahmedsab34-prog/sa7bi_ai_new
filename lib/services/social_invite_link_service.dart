
/// إنشاء وقراءة روابط دعوات المباريات الداخلية في صاحبي AI.
abstract final class SocialInviteLinkService {
  static const String scheme = 'sa7bi';
  static const String host = 'game';
  static const String invitePath = '/invite';

  static final RegExp _codePattern = RegExp(r'^[A-Z0-9]{6}$');

  static Uri buildGameInviteUri(String inviteCode) {
    final code = inviteCode.trim().toUpperCase();

    if (!_codePattern.hasMatch(code)) {
      throw ArgumentError.value(
        inviteCode,
        'inviteCode',
        'رمز الدعوة يجب أن يتكون من 6 أحرف أو أرقام.',
      );
    }

    return Uri(
      scheme: scheme,
      host: host,
      path: invitePath,
      queryParameters: <String, String>{'code': code},
    );
  }

  /// يعيد الرمز فقط للروابط الصحيحة التابعة للتطبيق.
  static String? extractInviteCode(Uri uri) {
    if (uri.scheme.toLowerCase() != scheme ||
        uri.host.toLowerCase() != host ||
        uri.path != invitePath) {
      return null;
    }

    final code = uri.queryParameters['code']?.trim().toUpperCase();
    if (code == null || !_codePattern.hasMatch(code)) return null;

    return code;
  }

  static bool isValidInviteCode(String value) {
    return _codePattern.hasMatch(value.trim().toUpperCase());
  }
}
