import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef AudioDownloadProgress = void Function(
  int receivedBytes,
  int totalBytes,
);

class DownloadedAudio {
  const DownloadedAudio({
    required this.id,
    required this.title,
    required this.filePath,
    required this.sourceUrl,
    required this.sizeBytes,
    required this.downloadedAt,
    this.artist,
    this.album,
    this.durationMs,
    this.artUri,
  });

  final String id;
  final String title;
  final String filePath;
  final String sourceUrl;
  final int sizeBytes;
  final DateTime downloadedAt;
  final String? artist;
  final String? album;
  final int? durationMs;
  final String? artUri;

  MediaItem toMediaItem() {
    return MediaItem(
      id: filePath,
      title: title,
      artist: artist,
      album: album,
      duration: durationMs == null
          ? null
          : Duration(milliseconds: durationMs!),
      artUri: artUri == null || artUri!.isEmpty
          ? null
          : Uri.tryParse(artUri!),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'filePath': filePath,
      'sourceUrl': sourceUrl,
      'sizeBytes': sizeBytes,
      'downloadedAt': downloadedAt.millisecondsSinceEpoch,
      'artist': artist,
      'album': album,
      'durationMs': durationMs,
      'artUri': artUri,
    };
  }

  static DownloadedAudio? fromJson(dynamic value) {
    if (value is! Map) return null;

    final map = Map<String, dynamic>.from(value);

    final id = map['id'];
    final title = map['title'];
    final filePath = map['filePath'];
    final sourceUrl = map['sourceUrl'];
    final sizeBytes = map['sizeBytes'];
    final downloadedAt = map['downloadedAt'];

    if (id is! String ||
        title is! String ||
        filePath is! String ||
        sourceUrl is! String ||
        sizeBytes is! num ||
        downloadedAt is! num) {
      return null;
    }

    return DownloadedAudio(
      id: id,
      title: title,
      filePath: filePath,
      sourceUrl: sourceUrl,
      sizeBytes: sizeBytes.toInt(),
      downloadedAt: DateTime.fromMillisecondsSinceEpoch(
        downloadedAt.toInt(),
      ),
      artist: map['artist'] is String
          ? map['artist'] as String
          : null,
      album: map['album'] is String
          ? map['album'] as String
          : null,
      durationMs: map['durationMs'] is num
          ? (map['durationMs'] as num).toInt()
          : null,
      artUri: map['artUri'] is String
          ? map['artUri'] as String
          : null,
    );
  }
}

class _PartialDownload {
  const _PartialDownload({
    required this.id,
    required this.sourceUrl,
    required this.filePath,
    required this.totalBytes,
    required this.validator,
    required this.extension,
    required this.updatedAt,
  });

  final String id;
  final String sourceUrl;
  final String filePath;
  final int totalBytes;
  final String validator;
  final String extension;
  final int updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourceUrl': sourceUrl,
        'filePath': filePath,
        'totalBytes': totalBytes,
        'validator': validator,
        'extension': extension,
        'updatedAt': updatedAt,
      };

  static _PartialDownload? fromJson(dynamic value) {
    if (value is! Map) return null;

    final map = Map<String, dynamic>.from(value);

    if (map['id'] is! String ||
        map['sourceUrl'] is! String ||
        map['filePath'] is! String ||
        map['totalBytes'] is! num ||
        map['validator'] is! String ||
        map['extension'] is! String ||
        map['updatedAt'] is! num) {
      return null;
    }

    return _PartialDownload(
      id: map['id'] as String,
      sourceUrl: map['sourceUrl'] as String,
      filePath: map['filePath'] as String,
      totalBytes: (map['totalBytes'] as num).toInt(),
      validator: map['validator'] as String,
      extension: map['extension'] as String,
      updatedAt: (map['updatedAt'] as num).toInt(),
    );
  }

  _PartialDownload copyWith({
    int? totalBytes,
    String? validator,
    String? extension,
    int? updatedAt,
  }) {
    return _PartialDownload(
      id: id,
      sourceUrl: sourceUrl,
      filePath: filePath,
      totalBytes: totalBytes ?? this.totalBytes,
      validator: validator ?? this.validator,
      extension: extension ?? this.extension,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// تنزيل ملفات صوتية مباشرة مع الاحتفاظ بالجزء المكتمل عند الانقطاع.
///
/// الاستكمال الآمن يعتمد على دعم الخادم لـ HTTP Range مع ETag
/// أو Last-Modified. لا ينزل قوائم HLS أو محطات الراديو الحية.
class AudioDownloadsService {
  AudioDownloadsService._();

  static final AudioDownloadsService instance =
      AudioDownloadsService._();

  static const String _storageKey =
      'sa7bi_audio_downloads_v1';

  static const String _partialStorageKey =
      'sa7bi_audio_download_parts_v1';

  static const int maxDownloadBytes =
      100 * 1024 * 1024;

  static const Duration _requestTimeout =
      Duration(seconds: 30);

  static const Duration _streamTimeout =
      Duration(seconds: 45);

  static const Duration _partialRetention =
      Duration(days: 30);

  final http.Client _client = http.Client();
  final Set<String> _activeDownloads = <String>{};

  static bool isSupportedSourceUrl(String source) {
    final uri = Uri.tryParse(source.trim());

    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return false;
    }

    const unsupportedExtensions = <String>[
      '.m3u8',
      '.m3u',
      '.pls',
      '.asx',
      '.mpd',
      '.ism',
    ];

    final path = uri.path.toLowerCase();

    return !unsupportedExtensions.any(path.endsWith);
  }

  Future<Directory> _downloadDirectory() async {
    final root = await getApplicationSupportDirectory();

    final directory = Directory(
      '${root.path}${Platform.pathSeparator}'
      'sa7bi_audio_downloads',
    );

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return directory;
  }

  Future<List<DownloadedAudio>> getDownloads() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_storageKey);

    if (encoded == null || encoded.trim().isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(encoded);

      if (decoded is! List) return const [];

      final result = <DownloadedAudio>[];

      for (final value in decoded) {
        final item = DownloadedAudio.fromJson(value);
        if (item == null) continue;

        if (await File(item.filePath).exists()) {
          result.add(item);
        }
      }

      result.sort(
        (a, b) => b.downloadedAt.compareTo(a.downloadedAt),
      );

      return result;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveDownloads(
    List<DownloadedAudio> items,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _storageKey,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }

  Future<List<_PartialDownload>> _loadPartials() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_partialStorageKey);

    if (encoded == null || encoded.trim().isEmpty) {
      return <_PartialDownload>[];
    }

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return <_PartialDownload>[];

      final now = DateTime.now();
      final valid = <_PartialDownload>[];

      for (final value in decoded) {
        final item = _PartialDownload.fromJson(value);
        if (item == null) continue;

        final age = now.difference(
          DateTime.fromMillisecondsSinceEpoch(item.updatedAt),
        );

        final file = File(item.filePath);

        if (age > _partialRetention || !await file.exists()) {
          try {
            if (await file.exists()) await file.delete();
          } catch (_) {}
          continue;
        }

        valid.add(item);
      }

      await _savePartials(valid);
      return valid;
    } catch (_) {
      return <_PartialDownload>[];
    }
  }

  Future<void> _savePartials(
    List<_PartialDownload> items,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _partialStorageKey,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> _upsertPartial(
    _PartialDownload partial,
  ) async {
    final items = await _loadPartials();

    items.removeWhere(
      (item) =>
          item.id == partial.id ||
          item.sourceUrl == partial.sourceUrl,
    );

    items.add(partial);
    await _savePartials(items);
  }

  Future<void> _removePartial(
    _PartialDownload partial, {
    bool deleteFile = false,
  }) async {
    if (deleteFile) {
      try {
        final file = File(partial.filePath);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }

    final items = await _loadPartials();
    items.removeWhere((item) => item.id == partial.id);
    await _savePartials(items);
  }

  Future<_PartialDownload> _newPartial(
    String sourceUrl,
  ) async {
    final directory = await _downloadDirectory();

    final id = DateTime.now()
        .microsecondsSinceEpoch
        .toString();

    final filePath =
        '${directory.path}${Platform.pathSeparator}'
        'sa7bi_partial_$id.part';

    await File(filePath).create(recursive: true);

    final partial = _PartialDownload(
      id: id,
      sourceUrl: sourceUrl,
      filePath: filePath,
      totalBytes: 0,
      validator: '',
      extension: '',
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    await _upsertPartial(partial);
    return partial;
  }

  Future<_PartialDownload> _findOrCreatePartial(
    String sourceUrl,
  ) async {
    final items = await _loadPartials();

    for (final item in items) {
      if (item.sourceUrl != sourceUrl) continue;

      final file = File(item.filePath);

      if (!await file.exists()) {
        await _removePartial(item);
        break;
      }

      final size = await file.length();

      if (size > maxDownloadBytes) {
        await _removePartial(item, deleteFile: true);
        break;
      }

      return item;
    }

    return _newPartial(sourceUrl);
  }

  Future<_PartialDownload> _resetPartial(
    _PartialDownload partial,
  ) async {
    final file = File(partial.filePath);

    if (await file.exists()) {
      await file.delete();
    }

    await file.create(recursive: true);

    final reset = partial.copyWith(
      totalBytes: 0,
      validator: '',
      extension: '',
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    await _upsertPartial(reset);
    return reset;
  }

  String _readValidator(Map<String, String> headers) {
    final etag = (headers['etag'] ?? '').trim();

    if (etag.isNotEmpty && !etag.startsWith('W/')) {
      return 'etag:$etag';
    }

    final modified = (headers['last-modified'] ?? '').trim();

    if (modified.isNotEmpty) {
      return 'last-modified:$modified';
    }

    return '';
  }

  String? _ifRangeValue(String validator) {
    if (validator.startsWith('etag:')) {
      return validator.substring(5);
    }

    if (validator.startsWith('last-modified:')) {
      return validator.substring(14);
    }

    return null;
  }

  ({int start, int end, int total})? _parseContentRange(
    String? value,
  ) {
    if (value == null) return null;

    final match = RegExp(
      r'^bytes\s+(\d+)-(\d+)/(\d+)$',
      caseSensitive: false,
    ).firstMatch(value.trim());

    if (match == null) return null;

    final start = int.tryParse(match.group(1)!);
    final end = int.tryParse(match.group(2)!);
    final total = int.tryParse(match.group(3)!);

    if (start == null ||
        end == null ||
        total == null ||
        start < 0 ||
        end < start ||
        total <= end) {
      return null;
    }

    return (start: start, end: end, total: total);
  }

  Future<DownloadedAudio> download(
    MediaItem source, {
    AudioDownloadProgress? onProgress,
  }) async {
    final sourceUrl = source.id.trim();

    if (!isSupportedSourceUrl(sourceUrl)) {
      throw const AudioDownloadException(
        'المصدر غير مناسب للتنزيل. نحتاج رابط HTTPS مباشرًا.',
      );
    }

    if (!_activeDownloads.add(sourceUrl)) {
      throw const AudioDownloadException(
        'هذا الملف قيد التنزيل بالفعل.',
      );
    }

    try {
      return await _downloadWithResume(
        source,
        sourceUrl,
        onProgress: onProgress,
      );
    } finally {
      _activeDownloads.remove(sourceUrl);
    }
  }

  Future<DownloadedAudio> _downloadWithResume(
    MediaItem source,
    String sourceUrl, {
    AudioDownloadProgress? onProgress,
  }) async {
    final existingItems = await getDownloads();

    for (final item in existingItems) {
      if (item.sourceUrl == sourceUrl &&
          await File(item.filePath).exists()) {
        return item;
      }
    }

    var partial = await _findOrCreatePartial(sourceUrl);
    var partialFile = File(partial.filePath);
    var offset = await partialFile.length();

    // لا نستكمل ملفًا قديمًا من غير مُعرّف نسخة موثوق.
    // نبدأ من الصفر بدل دمج أجزاء ربما تخص ملفين مختلفين.
    if (offset > 0 &&
        (partial.validator.isEmpty ||
            partial.totalBytes <= 0 ||
            offset > partial.totalBytes)) {
      partial = await _resetPartial(partial);
      partialFile = File(partial.filePath);
      offset = 0;
    }

    if (offset > 0 &&
        offset == partial.totalBytes &&
        partial.extension.isNotEmpty) {
      return _finalize(
        source,
        partial,
        partial.totalBytes,
      );
    }

    final uri = Uri.parse(sourceUrl);
    final headers = <String, String>{
      'Accept': 'audio/*, application/octet-stream;q=0.9, */*;q=0.1',
      'Cache-Control': 'no-cache',
    };

    if (offset > 0) {
      headers['Range'] = 'bytes=$offset-';

      final ifRange = _ifRangeValue(partial.validator);
      if (ifRange != null) {
        headers['If-Range'] = ifRange;
      }
    }

    final request = http.Request('GET', uri)
      ..headers.addAll(headers);

    late final http.StreamedResponse response;

    try {
      response = await _client
          .send(request)
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw const AudioDownloadException(
        'انتهت مهلة الاتصال. اضغط التنزيل مرة أخرى لمحاولة الاستكمال.',
      );
    } catch (_) {
      throw const AudioDownloadException(
        'تعذر الاتصال بمصدر الصوت. افحص الإنترنت ثم أعد المحاولة.',
      );
    }

    final finalUri = response.request?.url ?? uri;

    if (finalUri.scheme.toLowerCase() != 'https') {
      await _removePartial(partial, deleteFile: true);
      throw const AudioDownloadException(
        'تم رفض التحويل إلى رابط غير آمن.',
      );
    }

    if (response.statusCode == 416 &&
        offset > 0 &&
        offset == partial.totalBytes &&
        partial.extension.isNotEmpty) {
      return _finalize(
        source,
        partial,
        partial.totalBytes,
      );
    }

    var writeOffset = offset;
    late int totalBytes;

    if (response.statusCode == 200) {
      // الخادم تجاهل Range أو طلب نسخة كاملة؛ نكتب من البداية.
      writeOffset = 0;

      final length = response.contentLength;
      if (length == null || length <= 0) {
        await _removePartial(partial, deleteFile: true);
        throw const AudioDownloadException(
          'المصدر لا يعلن حجم الملف، لذلك لا يمكن التحقق من اكتمال التنزيل.',
        );
      }

      totalBytes = length;
    } else if (response.statusCode == 206) {
      final range = _parseContentRange(
        response.headers['content-range'],
      );

      if (range == null || range.start != offset) {
        await _removePartial(partial, deleteFile: true);
        throw const AudioDownloadException(
          'استجابة الاستكمال غير صحيحة. أعد التنزيل من البداية.',
        );
      }

      totalBytes = range.total;

      if (partial.totalBytes > 0 &&
          partial.totalBytes != totalBytes) {
        await _removePartial(partial, deleteFile: true);
        throw const AudioDownloadException(
          'تغيّر حجم الملف على المصدر. ابدأ تنزيلًا جديدًا.',
        );
      }

      final responseValidator = _readValidator(response.headers);

      if (partial.validator.isNotEmpty &&
          responseValidator.isNotEmpty &&
          partial.validator != responseValidator) {
        await _removePartial(partial, deleteFile: true);
        throw const AudioDownloadException(
          'تغيّرت نسخة الملف على المصدر. اضغط التنزيل مرة أخرى.',
        );
      }
    } else {
      throw AudioDownloadException(
        'مصدر الصوت لم يقبل التنزيل. كود الاستجابة: '
        '${response.statusCode}',
      );
    }

    if (totalBytes <= 0 || totalBytes > maxDownloadBytes) {
      await _removePartial(partial, deleteFile: true);
      throw const AudioDownloadException(
        'حجم الملف غير صالح أو أكبر من الحد المسموح به وهو 100 ميجابايت.',
      );
    }

    final contentType =
        (response.headers['content-type'] ?? '')
            .split(';')
            .first
            .trim()
            .toLowerCase();

    if (contentType.contains('mpegurl') ||
        contentType.contains('dash+xml') ||
        contentType.startsWith('text/')) {
      await _removePartial(partial, deleteFile: true);
      throw const AudioDownloadException(
        'هذا المصدر قائمة تشغيل أو صفحة ويب وليس ملفًا صوتيًا مباشرًا.',
      );
    }

    final isAudioContent =
        contentType.startsWith('audio/') ||
        contentType == 'application/octet-stream' ||
        contentType == 'application/ogg' ||
        contentType.isEmpty;

    if (!isAudioContent) {
      await _removePartial(partial, deleteFile: true);
      throw const AudioDownloadException(
        'نوع الملف الذي أعاده المصدر ليس ملفًا صوتيًا.',
      );
    }

    final extension = _fileExtension(
      finalUri,
      contentType,
    ) ?? (writeOffset > 0 ? partial.extension : null);

    if (extension == null || extension.isEmpty) {
      await _removePartial(partial, deleteFile: true);
      throw const AudioDownloadException(
        'لم نستطع تحديد صيغة الملف الصوتي بأمان.',
      );
    }

    final responseValidator = _readValidator(response.headers);
    final validator = responseValidator.isNotEmpty
        ? responseValidator
        : (writeOffset > 0 ? partial.validator : '');

    partial = partial.copyWith(
      totalBytes: totalBytes,
      validator: validator,
      extension: extension,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    await _upsertPartial(partial);

    final output = partialFile.openWrite(
      mode: writeOffset > 0 ? FileMode.append : FileMode.write,
    );

    var receivedBytes = writeOffset;

    try {
      onProgress?.call(receivedBytes, totalBytes);

      await for (final chunk in response.stream.timeout(
        _streamTimeout,
      )) {
        receivedBytes += chunk.length;

        if (receivedBytes > maxDownloadBytes ||
            receivedBytes > totalBytes) {
          throw const AudioDownloadException(
            'تجاوز التنزيل الحجم المسموح أو الحجم المعلن من المصدر.',
          );
        }

        output.add(chunk);

        onProgress?.call(
          receivedBytes,
          totalBytes,
        );
      }

      await output.flush();
      await output.close();
    } catch (error) {
      try {
        await output.close();
      } catch (_) {}

      if (partial.validator.isEmpty) {
        await _removePartial(partial, deleteFile: true);
      }

      if (error is AudioDownloadException) rethrow;

      throw const AudioDownloadException(
        'انقطع تنزيل الصوت. اضغط حفظ مرة أخرى لاستكمال الجزء المحفوظ إذا كان المصدر يدعم ذلك.',
      );
    }

    final actualSize = await partialFile.length();

    if (actualSize > totalBytes ||
        actualSize > maxDownloadBytes) {
      await _removePartial(partial, deleteFile: true);
      throw const AudioDownloadException(
        'حجم الملف المستلم غير مطابق للمصدر.',
      );
    }

    if (actualSize < totalBytes) {
      if (partial.validator.isEmpty) {
        await _removePartial(partial, deleteFile: true);
      }

      throw const AudioDownloadException(
        'التنزيل لم يكتمل بعد. اضغط التنزيل مرة أخرى لمحاولة الاستكمال.',
      );
    }

    return _finalize(
      source,
      partial,
      actualSize,
    );
  }

  Future<DownloadedAudio> _finalize(
    MediaItem source,
    _PartialDownload partial,
    int actualSize,
  ) async {
    if (partial.extension.isEmpty ||
        actualSize <= 0 ||
        actualSize > maxDownloadBytes) {
      await _removePartial(partial, deleteFile: true);
      throw const AudioDownloadException(
        'تعذر اعتماد الملف الصوتي النهائي.',
      );
    }

    final partialFile = File(partial.filePath);

    if (!await partialFile.exists() ||
        await partialFile.length() != actualSize) {
      throw const AudioDownloadException(
        'الملف المؤقت غير مكتمل. أعد محاولة التنزيل.',
      );
    }

    final directory = await _downloadDirectory();

    final finalPath =
        '${directory.path}${Platform.pathSeparator}'
        'sa7bi_audio_${partial.id}${partial.extension}';

    final finalFile = File(finalPath);

    if (await finalFile.exists()) {
      await finalFile.delete();
    }

    final savedFile = await partialFile.rename(finalPath);

    final downloaded = DownloadedAudio(
      id: partial.id,
      title: source.title.trim().isEmpty
          ? 'ملف صوتي'
          : source.title.trim(),
      filePath: savedFile.path,
      sourceUrl: partial.sourceUrl,
      sizeBytes: actualSize,
      downloadedAt: DateTime.now(),
      artist: source.artist,
      album: source.album,
      durationMs: source.duration?.inMilliseconds,
      artUri: source.artUri?.toString(),
    );

    final latestItems = await getDownloads();

    latestItems.removeWhere(
      (item) => item.sourceUrl == partial.sourceUrl,
    );

    latestItems.insert(0, downloaded);

    await _saveDownloads(latestItems);
    await _removePartial(partial);

    return downloaded;
  }

  String? _fileExtension(
    Uri uri,
    String contentType,
  ) {
    const allowed = <String>{
      '.mp3',
      '.m4a',
      '.m4b',
      '.aac',
      '.ogg',
      '.oga',
      '.opus',
      '.wav',
      '.flac',
      '.mpga',
      '.webm',
    };

    if (uri.pathSegments.isNotEmpty) {
      final name = uri.pathSegments.last.toLowerCase();
      final dot = name.lastIndexOf('.');

      if (dot >= 0) {
        final extension = name.substring(dot);

        if (allowed.contains(extension)) {
          return extension;
        }
      }
    }

    switch (contentType) {
      case 'audio/mpeg':
      case 'audio/mp3':
      case 'audio/x-mpeg':
        return '.mp3';

      case 'audio/mp4':
      case 'audio/x-m4a':
        return '.m4a';

      case 'audio/aac':
        return '.aac';

      case 'audio/ogg':
      case 'application/ogg':
        return '.ogg';

      case 'audio/wav':
      case 'audio/x-wav':
        return '.wav';

      case 'audio/flac':
      case 'audio/x-flac':
        return '.flac';

      default:
        return null;
    }
  }

  Future<void> deleteDownload(String id) async {
    final items = await getDownloads();

    DownloadedAudio? target;

    for (final item in items) {
      if (item.id == id) {
        target = item;
        break;
      }
    }

    if (target != null) {
      try {
        final file = File(target.filePath);

        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        throw const AudioDownloadException(
          'تعذر حذف الملف من مساحة التطبيق.',
        );
      }
    }

    final remaining = items
        .where((item) => item.id != id)
        .toList(growable: false);

    await _saveDownloads(remaining);
  }

  Future<void> deletePartialDownload(String sourceUrl) async {
    final items = await _loadPartials();

    for (final item in items) {
      if (item.sourceUrl == sourceUrl) {
        await _removePartial(item, deleteFile: true);
      }
    }
  }
}

class AudioDownloadException implements Exception {
  const AudioDownloadException(this.message);

  final String message;

  @override
  String toString() => message;
}
