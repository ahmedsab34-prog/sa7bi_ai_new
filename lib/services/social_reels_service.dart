
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../config/app_config.dart';
import 'sa7bi_network_client.dart';
import 'social_guest_session_service.dart';
import 'social_session_storage.dart';

class SocialReelsService {
  SocialReelsService._();

  static final SocialReelsService instance =
      SocialReelsService._();

  static const Duration _timeout = Duration(seconds: 45);

  static const int maximumVideoBytes =
      50 * 1024 * 1024;

  String? _token;
  Future<void>? _pendingInitialization;

  bool get isInitialized =>
      _token != null && _token!.isNotEmpty;

  Future<void> initialize() async {
    if (isInitialized) return;

    final pending = _pendingInitialization;

    if (pending != null) {
      await pending;
      return;
    }

    final task = _initializeSession();
    _pendingInitialization = task;

    try {
      await task;
    } finally {
      if (identical(_pendingInitialization, task)) {
        _pendingInitialization = null;
      }
    }
  }

  Future<void> _initializeSession() async {
    await SocialGuestSessionService.instance.ensureSession();

    final token =
        await SocialSessionStorage.instance.readToken();

    if (token == null || token.trim().isEmpty) {
      throw const SocialReelsException(
        'AUTH_REQUIRED',
        'تعذر استعادة جلسة حسابك. افتح الحساب وحاول مرة أخرى.',
      );
    }

    _token = token.trim();
  }

  Future<void> refreshSession() async {
    _token = null;
    await initialize();
  }

  Uri _uri(
    String path, {
    Map<String, String>? query,
  }) {
    final base = Uri.parse(
      AppConfig.buildBackendUrl(path),
    );

    return base.replace(
      queryParameters: query == null || query.isEmpty
          ? null
          : query,
    );
  }

  Future<Map<String, dynamic>> _sendJson(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    await initialize();

    final token = _token;

    if (token == null || token.isEmpty) {
      throw const SocialReelsException(
        'AUTH_REQUIRED',
        'جلسة الحساب غير متاحة.',
      );
    }

    final request = http.Request(
      method,
      _uri(path, query: query),
    );

    request.headers.addAll({
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      'Cache-Control': 'no-store',
    });

    if (body != null) {
      request.headers['Content-Type'] =
          'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }

    return _sendRequest(request);
  }

  Future<Map<String, dynamic>> _sendRequest(
    http.Request request,
  ) async {
    late final http.StreamedResponse streamed;

    try {
      streamed = await Sa7biNetworkClient.client
          .send(request)
          .timeout(_timeout);
    } on TimeoutException {
      throw const SocialReelsException(
        'NETWORK_TIMEOUT',
        'تأخر الاتصال بالخادم. تحقق من الإنترنت وحاول مرة أخرى.',
      );
    } on http.ClientException {
      throw const SocialReelsException(
        'NETWORK_ERROR',
        'تعذر الاتصال بخدمة الريلز.',
      );
    } catch (_) {
      throw const SocialReelsException(
        'NETWORK_ERROR',
        'حدث خطأ أثناء الاتصال بخدمة الريلز.',
      );
    }

    late final http.Response response;

    try {
      response = await http.Response.fromStream(streamed)
          .timeout(_timeout);
    } on TimeoutException {
      throw const SocialReelsException(
        'NETWORK_TIMEOUT',
        'انتهت مهلة استلام رد الخادم.',
      );
    } catch (_) {
      throw const SocialReelsException(
        'NETWORK_ERROR',
        'انقطع الاتصال أثناء استلام رد الخادم.',
      );
    }

    Map<String, dynamic> decoded;

    try {
      final value = jsonDecode(
        utf8.decode(
          response.bodyBytes,
          allowMalformed: true,
        ),
      );

      if (value is! Map) {
        throw const FormatException(
          'Expected a JSON object.',
        );
      }

      decoded = Map<String, dynamic>.from(value);
    } catch (_) {
      throw SocialReelsException(
        'INVALID_SERVER_RESPONSE',
        'رد الخادم غير مفهوم (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    if (
      response.statusCode < 200 ||
      response.statusCode >= 300 ||
      decoded['ok'] != true
    ) {
      final error = _string(
        decoded['error'],
        fallback: 'HTTP_${response.statusCode}',
      );

      throw SocialReelsException(
        error,
        _friendlyMessage(error, decoded['message']),
        statusCode: response.statusCode,
      );
    }

    return decoded;
  }

  Future<List<SocialReel>> loadFeed({
    int limit = 20,
    int? before,
  }) async {
    final query = <String, String>{
      'limit': limit.clamp(1, 30).toString(),
      if (before != null && before > 0)
        'before': before.toString(),
    };

    final result = await _sendJson(
      'GET',
      '/v1/social/reels/feed',
      query: query,
    );

    final values = result['reels'];

    if (values is! List) {
      return const [];
    }

    return values
        .whereType<Map>()
        .map(
          (item) => SocialReel.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList(growable: false);
  }

  Future<SocialReel> uploadReel({
    required XFile file,
    String caption = '',
  }) async {
    await initialize();

    final token = _token;

    if (token == null || token.isEmpty) {
      throw const SocialReelsException(
        'AUTH_REQUIRED',
        'جلسة الحساب غير متاحة.',
      );
    }

    final fileLength = await file.length();

    if (fileLength <= 0) {
      throw const SocialReelsException(
        'EMPTY_UPLOAD',
        'الفيديو فارغ.',
      );
    }

    if (fileLength > maximumVideoBytes) {
      throw const SocialReelsException(
        'REEL_TOO_LARGE',
        'حجم الفيديو أكبر من 50 ميجابايت.',
      );
    }

    final mimeType = _mimeType(file);

    if (mimeType == null) {
      throw const SocialReelsException(
        'UNSUPPORTED_VIDEO_TYPE',
        'صيغة الفيديو غير مدعومة. استخدم MP4 أو MOV أو WEBM.',
      );
    }

    late final List<int> bytes;

    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      throw const SocialReelsException(
        'FILE_READ_FAILED',
        'تعذر قراءة الفيديو من الهاتف.',
      );
    }

    if (bytes.isEmpty) {
      throw const SocialReelsException(
        'EMPTY_UPLOAD',
        'الفيديو فارغ.',
      );
    }

    if (bytes.length != fileLength) {
      throw const SocialReelsException(
        'FILE_READ_INCOMPLETE',
        'لم تتم قراءة ملف الفيديو بالكامل.',
      );
    }

    final cleanedCaption = caption.trim();

    final request = http.Request(
      'POST',
      _uri(
        '/v1/social/reels',
        query: {
          if (cleanedCaption.isNotEmpty)
            'caption': cleanedCaption.length > 220
                ? cleanedCaption.substring(0, 220)
                : cleanedCaption,
        },
      ),
    );

    request.headers.addAll({
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      'Content-Type': mimeType,
      'Content-Length': bytes.length.toString(),
      'Cache-Control': 'no-store',
    });

    request.bodyBytes = bytes;

    // لا نكرر طلب الرفع تلقائيًا عند انتهاء المهلة.
    // المستخدم يستطيع تحديث الخلاصة لمعرفة هل تم النشر.
    final result = await _sendRequest(request);

    final rawReel = result['reel'];

    if (rawReel is! Map) {
      throw const SocialReelsException(
        'INVALID_SERVER_RESPONSE',
        'تم إرسال الفيديو لكن الخادم لم يُرجع بيانات المنشور.',
      );
    }

    return SocialReel.fromJson(
      Map<String, dynamic>.from(rawReel),
    );
  }

  String? _mimeType(XFile file) {
    final declared = file.mimeType?.toLowerCase().trim();

    const supported = {
      'video/mp4',
      'video/quicktime',
      'video/webm',
      'video/3gpp',
      'video/x-m4v',
    };

    if (declared != null && supported.contains(declared)) {
      return declared;
    }

    final name = file.name.toLowerCase();

    if (name.endsWith('.mp4')) return 'video/mp4';
    if (name.endsWith('.mov')) return 'video/quicktime';
    if (name.endsWith('.webm')) return 'video/webm';
    if (name.endsWith('.3gp')) return 'video/3gpp';
    if (name.endsWith('.m4v')) return 'video/x-m4v';

    return null;
  }

  Future<void> likeReel(String reelId) async {
    await _sendJson(
      'POST',
      '/v1/social/reels/$reelId/like',
      body: const {},
    );
  }

  Future<void> unlikeReel(String reelId) async {
    await _sendJson(
      'DELETE',
      '/v1/social/reels/$reelId/like',
    );
  }

  Future<List<SocialReelComment>> loadComments(
    String reelId,
  ) async {
    final result = await _sendJson(
      'GET',
      '/v1/social/reels/$reelId/comments',
    );

    final values = result['comments'];

    if (values is! List) return const [];

    return values
        .whereType<Map>()
        .map(
          (item) => SocialReelComment.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList(growable: false);
  }

  Future<SocialReelComment> addComment({
    required String reelId,
    required String text,
  }) async {
    final cleaned = text.trim();

    if (cleaned.isEmpty || cleaned.length > 1000) {
      throw const SocialReelsException(
        'INVALID_COMMENT',
        'التعليق يجب أن يكون من حرف واحد إلى 1000 حرف.',
      );
    }

    final result = await _sendJson(
      'POST',
      '/v1/social/reels/$reelId/comments',
      body: {'text': cleaned},
    );

    final raw = result['comment'];

    if (raw is! Map) {
      throw const SocialReelsException(
        'INVALID_SERVER_RESPONSE',
        'الخادم لم يُرجع بيانات التعليق.',
      );
    }

    return SocialReelComment.fromJson(
      Map<String, dynamic>.from(raw),
    );
  }

  Future<void> followUser(String userId) async {
    await _sendJson(
      'POST',
      '/v1/social/users/$userId/follow',
      body: const {},
    );
  }

  Future<void> unfollowUser(String userId) async {
    await _sendJson(
      'DELETE',
      '/v1/social/users/$userId/follow',
    );
  }

  Future<void> deleteReel(String reelId) async {
    await _sendJson(
      'DELETE',
      '/v1/social/reels/$reelId',
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  static String _string(
    dynamic value, {
    String fallback = '',
  }) {
    return value is String && value.trim().isNotEmpty
        ? value.trim()
        : fallback;
  }

  static String _friendlyMessage(
    String error,
    dynamic serverMessage,
  ) {
    switch (error) {
      case 'AUTH_REQUIRED':
      case 'SESSION_EXPIRED':
        return 'انتهت جلسة الحساب. افتح الحساب وحاول مرة أخرى.';
      case 'REELS_STORAGE_NOT_CONFIGURED':
        return 'تخزين الريلز لم يتم تفعيله على الخادم بعد.';
      case 'REEL_TOO_LARGE':
        return 'حجم الفيديو أكبر من الحد المسموح (50 ميجابايت).';
      case 'UNSUPPORTED_VIDEO_TYPE':
        return 'صيغة الفيديو غير مدعومة.';
      case 'REEL_DAILY_LIMIT':
        return 'وصلت إلى الحد اليومي لرفع الفيديوهات.';
      case 'REEL_NOT_FOUND':
        return 'الفيديو غير موجود أو تم حذفه.';
      case 'REEL_DELETE_FORBIDDEN':
        return 'لا يمكنك حذف فيديو لا تملكه.';
      case 'EMPTY_COMMENT':
      case 'INVALID_COMMENT':
        return 'اكتب تعليقًا صالحًا قبل الإرسال.';
      case 'CANNOT_FOLLOW_SELF':
        return 'لا يمكنك متابعة حسابك الشخصي.';
      case 'USER_NOT_FOUND':
        return 'حساب المستخدم غير موجود.';
      case 'NETWORK_TIMEOUT':
        return 'انتهت مهلة الاتصال. حدّث الصفحة قبل إعادة رفع الفيديو.';
      default:
        return serverMessage is String &&
                serverMessage.trim().isNotEmpty
            ? serverMessage.trim()
            : 'تعذر إكمال العملية ($error). حاول مرة أخرى.';
    }
  }
}

class SocialReel {
  const SocialReel({
    required this.id,
    required this.ownerId,
    required this.username,
    required this.caption,
    required this.videoUrl,
    required this.contentType,
    required this.sizeBytes,
    required this.createdAt,
    required this.likesCount,
    required this.commentsCount,
    required this.likedByMe,
    required this.followedByMe,
    required this.isMine,
  });

  final String id;
  final String ownerId;
  final String username;
  final String caption;
  final String videoUrl;
  final String contentType;
  final int sizeBytes;
  final int createdAt;
  final int likesCount;
  final int commentsCount;
  final bool likedByMe;
  final bool followedByMe;
  final bool isMine;

  SocialReel copyWith({
    int? likesCount,
    int? commentsCount,
    bool? likedByMe,
    bool? followedByMe,
  }) {
    return SocialReel(
      id: id,
      ownerId: ownerId,
      username: username,
      caption: caption,
      videoUrl: videoUrl,
      contentType: contentType,
      sizeBytes: sizeBytes,
      createdAt: createdAt,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      likedByMe: likedByMe ?? this.likedByMe,
      followedByMe: followedByMe ?? this.followedByMe,
      isMine: isMine,
    );
  }

  factory SocialReel.fromJson(Map<String, dynamic> json) {
    return SocialReel(
      id: json['id'] is String ? json['id'] as String : '',
      ownerId:
          json['ownerId'] is String ? json['ownerId'] as String : '',
      username: SocialReelsService._string(
        json['username'],
        fallback: 'صاحبي',
      ),
      caption: json['caption'] is String
          ? json['caption'] as String
          : '',
      videoUrl: json['videoUrl'] is String
          ? json['videoUrl'] as String
          : '',
      contentType: json['contentType'] is String
          ? json['contentType'] as String
          : 'video/mp4',
      sizeBytes: SocialReelsService._readInt(json['sizeBytes']),
      createdAt: SocialReelsService._readInt(json['createdAt']),
      likesCount: SocialReelsService._readInt(json['likesCount']),
      commentsCount:
          SocialReelsService._readInt(json['commentsCount']),
      likedByMe: json['likedByMe'] == true,
      followedByMe: json['followedByMe'] == true,
      isMine: json['isMine'] == true,
    );
  }
}

class SocialReelComment {
  const SocialReelComment({
    required this.id,
    required this.userId,
    required this.username,
    required this.text,
    required this.createdAt,
    required this.isMine,
  });

  final String id;
  final String userId;
  final String username;
  final String text;
  final int createdAt;
  final bool isMine;

  factory SocialReelComment.fromJson(
    Map<String, dynamic> json,
  ) {
    return SocialReelComment(
      id: json['id'] is String ? json['id'] as String : '',
      userId:
          json['userId'] is String ? json['userId'] as String : '',
      username: SocialReelsService._string(
        json['username'],
        fallback: 'صاحبي',
      ),
      text: json['text'] is String
          ? json['text'] as String
          : '',
      createdAt: SocialReelsService._readInt(json['createdAt']),
      isMine: json['isMine'] == true,
    );
  }
}

class SocialReelsException implements Exception {
  const SocialReelsException(
    this.code,
    this.message, {
    this.statusCode,
  });

  final String code;
  final String message;
  final int? statusCode;

  @override
  String toString() =>
      'SocialReelsException($code): $message';
}
