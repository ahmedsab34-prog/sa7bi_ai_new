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

/// عنصر صوت تم تنزيله وحفظه داخل مساحة التطبيق الخاصة.
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

/// تنزيل وحفظ المقاطع الصوتية المباشرة لاستخدامها دون إنترنت.
///
/// لا يحاول تنزيل محطات الراديو الحية أو ملفات قوائم التشغيل
/// مثل m3u8؛ لأنها ليست ملفات صوتية مكتملة قابلة للحفظ بهذه الطريقة.
class AudioDownloadsService {
  AudioDownloadsService._();

  static final AudioDownloadsService instance =
      AudioDownloadsService._();

  static const String _storageKey =
      'sa7bi_audio_downloads_v1';

  static const int maxDownloadBytes =
      100 * 1024 * 1024;

  static const Duration _requestTimeout =
      Duration(seconds: 30);

  static const Duration _streamTimeout =
      Duration(seconds: 45);

  final http.Client _client = http.Client();

  /// يسمح فقط بروابط HTTPS صالحة.
  /// يتم استبعاد صيغ قوائم التشغيل والبث الحي المعروفة.
  static bool isSupportedSourceUrl(String source) {
    final uri = Uri.tryParse(source.trim());

    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return false;
    }

    final path = uri.path.toLowerCase();

    const unsupportedExtensions = [
      '.m3u8',
      '.m3u',
      '.pls',
      '.asx',
      '.mpd',
      '.ism',
    ];

    for (final extension in unsupportedExtensions) {
      if (path.endsWith(extension)) {
        return false;
      }
    }

    return true;
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

      if (decoded is! List) {
        return const [];
      }

      final result = <DownloadedAudio>[];

      for (final value in decoded) {
        final item = DownloadedAudio.fromJson(value);

        if (item == null) continue;

        final file = File(item.filePath);

        if (!await file.exists()) {
          continue;
        }

        result.add(item);
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
      jsonEncode(
        items.map((item) => item.toJson()).toList(),
      ),
    );
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

    // لا نكرر تنزيل نفس الملف إذا كان موجودًا بالفعل.
    final existingItems = await getDownloads();

    for (final item in existingItems) {
      if (item.sourceUrl == sourceUrl &&
          await File(item.filePath).exists()) {
        return item;
      }
    }

    final uri = Uri.parse(sourceUrl);

    final request = http.Request('GET', uri)
      ..headers['Accept'] =
          'audio/*, application/octet-stream;q=0.9, */*;q=0.1';

    late final http.StreamedResponse response;

    try {
      response = await _client
          .send(request)
          .timeout(_requestTimeout);
    } catch (_) {
      throw const AudioDownloadException(
        'تعذر الاتصال بمصدر الصوت. افحص الإنترنت وحاول مرة أخرى.',
      );
    }

    final finalUri = response.request?.url ?? uri;

    if (finalUri.scheme.toLowerCase() != 'https') {
      throw const AudioDownloadException(
        'تم رفض التحويل إلى رابط غير آمن.',
      );
    }

    if (response.statusCode != 200) {
      throw AudioDownloadException(
        'مصدر الصوت لم يقبل التنزيل. كود الاستجابة: '
        '${response.statusCode}',
      );
    }

    final totalBytes = response.contentLength;

    if (totalBytes == null || totalBytes <= 0) {
      throw const AudioDownloadException(
        'المصدر لا يعلن حجم الملف. قد يكون بثًا مباشرًا وليس ملفًا قابلًا للتنزيل.',
      );
    }

    if (totalBytes > maxDownloadBytes) {
      throw const AudioDownloadException(
        'حجم الملف أكبر من الحد المسموح به وهو 100 ميجابايت.',
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
      throw const AudioDownloadException(
        'هذا المصدر قائمة تشغيل أو صفحة ويب وليس ملفًا صوتيًا مباشرًا.',
      );
    }

    final extension = _fileExtension(
      uri,
      contentType,
    );

    if (extension == null) {
      throw const AudioDownloadException(
        'لم نستطع تحديد صيغة الملف الصوتي بأمان.',
      );
    }

    final isAudioContent =
        contentType.startsWith('audio/') ||
        contentType == 'application/octet-stream' ||
        contentType == 'application/ogg' ||
        contentType.isEmpty;

    if (!isAudioContent) {
      throw const AudioDownloadException(
        'نوع الملف الذي أعاده المصدر ليس ملفًا صوتيًا.',
      );
    }

    final directory = await _downloadDirectory();

    final id = DateTime.now()
        .microsecondsSinceEpoch
        .toString();

    final file = File(
      '${directory.path}${Platform.pathSeparator}'
      'sa7bi_audio_$id$extension',
    );

    final output = file.openWrite();

    var receivedBytes = 0;

    try {
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

      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}

      if (error is AudioDownloadException) {
        rethrow;
      }

      throw const AudioDownloadException(
        'انقطع تنزيل الصوت أو حدث خطأ أثناء استقبال الملف.',
      );
    }

    if (receivedBytes != totalBytes || receivedBytes == 0) {
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}

      throw const AudioDownloadException(
        'الملف الذي وصل غير مكتمل. لم نحفظه في التنزيلات.',
      );
    }

    final downloaded = DownloadedAudio(
      id: id,
      title: source.title.trim().isEmpty
          ? 'ملف صوتي'
          : source.title.trim(),
      filePath: file.path,
      sourceUrl: sourceUrl,
      sizeBytes: receivedBytes,
      downloadedAt: DateTime.now(),
      artist: source.artist,
      album: source.album,
      durationMs: source.duration?.inMilliseconds,
      artUri: source.artUri?.toString(),
    );

    final latestItems = await getDownloads();

    latestItems.insert(0, downloaded);

    await _saveDownloads(latestItems);

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
}

class AudioDownloadException implements Exception {
  const AudioDownloadException(this.message);

  final String message;

  @override
  String toString() => message;
}
