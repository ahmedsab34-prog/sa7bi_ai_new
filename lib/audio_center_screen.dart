// ============================================================
// FILE: lib/audio_center_screen.dart
// ============================================================

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'ai_service.dart';
import 'audio_player_service.dart';
import 'audio_rain_visualizer.dart';
import 'services/chat_voice_service.dart';

part 'audio_quran_section.dart';
part 'audio_radio_section.dart';
part 'audio_search_section.dart';

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

  final TextEditingController _searchController =
      TextEditingController();

  final List<String> _categories = const [
    'القرآن',
    'الحديث',
    'التفسير',
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

  List<HadithItem> _hadithItems = [];
  List<HadithBook> _hadithBooks = [];
  HadithBook? _hadithBook;

  List<TafsirBook> _tafsirBooks = [];
  TafsirBook? _tafsirBook;
  List<TafsirItem> _tafsirItems = [];
  int? _tafsirSura;

  QuranCatalog? _quran;
  QuranReciter? _reciter;
  QuranMoshaf? _moshaf;
  QuranSura? _sura;

  List<RadioCountry> _countries = [];
  RadioCountry? _country;
  List<RadioStation> _stations = [];

  // ============================================================
  // PODCAST STATE
  // ============================================================

  List<PodcastItem> _podcasts = [];

  PodcastItem? _selectedPodcast;

  List<PodcastEpisode> _podcastEpisodes = [];

  bool _loadingPodcastEpisodes = false;

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
                item.title.trim().isNotEmpty) {
              _currentTitle = item.title;
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
      _hadithItems = [];
      _tafsirItems = [];
      _stations = [];
      _searchController.clear();

      _podcasts = [];
      _selectedPodcast = null;
      _podcastEpisodes = [];
      _loadingPodcastEpisodes = false;
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
          await _loadHadith();
          break;

        case 2:
          await _loadTafsir();
          break;

        case 3:
          await _loadMusic();
          break;

        case 4:
          await _loadPodcast();
          break;

        case 5:
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
  // AUDIO PLAYBACK
  // ============================================================

  Future<void> _playUrl(
    String url,
    String title, {
    String? artist,
    String? artwork,
  }) async {
    final clean = url.trim();

    if (clean.isEmpty) {
      _message('المصدر الصوتي غير متاح.');
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

      final file = result.files.single;
      final path = file.path;

      if (path == null ||
          path.trim().isEmpty) {
        _message('تعذر الوصول إلى الملف.');
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

      _message('تعذر تشغيل الملف الصوتي.');
    }
  }

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
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'مركز الصوت',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'ملف صوتي من الهاتف',
              onPressed:
                  _switchingAudio
                      ? null
                      : _pickLocalAudio,
              icon: const Icon(
                Icons.folder_open_rounded,
                color: Colors.white,
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            _categoryBar(),
            if (_playing) _playingBar(),
            Expanded(
              child: RefreshIndicator(
                color: _gold,
                backgroundColor: _card,
                onRefresh: _loadCategory,
                child: _content(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryBar() {
    return SizedBox(
      height: 62,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 7,
          vertical: 6,
        ),
        child: Row(
          children:
              List.generate(
            _categories.length,
            (index) {
              final selected =
                  index == _categoryIndex;

              return Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 2,
                  ),
                  child: GestureDetector(
                    onTap: _loading
                        ? null
                        : () =>
                            _changeCategory(
                              index,
                            ),
                    child: AnimatedContainer(
                      duration:
                          const Duration(
                        milliseconds: 180,
                      ),
                      decoration:
                          BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                        color: selected
                            ? _goldDark
                            : _card,
                        border: Border.all(
                          color: selected
                              ? _gold
                              : Colors.white10,
                        ),
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _categories[index],
                            maxLines: 1,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
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

  Widget _playingBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        12,
        3,
        12,
        8,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: _card,
        borderRadius:
            BorderRadius.circular(17),
        border: Border.all(
          color:
              _gold.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        children: [
          const AudioRainVisualizer(),
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
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed:
                _switchingAudio
                    ? null
                    : _stop,
            icon: const Icon(
              Icons.stop_circle_rounded,
              color: _gold,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

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
        return _hadithView();

      case 2:
        return _tafsirView();

      case 3:
        return _searchableList(
          title: 'الموسيقى',
          items: _audioItems,
          empty: _error.isNotEmpty
              ? _error
              : 'ابحث عن موسيقى.',
        );

      case 4:
        return _podcastView();

      case 5:
        return _radioView();

      default:
        return const SizedBox.shrink();
    }
  }

  // ============================================================
  // COMMON UI
  // ============================================================

  Widget _dropdown<T>({
    required T? value,
    required List<T> items,
    required String label,
    required String Function(T) text,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: items.contains(value)
          ? value
          : null,
      isExpanded: true,
      dropdownColor: _card,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            const TextStyle(
          color: Colors.white70,
        ),
        filled: true,
        fillColor: _card,
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(14),
          borderSide: BorderSide.none,
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

  Widget _sectionTitle(String title) {
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
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _searchBox() {
    return TextField(
      controller: _searchController,
      textDirection: TextDirection.rtl,
      style: const TextStyle(
        color: Colors.white,
      ),
      textInputAction:
          TextInputAction.search,
      onSubmitted: (_) => _search(),
      decoration: InputDecoration(
        hintText: 'ابحث...',
        hintStyle:
            const TextStyle(
          color: Colors.white38,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: _gold,
        ),
        suffixIcon: IconButton(
          tooltip: 'بحث',
          onPressed:
              _loading ? null : _search,
          icon: const Icon(
            Icons.arrow_forward_rounded,
            color: _gold,
          ),
        ),
        filled: true,
        fillColor: _card,
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _emptyText(String text) {
    return Container(
      margin:
          const EdgeInsets.only(top: 18),
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
        textAlign: TextAlign.center,
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
              _gold.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(
                    color: Colors.white,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style:
                      const TextStyle(
                    color: Colors.white60,
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

  // ============================================================
  // HADITH
  // ============================================================

  Future<void> _loadHadith() async {
    try {
      final books =
          await AiService.getHadithBooks();

      if (!mounted) {
        return;
      }

      HadithBook? selected =
          _hadithBook;

      if (selected == null ||
          !books.contains(selected)) {
        selected =
            books.isNotEmpty
                ? books.first
                : null;
      }

      final items =
          await AiService.searchHadith(
        query:
            _searchController.text.trim(),
        book: selected?.id,
        limit: 20,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _hadithBooks = books;
        _hadithBook = selected;
        _hadithItems = items;
        _error = items.isEmpty
            ? 'لم يتم العثور على أحاديث حاليًا.'
            : '';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _hadithItems = [];
          _error =
              'تعذر تحميل الأحاديث حاليًا.';
        });
      }
    }
  }

  Future<void> _playHadith(
    HadithItem item,
  ) async {
    final text = item.text.trim();

    if (text.isEmpty) {
      _message('نص الحديث غير متاح.');
      return;
    }

    if (_switchingAudio) {
      return;
    }

    setState(() {
      _switchingAudio = true;
    });

    try {
      await AudioController.stop();

      await _voice.stopSpeaking();

      final ok =
          await _voice.speak(
        text,
        language: 'ar-EG',
        rate: 0.45,
      );

      if (!mounted) {
        return;
      }

      if (ok) {
        setState(() {
          _currentTitle =
              '${item.bookName} — حديث ${item.number}';
          _playing = true;
          _error = '';
        });
      } else {
        _message(
          'تعذر تشغيل الحديث بالصوت.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _switchingAudio = false;
        });
      }
    }
  }

  Widget _hadithView() {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        14,
        8,
        14,
        30,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: _sectionTitle(
                'الحديث الشريف',
              ),
            ),
            IconButton(
              tooltip: 'تحديث',
              onPressed:
                  _loading
                      ? null
                      : _loadHadith,
              icon: Icon(
                Icons.refresh_rounded,
                color: _gold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_hadithBooks.isNotEmpty)
          _dropdown<HadithBook>(
            value: _hadithBook,
            items: _hadithBooks,
            label: 'كتاب الحديث',
            text: (book) => book.name,
            onChanged: (book) async {
              if (book == null) {
                return;
              }

              setState(() {
                _hadithBook = book;
                _loading = true;
              });

              await _loadHadith();

              if (mounted) {
                setState(() {
                  _loading = false;
                });
              }
            },
          ),
        const SizedBox(height: 10),
        _searchBox(),
        const SizedBox(height: 12),
        ..._hadithItems.map(
          (item) => _hadithCard(item),
        ),
        if (_hadithItems.isEmpty)
          _emptyText(
            _error.isNotEmpty
                ? _error
                : 'ابحث عن حديث.',
          ),
        const SizedBox(height: 10),
        _infoCard(
          Icons.record_voice_over_rounded,
          'تشغيل صوتي',
          'الأحاديث التي يوفرها المصدر نصية، لذلك يستخدم التطبيق نطق الهاتف العربي لقراءتها.',
        ),
      ],
    );
  }

  Widget _hadithCard(
    HadithItem item,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(bottom: 10),
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            item.bookName.isEmpty
                ? 'حديث ${item.number}'
                : '${item.bookName} — حديث ${item.number}',
            style: TextStyle(
              color: _gold,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.text,
            textDirection:
                TextDirection.rtl,
            style: const TextStyle(
              color: Colors.white,
              height: 1.7,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment:
                Alignment.centerLeft,
            child: IconButton(
              tooltip: 'استماع',
              onPressed:
                  _switchingAudio
                      ? null
                      : () =>
                          _playHadith(item),
              icon: Icon(
                Icons.play_circle_fill_rounded,
                color: _gold,
                size: 38,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TAFSIR
  // ============================================================

  Future<void> _loadTafsir() async {
    try {
      final books =
          await AiService.getTafsirBooks();

      if (!mounted) {
        return;
      }

      TafsirBook? selected =
          _tafsirBook;

      if (selected == null ||
          !books.contains(selected)) {
        selected =
            books.isNotEmpty
                ? books.first
                : null;
      }

      if (selected == null) {
        setState(() {
          _tafsirBooks = [];
          _tafsirBook = null;
          _tafsirItems = [];
          _error =
              'لم يتم العثور على كتب تفسير متاحة.';
        });
        return;
      }

      final items =
          await AiService.searchTafsir(
        tafsirId: selected.id,
        query:
            _searchController.text.trim(),
        sura: _tafsirSura,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _tafsirBooks = books;
        _tafsirBook = selected;
        _tafsirItems = items;
        _error = items.isEmpty
            ? 'لم يتم العثور على نتائج تفسير حاليًا.'
            : '';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _tafsirItems = [];
          _error =
              'تعذر تحميل التفسير حاليًا.';
        });
      }
    }
  }

  Widget _tafsirView() {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        14,
        8,
        14,
        30,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: _sectionTitle(
                'التفسير',
              ),
            ),
            IconButton(
              tooltip: 'تحديث',
              onPressed:
                  _loading
                      ? null
                      : _loadTafsir,
              icon: Icon(
                Icons.refresh_rounded,
                color: _gold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_tafsirBooks.isNotEmpty)
          _dropdown<TafsirBook>(
            value: _tafsirBook,
            items: _tafsirBooks,
            label: 'كتاب التفسير',
            text: (book) => book.name,
            onChanged: (book) async {
              if (book == null) {
                return;
              }

              setState(() {
                _tafsirBook = book;
                _loading = true;
              });

              await _loadTafsir();

              if (mounted) {
                setState(() {
                  _loading = false;
                });
              }
            },
          ),
        const SizedBox(height: 10),
        _searchBox(),
        const SizedBox(height: 12),
        ..._tafsirItems.map(
          (item) => _tafsirCard(item),
        ),
        if (_tafsirItems.isEmpty)
          _emptyText(
            _error.isNotEmpty
                ? _error
                : 'ابحث عن تفسير.',
          ),
      ],
    );
  }

  Widget _tafsirCard(
    TafsirItem item,
  ) {
    final hasAudio =
        item.audioUrl.trim().isNotEmpty;

    return Container(
      margin:
          const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ),
        title: Text(
          item.suraName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight:
                FontWeight.w800,
          ),
        ),
        subtitle: Text(
          item.tafsirName.isEmpty
              ? 'تفسير سورة ${item.sura}'
              : item.tafsirName,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 12,
          ),
        ),
        trailing: IconButton(
          tooltip:
              hasAudio
                  ? 'تشغيل التفسير'
                  : 'الصوت غير متاح',
          onPressed:
              !hasAudio ||
                      _switchingAudio
                  ? null
                  : () => _playUrl(
                        item.audioUrl,
                        item.suraName,
                        artist:
                            item.tafsirName,
                      ),
          icon: Icon(
            hasAudio
                ? Icons.play_circle_fill_rounded
                : Icons.volume_off_rounded,
            color:
                hasAudio
                    ? _gold
                    : Colors.white24,
            size: 36,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MUSIC
  // ============================================================

  Future<void> _loadMusic() async {
    final query =
        _searchController.text.trim();

    final items =
        await AiService.searchAudio(
      query.isEmpty
          ? 'Arabic music'
          : query,
      type: 'music',
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _audioItems = items;
      _error = items.isEmpty
          ? 'لم يتم العثور على موسيقى متاحة حاليًا.'
          : '';
    });
  }

  // ============================================================
  // PODCAST
  // ============================================================

  Future<void> _loadPodcast() async {
    final query =
        _searchController.text.trim();

    final podcasts =
        await AiService.searchPodcasts(
      query: query.isEmpty
          ? 'Arabic podcast'
          : query,
      limit: 30,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _podcasts = podcasts;
      _selectedPodcast = null;
      _podcastEpisodes = [];
      _loadingPodcastEpisodes = false;

      _error = podcasts.isEmpty
          ? 'لم يتم العثور على بودكاست متاح حاليًا.'
          : '';
    });
  }

  Future<void> _openPodcast(
    PodcastItem podcast,
  ) async {
    final feedUrl =
        podcast.feedUrl.trim();

    if (feedUrl.isEmpty) {
      _message(
        'هذا البودكاست لا يوفر رابط الحلقات حاليًا.',
      );
      return;
    }

    setState(() {
      _selectedPodcast = podcast;
      _podcastEpisodes = [];
      _loadingPodcastEpisodes = true;
      _error = '';
    });

    try {
      final episodes =
          await AiService.getPodcastEpisodes(
        feedUrl: feedUrl,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _podcastEpisodes = episodes;
        _loadingPodcastEpisodes = false;

        _error = episodes.isEmpty
            ? 'لم يتم العثور على حلقات متاحة لهذا البودكاست حاليًا.'
            : '';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _podcastEpisodes = [];
        _loadingPodcastEpisodes = false;
        _error =
            'تعذر تحميل حلقات البودكاست حاليًا.';
      });
    }
  }

  void _closePodcastEpisodes() {
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedPodcast = null;
      _podcastEpisodes = [];
      _loadingPodcastEpisodes = false;
      _error = '';
    });
  }

  Widget _podcastView() {
    final selected =
        _selectedPodcast;

    if (selected != null) {
      return _podcastEpisodesView(
        selected,
      );
    }

    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        14,
        8,
        14,
        30,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: _sectionTitle(
                'البودكاست',
              ),
            ),
            IconButton(
              tooltip: 'تحديث',
              onPressed:
                  _loading
                      ? null
                      : _search,
              icon: Icon(
                Icons.refresh_rounded,
                color: _gold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _searchBox(),
        const SizedBox(height: 12),
        if (_podcasts.isEmpty)
          _emptyText(
            _error.isNotEmpty
                ? _error
                : 'ابحث عن بودكاست.',
          ),
        ..._podcasts.map(
          (podcast) =>
              _podcastCard(podcast),
        ),
      ],
    );
  }

  Widget _podcastCard(
    PodcastItem podcast,
  ) {
    final artwork =
        podcast.artwork.trim();

    final author =
        podcast.author.trim().isNotEmpty
            ? podcast.author.trim()
            : podcast.artist.trim();

    return Container(
      margin:
          const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius:
            BorderRadius.circular(17),
        border: Border.all(
          color:
              _gold.withValues(alpha: 0.12),
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 7,
        ),
        leading: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(13),
            color:
                _goldDark.withValues(
              alpha: 0.22,
            ),
            image: artwork.isEmpty
                ? null
                : DecorationImage(
                    image:
                        NetworkImage(
                      artwork,
                    ),
                    fit: BoxFit.cover,
                  ),
          ),
          child: artwork.isEmpty
              ? const Icon(
                  Icons.podcasts_rounded,
                  color: _gold,
                  size: 30,
                )
              : null,
        ),
        title: Text(
          podcast.title,
          maxLines: 2,
          overflow:
              TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Padding(
          padding:
              const EdgeInsets.only(top: 4),
          child: Text(
            [
              if (author.isNotEmpty)
                author,
              if (podcast.episodeCount > 0)
                '${podcast.episodeCount} حلقة',
            ].join(' • '),
            maxLines: 2,
            overflow:
                TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
            ),
          ),
        ),
        trailing: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: _gold,
          size: 18,
        ),
        onTap:
            _loadingPodcastEpisodes
                ? null
                : () =>
                    _openPodcast(
                      podcast,
                    ),
      ),
    );
  }

  Widget _podcastEpisodesView(
    PodcastItem podcast,
  ) {
    final artwork =
        podcast.artwork.trim();

    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        14,
        8,
        14,
        30,
      ),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'رجوع للبودكاست',
              onPressed:
                  _loadingPodcastEpisodes
                      ? null
                      : _closePodcastEpisodes,
              icon: Icon(
                Icons.arrow_forward_rounded,
                color: _gold,
              ),
            ),
            Expanded(
              child: _sectionTitle(
                podcast.title,
              ),
            ),
            IconButton(
              tooltip: 'تحديث الحلقات',
              onPressed:
                  _loadingPodcastEpisodes
                      ? null
                      : () =>
                          _openPodcast(
                            podcast,
                          ),
              icon: Icon(
                Icons.refresh_rounded,
                color: _gold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding:
              const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _card,
            borderRadius:
                BorderRadius.circular(17),
            border: Border.all(
              color:
                  _gold.withValues(alpha: 0.14),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(15),
                  color:
                      _goldDark.withValues(
                    alpha: 0.22,
                  ),
                  image: artwork.isEmpty
                      ? null
                      : DecorationImage(
                          image:
                              NetworkImage(
                            artwork,
                          ),
                          fit: BoxFit.cover,
                        ),
                ),
                child: artwork.isEmpty
                    ? const Icon(
                        Icons.podcasts_rounded,
                        color: _gold,
                        size: 34,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      podcast.title,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                    if (podcast.author
                        .trim()
                        .isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        podcast.author.trim(),
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (podcast.description
                        .trim()
                        .isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        podcast.description.trim(),
                        maxLines: 3,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_loadingPodcastEpisodes)
          const Padding(
            padding:
                EdgeInsets.symmetric(
              vertical: 50,
            ),
            child: Center(
              child:
                  CircularProgressIndicator(),
            ),
          )
        else ...[
          Text(
            'الحلقات',
            style: TextStyle(
              color: _gold,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          if (_podcastEpisodes.isEmpty)
            _emptyText(
              _error.isNotEmpty
                  ? _error
                  : 'لا توجد حلقات متاحة حاليًا.',
            ),
          ..._podcastEpisodes.map(
            (episode) =>
                _podcastEpisodeCard(
              episode,
              podcast,
            ),
          ),
        ],
      ],
    );
  }

  Widget _podcastEpisodeCard(
    PodcastEpisode episode,
    PodcastItem podcast,
  ) {
    final audioUrl =
        episode.audioUrl.trim();

    final image =
        episode.image.trim().isNotEmpty
            ? episode.image.trim()
            : podcast.artwork.trim();

    final hasAudio =
        audioUrl.isNotEmpty;

    final metadata = <String>[];

    if (episode.publishedAt
        .trim()
        .isNotEmpty) {
      metadata.add(
        episode.publishedAt.trim(),
      );
    }

    if (episode.duration
        .trim()
        .isNotEmpty) {
      metadata.add(
        episode.duration.trim(),
      );
    }

    if (episode.season > 0) {
      metadata.add(
        'الموسم ${episode.season}',
      );
    }

    if (episode.episode > 0) {
      metadata.add(
        'الحلقة ${episode.episode}',
      );
    }

    if (episode.explicit) {
      metadata.add('محتوى صريح');
    }

    return Container(
      margin:
          const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 7,
        ),
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(12),
            color:
                _goldDark.withValues(
              alpha: 0.20,
            ),
            image: image.isEmpty
                ? null
                : DecorationImage(
                    image:
                        NetworkImage(
                      image,
                    ),
                    fit: BoxFit.cover,
                  ),
          ),
          child: image.isEmpty
              ? const Icon(
                  Icons.headphones_rounded,
                  color: _gold,
                )
              : null,
        ),
        title: Text(
          episode.title,
          maxLines: 2,
          overflow:
              TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Padding(
          padding:
              const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              if (metadata.isNotEmpty)
                Text(
                  metadata.join(' • '),
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                  ),
                ),
              if (episode.description
                  .trim()
                  .isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  episode.description.trim(),
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
        trailing: IconButton(
          tooltip:
              hasAudio
                  ? 'تشغيل الحلقة'
                  : 'الصوت غير متاح',
          onPressed:
              !hasAudio ||
                      _switchingAudio
                  ? null
                  : () => _playUrl(
                        audioUrl,
                        episode.title,
                        artist:
                            podcast.title,
                        artwork:
                            image.isEmpty
                                ? null
                                : image,
                      ),
          icon: Icon(
            hasAudio
                ? Icons.play_circle_fill_rounded
                : Icons.volume_off_rounded,
            color:
                hasAudio
                    ? _gold
                    : Colors.white24,
            size: 38,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Future<void> _search() async {
    if (_loading) {
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      switch (_categoryIndex) {
        case 0:
          await _loadQuran();
          break;

        case 1:
          await _loadHadith();
          break;

        case 2:
          await _loadTafsir();
          break;

        case 3:
          await _loadMusic();
          break;

        case 4:
          await _loadPodcast();
          break;

        case 5:
          if (_country != null) {
            await _loadStations(
              _country!,
            );
          }
          break;
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
  // SEARCHABLE LIST
  // ============================================================

  Widget _searchableList({
    required String title,
    required List<AudioSearchItem> items,
    required String empty,
  }) {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        14,
        8,
        14,
        30,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child:
                  _sectionTitle(title),
            ),
            IconButton(
              tooltip: 'تحديث',
              onPressed:
                  _loading
                      ? null
                      : _search,
              icon: Icon(
                Icons.refresh_rounded,
                color: _gold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _searchBox(),
        const SizedBox(height: 12),
        ...items.map(
          (item) => _audioCard(
            item,
            () {
              final url =
                  item.url.trim();

              if (url.isNotEmpty) {
                _playUrl(
                  url,
                  item.title,
                  artist: item.artist,
                  artwork: item.artwork,
                );
              } else {
                _message(
                  'لا يوجد رابط تشغيل لهذا العنصر.',
                );
              }
            },
          ),
        ),
        if (items.isEmpty)
          _emptyText(empty),
      ],
    );
  }

  Widget _audioCard(
    AudioSearchItem item,
    VoidCallback onPlay,
  ) {
    final hasUrl =
        item.url.trim().isNotEmpty;

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      decoration: BoxDecoration(
        color: _card,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(12),
            color: _goldDark.withValues(
              alpha: 0.22,
            ),
            image:
                item.artwork
                        .trim()
                        .isEmpty
                    ? null
                    : DecorationImage(
                        image:
                            NetworkImage(
                          item.artwork
                              .trim(),
                        ),
                        fit: BoxFit.cover,
                      ),
          ),
          child:
              item.artwork
                      .trim()
                      .isEmpty
                  ? Icon(
                      Icons
                          .music_note_rounded,
                      color: _gold,
                    )
                  : null,
        ),
        title: Text(
          item.title,
          maxLines: 2,
          overflow:
              TextOverflow.ellipsis,
          style:
              const TextStyle(
            color: Colors.white,
            fontWeight:
                FontWeight.w800,
          ),
        ),
        subtitle: Text(
          [
            if (item.artist != null &&
                item.artist!
                    .trim()
                    .isNotEmpty)
              item.artist!.trim(),
            if (item.collection
                .trim()
                .isNotEmpty)
              item.collection.trim(),
            if (!hasUrl)
              'الرابط غير متاح',
          ].join(' • '),
          maxLines: 2,
          overflow:
              TextOverflow.ellipsis,
          style:
              const TextStyle(
            color: Colors.white60,
            fontSize: 11,
          ),
        ),
        trailing: IconButton(
          tooltip:
              hasUrl
                  ? 'تشغيل'
                  : 'غير متاح',
          onPressed:
              _switchingAudio
                  ? null
                  : onPlay,
          icon: Icon(
            hasUrl
                ? Icons.play_circle_fill_rounded
                : Icons.volume_off_rounded,
            color:
                hasUrl
                    ? _gold
                    : Colors.white24,
            size: 36,
          ),
        ),
      ),
    );
  }
}
