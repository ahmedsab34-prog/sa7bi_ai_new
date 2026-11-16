import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';
import 'sa7bi_network_client.dart';
import 'social_guest_session_service.dart';
import 'social_session_storage.dart';

/// Metadata for a private Sa7bi Connect attachment.
class SocialAttachment {
  const SocialAttachment({
    required this.id,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
    required this.createdAt,
  });

  final String id;
  final String fileName;
  final String contentType;
  final int sizeBytes;
  final int createdAt;

  factory SocialAttachment.fromJson(Map<String, dynamic> json) {
    return SocialAttachment(
      id: json['id'] is String ? json['id'] as String : '',
      fileName: json['fileName'] is String
          ? json['fileName'] as String
          : 'attachment',
      contentType: json['contentType'] is String
          ? json['contentType'] as String
          : 'application/octet-stream',
      sizeBytes: _readInt(json['sizeBytes']),
      createdAt: _readInt(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'fileName': fileName,
        'contentType': contentType,
        'sizeBytes': sizeBytes,
        'createdAt': createdAt,
      };
}

/// Decoded presentation model embedded in a normal chat message's text.
class SocialAttachmentMessage {
  const SocialAttachmentMessage({
    required this.attachment,
    required this.caption,
  });

  final SocialAttachment attachment;
  final String caption;
}

/// A versioned envelope keeps existing message database schemas unchanged.
/// New clients decode it; older clients still receive a normal text field.
class SocialAttachmentMessageCodec {
  SocialAttachmentMessageCodec._();

  static const String prefix = 'SA7BI_ATTACHMENT_V1:';

  static String encode(
    SocialAttachment attachment, {
    String caption = '',
  }) {
    final cleanCaption = caption.trim();
    final safeCaption = cleanCaption.length > 500
        ? cleanCaption.substring(0, 500)
        : cleanCaption;
    final payload = <String, dynamic>{
      'version': 1,
      'attachment': attachment.toJson(),
      'caption': safeCaption,
    };

    return '$prefix${base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '')}';
  }

  static SocialAttachmentMessage? decode(String messageText) {
    if (!messageText.startsWith(prefix)) return null;

    final encoded = messageText.substring(prefix.length).trim();
    if (encoded.isEmpty || encoded.length > 4096) return null;

    try {
      final normalized = base64Url.normalize(encoded);
      final decoded = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      if (decoded is! Map) return null;

      final payload = Map<String, dynamic>.from(decoded);
      if (payload['version'] != 1 || payload['attachment'] is! Map) {
        return null;
      }

      final attachment = SocialAttachment.fromJson(
        Map<String, dynamic>.from(payload['attachment'] as Map),
      );
      if (!_isUuid(attachment.id) ||
          attachment.fileName.isEmpty ||
          attachment.sizeBytes <= 0) {
        return null;
      }

      final caption = payload['caption'] is String
          ? (payload['caption'] as String).trim()
          : '';

      return SocialAttachmentMessage(
        attachment: attachment,
        caption: caption,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Uploads and downloads authenticated private Connect attachments.
///
/// Upload scopes are either:
/// - conversation: a private one-to-one conversation UUID.
/// - group: a group UUID (public or private, with current membership).
///
/// The Worker verifies the session and membership on every upload/download.
class SocialAttachmentService {
  SocialAttachmentService._();

  static final SocialAttachmentService instance =
      SocialAttachmentService._();

  static const int maximumUploadBytes = 10 * 1024 * 1024;
  static const Duration _requestTimeout = Duration(seconds: 40);
  static const Duration _downloadTimeout = Duration(seconds: 60);

  static const Set<String> allowedContentTypes = <String>{
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
    'audio/mp4',
    'audio/aac',
    'audio/mpeg',
    'audio/ogg',
    'audio/webm',
    'application/pdf',
    'text/plain',
  };

  Future<String> _requireToken() async {
    await SocialGuestSessionService.instance.ensureSession();
    final token = await SocialSessionStorage.instance.readToken();

    if (token == null || token.isEmpty) {
      throw const SocialAttachmentException(
        'AUTH_REQUIRED',
        'جلسة صاحبي Connect غير متاحة. حاول تسجيل الدخول مرة أخرى.',
      );
    }

    return token;
  }

  Future<SocialAttachment> upload({
    required String scopeType,
    required String scopeId,
    required String fileName,
    required String contentType,
    required Uint8List bytes,
  }) async {
    final normalizedScope = scopeType.trim().toLowerCase();
    final normalizedScopeId = scopeId.trim().toLowerCase();
    final normalizedType = contentType.split(';').first.trim().toLowerCase();
    final safeName = _safeFileName(fileName);

    if (normalizedScope != 'conversation' && normalizedScope != 'group') {
      throw const SocialAttachmentException(
        'INVALID_ATTACHMENT_SCOPE',
        'نوع المحادثة غير صالح لإرسال المرفق.',
      );
    }

    if (!_isUuid(normalizedScopeId)) {
      throw const SocialAttachmentException(
        'INVALID_ATTACHMENT_SCOPE_ID',
        'معرّف المحادثة أو المجموعة غير صالح.',
      );
    }

    if (!allowedContentTypes.contains(normalizedType)) {
      throw const SocialAttachmentException(
        'UNSUPPORTED_ATTACHMENT_TYPE',
        'نوع الملف غير مدعوم. استخدم صورة أو صوتًا أو PDF أو ملفًا نصيًا.',
      );
    }

    if (bytes.isEmpty || bytes.length > maximumUploadBytes) {
      throw const SocialAttachmentException(
        'ATTACHMENT_TOO_LARGE',
        'حجم المرفق يجب ألا يتجاوز 10 ميجابايت.',
      );
    }

    final token = await _requireToken();
    final request = http.Request(
      'POST',
      Uri.parse(AppConfig.buildBackendUrl('/v1/social/attachments')),
    )
      ..headers.addAll(<String, String>{
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
        'Cache-Control': 'no-store',
        'Content-Type': normalizedType,
        'X-Sa7bi-Attachment-Scope': normalizedScope,
        'X-Sa7bi-Attachment-Scope-Id': normalizedScopeId,
        'X-Sa7bi-Attachment-Filename':
            base64Url.encode(utf8.encode(safeName)).replaceAll('=', ''),
      });
    request.bodyBytes = bytes;
    request.contentLength = bytes.length;

    final response = await _send(request, timeout: _requestTimeout);
    final data = _decodeMap(response.bodyBytes);

    if (response.statusCode < 200 || response.statusCode >= 300 ||
        data?['ok'] != true) {
      final code = _errorCode(data, response.statusCode);
      throw SocialAttachmentException(
        code,
        _friendlyError(code),
        statusCode: response.statusCode,
      );
    }

    final rawAttachment = data?['attachment'];
    if (rawAttachment is! Map) {
      throw const SocialAttachmentException(
        'INVALID_SERVER_RESPONSE',
        'الخادم لم يُرجع بيانات المرفق بالشكل المتوقع.',
      );
    }

    final attachment = SocialAttachment.fromJson(
      Map<String, dynamic>.from(rawAttachment),
    );

    if (!_isUuid(attachment.id) || attachment.sizeBytes != bytes.length) {
      throw const SocialAttachmentException(
        'INVALID_SERVER_RESPONSE',
        'بيانات المرفق التي وصلت من الخادم غير مكتملة.',
      );
    }

    return attachment;
  }

  Future<Uint8List> downloadBytes(String attachmentId) async {
    final id = attachmentId.trim().toLowerCase();
    if (!_isUuid(id)) {
      throw const SocialAttachmentException(
        'ATTACHMENT_NOT_FOUND',
        'معرّف المرفق غير صحيح.',
      );
    }

    final token = await _requireToken();
    final request = http.Request(
      'GET',
      Uri.parse(AppConfig.buildBackendUrl('/v1/social/attachments/$id')),
    )
      ..headers.addAll(<String, String>{
        'Accept': '*/*',
        'Authorization': 'Bearer $token',
        'Cache-Control': 'no-store',
      });

    final response = await _send(request, timeout: _downloadTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final data = _decodeMap(response.bodyBytes);
      final code = _errorCode(data, response.statusCode);
      throw SocialAttachmentException(
        code,
        _friendlyError(code),
        statusCode: response.statusCode,
      );
    }

    if (response.bodyBytes.isEmpty ||
        response.bodyBytes.length > maximumUploadBytes) {
      throw const SocialAttachmentException(
        'INVALID_ATTACHMENT_BYTES',
        'تعذر تنزيل المرفق أو أن حجمه غير صالح.',
      );
    }

    return Uint8List.fromList(response.bodyBytes);
  }

  Future<File> downloadToTemporaryFile({
    required String attachmentId,
    required String fileName,
  }) async {
    final id = attachmentId.trim().toLowerCase();
    if (!_isUuid(id)) {
      throw const SocialAttachmentException(
        'ATTACHMENT_NOT_FOUND',
        'معرّف المرفق غير صحيح.',
      );
    }

    final bytes = await downloadBytes(id);
    final directory = await getTemporaryDirectory();
    final safeName = _safeFileName(fileName);
    final file = File('${directory.path}/sa7bi_${id}_$safeName');

    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> delete(String attachmentId) async {
    final id = attachmentId.trim().toLowerCase();
    if (!_isUuid(id)) return;

    final token = await _requireToken();
    final request = http.Request(
      'DELETE',
      Uri.parse(AppConfig.buildBackendUrl('/v1/social/attachments/$id')),
    )
      ..headers.addAll(<String, String>{
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
        'Cache-Control': 'no-store',
      });

    final response = await _send(request, timeout: _requestTimeout);
    final data = _decodeMap(response.bodyBytes);

    if (response.statusCode < 200 || response.statusCode >= 300 ||
        data?['ok'] != true) {
      final code = _errorCode(data, response.statusCode);
      throw SocialAttachmentException(
        code,
        _friendlyError(code),
        statusCode: response.statusCode,
      );
    }
  }

  Future<http.Response> _send(
    http.Request request, {
    required Duration timeout,
  }) async {
    try {
      final streamed = await Sa7biNetworkClient.client
          .send(request)
          .timeout(timeout);
      return await http.Response.fromStream(streamed).timeout(timeout);
    } on TimeoutException {
      throw const SocialAttachmentException(
        'NETWORK_TIMEOUT',
        'الاتصال بالمرفقات استغرق وقتًا طويلًا. حاول مرة أخرى.',
      );
    } on http.ClientException {
      throw const SocialAttachmentException(
        'NETWORK_ERROR',
        'تعذر الاتصال بخدمة المرفقات. تحقق من الإنترنت.',
      );
    }
  }

  Map<String, dynamic>? _decodeMap(List<int> bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: true));
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  String _errorCode(Map<String, dynamic>? data, int statusCode) {
    final value = data?['error'];
    return value is String && value.isNotEmpty
        ? value
        : 'HTTP_$statusCode';
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'AUTH_REQUIRED':
      case 'SESSION_EXPIRED':
        return 'انتهت جلسة الحساب. أعد فتح Connect وحاول مرة أخرى.';
      case 'ATTACHMENT_SCOPE_ACCESS_DENIED':
      case 'ATTACHMENT_ACCESS_DENIED':
        return 'لا تملك صلاحية الوصول إلى هذا المرفق أو المحادثة.';
      case 'ATTACHMENT_DELETE_ACCESS_DENIED':
        return 'لا يمكنك حذف مرفق أرسله حساب آخر.';
      case 'ATTACHMENT_NOT_FOUND':
        return 'المرفق غير موجود أو لم يعد متاحًا.';
      case 'UNSUPPORTED_ATTACHMENT_TYPE':
        return 'نوع الملف غير مدعوم.';
      case 'ATTACHMENT_TOO_LARGE':
        return 'حجم المرفق أكبر من الحد المسموح (10 ميجابايت).';
      case 'ATTACHMENT_STORAGE_NOT_CONFIGURED':
        return 'تخزين مرفقات Connect غير متاح على الخادم حاليًا.';
      case 'NETWORK_TIMEOUT':
        return 'انتهت مهلة الاتصال. حاول مرة أخرى.';
      default:
        return 'تعذر إكمال طلب المرفق ($code). حاول مرة أخرى.';
    }
  }

  static String _safeFileName(String value) {
    final cleaned = value
        .replaceAll(RegExp(r'[\\/\u0000-\u001f\u007f<>:"|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return 'attachment';
    return cleaned.length > 120 ? cleaned.substring(0, 120) : cleaned;
  }
}

class SocialAttachmentException implements Exception {
  const SocialAttachmentException(
    this.code,
    this.message, {
    this.statusCode,
  });

  final String code;
  final String message;
  final int? statusCode;

  @override
  String toString() => 'SocialAttachmentException($code): $message';
}

bool _isUuid(String value) =>
    RegExp(r'^[a-f0-9-]{36}$', caseSensitive: false).hasMatch(value);

int _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return 0;
}
