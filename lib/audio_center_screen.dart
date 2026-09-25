import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'ai_service.dart';
import 'audio_player_service.dart';
import 'services/chat_voice_service.dart';

class AudioCenterScreen extends StatefulWidget {
  const AudioCenterScreen({
    super.key,
  });

  @override
  State<AudioCenterScreen> createState() =>
      _AudioCenterScreenState();
}

class _AudioCenterScreenState extends State<AudioCenterScreen> {
  static const Color _gold = Color(0xFFE6C875);
  static const Color _goldDark = Color(0xFFB9913E);
  static const Color _bg = Color(0xFF07111F);
  static const Color _card = Color(0xFF132238);

  final ChatVoiceService _voice = ChatVoiceService();

  final TextEditingController _searchController =
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

  StreamSubscription<PlaybackState>? _playbackSub;

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
      final handler = await AudioController.initialize();

      _playbackSub = handler.playbackState.listen(
        (state) {
          if (!mounted) {
            return;
          }

          final item = handler.mediaItem.value;

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

  // ============================================================
  // CATEGORY
  // ============================================================

  Future<void> _changeCategory(int index) async {
    if (_categoryIndex == index && !_loading) {
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
  // QURAN
  // ============================================================

  Future<void> _loadQuran() async {
    final data = await AiService.getQuranCatalog();

    if (!mounted) {
      return;
    }

    if (data == null ||
        data.reciters.isEmpty ||
        data.suwar.isEmpty) {
      setState(() {
        _quran = null;
        _reciter = null;
        _moshaf = null;
        _sura = null;
        _error = 'تعذر تحميل قائمة القرآن حاليًا.';
      });
      return;
    }

    QuranReciter? selectedReciter;

    for (final reciter in data.reciters) {
      if (reciter.moshaf.isNotEmpty) {
        selectedReciter = reciter;
        break;
      }
    }

    selectedReciter ??= data.reciters.first;

    final moshaf = selectedReciter.moshaf.isNotEmpty
        ? selectedReciter.moshaf.first
        : null;

    setState(() {
      _quran = data;
      _reciter = selectedReciter;
      _moshaf = moshaf;
      _sura = data.suwar.first;
    });
  }

  String? _quranUrl(
    QuranMoshaf moshaf,
    QuranSura sura,
  ) {
    var server = moshaf.server.trim();

    if (server.isEmpty) {
      return null;
    }

    if (!server.endsWith('/')) {
      server = '$server/';
    }

    return '$server'
        '${sura.id.toString().padLeft(3, '0')}'
        '.mp3';
  }

  Future<void> _playQuran() async {
    if (_switchingAudio) {
      return;
    }

    final moshaf = _moshaf;
    final sura = _sura;

    if (moshaf == null || sura == null) {
      _message(
        'اختار القارئ والرواية والسورة أولًا.',
      );
      return;
    }

    final url = _quranUrl(moshaf, sura);

    if (url == null || url.isEmpty) {
      _message(
        'رابط الصوت غير متاح لهذه الرواية.',
      );
      return;
    }

    setState(() {
      _switchingAudio = true;
    });

    try {
      final handler = await AudioController.initialize();

      final first = MediaItem(
        id: url,
        title: sura.name,
        artist: _reciter?.name ?? 'القرآن الكريم',
        album: 'القرآن الكريم',
      );

      await handler.playMediaItem(first);

      final catalog = _quran;

      if (catalog != null) {
        final selectedIndex = catalog.suwar.indexWhere(
          (item) => item.id == sura.id,
        );

        final start =
            selectedIndex < 0 ? 0 : selectedIndex + 1;

        final remaining = <MediaItem>[];

        for (var i = start; i < catalog.suwar.length; i++) {
          final nextSura = catalog.suwar[i];
          final nextUrl = _quranUrl(
            moshaf,
            nextSura,
          );

          if (nextUrl == null || nextUrl.isEmpty) {
            continue;
          }

          remaining.add(
            MediaItem(
              id: nextUrl,
              title: nextSura.name,
              artist:
                  _reciter?.name ?? 'القرآن الكريم',
              album: 'القرآن الكريم',
            ),
          );
        }

        if (remaining.isNotEmpty) {
          try {
            await handler.addQueueItems(remaining);
          } catch (_) {
            // تشغيل السورة الحالية يظل صالحًا.
          }
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _currentTitle =
            '${sura.name} - ${_reciter?.name ?? 'القرآن'}';
        _playing = true;
      });
    } catch (_) {
      _message(
        'تعذر تشغيل القرآن حاليًا. جرّب سورة أخرى.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _switchingAudio = false;
        });
      }
    }
  }

  // ============================================================
  // ADHKAR
  // ============================================================

  Future<void> _loadAdhkar() async {
    final query = _searchController.text.trim();

    final items = await AiService.searchAudio(
      query.isEmpty ? 'أذكار' : query,
      type: 'adhkar',
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _audioItems = items;

      if (items.isEmpty) {
        _error = 'لم يتم العثور على أذكار حاليًا.';
      }
    });
  }

  Future<void> _playAdhkar(
    AudioSearchItem item,
  ) async {
    final url = item.url.trim();

    if (url.isNotEmpty) {
      await _playUrl(
        url,
        item.title,
        artist: item.artist ?? 'الأذكار',
        artwork: item.artwork,
      );
      return;
    }

    final text = item.text.trim().isNotEmpty
        ? item.text.trim()
        : item.title.trim();

    if (text.isEmpty) {
      _message(
        'لا يوجد محتوى صوتي لهذا الذكر.',
      );
      return;
    }

    try {
      await AudioController.stop();
    } catch (_) {}

    final ok = await _voice.speak(
      text,
      language: 'ar-EG',
      rate: 0.45,
    );

    if (!mounted) {
      return;
    }

    if (ok) {
      setState(() {
        _currentTitle = item.title;
        _playing = true;
      });
    } else {
      _message(
        'تعذر تشغيل صوت الذكر.',
      );
    }
  }

  // ============================================================
  // MUSIC
  // ============================================================

  Future<void> _loadMusic() async {
    final query = _searchController.text.trim();

    final items = await AiService.searchAudio(
      query.isEmpty ? 'Arabic music' : query,
      type: 'music',
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _audioItems = items;

      if (items.isEmpty) {
        _error =
            'لم يتم العثور على موسيقى متاحة حاليًا.';
      }
    });
  }

  // ============================================================
  // PODCAST
  // ============================================================

  Future<void> _loadPodcast() async {
    final query = _searchController.text.trim();

    final items = await AiService.searchAudio(
      query.isEmpty ? 'Arabic podcast' : query,
      type: 'podcast',
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _audioItems = items;

      if (items.isEmpty) {
        _error =
            'لم يتم العثور على بودكاست متاح حاليًا.';
      }
    });
  }

  // ============================================================
  // RADIO
  // ============================================================

  Future<void> _loadRadio() async {
    final countries = await AiService.getRadioCountries();

    if (!mounted) {
      return;
    }

    if (countries.isEmpty) {
      setState(() {
        _countries = [];
        _country = null;
        _stations = [];
        _error =
            'تعذر تحميل الدول والإذاعات حاليًا.';
      });
      return;
    }

    var selected = countries.first;

    for (final country in countries) {
      final code = country.code.toUpperCase();
      final name = country.name.toLowerCase();

      if (code == 'EG' ||
          name.contains('egypt') ||
          name.contains('مصر')) {
        selected = country;
        break;
      }
    }

    setState(() {
      _countries = countries;
      _country = selected;
    });

    await _loadStations(selected);
  }

  Future<void> _loadStations(
    RadioCountry country,
  ) async {
    try {
      final stations =
          await AiService.getRadioStations(
        country.code,
      );

      if (!mounted) {
        return;
      }

      final seen = <String>{};
      final cleanStations = <RadioStation>[];

      for (final station in stations) {
        final url = station.url.trim();

        if (url.isEmpty) {
          continue;
        }

        final key = url.toLowerCase();

        if (seen.add(key)) {
          cleanStations.add(station);
        }
      }

      setState(() {
        _stations = cleanStations;
        _error = cleanStations.isEmpty
            ? 'لا توجد محطات متاحة لهذه الدولة حاليًا.'
            : '';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _stations = [];
          _error =
              'تعذر تحميل محطات هذه الدولة.';
        });
      }
    }
  }

  Future<void> _changeCountry(
    RadioCountry? country,
  ) async {
    if (country == null || _loading) {
      return;
    }

    setState(() {
      _country = country;
      _stations = [];
      _loading = true;
      _error = '';
    });

    try {
      await _loadStations(country);
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

      final file = result.files.single;
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
  // SEARCH
  // ============================================================

  Future<void> _search() async {
    if (_loading) {
      return;
    }

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
        if (_country != null) {
          await _loadStations(_country!);
        }
        break;
    }
  }

  void _message(String text) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
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
              onPressed: _switchingAudio
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

  // ============================================================
  // CATEGORY BAR
  // ============================================================

  Widget _categoryBar() {
    return SizedBox(
      height: 62,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 7,
          vertical: 6,
        ),
        child: Row(
          children: List.generate(
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
                            _changeCategory(index),
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
                              color:
                                  Colors.white,
                              fontSize: 12,
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

  // ============================================================
  // PLAYING BAR
  // ============================================================

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
              Icons.stop_circle_rounded,
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
  // QURAN VIEW
  // ============================================================

  Widget _quranView() {
    final quran = _quran;

    if (quran == null) {
      return ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.all(16),
        children: [
          _emptyText(
            _error.isNotEmpty
                ? _error
                : 'تعذر تحميل القرآن حاليًا.',
          ),
          ElevatedButton.icon(
            onPressed: _loadQuran,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
            label: const Text('تحديث'),
          ),
        ],
      );
    }

    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding:
          const EdgeInsets.fromLTRB(
        14,
        8,
        14,
        30,
      ),
      children: [
        _sectionTitle(
          'القرآن الكريم',
        ),
        const SizedBox(height: 12),
        _dropdown<QuranReciter>(
          value: _reciter,
          items: quran.reciters,
          label: 'اختار القارئ',
          text: (item) => item.name,
          onChanged: (value) {
            if (value == null) {
              return;
            }

            setState(() {
              _reciter = value;
              _moshaf =
                  value.moshaf.isNotEmpty
                      ? value.moshaf.first
                      : null;
            });
          },
        ),
        const SizedBox(height: 10),
        if (_reciter != null)
          _dropdown<QuranMoshaf>(
            value: _moshaf,
            items: _reciter!.moshaf,
            label: 'اختار الرواية',
            text: (item) =>
                item.name.isEmpty
                    ? 'الرواية'
                    : item.name,
            onChanged: (value) {
              setState(() {
                _moshaf = value;
              });
            },
          ),
        const SizedBox(height: 10),
        _dropdown<QuranSura>(
          value: _sura,
          items: quran.suwar,
          label: 'اختار السورة',
          text: (item) =>
              '${item.id}. ${item.name}',
          onChanged: (value) {
            setState(() {
              _sura = value;
            });
          },
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _switchingAudio
              ? null
              : _playQuran,
          icon: _switchingAudio
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(
                  Icons.play_arrow_rounded,
                ),
          label: Text(
            _switchingAudio
                ? 'جاري التشغيل...'
                : 'تشغيل السورة والمتابعة تلقائيًا',
          ),
          style:
              ElevatedButton.styleFrom(
            backgroundColor: _goldDark,
            foregroundColor:
                Colors.white,
            minimumSize:
                const Size(
              double.infinity,
              50,
            ),
            shape:
                RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(15),
            ),
          ),
        ),
        const SizedBox(height: 18),
        _infoCard(
          Icons.queue_music_rounded,
          'تشغيل متواصل',
          'بعد السورة المختارة يكمل المشغل السور التالية تلقائيًا.',
        ),
        const SizedBox(height: 10),
        _infoCard(
          Icons.headphones_rounded,
          'تشغيل في الخلفية',
          'الصوت يستمر أثناء التنقل داخل التطبيق مع دعم مشغل النظام.',
        ),
      ],
    );
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
      padding:
          const EdgeInsets.fromLTRB(
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
              onPressed:
                  _loading ? null : _search,
              icon: const Icon(
                Icons.refresh_rounded,
                color: _gold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _searchBox(),
        const SizedBox(height: 12),
        ..._audioCards(items),
        if (items.isEmpty)
          _emptyText(empty),
      ],
    );
  }

  Widget _audioList({
    required String title,
    required List<AudioSearchItem> items,
    required Future<void> Function(
      AudioSearchItem,
    ) onPlay,
    required String empty,
  }) {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding:
          const EdgeInsets.fromLTRB(
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
              onPressed:
                  _loading ? null : _search,
              icon: const Icon(
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
            () => onPlay(item),
          ),
        ),
        if (items.isEmpty)
          _emptyText(empty),
      ],
    );
  }

  List<Widget> _audioCards(
    List<AudioSearchItem> items,
  ) {
    return items
        .map(
          (item) => _audioCard(
            item,
            () => _playUrl(
              item.url,
              item.title,
              artist: item.artist,
              artwork: item.artwork,
            ),
          ),
        )
        .toList();
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
                item.artwork.trim().isEmpty
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
              item.artwork.trim().isEmpty
                  ? const Icon(
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
          style: const TextStyle(
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
            if (!hasUrl &&
                item.text
                    .trim()
                    .isNotEmpty)
              'تشغيل بالنطق الصوتي',
          ].join(' • '),
          maxLines: 2,
          overflow:
              TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 11,
          ),
        ),
        trailing: IconButton(
          tooltip:
              hasUrl ? 'تشغيل' : 'قراءة',
          onPressed:
              _switchingAudio
                  ? null
                  : onPlay,
          icon: const Icon(
            Icons
                .play_circle_fill_rounded,
            color: _gold,
            size: 36,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // RADIO
  // ============================================================

  Widget _radioView() {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding:
          const EdgeInsets.fromLTRB(
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
                  _sectionTitle('الراديو'),
            ),
            IconButton(
              onPressed:
                  _loading ? null : _search,
              icon: const Icon(
                Icons.refresh_rounded,
                color: _gold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_countries.isNotEmpty)
          DropdownButtonFormField<
              RadioCountry>(
            value: _country,
            dropdownColor: _card,
            style: const TextStyle(
              color: Colors.white,
            ),
            decoration:
                InputDecoration(
              labelText: 'الدولة',
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
            items:
                _countries.map(
              (country) {
                return DropdownMenuItem<
                    RadioCountry>(
                  value: country,
                  child: Text(
                    '${country.name} (${country.stationCount})',
                    overflow:
                        TextOverflow
                            .ellipsis,
                  ),
                );
              },
            ).toList(),
            onChanged:
                _loading
                    ? null
                    : _changeCountry,
          ),
        const SizedBox(height: 12),
        ..._stations.map(
          _radioCard,
        ),
        if (_stations.isEmpty)
          _emptyText(
            _error.isNotEmpty
                ? _error
                : 'لا توجد محطات متاحة حاليًا.',
          ),
      ],
    );
  }

  Widget _radioCard(
    RadioStation station,
  ) {
    final favicon =
        station.favicon.trim();

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
          vertical: 5,
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
            image: favicon.isEmpty
                ? null
                : DecorationImage(
                    image: NetworkImage(
                      favicon,
                    ),
                    fit: BoxFit.cover,
                  ),
          ),
          child: favicon.isEmpty
              ? const Icon(
                  Icons.radio_rounded,
                  color: _gold,
                )
              : null,
        ),
        title: Text(
          station.name,
          maxLines: 2,
          overflow:
              TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight:
                FontWeight.w800,
          ),
        ),
        subtitle: Text(
          [
            if (station.codec
                .trim()
                .isNotEmpty)
              station.codec.trim(),
            if (station.bitrate > 0)
              '${station.bitrate} kbps',
            if (station.tags
                .trim()
                .isNotEmpty)
              station.tags.trim(),
          ].join(' • '),
          maxLines: 2,
          overflow:
              TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 11,
          ),
        ),
        trailing: IconButton(
          tooltip:
              'تشغيل المحطة',
          onPressed:
              _switchingAudio
                  ? null
                  : () => _playUrl(
                        station.url,
                        station.name,
                        artist:
                            'راديو ${_country?.name ?? ''}'
                                .trim(),
                        artwork:
                            station.favicon,
                      ),
          icon: const Icon(
            Icons
                .play_circle_fill_rounded,
            color: _gold,
            size: 36,
          ),
        ),
      ),
    );
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
                  CrossAxisAlignment.start,
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

// ============================================================
// AUDIO RAIN VISUALIZER
// ============================================================

class _AudioRainVisualizer
    extends StatefulWidget {
  const _AudioRainVisualizer();

  @override
  State<_AudioRainVisualizer>
      createState() =>
          _AudioRainVisualizerState();
}

class _AudioRainVisualizerState
    extends State<
        _AudioRainVisualizer>
    with
        SingleTickerProviderStateMixin {
  late final AnimationController
      _controller;

  @override
  void initState() {
    super.initState();

    _controller =
        AnimationController(
      vsync: this,
      duration:
          const Duration(
        milliseconds: 1100,
      ),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return SizedBox(
      width: 42,
      height: 34,
      child: AnimatedBuilder(
        animation: _controller,
        builder:
            (context, child) {
          return Row(
            mainAxisAlignment:
                MainAxisAlignment
                    .spaceEvenly,
            crossAxisAlignment:
                CrossAxisAlignment
                    .end,
            children:
                List.generate(
              7,
              (index) {
                final phase =
                    (_controller.value +
                            index * 0.13) %
                        1.0;

                final height =
                    7.0 +
                        (phase * 20.0);

                return Container(
                  width: 3,
                  height: height,
                  decoration:
                      BoxDecoration(
                    color: Color.lerp(
                      Colors.white54,
                      _gold,
                      phase,
                    ),
                    borderRadius:
                        BorderRadius
                            .circular(
                      8,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
