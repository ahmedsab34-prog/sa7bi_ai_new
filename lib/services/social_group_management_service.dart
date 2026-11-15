import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'sa7bi_network_client.dart';
import 'social_community_service.dart';
import 'social_guest_session_service.dart';
import 'social_session_storage.dart';

/// خدمات المجموعات الخاصة وإدارة العضوية في صاحبي Connect.
/// تستخدم نفس جلسة المستخدم الموجودة في بقية خدمات Connect.
class SocialGroupManagementService {
  SocialGroupManagementService._();

  static final SocialGroupManagementService instance =
      SocialGroupManagementService._();

  static const Duration _timeout = Duration(seconds: 20);
  String? _token;
  Future<void>? _loadingToken;

  bool get isSignedIn => _token != null && _token!.isNotEmpty;

  Future<void> initialize() async {
    if (isSignedIn) return;
    _loadingToken ??= _loadToken();
    try {
      await _loadingToken;
    } finally {
      _loadingToken = null;
    }
  }

  Future<void> refreshSession() async {
    _token = null;
    await SocialGuestSessionService.instance.ensureSession();
    await initialize();
  }

  Future<void> _loadToken() async {
    await SocialGuestSessionService.instance.ensureSession();
    _token = await SocialSessionStorage.instance.readToken();
  }

  Future<List<SocialManagedGroup>> getMyGroups() async {
    final result = await _request('GET', '/v1/social/groups/mine');
    final values = result['groups'];
    if (values is! List) return const [];

    return values
        .whereType<Map>()
        .map((value) => SocialManagedGroup.fromJson(
              Map<String, dynamic>.from(value),
            ))
        .toList(growable: false);
  }

  Future<SocialManagedGroup> createPrivateGroup({
    required String name,
    String description = '',
  }) async {
    final cleanName = name.trim();
    final cleanDescription = description.trim();

    if (cleanName.length < 3 || cleanName.length > 40) {
      throw const SocialGroupManagementException(
        'INVALID_GROUP_NAME',
        'اسم المجموعة يجب أن يكون من 3 إلى 40 حرفًا.',
      );
    }
    if (cleanDescription.length > 160) {
      throw const SocialGroupManagementException(
        'INVALID_GROUP_DESCRIPTION',
        'وصف المجموعة لا يمكن أن يزيد عن 160 حرفًا.',
      );
    }

    final result = await _request(
      'POST',
      '/v1/social/groups/private',
      body: {
        'name': cleanName,
        'description': cleanDescription,
      },
    );

    return SocialManagedGroup.fromJson(_asMap(result['group']));
  }

  Future<SocialManagedGroup> joinByInviteCode(String code) async {
    final normalized = code.trim().toUpperCase();
    if (!RegExp(r'^[A-HJ-NP-Z2-9]{10}$').hasMatch(normalized)) {
      throw const SocialGroupManagementException(
        'GROUP_INVITE_INVALID',
        'رمز الدعوة يجب أن يتكون من 10 أحرف أو أرقام.',
      );
    }

    final result = await _request(
      'POST',
      '/v1/social/groups/join-invite',
      body: {'code': normalized},
    );
    return SocialManagedGroup.fromJson(_asMap(result['group']));
  }

  Future<SocialGroupInvite> createInvite(String groupId) async {
    _validateUuid(groupId);
    final result = await _request(
      'POST',
      '/v1/social/groups/$groupId/invites',
      body: const {},
    );
    return SocialGroupInvite.fromJson(_asMap(result['invite']));
  }

  Future<List<SocialManagedMember>> getMembers(String groupId) async {
    _validateUuid(groupId);
    final result = await _request(
      'GET',
      '/v1/social/groups/$groupId/members',
    );
    final values = result['members'];
    if (values is! List) return const [];

    return values
        .whereType<Map>()
        .map((value) => SocialManagedMember.fromJson(
              Map<String, dynamic>.from(value),
            ))
        .toList(growable: false);
  }

  Future<void> setAdmin({
    required String groupId,
    required String userId,
    required bool isAdmin,
  }) async {
    _validateUuid(groupId);
    _validateUuid(userId);
    await _request(
      'POST',
      '/v1/social/groups/$groupId/members/$userId/admin',
      body: {'isAdmin': isAdmin},
    );
  }

  Future<void> removeMember({
    required String groupId,
    required String userId,
  }) async {
    _validateUuid(groupId);
    _validateUuid(userId);
    await _request(
      'DELETE',
      '/v1/social/groups/$groupId/members/$userId',
    );
  }

  Future<void> leaveGroup(String groupId) async {
    _validateUuid(groupId);
    await _request(
      'POST',
      '/v1/social/groups/$groupId/leave',
      body: const {},
    );
  }

  Future<void> deleteGroup(String groupId) async {
    _validateUuid(groupId);
    await _request(
      'DELETE',
      '/v1/social/groups/$groupId',
    );
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    await initialize();
    if (!isSignedIn) await refreshSession();

    final token = _token;
    if (token == null || token.isEmpty) {
      throw const SocialGroupManagementException(
        'AUTH_REQUIRED',
        'جلسة حساب صاحبي Connect غير متاحة.',
      );
    }

    final request = http.Request(
      method,
      Uri.parse(AppConfig.buildBackendUrl(path)),
    )
      ..headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
        'Cache-Control': 'no-store',
      });

    if (body != null) {
      request.headers['Content-Type'] =
          'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }

    try {
      final streamed = await Sa7biNetworkClient.client
          .send(request)
          .timeout(_timeout);
      final response = await http.Response.fromStream(streamed)
          .timeout(_timeout);

      Map<String, dynamic> decoded;
      try {
        final value = jsonDecode(
          utf8.decode(response.bodyBytes, allowMalformed: true),
        );
        decoded = value is Map
            ? Map<String, dynamic>.from(value)
            : <String, dynamic>{};
      } catch (_) {
        decoded = <String, dynamic>{};
      }

      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          decoded['ok'] != true) {
        final code = decoded['error'] is String
            ? decoded['error'] as String
            : 'HTTP_${response.statusCode}';
        throw SocialGroupManagementException(
          code,
          _friendlyMessage(code, decoded['message']),
          statusCode: response.statusCode,
        );
      }

      return decoded;
    } on SocialGroupManagementException {
      rethrow;
    } on TimeoutException {
      throw const SocialGroupManagementException(
        'NETWORK_TIMEOUT',
        'انتهت مهلة الاتصال. حاول مرة أخرى.',
      );
    } on http.ClientException {
      throw const SocialGroupManagementException(
        'NETWORK_ERROR',
        'تعذر الاتصال بالخادم. تحقق من الإنترنت وحاول مرة أخرى.',
      );
    } catch (_) {
      throw const SocialGroupManagementException(
        'NETWORK_ERROR',
        'تعذر إكمال طلب المجموعات. حاول مرة أخرى.',
      );
    }
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static void _validateUuid(String value) {
    if (!RegExp(r'^[a-f0-9-]{36}$', caseSensitive: false).hasMatch(value)) {
      throw const SocialGroupManagementException(
        'GROUP_NOT_FOUND',
        'معرّف المجموعة غير صحيح.',
      );
    }
  }

  static String _friendlyMessage(String code, dynamic serverMessage) {
    switch (code) {
      case 'GROUP_NOT_FOUND':
        return 'المجموعة غير موجودة أو لم تعد متاحة.';
      case 'GROUP_INVITE_INVALID':
        return 'رمز الدعوة غير صحيح.';
      case 'GROUP_INVITE_EXPIRED':
        return 'انتهت صلاحية رمز الدعوة.';
      case 'GROUP_INVITE_MAX_USES':
        return 'اكتمل عدد مرات استخدام رمز الدعوة.';
      case 'GROUP_INVITE_RATE_LIMIT':
        return 'محاولات إدخال الرمز كثيرة. انتظر 15 دقيقة ثم حاول مرة أخرى.';
      case 'GROUP_FULL':
        return 'وصلت المجموعة إلى الحد الأقصى للأعضاء.';
      case 'GROUP_MEMBERSHIP_REQUIRED':
        return 'هذه العملية متاحة لأعضاء المجموعة فقط.';
      case 'GROUP_ADMIN_REQUIRED':
        return 'هذه العملية متاحة للمالك أو المشرف فقط.';
      case 'GROUP_OWNER_REQUIRED':
        return 'هذه العملية متاحة لمالك المجموعة فقط.';
      case 'GROUP_OWNER_MUST_DELETE':
        return 'مالك المجموعة لا يمكنه مغادرتها قبل حذفها أو نقل الملكية.';
      case 'GROUP_MEMBER_NOT_FOUND':
        return 'العضو غير موجود في هذه المجموعة.';
      case 'GROUP_CANNOT_REMOVE_OWNER':
        return 'لا يمكن إزالة مالك المجموعة.';
      case 'GROUP_ADMIN_CANNOT_REMOVE_ADMIN':
        return 'المشرف لا يمكنه إزالة مشرف آخر.';
      case 'GROUP_USE_LEAVE_ROUTE':
        return 'استخدم خيار مغادرة المجموعة.';
      default:
        return serverMessage is String && serverMessage.isNotEmpty
            ? serverMessage
            : 'تعذر إكمال الطلب ($code).';
    }
  }
}

class SocialManagedGroup {
  const SocialManagedGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.ownerId,
    required this.memberCount,
    required this.isMember,
    required this.isPublic,
    required this.myRole,
    required this.lastMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final String ownerId;
  final int memberCount;
  final bool isMember;
  final bool isPublic;
  final String myRole;
  final String lastMessage;
  final int createdAt;
  final int updatedAt;

  bool get isOwner => myRole == 'owner';
  bool get isAdmin => myRole == 'admin' || isOwner;

  factory SocialManagedGroup.fromJson(Map<String, dynamic> json) {
    return SocialManagedGroup(
      id: json['id'] is String ? json['id'] as String : '',
      name: json['name'] is String ? json['name'] as String : 'مجموعة',
      description: json['description'] is String
          ? json['description'] as String
          : '',
      ownerId: json['ownerId'] is String ? json['ownerId'] as String : '',
      memberCount: _readInt(json['memberCount']),
      isMember: json['isMember'] == true || json['isMember'] == 1,
      isPublic: json['isPublic'] == true || json['isPublic'] == 1,
      myRole: json['myRole'] is String ? json['myRole'] as String : 'member',
      lastMessage: json['lastMessage'] is String
          ? json['lastMessage'] as String
          : '',
      createdAt: _readInt(json['createdAt']),
      updatedAt: _readInt(json['updatedAt']),
    );
  }

  SocialPublicGroup toPublicGroup() {
    return SocialPublicGroup(
      id: id,
      name: name,
      description: description,
      ownerId: ownerId,
      memberCount: memberCount,
      isMember: isMember,
      lastMessage: lastMessage,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class SocialManagedMember {
  const SocialManagedMember({
    required this.userId,
    required this.username,
    required this.role,
    required this.joinedAt,
  });

  final String userId;
  final String username;
  final String role;
  final int joinedAt;

  factory SocialManagedMember.fromJson(Map<String, dynamic> json) {
    return SocialManagedMember(
      userId: json['userId'] is String ? json['userId'] as String : '',
      username: json['username'] is String
          ? json['username'] as String
          : 'لاعب',
      role: json['role'] is String ? json['role'] as String : 'member',
      joinedAt: _readInt(json['joinedAt']),
    );
  }
}

class SocialGroupInvite {
  const SocialGroupInvite({
    required this.code,
    required this.expiresAt,
    required this.maxUses,
  });

  final String code;
  final int expiresAt;
  final int maxUses;

  factory SocialGroupInvite.fromJson(Map<String, dynamic> json) {
    return SocialGroupInvite(
      code: json['code'] is String ? json['code'] as String : '',
      expiresAt: _readInt(json['expiresAt']),
      maxUses: _readInt(json['maxUses']),
    );
  }
}

class SocialGroupManagementException implements Exception {
  const SocialGroupManagementException(
    this.code,
    this.message, {
    this.statusCode,
  });

  final String code;
  final String message;
  final int? statusCode;

  @override
  String toString() => 'SocialGroupManagementException($code): $message';
}

int _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return 0;
}
