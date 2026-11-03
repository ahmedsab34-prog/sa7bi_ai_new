/// إنشاء وقراءة روابط دعوات المباريات والمجموعات في صاحبي AI.
abstract final class SocialInviteLinkService {
  static const String scheme = 'sa7bi';

  static const String gameHost = 'game';
  static const String gameInvitePath = '/invite';

  static const String communityHost = 'community';
  static const String communityInvitePath = '/group';

  static const String webHost = 'sa7bi-ai-new.ahmedsab34.workers.dev';
  static const String webGameInvitePath = '/game/invite';
  static const String webGroupInvitePath = '/groups/invite';

  static final RegExp _codePattern = RegExp(r'^[A-Z0-9]{6}$');

  static final RegExp _uuidPattern = RegExp(
    r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$',
    caseSensitive: false,
  );

  /// رابط HTTPS موثّق يفتح التطبيق مباشرة عند تثبيته.
  static Uri buildGameInviteUri(String inviteCode) {
    final code = inviteCode.trim().toUpperCase();

    if (!_codePattern.hasMatch(code)) {
      throw ArgumentError.value(
        inviteCode,
        'inviteCode',
        'رمز الدعوة يجب أن يتكون من 6 أحرف أو أرقام.',
      );
    }

    return Uri.https(
      webHost,
      webGameInvitePath,
      <String, String>{'code': code},
    );
  }

  /// رابط HTTPS لمشاركة مجموعة عامة.
  static Uri buildGroupInviteUri(String groupId) {
    final id = groupId.trim().toLowerCase();

    if (!_uuidPattern.hasMatch(id)) {
      throw ArgumentError.value(
        groupId,
        'groupId',
        'معرّف المجموعة غير صالح.',
      );
    }

    return Uri.https(
      webHost,
      webGroupInvitePath,
      <String, String>{'groupId': id},
    );
  }

  /// رابط قديم للتوافق مع الدعوات التي أُنشئت قبل روابط HTTPS.
  static Uri buildLegacyGameInviteUri(String inviteCode) {
    final code = inviteCode.trim().toUpperCase();

    if (!_codePattern.hasMatch(code)) {
      throw ArgumentError.value(inviteCode, 'inviteCode');
    }

    return Uri(
      scheme: scheme,
      host: gameHost,
      path: gameInvitePath,
      queryParameters: <String, String>{'code': code},
    );
  }

  static Uri buildLegacyGroupInviteUri(String groupId) {
    final id = groupId.trim().toLowerCase();

    if (!_uuidPattern.hasMatch(id)) {
      throw ArgumentError.value(groupId, 'groupId');
    }

    return Uri(
      scheme: scheme,
      host: communityHost,
      path: communityInvitePath,
      queryParameters: <String, String>{'groupId': id},
    );
  }

  /// يعيد رمز المباراة فقط للروابط الصحيحة التابعة للتطبيق أو نطاقه.
  static String? extractInviteCode(Uri uri) {
    final isLegacy = uri.scheme.toLowerCase() == scheme &&
        uri.host.toLowerCase() == gameHost &&
        uri.path == gameInvitePath;

    final isVerifiedWeb = uri.scheme.toLowerCase() == 'https' &&
        uri.host.toLowerCase() == webHost &&
        uri.path == webGameInvitePath;

    if (!isLegacy && !isVerifiedWeb) return null;

    final code = uri.queryParameters['code']?.trim().toUpperCase();

    if (code == null || !_codePattern.hasMatch(code)) return null;

    return code;
  }

  /// يعيد معرّف المجموعة فقط للروابط الصحيحة التابعة للتطبيق أو نطاقه.
  static String? extractGroupInviteId(Uri uri) {
    final isLegacy = uri.scheme.toLowerCase() == scheme &&
        uri.host.toLowerCase() == communityHost &&
        uri.path == communityInvitePath;

    final isVerifiedWeb = uri.scheme.toLowerCase() == 'https' &&
        uri.host.toLowerCase() == webHost &&
        uri.path == webGroupInvitePath;

    if (!isLegacy && !isVerifiedWeb) return null;

    final id = uri.queryParameters['groupId']?.trim().toLowerCase();

    if (id == null || !_uuidPattern.hasMatch(id)) return null;

    return id;
  }

  static String buildGroupInviteMessage({
    required String groupId,
    required String groupName,
  }) {
    final link = buildGroupInviteUri(groupId);
    final name = groupName.trim().isEmpty
        ? 'المجموعة'
        : groupName.trim();

    return 'انضم إلى مجموعة "$name" على صاحبي AI 👥\n'
        'افتح الرابط للانضمام مباشرة:\n$link';
  }

  static bool isValidInviteCode(String value) {
    return _codePattern.hasMatch(value.trim().toUpperCase());
  }

  static bool isValidGroupId(String value) {
    return _uuidPattern.hasMatch(value.trim());
  }
}
