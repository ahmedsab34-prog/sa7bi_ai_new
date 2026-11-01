import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import 'sa7bi_network_client.dart';
import 'social_games_service.dart';

/// مجموعات عامة ومباريات ضد صاحبي AI.
/// يستخدم جلسة حساب الألعاب نفسها ولا ينشئ جلسة منفصلة.
class SocialCommunityService {
  SocialCommunityService._();

  static final SocialCommunityService instance = SocialCommunityService._();
  static const String _tokenKey = 'sa7bi_social_games_session_token';
  static const Duration _timeout = Duration(seconds: 20);

  String? _token;
  Future<void>? _loadingToken;

  bool get isSignedIn => _token != null && _token!.isNotEmpty;

  Future<void> initialize() async {
    if (_token != null && _token!.isNotEmpty) return;
    _loadingToken ??= _loadToken();
    try {
      await _loadingToken;
    } finally {
      _loadingToken = null;
    }
  }

  Future<void> refreshSession() async {
    _token = null;
    await initialize();
  }

  Future<void> _loadToken() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_tokenKey);
    if (saved != null && saved.isNotEmpty) _token = saved;
  }

  Future<List<SocialPublicGroup>> getGroups() async {
    final result = await _request('GET', '/v1/social/groups');
    final values = result['groups'];
    if (values is! List) return const [];
    return values
        .whereType<Map>()
        .map((item) => SocialPublicGroup.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .toList(growable: false);
  }

  Future<SocialPublicGroup> createGroup({
    required String name,
    String description = '',
  }) async {
    final cleanName = name.trim();
    final cleanDescription = description.trim();
    if (cleanName.length < 3 || cleanName.length > 40) {
      throw const SocialCommunityException(
        'INVALID_GROUP_NAME',
        'اسم المجموعة يجب أن يكون من 3 إلى 40 حرفًا.',
      );
    }
    if (cleanDescription.length > 160) {
      throw const SocialCommunityException(
        'INVALID_GROUP_DESCRIPTION',
        'وصف المجموعة لا يمكن أن يزيد عن 160 حرفًا.',
      );
    }
    final result = await _request(
      'POST',
      '/v1/social/groups',
      body: {
        'name': cleanName,
        'description': cleanDescription,
      },
    );
    return SocialPublicGroup.fromJson(_asMap(result['group']));
  }

  Future<SocialPublicGroup> joinGroup(String groupId) async {
    _validateUuid(groupId, 'GROUP_NOT_FOUND');
    final result = await _request(
      'POST',
      '/v1/social/groups/$groupId/join',
      body: const {},
    );
    return SocialPublicGroup.fromJson(_asMap(result['group']));
  }

  Future<List<SocialGroupMessage>> getMessages(
    String groupId, {
    int limit = 50,
  }) async {
    _validateUuid(groupId, 'GROUP_NOT_FOUND');
    final safeLimit = limit.clamp(1, 100);
    final result = await _request(
      'GET',
      '/v1/social/groups/$groupId/messages?limit=$safeLimit',
    );
    final values = result['messages'];
    if (values is! List) return const [];
    return values
        .whereType<Map>()
        .map((item) => SocialGroupMessage.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .toList(growable: false);
  }

  Future<SocialGroupMessage> sendGroupMessage({
    required String groupId,
    required String text,
  }) async {
    _validateUuid(groupId, 'GROUP_NOT_FOUND');
    final cleanText = text.trim();
    if (cleanText.isEmpty || cleanText.length > 3000) {
      throw const SocialCommunityException(
        'INVALID_MESSAGE',
        'اكتب رسالة من حرف واحد إلى 3000 حرف.',
      );
    }
    final result = await _request(
      'POST',
      '/v1/social/groups/$groupId/messages',
      body: {'text': cleanText},
    );
    return SocialGroupMessage.fromJson(_asMap(result['message']));
  }

  /// يبحث عن لاعب حقيقي في طابور مشترك، ثم يترك الخادم يحوّل
  /// الغرفة نفسها إلى خصم AI بعد انتهاء مهلة البحث.
  Future<SocialQuickMatchResult> quickMatch({required String game}) async {
    const supported = {'tic_tac_toe', 'rock_paper_scissors', 'chess'};
    if (!supported.contains(game)) {
      throw const SocialCommunityException(
        'UNSUPPORTED_GAME',
        'اللعبة المختارة غير مدعومة.',
      );
    }
    final result = await _request(
      'POST',
      '/v1/games/matchmaking',
      body: {'game': game},
    );
    return SocialQuickMatchResult.fromJson(result);
  }

  /// يلغي البحث فقط إذا لم ينضم لاعب آخر بعد.
  Future<void> cancelQuickMatch(String roomId) async {
    _validateUuid(roomId, 'ROOM_NOT_FOUND');
    await _request(
      'POST',
      '/v1/games/rooms/$roomId/cancel-matchmaking',
      body: const {},
    );
  }

  /// ينشئ مباراة محفوظة مع خصم آلي على الخادم.
  Future<SocialGameRoom> createAiRoom({required String game}) async {
    const supported = {'tic_tac_toe', 'rock_paper_scissors', 'chess'};
    if (!supported.contains(game)) {
      throw const SocialCommunityException(
        'UNSUPPORTED_GAME',
        'اللعبة المختارة غير مدعومة.',
      );
    }
    final result = await _request(
      'POST',
      '/v1/games/ai',
      body: {'game': game},
    );
    return SocialGameRoom.fromJson(_asMap(result['room']));
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    await initialize();
    final token = _token;
    if (token == null || token.isEmpty) {
      throw const SocialCommunityException(
        'AUTH_REQUIRED',
        'سجّل الدخول إلى حساب الألعاب أولًا.',
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
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }

    try {
      final streamed = await Sa7biNetworkClient.client
          .send(request)
          .timeout(_timeout);
      final responseBody = await streamed.stream
          .bytesToString()
          .timeout(_timeout);
      Map<String, dynamic> decoded;
      try {
        final value = jsonDecode(responseBody);
        decoded = value is Map
            ? Map<String, dynamic>.from(value)
            : <String, dynamic>{};
      } catch (_) {
        decoded = <String, dynamic>{};
      }

      if (streamed.statusCode < 200 || streamed.statusCode >= 300 ||
          decoded['ok'] == false) {
        final code = decoded['error'] is String
            ? decoded['error'] as String
            : 'HTTP_${streamed.statusCode}';
        final message = _friendlyMessage(code, decoded['message']);
        throw SocialCommunityException(
          code,
          message,
          statusCode: streamed.statusCode,
        );
      }
      return decoded;
    } on SocialCommunityException {
      rethrow;
    } on TimeoutException {
      throw const SocialCommunityException(
        'NETWORK_TIMEOUT',
        'انتهت مهلة الاتصال. حاول مرة أخرى.',
      );
    } on http.ClientException {
      throw const SocialCommunityException(
        'NETWORK_ERROR',
        'تعذر الاتصال بالخادم. تحقق من الإنترنت وحاول مرة أخرى.',
      );
    } catch (error) {
      if (error is SocialCommunityException) rethrow;
      throw const SocialCommunityException(
        'NETWORK_ERROR',
        'تعذر إكمال الطلب. تحقق من الاتصال وحاول مرة أخرى.',
      );
    }
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static void _validateUuid(String value, String code) {
    if (!RegExp(r'^[a-f0-9-]{36}$', caseSensitive: false).hasMatch(value)) {
      throw SocialCommunityException(code, 'المعرّف غير صحيح.');
    }
  }

  static String _friendlyMessage(String code, dynamic serverMessage) {
    switch (code) {
      case 'AUTH_REQUIRED':
      case 'SESSION_EXPIRED':
        return 'انتهت جلسة الحساب. سجّل الدخول مرة أخرى.';
      case 'INVALID_GROUP_NAME':
        return 'اسم المجموعة يجب أن يكون من 3 إلى 40 حرفًا.';
      case 'GROUP_NOT_FOUND':
        return 'المجموعة غير موجودة أو لم تعد متاحة.';
      case 'GROUP_FULL':
        return 'وصلت المجموعة إلى الحد الأقصى للأعضاء.';
      case 'GROUP_MEMBERSHIP_REQUIRED':
        return 'انضم إلى المجموعة أولًا لعرض الرسائل.';
      case 'MESSAGE_RATE_LIMIT':
        return 'أرسلت رسائل كثيرة بسرعة. انتظر قليلًا ثم حاول.';
      case 'INVALID_MESSAGE':
        return serverMessage is String && serverMessage.isNotEmpty
            ? serverMessage
            : 'محتوى الرسالة غير صالح.';
      case 'UNSUPPORTED_GAME':
        return 'اللعبة المختارة غير مدعومة.';
      case 'MATCH_SEARCH_ALREADY_FINISHED':
        return 'انضم لاعب بالفعل أو انتهى البحث. حدّث حالة المباراة.';
      case 'MATCH_QUEUE_CREATE_CONFLICT':
        return 'حدث تعارض أثناء إنشاء البحث. حاول مرة أخرى.';
      case 'NETWORK_TIMEOUT':
        return 'انتهت مهلة الاتصال. حاول مرة أخرى.';
      default:
        return serverMessage is String && serverMessage.isNotEmpty
            ? serverMessage
            : 'تعذر إكمال الطلب ($code). حاول مرة أخرى.';
    }
  }
}


class SocialQuickMatchResult {
  const SocialQuickMatchResult({
    required this.room,
    required this.matched,
    required this.aiFallback,
    required this.waitSeconds,
    required this.reused,
  });

  final SocialGameRoom room;
  final bool matched;
  final bool aiFallback;
  final int waitSeconds;
  final bool reused;

  factory SocialQuickMatchResult.fromJson(Map<String, dynamic> json) {
    final rawRoom = json['room'];
    return SocialQuickMatchResult(
      room: SocialGameRoom.fromJson(SocialCommunityService._asMap(rawRoom)),
      matched: json['matched'] == true,
      aiFallback: json['aiFallback'] == true,
      waitSeconds: _readInt(json['waitSeconds']),
      reused: json['reused'] == true,
    );
  }
}

class SocialPublicGroup {
  const SocialPublicGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.ownerId,
    required this.memberCount,
    required this.isMember,
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
  final String lastMessage;
  final int createdAt;
  final int updatedAt;

  factory SocialPublicGroup.fromJson(Map<String, dynamic> json) {
    return SocialPublicGroup(
      id: json['id'] is String ? json['id'] as String : '',
      name: json['name'] is String ? json['name'] as String : 'مجموعة',
      description: json['description'] is String
          ? json['description'] as String
          : '',
      ownerId: json['ownerId'] is String ? json['ownerId'] as String : '',
      memberCount: _readInt(json['memberCount']),
      isMember: json['isMember'] == true || json['isMember'] == 1,
      lastMessage: json['lastMessage'] is String
          ? json['lastMessage'] as String
          : '',
      createdAt: _readInt(json['createdAt']),
      updatedAt: _readInt(json['updatedAt']),
    );
  }
}

class SocialGroupMessage {
  const SocialGroupMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.username,
    required this.text,
    required this.createdAt,
    required this.isMine,
  });

  final String id;
  final String groupId;
  final String senderId;
  final String username;
  final String text;
  final int createdAt;
  final bool isMine;

  factory SocialGroupMessage.fromJson(Map<String, dynamic> json) {
    return SocialGroupMessage(
      id: json['id'] is String ? json['id'] as String : '',
      groupId: json['groupId'] is String ? json['groupId'] as String : '',
      senderId: json['senderId'] is String ? json['senderId'] as String : '',
      username: json['username'] is String
          ? json['username'] as String
          : 'لاعب',
      text: json['text'] is String ? json['text'] as String : '',
      createdAt: _readInt(json['createdAt']),
      isMine: json['isMine'] == true,
    );
  }
}

class SocialCommunityException implements Exception {
  const SocialCommunityException(
    this.code,
    this.message, {
    this.statusCode,
  });

  final String code;
  final String message;
  final int? statusCode;

  @override
  String toString() => 'SocialCommunityException($code): $message';
}

int _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return 0;
}
