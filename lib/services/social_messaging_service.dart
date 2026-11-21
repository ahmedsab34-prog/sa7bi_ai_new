
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'sa7bi_network_client.dart';
import 'social_guest_session_service.dart';
import 'social_session_storage.dart';

/// خدمة المحادثات الخاصة والعامة ودعوات الألعاب.
/// تستخدم جلسة الحساب نفسها ولا تنشئ جلسة دخول منفصلة.
class SocialMessagingService {
  SocialMessagingService._();

  static final SocialMessagingService instance = SocialMessagingService._();

  static const Duration _timeout = Duration(seconds: 20);

  String? _token;
  Future<void>? _loadingToken;

  bool get isSignedIn => _token != null && _token!.isNotEmpty;

  Future<void> initialize() async {
    if (_token != null && _token!.isNotEmpty) return;

    final pending = _loadingToken;
    if (pending != null) {
      await pending;
      return;
    }

    final task = _initializeToken();
    _loadingToken = task;

    try {
      await task;
    } finally {
      if (identical(_loadingToken, task)) {
        _loadingToken = null;
      }
    }
  }

  Future<void> _initializeToken() async {
    await SocialGuestSessionService.instance.ensureSession();
    _token = await SocialSessionStorage.instance.readToken();
  }

  Future<void> refreshSession() async {
    _token = null;
    await initialize();
  }

  // ---------------------------------------------------------------------------
  // Public global chat
  // ---------------------------------------------------------------------------

  /// تحميل رسائل الغرفة العامة المشتركة بين مستخدمي صاحبي.
  /// before يستخدم لتحميل الرسائل الأقدم عند إضافة pagination.
  Future<List<SocialPublicMessage>> getPublicMessages({
    int limit = 50,
    int? before,
  }) async {
    final safeLimit = limit.clamp(1, 50);
    final query = <String, String>{
      'limit': safeLimit.toString(),
    };

    if (before != null && before > 0) {
      query['before'] = before.toString();
    }

    final uri = _uri('/v1/social/public/messages')
        .replace(queryParameters: query);

    final result = await _request(
      'GET',
      uri.toString(),
    );

    final values = result['messages'];
    if (values is! List) return const [];

    final currentUserId = result['currentUserId'] is String
        ? result['currentUserId'] as String
        : '';

    return values
        .whereType<Map>()
        .map(
          (item) => SocialPublicMessage.fromJson(
            Map<String, dynamic>.from(item),
            currentUserId: currentUserId,
          ),
        )
        .toList(growable: false);
  }

  /// إرسال رسالة إلى الغرفة العامة المشتركة.
  Future<SocialPublicMessage> sendPublicMessage(String text) async {
    final cleaned = text.trim();

    if (cleaned.isEmpty || cleaned.length > 3000) {
      throw const SocialMessagingException(
        'INVALID_MESSAGE',
        'اكتب رسالة من حرف واحد إلى 3000 حرف.',
      );
    }

    final result = await _request(
      'POST',
      '/v1/social/public/messages',
      body: {'text': cleaned},
    );

    return SocialPublicMessage.fromJson(
      _asMap(result['message']),
      currentUserId: '',
    ).copyWith(isMine: true);
  }

  /// الإبلاغ عن رسالة في الغرفة العامة.
  Future<void> reportPublicMessage({
    required String messageId,
    required String reason,
  }) async {
    final cleanedReason = reason.trim();

    if (messageId.trim().isEmpty || cleanedReason.isEmpty) {
      throw const SocialMessagingException(
        'INVALID_REPORT',
        'اختر سببًا واضحًا للإبلاغ عن الرسالة.',
      );
    }

    await _request(
      'POST',
      '/v1/social/public/report',
      body: {
        'messageId': messageId.trim(),
        'reason': cleanedReason,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Game invitations
  // ---------------------------------------------------------------------------

  Future<List<SocialGameInvitation>> getInvitations({
    String box = 'inbox',
  }) async {
    final safeBox = box == 'outbox' ? 'outbox' : 'inbox';
    final result = await _request(
      'GET',
      '/v1/social/invitations?box=$safeBox',
    );
    final values = result['invitations'];

    if (values is! List) return const [];

    return values
        .whereType<Map>()
        .map(
          (item) => SocialGameInvitation.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList(growable: false);
  }

  Future<SocialGameInvitation> createGameInvitation({
    required String recipientUserId,
    required String game,
  }) async {
    const allowedGames = {
      'tic_tac_toe',
      'rock_paper_scissors',
      'chess',
    };

    if (!allowedGames.contains(game)) {
      throw const SocialMessagingException(
        'UNSUPPORTED_GAME',
        'اللعبة المختارة غير مدعومة.',
      );
    }

    final result = await _request(
      'POST',
      '/v1/social/invitations',
      body: {
        'recipientUserId': recipientUserId,
        'game': game,
      },
    );

    return SocialGameInvitation.fromJson(_asMap(result['invitation']));
  }

  Future<String?> respondToInvitation({
    required String invitationId,
    required bool accept,
  }) async {
    final action = accept ? 'accept' : 'decline';
    final result = await _request(
      'POST',
      '/v1/social/invitations/$invitationId/$action',
      body: const {},
    );

    if (!accept) return null;

    final room = result['room'];
    if (room is Map && room['id'] is String) {
      return room['id'] as String;
    }

    throw const SocialMessagingException(
      'INVALID_SERVER_RESPONSE',
      'تم قبول الدعوة لكن الخادم لم يُرجع معرّف المباراة.',
    );
  }

  // ---------------------------------------------------------------------------
  // Private conversations
  // ---------------------------------------------------------------------------

  Future<List<SocialConversationSummary>> getConversations() async {
    final result = await _request(
      'GET',
      '/v1/social/conversations',
    );
    final values = result['conversations'];

    if (values is! List) return const [];

    return values
        .whereType<Map>()
        .map(
          (item) => SocialConversationSummary.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList(growable: false);
  }

  Future<String> createConversation(String userId) async {
    final result = await _request(
      'POST',
      '/v1/social/conversations',
      body: {'userId': userId},
    );
    final conversation = _asMap(result['conversation']);
    final id = conversation['id'];

    if (id is! String || id.isEmpty) {
      throw const SocialMessagingException(
        'INVALID_SERVER_RESPONSE',
        'الخادم لم يُرجع معرّف المحادثة.',
      );
    }

    return id;
  }

  Future<List<SocialPrivateMessage>> getMessages(
    String conversationId, {
    int limit = 50,
  }) async {
    final safeLimit = limit.clamp(1, 100);
    final result = await _request(
      'GET',
      '/v1/social/messages?conversationId=${Uri.encodeQueryComponent(conversationId)}&limit=$safeLimit',
    );
    final values = result['messages'];

    if (values is! List) return const [];

    return values
        .whereType<Map>()
        .map(
          (item) => SocialPrivateMessage.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList(growable: false);
  }

  Future<SocialPrivateMessage> sendMessage({
    required String conversationId,
    required String text,
  }) async {
    final cleaned = text.trim();

    if (cleaned.isEmpty || cleaned.length > 3000) {
      throw const SocialMessagingException(
        'INVALID_MESSAGE',
        'اكتب رسالة من حرف واحد إلى 3000 حرف.',
      );
    }

    final result = await _request(
      'POST',
      '/v1/social/messages',
      body: {
        'conversationId': conversationId,
        'text': cleaned,
      },
    );

    return SocialPrivateMessage.fromJson(_asMap(result['message']));
  }

  Future<void> markConversationRead(String conversationId) async {
    await _request(
      'POST',
      '/v1/social/messages/read',
      body: {'conversationId': conversationId},
    );
  }

  // ---------------------------------------------------------------------------
  // Shared network request handling
  // ---------------------------------------------------------------------------

  Uri _uri(String path) => Uri.parse(AppConfig.buildBackendUrl(path));

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    await initialize();

    final token = _token;
    if (token == null || token.isEmpty) {
      throw const SocialMessagingException(
        'AUTH_REQUIRED',
        'تعذر استعادة جلسة حسابك تلقائيًا. حاول مرة أخرى.',
      );
    }

    final request = http.Request(method, _uri(path))
      ..headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
        'Cache-Control': 'no-store',
      });

    if (body != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }

    http.StreamedResponse streamed;

    try {
      streamed = await Sa7biNetworkClient.client
          .send(request)
          .timeout(_timeout);
    } on TimeoutException {
      throw const SocialMessagingException(
        'NETWORK_TIMEOUT',
        'الاتصال استغرق وقتًا طويلًا. حاول مرة أخرى.',
      );
    } on http.ClientException {
      throw const SocialMessagingException(
        'NETWORK_ERROR',
        'تعذر الاتصال بخدمة الرسائل. تحقق من الإنترنت.',
      );
    } catch (_) {
      throw const SocialMessagingException(
        'NETWORK_ERROR',
        'تعذر الاتصال بخدمة الرسائل. تحقق من الإنترنت.',
      );
    }

    late final http.Response response;

    try {
      response = await http.Response.fromStream(streamed).timeout(_timeout);
    } on TimeoutException {
      throw const SocialMessagingException(
        'NETWORK_TIMEOUT',
        'الخادم تأخر في إرسال بيانات الرسالة. حاول مرة أخرى.',
      );
    } on http.ClientException {
      throw const SocialMessagingException(
        'NETWORK_ERROR',
        'انقطع الاتصال أثناء استلام بيانات الرسالة. تحقق من الإنترنت.',
      );
    } catch (_) {
      throw const SocialMessagingException(
        'NETWORK_ERROR',
        'تعذر استلام رد خدمة الرسائل. تحقق من الإنترنت.',
      );
    }

    Map<String, dynamic> decoded;

    try {
      final value = jsonDecode(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
      if (value is! Map) {
        throw const FormatException('Expected a JSON object.');
      }
      decoded = Map<String, dynamic>.from(value);
    } catch (_) {
      throw SocialMessagingException(
        'INVALID_SERVER_RESPONSE',
        'رد الخادم غير مفهوم (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['ok'] != true) {
      final error = _stringOr(
        decoded['error'],
        'HTTP_${response.statusCode}',
      );
      throw SocialMessagingException(
        error,
        _friendlyMessage(error, decoded['message']),
        statusCode: response.statusCode,
      );
    }

    return decoded;
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);

    throw const SocialMessagingException(
      'INVALID_SERVER_RESPONSE',
      'الخادم لم يُرجع البيانات بالشكل المتوقع.',
    );
  }

  static String _stringOr(dynamic value, String fallback) {
    return value is String && value.isNotEmpty ? value : fallback;
  }

  static String _friendlyMessage(String error, dynamic serverMessage) {
    switch (error) {
      case 'AUTH_REQUIRED':
      case 'SESSION_EXPIRED':
        return 'انتهت جلسة الحساب. حاول استعادتها مرة أخرى.';
      case 'INVALID_RECIPIENT':
      case 'INVALID_USER_ID':
        return 'حساب اللاعب المحدد غير صحيح.';
      case 'RECIPIENT_NOT_FOUND':
      case 'USER_NOT_FOUND':
        return 'حساب اللاعب غير موجود.';
      case 'CANNOT_INVITE_SELF':
      case 'CANNOT_MESSAGE_SELF':
        return 'لا يمكنك إرسال دعوة أو رسالة إلى حسابك نفسه.';
      case 'INVITATION_ALREADY_PENDING':
        return 'لديك دعوة معلّقة بالفعل لهذا اللاعب.';
      case 'INVITATION_NOT_FOUND':
        return 'الدعوة غير موجودة.';
      case 'INVITATION_ACCESS_DENIED':
        return 'هذه الدعوة ليست موجّهة إلى حسابك.';
      case 'INVITATION_NOT_PENDING':
        return 'تم الرد على الدعوة بالفعل أو لم تعد معلّقة.';
      case 'INVITATION_EXPIRED':
        return 'انتهت صلاحية الدعوة.';
      case 'ROOM_FULL':
      case 'ROOM_NOT_AVAILABLE':
        return 'الغرفة لم تعد متاحة للانضمام.';
      case 'CONVERSATION_ACCESS_DENIED':
        return 'لا تملك صلاحية الوصول إلى هذه المحادثة.';
      case 'CONVERSATION_NOT_FOUND':
        return 'المحادثة غير موجودة.';
      case 'MESSAGE_RATE_LIMIT':
        return 'أرسلت رسائل كثيرة بسرعة. انتظر قليلًا ثم حاول.';
      case 'INVALID_MESSAGE':
        return serverMessage is String && serverMessage.isNotEmpty
            ? serverMessage
            : 'نص الرسالة غير صالح.';
      case 'ALREADY_REPORTED':
        return 'سبق لك الإبلاغ عن هذه الرسالة.';
      case 'MESSAGE_NOT_FOUND':
        return 'الرسالة المطلوب الإبلاغ عنها غير موجودة.';
      case 'INVALID_REPORT':
        return 'بيانات الإبلاغ غير مكتملة.';
      case 'NETWORK_TIMEOUT':
        return 'انتهت مهلة الاتصال. حاول مرة أخرى.';
      default:
        return serverMessage is String && serverMessage.isNotEmpty
            ? serverMessage
            : 'تعذر إكمال الطلب ($error). حاول مرة أخرى.';
    }
  }
}

// -----------------------------------------------------------------------------
// Models
// -----------------------------------------------------------------------------

class SocialPublicMessage {
  const SocialPublicMessage({
    required this.id,
    required this.senderId,
    required this.username,
    required this.text,
    required this.createdAt,
    required this.isMine,
  });

  final String id;
  final String senderId;
  final String username;
  final String text;
  final int createdAt;
  final bool isMine;

  SocialPublicMessage copyWith({bool? isMine}) {
    return SocialPublicMessage(
      id: id,
      senderId: senderId,
      username: username,
      text: text,
      createdAt: createdAt,
      isMine: isMine ?? this.isMine,
    );
  }

  factory SocialPublicMessage.fromJson(
    Map<String, dynamic> json, {
    required String currentUserId,
  }) {
    final senderId =
        json['senderId'] is String ? json['senderId'] as String : '';

    return SocialPublicMessage(
      id: json['id'] is String ? json['id'] as String : '',
      senderId: senderId,
      username: json['username'] is String
          ? json['username'] as String
          : 'مستخدم صاحبي',
      text: json['text'] is String ? json['text'] as String : '',
      createdAt: _readInt(json['createdAt']),
      isMine: currentUserId.isNotEmpty && senderId == currentUserId,
    );
  }
}

class SocialMessageUser {
  const SocialMessageUser({
    required this.id,
    required this.username,
  });

  final String id;
  final String username;

  factory SocialMessageUser.fromJson(Map<String, dynamic> json) {
    return SocialMessageUser(
      id: json['id'] is String ? json['id'] as String : '',
      username: json['username'] is String
          ? json['username'] as String
          : 'لاعب',
    );
  }
}

class SocialGameInvitation {
  const SocialGameInvitation({
    required this.id,
    required this.sender,
    required this.recipient,
    required this.game,
    required this.status,
    required this.roomId,
    required this.inviteCode,
    required this.createdAt,
    required this.expiresAt,
    required this.direction,
  });

  final String id;
  final SocialMessageUser sender;
  final SocialMessageUser recipient;
  final String game;
  final String status;
  final String roomId;
  final String inviteCode;
  final int createdAt;
  final int expiresAt;
  final String direction;

  String get gameTitle {
    switch (game) {
      case 'chess':
        return 'الشطرنج';
      case 'tic_tac_toe':
        return 'إكس أو';
      case 'rock_paper_scissors':
        return 'حجر ورقة مقص';
      default:
        return 'لعبة جماعية';
    }
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'في انتظار الرد';
      case 'accepted':
        return 'تم قبول الدعوة';
      case 'declined':
        return 'تم رفض الدعوة';
      case 'expired':
        return 'انتهت صلاحية الدعوة';
      default:
        return status;
    }
  }

  factory SocialGameInvitation.fromJson(Map<String, dynamic> json) {
    return SocialGameInvitation(
      id: json['id'] is String ? json['id'] as String : '',
      sender: _readUser(json['sender']),
      recipient: _readUser(json['recipient']),
      game: json['game'] is String ? json['game'] as String : '',
      status: json['status'] is String ? json['status'] as String : 'unknown',
      roomId: json['roomId'] is String ? json['roomId'] as String : '',
      inviteCode:
          json['inviteCode'] is String ? json['inviteCode'] as String : '',
      createdAt: _readInt(json['createdAt']),
      expiresAt: _readInt(json['expiresAt']),
      direction:
          json['direction'] is String ? json['direction'] as String : 'incoming',
    );
  }
}

class SocialConversationSummary {
  const SocialConversationSummary({
    required this.id,
    required this.otherUser,
    required this.lastMessage,
    required this.unreadCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final SocialMessageUser otherUser;
  final SocialLastMessage? lastMessage;
  final int unreadCount;
  final int createdAt;
  final int updatedAt;

  factory SocialConversationSummary.fromJson(Map<String, dynamic> json) {
    final rawLast = json['lastMessage'];

    return SocialConversationSummary(
      id: json['id'] is String ? json['id'] as String : '',
      otherUser: _readUser(json['otherUser']),
      lastMessage: rawLast is Map
          ? SocialLastMessage.fromJson(Map<String, dynamic>.from(rawLast))
          : null,
      unreadCount: _readInt(json['unreadCount']),
      createdAt: _readInt(json['createdAt']),
      updatedAt: _readInt(json['updatedAt']),
    );
  }
}

class SocialLastMessage {
  const SocialLastMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String senderId;
  final String text;
  final int createdAt;

  factory SocialLastMessage.fromJson(Map<String, dynamic> json) {
    return SocialLastMessage(
      id: json['id'] is String ? json['id'] as String : '',
      senderId: json['senderId'] is String ? json['senderId'] as String : '',
      text: json['text'] is String ? json['text'] as String : '',
      createdAt: _readInt(json['createdAt']),
    );
  }
}

class SocialPrivateMessage {
  const SocialPrivateMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    required this.createdAt,
    required this.readAt,
    required this.isMine,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String text;
  final int createdAt;
  final int? readAt;
  final bool isMine;

  factory SocialPrivateMessage.fromJson(Map<String, dynamic> json) {
    return SocialPrivateMessage(
      id: json['id'] is String ? json['id'] as String : '',
      conversationId: json['conversationId'] is String
          ? json['conversationId'] as String
          : '',
      senderId: json['senderId'] is String ? json['senderId'] as String : '',
      text: json['text'] is String ? json['text'] as String : '',
      createdAt: _readInt(json['createdAt']),
      readAt: json['readAt'] == null ? null : _readInt(json['readAt']),
      isMine: json['isMine'] == true,
    );
  }
}

SocialMessageUser _readUser(dynamic value) {
  if (value is Map) {
    return SocialMessageUser.fromJson(Map<String, dynamic>.from(value));
  }
  return const SocialMessageUser(id: '', username: 'لاعب');
}

int _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return 0;
}

class SocialMessagingException implements Exception {
  const SocialMessagingException(
    this.code,
    this.message, {
    this.statusCode,
  });

  final String code;
  final String message;
  final int? statusCode;

  @override
  String toString() => 'SocialMessagingException($code): $message';
}
