import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import 'audio_player_service.dart';
import 'services/audio_downloads_service.dart';

class AudioDownloadsScreen extends StatefulWidget {
  const AudioDownloadsScreen({super.key});

  @override
  State<AudioDownloadsScreen> createState() =>
      _AudioDownloadsScreenState();
}

class _AudioDownloadsScreenState
    extends State<AudioDownloadsScreen> {
  final AudioDownloadsService _downloads =
      AudioDownloadsService.instance;

  StreamSubscription<PlaybackState>? _playbackSubscription;

  MediaItem? _currentItem;
  List<DownloadedAudio> _items = [];

  bool _loading = true;
  bool _downloading = false;

  double? _progress;
  int _lastProgressBytes = 0;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final handler = await AudioController.initialize();

      if (!mounted) return;

      setState(() {
        _currentItem = handler.mediaItem.value;
      });

      _playbackSubscription =
          handler.playbackState.listen(
        (_) {
          if (!mounted) return;

          final item = handler.mediaItem.value;

          if (item?.id != _currentItem?.id) {
            setState(() {
              _currentItem = item;
            });
          }
        },
        onError: (_) {},
      );
    } catch (_) {
      // يمكن فتح مدير التنزيلات حتى لو لم يكن المشغل جاهزًا.
    }

    await _refresh();
  }

  @override
  void dispose() {
    _playbackSubscription?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final result = await _downloads.getDownloads();

      if (!mounted) return;

      setState(() {
        _items = result;
      });
    } catch (_) {
      if (mounted) {
        _showMessage('تعذر قراءة قائمة التنزيلات.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _downloadCurrent() async {
    final source = _currentItem;

    if (source == null) {
      _showMessage(
        'شغّل مقطعًا صوتيًا من مركز الصوت أولًا.',
      );
      return;
    }

    if (!AudioDownloadsService.isSupportedSourceUrl(
      source.id,
    )) {
      _showMessage(
        'المقطع الحالي ليس رابط ملف مباشرًا قابلًا للتنزيل.',
      );
      return;
    }

    setState(() {
      _downloading = true;
      _progress = 0;
      _lastProgressBytes = 0;
    });

    try {
      final saved = await _downloads.download(
        source,
        onProgress: (received, total) {
          if (!mounted) return;

          if (received == total ||
              received - _lastProgressBytes >= 512 * 1024) {
            _lastProgressBytes = received;

            setState(() {
              _progress = total <= 0
                  ? null
                  : received / total;
            });
          }
        },
      );

      if (!mounted) return;

      await _refresh();

      if (!mounted) return;

      _showMessage(
        'تم حفظ ${saved.title} للاستخدام دون إنترنت.',
      );
    } on AudioDownloadException catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showMessage('حدث خطأ أثناء تنزيل الصوت.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
          _progress = null;
          _lastProgressBytes = 0;
        });
      }
    }
  }

  Future<void> _playDownloaded(
    DownloadedAudio item,
  ) async {
    try {
      await AudioController.playLocalFile(
        path: item.filePath,
        title: item.title,
        artist: item.artist,
      );

      if (mounted) {
        _showMessage(
          'بدأ تشغيل ${item.title} من الذاكرة المحلية.',
        );
      }
    } catch (_) {
      if (mounted) {
        _showMessage('تعذر تشغيل الملف المحفوظ.');
      }
    }
  }

  Future<void> _deleteDownloaded(
    DownloadedAudio item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF151D2B),
          title: const Text(
            'حذف التنزيل؟',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            'سيتم حذف "${item.title}" من مساحة التطبيق.',
            textDirection: TextDirection.rtl,
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text(
                'حذف',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _downloads.deleteDownload(item.id);
      await _refresh();

      if (mounted) {
        _showMessage('تم حذف الملف.');
      }
    } on AudioDownloadException catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showMessage('تعذر حذف الملف.');
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textDirection: TextDirection.rtl,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes بايت';
    }

    final kb = bytes / 1024;

    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} كيلوبايت';
    }

    final mb = kb / 1024;

    return '${mb.toStringAsFixed(1)} ميجابايت';
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();

    String twoDigits(int value) {
      return value.toString().padLeft(2, '0');
    }

    return '${twoDigits(local.day)}/'
        '${twoDigits(local.month)}/'
        '${local.year}';
  }

  Widget _buildCurrentDownloadCard() {
    final source = _currentItem;

    final canDownload = source != null &&
        AudioDownloadsService.isSupportedSourceUrl(
          source.id,
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF132238),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0x5535C6E8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(
                Icons.cloud_download_rounded,
                color: Color(0xFF63E6FF),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'تنزيل المقطع الحالي',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            source?.title ?? 'لا يوجد مقطع محدد حاليًا',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (_downloading) ...[
            LinearProgressIndicator(
              value: _progress,
              minHeight: 5,
              backgroundColor: Colors.white12,
              color: const Color(0xFF63E6FF),
            ),
            const SizedBox(height: 8),
            const Text(
              'جارٍ حفظ الملف على الجهاز...',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: Colors.white60,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 8),
          ],
          FilledButton.icon(
            onPressed: _downloading || !canDownload
                ? null
                : _downloadCurrent,
            icon: _downloading
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(
                    Icons.download_rounded,
                  ),
            label: Text(
              _downloading
                  ? 'جارٍ التنزيل'
                  : 'حفظ للاستخدام دون إنترنت',
            ),
          ),
          if (!canDownload)
            const Padding(
              padding: EdgeInsets.only(top: 7),
              child: Text(
                'اختر ملفًا صوتيًا مباشرًا من مركز الصوت. '
                'البث الحي وقوائم التشغيل لا يمكن حفظهما هنا.',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDownloadedTile(DownloadedAudio item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF111C2D),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: ListTile(
        onTap: () => _playDownloaded(item),
        leading: const CircleAvatar(
          backgroundColor: Color(0x2235C6E8),
          child: Icon(
            Icons.play_arrow_rounded,
            color: Color(0xFF63E6FF),
          ),
        ),
        title: Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textDirection: TextDirection.rtl,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        subtitle: Text(
          [
            if (item.artist?.trim().isNotEmpty == true)
              item.artist!,
            _formatSize(item.sizeBytes),
            _formatDate(item.downloadedAt),
          ].join(' • '),
          textDirection: TextDirection.rtl,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
          ),
        ),
        trailing: IconButton(
          tooltip: 'حذف التنزيل',
          onPressed: _downloading
              ? null
              : () => _deleteDownloaded(item),
          icon: const Icon(
            Icons.delete_outline_rounded,
            color: Colors.redAccent,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF07111F),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0C1727),
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'تنزيلاتي الصوتية',
            style: TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'تحديث',
              onPressed: _loading ? null : _refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              12,
              12,
              12,
              28,
            ),
            children: [
              _buildCurrentDownloadCard(),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'الملفات المحفوظة',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    '${_items.length} ملف',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF63E6FF),
                    ),
                  ),
                )
              else if (_items.isEmpty)
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111C2D),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.library_music_outlined,
                        color: Colors.white38,
                        size: 35,
                      ),
                      SizedBox(height: 9),
                      Text(
                        'لا توجد تنزيلات حتى الآن',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'شغّل ملفًا صوتيًا مباشرًا ثم احفظه من الأعلى.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ..._items.map(_buildDownloadedTile),
            ],
          ),
        ),
      ),
    );
  }
}
