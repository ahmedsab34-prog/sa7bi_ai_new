import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'ai_service.dart';
import 'audio_player_service.dart';
import 'services/chat_voice_service.dart';

part 'audio_quran_section.dart';
part 'audio_radio_section.dart';
part 'audio_search_section.dart';
part 'audio_rain_visualizer.dart';

class AudioCenterScreen extends StatefulWidget {
  const AudioCenterScreen({
    super.key,
  });

  @override
  State<AudioCenterScreen> createState() =>
      _AudioCenterScreenState();
}

class _AudioCenterScreenState
    extends State<AudioCenterScreen> {
  static const Color _gold =
      Color(0xFFE6C875);

  static const Color _goldDark =
      Color(0xFFB9913E);

  static const Color _bg =
      Color(0xFF07111F);

  static const Color _card =
      Color(0xFF132238);

  final ChatVoiceService _voice =
      ChatVoiceService();

  final TextEditingController
      _searchController =
      TextEditingController();

  final List<String> _categories = const [
    'القرآن',
    'الأذكار',
    'موسيقى',
    'بودكاست',
    'الراديو',
  ];

  int _categoryIndex = 0;

  bool _loading = false;
  bool _playing = false;
  bool _switchingAudio = false;

  String _error = '';
  String _currentTitle = '';

  StreamSubscription<PlaybackState>?
      _playbackSub;

  List<AudioSearchItem> _audioItems = [];

  QuranCatalog? _quran;
  QuranReciter? _reciter;
  QuranMoshaf? _moshaf;
  QuranSura? _sura;

  List<RadioCountry> _countries = [];
  RadioCountry? _country;
  List<RadioStation> _stations = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final handler =
          await AudioController.initialize();

      _playbackSub =
          handler.playbackState.listen(
        (state) {
          if (!mounted) {
            return;
          }

          final item =
              handler.mediaItem.value;

          setState(() {
            _playing = state.playing;

            if (item != null &&
                item.title
                    .trim()
                    .isNotEmpty) {
              _currentTitle =
                  item.title;
            }
          });
        },
        onError: (_) {},
      );
    } catch (_) {}

    await _loadCategory();
  }

  @override
  void dispose() {
    _playbackSub?.cancel();
    _searchController.dispose();
    _voice.dispose();
    super.dispose();
  }

  // ============================================================
  // CATEGORY
  // ============================================================

  Future<void> _changeCategory(
    int index,
  ) async {
    if (_categoryIndex == index &&
        !_loading) {
      return;
    }

    setState(() {
      _categoryIndex = index;
      _error = '';
      _audioItems = [];
      _stations = [];
      _searchController.clear();
    });

    await _loadCategory();
  }

  Future<void> _loadCategory() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      switch (_categoryIndex) {
        case 0:
          await _loadQuran();
          break;

        case 1:
          await _loadAdhkar();
          break;

        case 2:
          await _loadMusic();
          break;

        case 3:
          await _loadPodcast();
          break;

        case 4:
          await _loadRadio();
          break;
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'حصلت مشكلة أثناء تحميل المحتوى. جرّب التحديث.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ============================================================
  // SAFE AUDIO SWITCH
  // ============================================================

  Future<void> _playUrl(
    String url,
    String title, {
    String? artist,
    String? artwork,
  }) async {
    final clean = url.trim();

    if (clean.isEmpty) {
      _message(
        'المصدر الصوتي غير متاح.',
      );
      return;
    }

    if (_switchingAudio) {
      return;
    }

    setState(() {
      _switchingAudio = true;
    });

    try {
      await _voice.stopSpeaking();

      Uri? artUri;

      if (artwork != null &&
          artwork.trim().isNotEmpty) {
        artUri = Uri.tryParse(
          artwork.trim(),
        );
      }

      await AudioController.playUrl(
        url: clean,
        title: title,
        artist: artist,
        artUri: artUri,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _currentTitle = title;
        _playing = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _playing = false;
        });
      }

      _message(
        'تعذر تشغيل الصوت. قد يكون المصدر غير متاح حاليًا.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _switchingAudio = false;
        });
      }
    }
  }

  Future<void> _stop() async {
    try {
      await AudioController.stop();
    } catch (_) {}

    try {
      await _voice.stopSpeaking();
    } catch (_) {}

    if (!mounted) {
      return;
    }

    setState(() {
      _playing = false;
      _currentTitle = '';
      _switchingAudio = false;
    });
  }

  // ============================================================
  // LOCAL AUDIO
  // ============================================================

  Future<void> _pickLocalAudio() async {
    if (_switchingAudio) {
      return;
    }

    try {
      final result =
          await FilePicker.platform.pickFiles(
        type: FileType.audio,
      );

      if (result == null ||
          result.files.isEmpty) {
        return;
      }

      final file =
          result.files.single;

      final path = file.path;

      if (path == null ||
          path.trim().isEmpty) {
        _message(
          'تعذر الوصول إلى الملف.',
        );
        return;
      }

      setState(() {
        _switchingAudio = true;
      });

      await _voice.stopSpeaking();

      await AudioController.playLocalFile(
        path: path,
        title: file.name,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _currentTitle = file.name;
        _playing = true;
        _switchingAudio = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _switchingAudio = false;
        });
      }

      _message(
        'تعذر تشغيل الملف الصوتي.',
      );
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _message(String text) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(text),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Directionality(
      textDirection:
          TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor:
              Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'مركز الصوت',
            style: TextStyle(
              color: Colors.white,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          actions: [
            IconButton(
              tooltip:
                  'ملف صوتي من الهاتف',
              onPressed:
                  _switchingAudio
                      ? null
                      : _pickLocalAudio,
              icon: const Icon(
                Icons
                    .folder_open_rounded,
                color: Colors.white,
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            _categoryBar(),
            if (_playing)
              _playingBar(),
            Expanded(
              child:
                  RefreshIndicator(
                color: _gold,
                backgroundColor:
                    _card,
                onRefresh:
                    _loadCategory,
                child: _content(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CATEGORY BAR
  // ============================================================

  Widget _categoryBar() {
    return SizedBox(
      height: 62,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 7,
          vertical: 6,
        ),
        child: Row(
          children:
              List.generate(
            _categories.length,
            (index) {
              final selected =
                  index ==
                      _categoryIndex;

              return Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 2,
                  ),
                  child:
                      GestureDetector(
                    onTap: _loading
                        ? null
                        : () =>
                            _changeCategory(
                              index,
                            ),
                    child:
                        AnimatedContainer(
                      duration:
                          const Duration(
                        milliseconds: 180,
                      ),
                      decoration:
                          BoxDecoration(
                        borderRadius:
                            BorderRadius
                                .circular(
                          14,
                        ),
                        color: selected
                            ? _goldDark
                            : _card,
                        border:
                            Border.all(
                          color: selected
                              ? _gold
                              : Colors
                                  .white10,
                        ),
                      ),
                      child: Center(
                        child:
                            FittedBox(
                          fit: BoxFit
                              .scaleDown,
                          child: Text(
                            _categories[
                                index],
                            maxLines: 1,
                            style:
                                TextStyle(
                              color:
                                  Colors
                                      .white,
                              fontSize: 12,
                              fontWeight:
                                  selected
                                      ? FontWeight
                                          .w800
                                      : FontWeight
                                          .w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PLAYING BAR
  // ============================================================

  Widget _playingBar() {
    return Container(
      margin:
          const EdgeInsets.fromLTRB(
        12,
        3,
        12,
        8,
      ),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: _card,
        borderRadius:
            BorderRadius.circular(17),
        border: Border.all(
          color: _gold.withValues(
            alpha: 0.30,
          ),
        ),
      ),
      child: Row(
        children: [
          const _AudioRainVisualizer(),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _currentTitle.isEmpty
                  ? 'يتم التشغيل الآن'
                  : _currentTitle,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed:
                _switchingAudio
                    ? null
                    : _stop,
            icon: const Icon(
              Icons
                  .stop_circle_rounded,
              color: _gold,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CONTENT
  // ============================================================

  Widget _content() {
    if (_loading) {
      return ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 100),
          Center(
            child:
                CircularProgressIndicator(),
          ),
        ],
      );
    }

    switch (_categoryIndex) {
      case 0:
        return _quranView();

      case 1:
        return _audioList(
          title: 'الأذكار',
          items: _audioItems,
          onPlay: _playAdhkar,
          empty: _error.isNotEmpty
              ? _error
              : 'لا توجد أذكار متاحة حاليًا.',
        );

      case 2:
        return _searchableList(
          title: 'الموسيقى',
          items: _audioItems,
          empty: _error.isNotEmpty
              ? _error
              : 'ابحث عن موسيقى.',
        );

      case 3:
        return _searchableList(
          title: 'البودكاست',
          items: _audioItems,
          empty: _error.isNotEmpty
              ? _error
              : 'ابحث عن بودكاست.',
        );

      case 4:
        return _radioView();

      default:
        return const SizedBox.shrink();
    }
  }

  // ============================================================
  // UI HELPERS
  // ============================================================

  Widget _dropdown<T>({
    required T? value,
    required List<T> items,
    required String label,
    required String Function(T)
        text,
    required ValueChanged<T?>
        onChanged,
  }) {
    final safeValue =
        items.contains(value)
            ? value
            : null;

    return DropdownButtonFormField<T>(
      value: safeValue,
      isExpanded: true,
      dropdownColor: _card,
      style: const TextStyle(
        color: Colors.white,
        fontWeight:
            FontWeight.w700,
      ),
      decoration:
          InputDecoration(
        labelText: label,
        labelStyle:
            const TextStyle(
          color: Colors.white70,
        ),
        filled: true,
        fillColor: _card,
        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            14,
          ),
          borderSide:
              BorderSide.none,
        ),
      ),
      items: items.map(
        (item) {
          return DropdownMenuItem<T>(
            value: item,
            child: Text(
              text(item),
              overflow:
                  TextOverflow.ellipsis,
            ),
          );
        },
      ).toList(),
      onChanged: onChanged,
    );
  }

  Widget _sectionTitle(
    String title,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 2,
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight:
              FontWeight.w900,
        ),
      ),
    );
  }

  Widget _searchBox() {
    return TextField(
      controller:
          _searchController,
      textDirection:
          TextDirection.rtl,
      style: const TextStyle(
        color: Colors.white,
      ),
      textInputAction:
          TextInputAction.search,
      onSubmitted:
          (_) => _search(),
      decoration:
          InputDecoration(
        hintText: 'ابحث...',
        hintStyle:
            const TextStyle(
          color: Colors.white38,
        ),
        prefixIcon:
            const Icon(
          Icons.search_rounded,
          color: _gold,
        ),
        suffixIcon:
            IconButton(
          tooltip: 'بحث',
          onPressed:
              _loading
                  ? null
                  : _search,
          icon: const Icon(
            Icons
                .arrow_forward_rounded,
            color: _gold,
          ),
        ),
        filled: true,
        fillColor: _card,
        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            14,
          ),
          borderSide:
              BorderSide.none,
        ),
      ),
    );
  }

  Widget _emptyText(
    String text,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        top: 18,
      ),
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: Text(
        text,
        textAlign:
            TextAlign.center,
        style: const TextStyle(
          color: Colors.white70,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _infoCard(
    IconData icon,
    String title,
    String description,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color:
              _gold.withValues(
            alpha: 0.14,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration:
                BoxDecoration(
              shape:
                  BoxShape.circle,
              color:
                  _goldDark.withValues(
                alpha: 0.22,
              ),
            ),
            child: Icon(
              icon,
              color: _gold,
            ),
          ),
          const SizedBox(
            width: 12,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(
                    color:
                        Colors.white,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(
                  height: 4,
                ),
                Text(
                  description,
                  style:
                      const TextStyle(
                    color:
                        Colors.white60,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
