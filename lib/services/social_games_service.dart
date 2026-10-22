
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import 'sa7bi_network_client.dart';

/// واجهة موحدة للتعامل مع حسابات الألعاب والمباريات المحفوظة.
///
/// الخادم هو المصدر الأساسي لحالة المباراة وقانونية الحركات.
/// لا تعتبر أي حركة ناجحة إلا بعد استلام رد ناجح من الخادم.
class SocialGamesService {
  SocialGamesService._();

  static final SocialGamesService instance = SocialGamesService._();

  static const String _tokenKey = 'sa7bi_social_games_session_token';
  static const Duration _requestTimeout = Duration(seconds: 20);

  String? _token;

  Future<void>? _loadingToken;

  String? get sessionToken => _token;

  bool get isSignedIn => _token != null && _token!.isNotEmpty;

  /// استعادة جلسة الألعاب المحفوظة محليًا.
  ///
  /// الرمز محفوظ محليًا لتجنب تسجيل الدخول عند كل فتح للتطبيق.
  /// صلاحية الرمز النهائية يحددها الخادم.
  Future<void> initialize() async {
    if (_token != null) return;

    _loadingToken ??= _loadToken();

    try {
      await _loadingToken;
    } finally {
      _loadingToken = null;
    }
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_tokenKey);

    if (saved != null && saved.isNotEmpty) {
      _token = saved;
    }
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_tokenKey, token);
    _token = token;
  }

  /// تسجيل حساب ألعاب جديد.
  ///
  /// يشترط الخادم اسم مستخدم من 3 إلى 24 حرفًا/رقمًا،
  /// وكلمة مرور من 10 إلى 128 حرفًا.
  Future<SocialGameAuthResult> register({
    required String username,
    required String password,
  }) async {
    final result = await _request(
      'POST',
      '/v1/social/register',
      body: {
        'username': username.trim(),
        'password': password,
      },
      authenticated: false,
    );

    final token = _requiredString(result['token'], 'token');
    final userJson = _asMap(result['user']);

    await _saveToken(token);

    return SocialGameAuthResult(
      token: token,
      user: SocialGameUser.fromJson(userJson),
    );
  }

  /// تسجيل الدخول إلى حساب الألعاب.
  Future<SocialGameAuthResult> login({
    required String username,
    required String password,
  }) async {
    final result = await _request(
      'POST',
      '/v1/social/login',
      body: {
        'username': username.trim(),
        'password': password,
      },
      authenticated: false,
    );

    final token = _requiredString(result['token'], 'token');
    final userJson = _asMap(result['user']);

    await _saveToken(token);

    return SocialGameAuthResult(
      token: token,
      user: SocialGameUser.fromJson(userJson),
    );
  }

  /// مسح جلسة الألعاب المحلية فقط.
  ///
  /// لا يحذف الحساب أو المباريات المحفوظة على الخادم.
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_tokenKey);
    _token = null;
  }

  /// جلب المستخدم الحالي والتحقق من أن الجلسة لا تزال صالحة.
  Future<SocialGameUser> getCurrentUser() async {
    final result = await _request(
      'GET',
      '/v1/social/me',
    );

    return SocialGameUser.fromJson(_asMap(result['user']));
  }

  /// البحث عن حسابات أخرى لدعوتها إلى اللعب.
  Future<List<SocialGameUser>> searchUsers(String query) async {
    final cleaned = query.trim();

    if (cleaned.length < 2) {
      return const [];
    }

    final uri = _uri('/v1/social/users/search').replace(
      queryParameters: {'q': cleaned},
    );

    final result = await _send(
      'GET',
      uri,
    );

    final values = result['users'];

    if (values is! List) {
      return const [];
    }

    return values
        .whereType<Map>()
        .map(
          (item) => SocialGameUser.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList(growable: false);
  }

  /// إنشاء غرفة جديدة.
  ///
  /// الألعاب التي يدعمها الخادم حاليًا:
  /// tic_tac_toe, rock_paper_scissors, chess.
  Future<SocialGameRoom> createRoom({
    required String game,
  }) async {
    final result = await _request(
      'POST',
      '/v1/games/rooms',
      body: {'game': game},
    );

    return SocialGameRoom.fromJson(
      _asMap(result['room']),
    );
  }

  /// الانضمام إلى غرفة باستخدام رمز الدعوة.
  Future<SocialGameRoom> joinRoom({
    required String inviteCode,
  }) async {
    final result = await _request(
      'POST',
      '/v1/games/rooms/join',
      body: {'code': inviteCode.trim().toUpperCase()},
    );

    return SocialGameRoom.fromJson(
      _asMap(result['room']),
    );
  }

  /// استرجاع غرفة محددة بعد إغلاق التطبيق أو إعادة فتحه.
  Future<SocialGameRoom> getRoom(String roomId) async {
    _validateRoomId(roomId);

    final result = await _request(
      'GET',
      '/v1/games/rooms/$roomId',
    );

    return SocialGameRoom.fromJson(
      _asMap(result['room']),
    );
  }

  /// قائمة المباريات المرتبطة بالحساب الحالي.
  ///
  /// تشمل المباريات المنتظرة والجارية والمتوقفة والمنتهية.
  Future<List<SocialGameRoom>> getMyRooms() async {
    final result = await _request(
      'GET',
      '/v1/games/rooms/mine',
    );

    final values = result['rooms'];

    if (values is! List) {
      return const [];
    }

    return values
        .whereType<Map>()
        .map(
          (item) => SocialGameRoom.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList(growable: false);
  }

  /// إرسال حركة إكس أو.
  Future<SocialGameRoom> playTicTacToe({
    required String roomId,
    required int index,
  }) async {
    _validateRoomId(roomId);

    if (index < 0 || index > 8) {
      throw const SocialGamesException(
        'INVALID_MOVE',
        'المربع المحدد غير صحيح.',
      );
    }

    final result = await _request(
      'POST',
      '/v1/games/rooms/$roomId/move',
      body: {'index': index},
    );

    return SocialGameRoom.fromJson(
      _asMap(result['room']),
    );
  }

  /// إرسال اختيار حجر أو ورقة أو مقص.
  ///
  /// القيم المقبولة: rock, paper, scissors.
  Future<SocialGameRoom> playRockPaperScissors({
    required String roomId,
    required String choice,
  }) async {
    _validateRoomId(roomId);

    const allowed = {'rock', 'paper', 'scissors'};

    if (!allowed.contains(choice)) {
      throw const SocialGamesException(
        'INVALID_MOVE',
        'الاختيار غير صحيح.',
      );
    }

    final result = await _request(
      'POST',
      '/v1/games/rooms/$roomId/move',
      body: {'choice': choice},
    );

    return SocialGameRoom.fromJson(
      _asMap(result['room']),
    );
  }

  /// إرسال نقلة شطرنج باستخدام إحداثيات SAN-free من/إلى.
  ///
  /// مثال: from: 'e2', to: 'e4'.
  /// عند ترقية بيدق يمكن تمرير promotion: 'q' أو 'r' أو 'b' أو 'n'.
  /// الخادم هو من يتحقق من قانونية النقلة.
  Future<SocialGameRoom> playChessMove({
    required String roomId,
    required String from,
    required String to,
    String promotion = 'q',
  }) async {
    _validateRoomId(roomId);

    if (!RegExp(r'^[a-h][1-8]$').hasMatch(from) ||
        !RegExp(r'^[a-h][1-8]$').hasMatch(to)) {
      throw const SocialGamesException(
        'INVALID_MOVE',
        'مربع البداية أو الوصول غير صحيح.',
      );
    }

    const allowedPromotions = {'q', 'r', 'b', 'n'};

    if (!allowedPromotions.contains(promotion.toLowerCase())) {
      throw const SocialGamesException(
        'INVALID_MOVE',
        'اختيار ترقية البيدق غير صحيح.',
      );
    }

    final result = await _request(
      'POST',
      '/v1/games/rooms/$roomId/move',
      body: {
        'from': from,
        'to': to,
        'promotion': promotion.toLowerCase(),
      },
    );

    return SocialGameRoom.fromJson(
      _asMap(result['room']),
    );
  }

  /// إيقاف المباراة مؤقتًا.
  ///
  /// الخادم يرفض إيقاف مباراة غير جارية أو منتهية.
  Future<SocialGameRoom> pauseRoom(String roomId) async {
    _validateRoomId(roomId);

    final result = await _request(
      'POST',
      '/v1/games/rooms/$roomId/pause',
      body: const {},
    );

    return SocialGameRoom.fromJson(
      _asMap(result['room']),
    );
  }

  /// استئناف مباراة متوقفة.
  Future<SocialGameRoom> resumeRoom(String roomId) async {
    _validateRoomId(roomId);

    final result = await _request(
      'POST',
      '/v1/games/rooms/$roomId/resume',
      body: const {},
    );

    return SocialGameRoom.fromJson(
      _asMap(result['room']),
    );
  }

  /// تكوين نص دعوة يمكن إرساله في الشات أو مشاركته.
  ///
  /// إرسال النص لا ينضم إلى المباراة تلقائيًا؛
  /// الطرف الآخر يحتاج إلى تسجيل الدخول ثم استخدام joinRoom.
  String buildInviteMessage(SocialGameRoom room) {
    final gameName = room.gameTitle;

    return 'تعالى نلعب $gameName على صاحبي AI 🎮\n'
        'رمز الدعوة: ${room.inviteCode}\n'
        'افتح قسم الألعاب في التطبيق واختر الانضمام إلى مباراة.';
  }

  Uri _uri(String path) {
    return Uri.parse(AppConfig.buildBackendUrl(path));
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    await initialize();

    final response = await _send(
      method,
      _uri(path),
      body: body,
      authenticated: authenticated,
    );

    if (response['ok'] != true) {
      throw SocialGamesException(
        _stringOr(response['error'], 'REQUEST_FAILED'),
        _friendlyMessage(
          _stringOr(response['error'], 'REQUEST_FAILED'),
          response['message'],
        ),
      );
    }

    return response;
  }

  Future<Map<String, dynamic>> _send(
    String method,
    Uri uri, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Cache-Control': 'no-store',
    };

    if (body != null) {
      headers['Content-Type'] = 'application/json; charset=utf-8';
    }

    if (authenticated) {
      await initialize();

      final token = _token;

      if (token == null || token.isEmpty) {
        throw const SocialGamesException(
          'AUTH_REQUIRED',
          'سجّل الدخول أولًا لاستخدام الألعاب الجماعية.',
        );
      }

      headers['Authorization'] = 'Bearer $token';
    }

    final request = http.Request(method, uri)
      ..headers.addAll(headers);

    if (body != null) {
      request.body = jsonEncode(body);
    }

    http.StreamedResponse streamed;

    try {
      streamed = await Sa7biNetworkClient.client
          .send(request)
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw const SocialGamesException(
        'NETWORK_TIMEOUT',
        'الاتصال بالخادم استغرق وقتًا طويلًا. حاول مرة أخرى.',
      );
    } on http.ClientException {
      rethrow;
    } catch (_) {
      throw const SocialGamesException(
        'NETWORK_ERROR',
        'تعذر الاتصال بخدمة الألعاب. تحقق من الإنترنت وحاول مرة أخرى.',
      );
    }

    final response = await http.Response.fromStream(streamed);

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
      throw SocialGamesException(
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

      throw SocialGamesException(
        error,
        _friendlyMessage(error, decoded['message']),
        statusCode: response.statusCode,
      );
    }

    return decoded;
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    throw const SocialGamesException(
      'INVALID_SERVER_RESPONSE',
      'الخادم لم يُرجع بيانات اللعبة بالشكل المتوقع.',
    );
  }

  static String _requiredString(dynamic value, String field) {
    if (value is String && value.isNotEmpty) {
      return value;
    }

    throw SocialGamesException(
      'INVALID_SERVER_RESPONSE',
      'حقل $field غير موجود في رد الخادم.',
    );
  }

  static String _stringOr(dynamic value, String fallback) {
    return value is String && value.isNotEmpty ? value : fallback;
  }

  static void _validateRoomId(String roomId) {
    if (!RegExp(
      r'^[a-f0-9-]{36}$',
      caseSensitive: false,
    ).hasMatch(roomId)) {
      throw const SocialGamesException(
        'INVALID_ROOM_ID',
        'معرّف المباراة غير صحيح.',
      );
    }
  }

  static String _friendlyMessage(
    String error,
    dynamic serverMessage,
  ) {
    switch (error) {
      case 'AUTH_REQUIRED':
      case 'SESSION_EXPIRED':
        return 'انتهت جلسة الألعاب أو لم تسجّل الدخول. سجّل الدخول مرة أخرى.';
      case 'INVALID_CREDENTIALS':
        return 'اسم المستخدم أو كلمة المرور غير صحيح.';
      case 'USERNAME_TAKEN':
        return 'اسم المستخدم مستخدم بالفعل. اختر اسمًا آخر.';
      case 'INVALID_USERNAME':
      case 'INVALID_PASSWORD':
      case 'INVALID_INVITE_CODE':
      case 'INVALID_MOVE':
        return serverMessage is String && serverMessage.isNotEmpty
            ? serverMessage
            : 'البيانات المدخلة غير صحيحة.';
      case 'ROOM_NOT_FOUND':
        return 'المباراة غير موجودة أو رمز الدعوة غير صحيح.';
      case 'ROOM_FULL':
        return 'المباراة ممتلئة بالفعل.';
      case 'CANNOT_JOIN_OWN_ROOM':
        return 'لا يمكنك الانضمام إلى الغرفة التي أنشأتها بنفس الحساب.';
      case 'WAITING_FOR_PLAYER':
        return 'المباراة تنتظر انضمام لاعب آخر.';
      case 'NOT_YOUR_TURN':
        return 'استنى دورك قبل تنفيذ الحركة التالية.';
      case 'ILLEGAL_CHESS_MOVE':
        return 'نقلة الشطرنج غير قانونية. اختر حركة أخرى.';
      case 'GAME_PAUSED':
        return 'المباراة متوقفة مؤقتًا. استأنفها قبل اللعب.';
      case 'ROUND_FINISHED':
      case 'ROOM_FINISHED':
        return 'انتهت المباراة بالفعل.';
      case 'MOVE_ALREADY_SUBMITTED':
        return 'تم إرسال اختيارك لهذه الجولة بالفعل.';
      case 'ROOM_ACCESS_DENIED':
        return 'هذا الحساب ليس من المشاركين في المباراة.';
      case 'UNSUPPORTED_GAME':
        return 'اللعبة المطلوبة غير مدعومة على الخادم الحالي.';
      case 'NETWORK_TIMEOUT':
        return 'انتهت مهلة الاتصال. حاول مرة أخرى.';
      case 'SOCIAL_SERVICE_NOT_CONFIGURED':
        return 'خدمة الألعاب لم تُفعّل على الخادم بعد.';
      default:
        return serverMessage is String && serverMessage.isNotEmpty
            ? serverMessage
            : 'تعذر إكمال الطلب ($error). حاول مرة أخرى.';
    }
  }
}

/// نتيجة تسجيل الدخول أو إنشاء الحساب.
class SocialGameAuthResult {
  const SocialGameAuthResult({
    required this.token,
    required this.user,
  });

  final String token;
  final SocialGameUser user;
}

/// بيانات حساب لاعب آمنة للعرض.
class SocialGameUser {
  const SocialGameUser({
    required this.id,
    required this.username,
    this.createdAt,
  });

  final String id;
  final String username;
  final int? createdAt;

  factory SocialGameUser.fromJson(Map<String, dynamic> json) {
    return SocialGameUser(
      id: json['id'] is String ? json['id'] as String : '',
      username: json['username'] is String
          ? json['username'] as String
          : 'لاعب',
      createdAt: json['createdAt'] is int
          ? json['createdAt'] as int
          : json['created_at'] is int
              ? json['created_at'] as int
              : null,
    );
  }
}

/// نموذج مباراة مسترجع من الخادم.
class SocialGameRoom {
  const SocialGameRoom({
    required this.id,
    required this.inviteCode,
    required this.game,
    required this.status,
    required this.myRole,
    required this.state,
    required this.createdAt,
    required this.updatedAt,
    this.host,
    this.guest,
  });

  final String id;
  final String inviteCode;
  final String game;
  final String status;
  final String myRole;
  final Map<String, dynamic> state;
  final int? createdAt;
  final int? updatedAt;
  final SocialGamePlayer? host;
  final SocialGamePlayer? guest;

  bool get isWaiting => status == 'waiting';

  bool get isPlaying => status == 'playing';

  bool get isPaused => status == 'paused';

  bool get isFinished => status == 'finished';

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
      case 'waiting':
        return 'في انتظار لاعب';
      case 'playing':
        return 'مباراة جارية';
      case 'paused':
        return 'متوقفة مؤقتًا';
      case 'finished':
        return 'انتهت المباراة';
      default:
        return status;
    }
  }

  factory SocialGameRoom.fromJson(Map<String, dynamic> json) {
    final rawState = json['state'];

    return SocialGameRoom(
      id: json['id'] is String ? json['id'] as String : '',
      inviteCode: json['inviteCode'] is String
          ? json['inviteCode'] as String
          : '',
      game: json['game'] is String ? json['game'] as String : '',
      status: json['status'] is String
          ? json['status'] as String
          : 'unknown',
      myRole: json['myRole'] is String
          ? json['myRole'] as String
          : '',
      state: rawState is Map
          ? Map<String, dynamic>.from(rawState)
          : <String, dynamic>{},
      createdAt: json['createdAt'] is int
          ? json['createdAt'] as int
          : null,
      updatedAt: json['updatedAt'] is int
          ? json['updatedAt'] as int
          : null,
      host: json['host'] is Map
          ? SocialGamePlayer.fromJson(
              Map<String, dynamic>.from(json['host'] as Map),
            )
          : null,
      guest: json['guest'] is Map
          ? SocialGamePlayer.fromJson(
              Map<String, dynamic>.from(json['guest'] as Map),
            )
          : null,
    );
  }
}

/// بيانات اللاعب داخل غرفة محددة.
class SocialGamePlayer {
  const SocialGamePlayer({
    required this.id,
    required this.username,
    required this.mark,
  });

  final String id;
  final String username;
  final String mark;

  factory SocialGamePlayer.fromJson(Map<String, dynamic> json) {
    return SocialGamePlayer(
      id: json['id'] is String ? json['id'] as String : '',
      username: json['username'] is String
          ? json['username'] as String
          : 'لاعب',
      mark: json['mark'] is String ? json['mark'] as String : '',
    );
  }
}

/// خطأ معروف من خدمة الألعاب، مع رمز يمكن للواجهة التعامل معه.
class SocialGamesException implements Exception {
  const SocialGamesException(
    this.code,
    this.message, {
    this.statusCode,
  });

  final String code;
  final String message;
  final int? statusCode;

  @override
  String toString() => 'SocialGamesException($code): $message';
}
