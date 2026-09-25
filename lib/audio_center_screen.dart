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

  String _error = '';
  String _currentTitle = '';

  StreamSubscription<PlaybackState>?
      _playbackSub;

  List<AudioSearchItem>
      _audioItems = [];

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

          setState(() {
            _playing = state.playing;

            final item =
                handler.mediaItem.value;

            if (item != null &&
                item.title.trim().isNotEmpty) {
              _currentTitle = item.title;
            }
          });
        },
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
  // QURAN
  // ============================================================

  Future<void> _loadQuran() async {
    final data =
        await AiService.getQuranCatalog();

    if (!mounted) {
      return;
    }

    if (data == null ||
        data.reciters.isEmpty ||
        data.suwar.isEmpty) {
      setState(() {
        _quran = null;
        _error =
            'تعذر تحميل قائمة القرآن حاليًا.';
      });

      return;
    }

    final reciter =
        data.reciters.first;

    final moshaf =
        reciter.moshaf.isNotEmpty
            ? reciter.moshaf.first
            : null;

    setState(() {
      _quran = data;
      _reciter = reciter;
      _moshaf = moshaf;
      _sura = data.suwar.first;
    });
  }

  String? _quranUrl(
    QuranMoshaf moshaf,
    QuranSura sura,
  ) {
    var server =
        moshaf.server.trim();

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
    final moshaf = _moshaf;
    final sura = _sura;

    if (moshaf == null ||
        sura == null) {
      _message(
        'اختار القارئ والرواية والسورة أولًا.',
      );
      return;
    }

    final url =
        _quranUrl(
      moshaf,
      sura,
    );

    if (url == null) {
      _message(
        'رابط الصوت غير متاح لهذه الرواية.',
      );
      return;
    }

    try {
      final handler =
          await AudioController.initialize();

      final first =
          MediaItem(
        id: url,
        title: sura.name,
        artist:
            _reciter?.name ??
                'القرآن الكريم',
        album: 'القرآن الكريم',
      );

      await handler.playMediaItem(
        first,
      );

      final catalog = _quran;

      if (catalog != null) {
        final remaining =
            <MediaItem>[];

        final selectedIndex =
            catalog.suwar.indexWhere(
          (item) =>
              item.id == sura.id,
        );

        final start =
            selectedIndex < 0
                ? 0
                : selectedIndex + 1;

        for (
          var i = start;
          i < catalog.suwar.length;
          i++
        ) {
          final nextSura =
              catalog.suwar[i];

          final nextUrl =
              _quranUrl(
            moshaf,
            nextSura,
          );

          if (nextUrl == null) {
            continue;
          }

          remaining.add(
            MediaItem(
              id: nextUrl,
              title: nextSura.name,
              artist:
                  _reciter?.name ??
                      'القرآن الكريم',
              album:
                  'القرآن الكريم',
            ),
          );
        }

        if (remaining.isNotEmpty) {
          await handler.addQueueItems(
            remaining,
          );
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _currentTitle =
            '${sura.name} - '
            '${_reciter?.name ?? 'القرآن'}';

        _playing = true;
      });
    } catch (_) {
      _message(
        'تعذر تشغيل القرآن حاليًا.',
      );
    }
  }

  // ============================================================
  // ADHKAR
  // ============================================================

  Future<void> _loadAdhkar() async {
    final query =
        _searchController.text.trim();

    final items =
        await AiService.searchAudio(
      query.isEmpty
          ? 'أذكار'
          : query,
      type: 'adhkar',
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _audioItems = items;

      if (items.isEmpty) {
        _error =
            'لم يتم العثور على أذكار حاليًا.';
      }
    });
  }

  Future<void> _playAdhkar(
    AudioSearchItem item,
  ) async {
    final url =
        item.url.trim();

    // الأولوية للصوت الحقيقي
    // القادم من الخادم.
    if (url.isNotEmpty) {
      await _playUrl(
        url,
        item.title,
        artist:
            item.artist ??
                'الأذكار',
        artwork:
            item.artwork,
      );

      return;
    }

    // احتياطي فقط إذا لم يتوفر
    // ملف صوتي من المصدر.
    final text =
        item.text.trim().isNotEmpty
            ? item.text.trim()
            : item.title.trim();

    if (text.isEmpty) {
      _message(
        'لا يوجد محتوى صوتي لهذا الذكر.',
      );
      return;
    }

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
            item.title;
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
    });
  }

  // ============================================================
  // PODCAST
  // ============================================================

  Future<void> _loadPodcast() async {
    final query =
        _searchController.text.trim();

    final items =
        await AiService.searchAudio(
      query.isEmpty
          ? 'Arabic podcast'
          : query,
      type: 'podcast',
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _audioItems = items;
    });
  }

  // ============================================================
  // RADIO
  // ============================================================

  Future<void> _loadRadio() async {
    final countries =
        await AiService.getRadioCountries();

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

    var selected =
        countries.first;

    for (final country
        in countries) {
      final code =
          country.code
              .toUpperCase();

      final name =
          country.name
              .toLowerCase();

      if (code == 'EG' ||
          name.contains('egypt') ||
          name.contains('مصر')) {
        selected = country;
        break;
      }
    }

    setState(() {
      _countries =
          countries;
      _country =
          selected;
    });

    await _loadStations(
      selected,
    );
  }

  Future<void> _loadStations(
    RadioCountry country,
  ) async {
    try {
      final stations =
          await AiService
              .getRadioStations(
        country.code,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _stations = stations;

        _error =
            stations.isEmpty
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
    if (country == null) {
      return;
    }

    setState(() {
      _country = country;
      _stations = [];
      _loading = true;
      _error = '';
    });

    await _loadStations(
      country,
    );

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  // ============================================================
  // PLAYER
  // ============================================================

  Future<void> _playUrl(
    String url,
    String title, {
    String? artist,
    String? artwork,
  }) async {
    final clean =
        url.trim();

    if (clean.isEmpty) {
      _message(
        'المصدر الصوتي غير متاح.',
      );
      return;
    }

    try {
      Uri? artUri;

      if (artwork != null &&
          artwork.trim().isNotEmpty) {
        artUri =
            Uri.tryParse(
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
        _currentTitle =
            title;
        _playing = true;
      });
    } catch (_) {
      _message(
        'تعذر تشغيل الصوت. قد تكون المحطة أو المصدر غير متاح حاليًا.',
      );
    }
  }

  Future<void> _stop() async {
    try {
      await AudioController.stop();

      await _voice.stopSpeaking();

      if (!mounted) {
        return;
      }

      setState(() {
        _playing = false;
        _currentTitle = '';
      });
    } catch (_) {}
  }

  // ============================================================
  // LOCAL AUDIO
  // ============================================================

  Future<void> _pickLocalAudio() async {
    try {
      final result =
          await FilePicker.platform
              .pickFiles(
        type: FileType.audio,
      );

      if (result == null ||
          result.files.isEmpty) {
        return;
      }

      final file =
          result.files.single;

      final path =
          file.path;

      if (path == null ||
          path.trim().isEmpty) {
        _message(
          'تعذر الوصول إلى الملف.',
        );
        return;
      }

      await AudioController
          .playLocalFile(
        path: path,
        title: file.name,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _currentTitle =
            file.name;
        _playing = true;
      });
    } catch (_) {
      _message(
        'تعذر تشغيل الملف الصوتي.',
      );
    }
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Future<void> _search() async {
    switch (_categoryIndex) {
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
          await _loadStations(
            _country!,
          );
        }
        break;
    }
  }

  void _message(
    String text,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
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
                  _pickLocalAudio,
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
                child:
                    _content(),
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
                    onTap: () =>
                        _changeCategory(
                      index,
                    ),

                    child:
                        AnimatedContainer(
                      duration:
                          const Duration(
                        milliseconds:
                            180,
                      ),

                      decoration:
                          BoxDecoration(
                        borderRadius:
                            BorderRadius
                                .circular(
                          14,
                        ),

                        color:
                            selected
                                ? _goldDark
                                : _card,

                        border:
                            Border.all(
                          color:
                              selected
                                  ? _gold
                                  : Colors
                                      .white10,
                        ),
                      ),

                      child:
                          Center(
                        child:
                            FittedBox(
                          fit:
                              BoxFit
                                  .scaleDown,

                          child:
                              Text(
                            _categories[
                                index],

                            maxLines: 1,

                            style:
                                TextStyle(
                              color:
                                  Colors
                                      .white,

                              fontSize:
                                  12,

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

      decoration:
          BoxDecoration(
        color: _card,
        borderRadius:
            BorderRadius.circular(
          17,
        ),
        border:
            Border.all(
          color: Colors.white12,
        ),
      ),

      child: Row(
        children: [
          const _AudioRainVisualizer(),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Text(
              _currentTitle.isEmpty
                  ? 'يتم تشغيل الصوت'
                  : _currentTitle,

              maxLines: 1,

              overflow:
                  TextOverflow.ellipsis,

              style:
                  const TextStyle(
                color: Colors.white,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),

          IconButton(
            onPressed: _stop,

            icon:
                const Icon(
              Icons
                  .stop_circle_outlined,
              color: Colors.white,
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
                CircularProgressIndicator(
              color: _gold,
            ),
          ),
        ],
      );
    }

    if (_error.isNotEmpty &&
        _categoryIndex != 1 &&
        _audioItems.isEmpty &&
        _stations.isEmpty) {
      return ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),

        padding:
            const EdgeInsets.all(
          24,
        ),

        children: [
          const SizedBox(
            height: 70,
          ),

          const Icon(
            Icons
                .cloud_off_rounded,
            color:
                Colors.white38,
            size: 52,
          ),

          const SizedBox(
            height: 16,
          ),

          Text(
            _error,
            textAlign:
                TextAlign.center,

            style:
                const TextStyle(
              color:
                  Colors.white70,
              height: 1.6,
            ),
          ),

          const SizedBox(
            height: 18,
          ),

          Center(
            child:
                ElevatedButton.icon(
              onPressed:
                  _loadCategory,

              icon:
                  const Icon(
                Icons
                    .refresh_rounded,
              ),

              label:
                  const Text(
                'إعادة المحاولة',
              ),
            ),
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
          onPlay:
              _playAdhkar,
          empty:
              'لا توجد أذكار متاحة حاليًا.',
        );

      case 2:
        return _searchableList(
          title: 'الموسيقى',
          items: _audioItems,
          empty:
              'ابحث عن أغنية أو فنان.',
        );

      case 3:
        return _searchableList(
          title: 'البودكاست',
          items: _audioItems,
          empty:
              'ابحث عن بودكاست أو برنامج.',
        );

      case 4:
        return _radioView();

      default:
        return const SizedBox
            .shrink();
    }
  }

  // ============================================================
  // QURAN VIEW
  // ============================================================

  Widget _quranView() {
    final data = _quran;

    if (data == null) {
      return ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),

        children: const [
          SizedBox(
            height: 80,
          ),

          Center(
            child: Text(
              'جارٍ تحميل القرآن...',
              style:
                  TextStyle(
                color:
                    Colors.white70,
              ),
            ),
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

        const SizedBox(
          height: 10,
        ),

        _dropdown<QuranReciter>(
          value: _reciter,
          items:
              data.reciters,
          label: 'القارئ',
          text:
              (item) =>
                  item.name,

          onChanged:
              (value) {
            if (value == null) {
              return;
            }

            setState(() {
              _reciter = value;

              _moshaf =
                  value.moshaf
                          .isNotEmpty
                      ? value.moshaf
                          .first
                      : null;
            });
          },
        ),

        const SizedBox(
          height: 10,
        ),

        if (_reciter != null)
          _dropdown<QuranMoshaf>(
            value: _moshaf,
            items:
                _reciter!.moshaf,
            label: 'الرواية',
            text:
                (item) =>
                    item.name,

            onChanged:
                (value) {
              if (value != null) {
                setState(() {
                  _moshaf =
                      value;
                });
              }
            },
          ),

        const SizedBox(
          height: 10,
        ),

        _dropdown<QuranSura>(
          value: _sura,
          items:
              data.suwar,
          label: 'السورة',
          text:
              (item) =>
                  '${item.id}. ${item.name}',

          onChanged:
              (value) {
            if (value != null) {
              setState(() {
                _sura =
                    value;
              });
            }
          },
        ),

        const SizedBox(
          height: 16,
        ),

        ElevatedButton.icon(
          onPressed:
              _playQuran,

          icon:
              const Icon(
            Icons
                .play_arrow_rounded,
          ),

          label:
              const Text(
            'تشغيل السورة والمتابعة تلقائيًا',
          ),

          style:
              ElevatedButton
                  .styleFrom(
            backgroundColor:
                _goldDark,

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
                  BorderRadius
                      .circular(
                15,
              ),
            ),
          ),
        ),

        const SizedBox(
          height: 20,
        ),

        _infoCard(
          Icons
              .queue_music_rounded,
          'التشغيل المتواصل',
          'بعد السورة المختارة يكمل المشغل السور التالية تلقائيًا في الخلفية.',
        ),

        const SizedBox(
          height: 10,
        ),

        _infoCard(
          Icons
              .headphones_rounded,
          'التشغيل في الخلفية',
          'المشغل يستمر أثناء التنقل داخل التطبيق، ويدعم المقاطعات الصوتية.',
        ),
      ],
    );
  }

  // ============================================================
  // SEARCHABLE LIST
  // ============================================================

  Widget _searchableList({
    required String title,
    required List<AudioSearchItem>
        items,
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
                  _sectionTitle(
                title,
              ),
            ),

            IconButton(
              onPressed:
                  _search,

              icon:
                  const Icon(
                Icons
                    .refresh_rounded,
                color: _gold,
              ),
            ),
          ],
        ),

        const SizedBox(
          height: 8,
        ),

        _searchBox(),

        const SizedBox(
          height: 12,
        ),

        ..._audioCards(
          items,
        ),

        if (items.isEmpty)
          _emptyText(
            empty,
          ),
      ],
    );
  }

  // ============================================================
  // ADHKAR LIST
  // ============================================================

  Widget _audioList({
    required String title,
    required List<AudioSearchItem>
        items,
    required Future<void>
        Function(
      AudioSearchItem,
    )
        onPlay,
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
                  _sectionTitle(
                title,
              ),
            ),

            IconButton(
              onPressed:
                  _search,

              icon:
                  const Icon(
                Icons
                    .refresh_rounded,
                color: _gold,
              ),
            ),
          ],
        ),

        const SizedBox(
          height: 8,
        ),

        _searchBox(),

        const SizedBox(
          height: 12,
        ),

        ...items.map(
          (item) =>
              _audioCard(
            item,
            () =>
                onPlay(item),
          ),
        ),

        if (items.isEmpty)
          _emptyText(
            empty,
          ),
      ],
    );
  }

  // ============================================================
  // AUDIO CARDS
  // ============================================================

  List<Widget> _audioCards(
    List<AudioSearchItem>
        items,
  ) {
    return items
        .map(
          (item) =>
              _audioCard(
            item,
            () => _playUrl(
              item.url,
              item.title,
              artist:
                  item.artist,
              artwork:
                  item.artwork,
            ),
          ),
        )
        .toList();
  }

  Widget _audioCard(
    AudioSearchItem item,
    VoidCallback onPlay,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 9,
      ),

      decoration:
          BoxDecoration(
        color: _card,

        borderRadius:
            BorderRadius.circular(
          17,
        ),

        border:
            Border.all(
          color:
              Colors.white10,
        ),
      ),

      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 2,
        ),

        leading:
            _artwork(
          item.artwork,
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
                FontWeight.w700,
          ),
        ),

        subtitle:
            Text(
          item.artist
                      ?.isNotEmpty ==
                  true
              ? item.artist!
              : item.collection
                      .isNotEmpty
                  ? item.collection
                  : 'صاحبي AI',

          maxLines: 1,

          overflow:
              TextOverflow.ellipsis,

          style:
              const TextStyle(
            color:
                Colors.white54,
          ),
        ),

        trailing:
            IconButton(
          onPressed:
              onPlay,

          icon:
              const Icon(
            Icons
                .play_circle_fill_rounded,
            color: _gold,
            size: 38,
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
                  _sectionTitle(
                'الراديو',
              ),
            ),

            IconButton(
              onPressed:
                  _loadRadio,

              icon:
                  const Icon(
                Icons
                    .refresh_rounded,
                color: _gold,
              ),
            ),
          ],
        ),

        const SizedBox(
          height: 10,
        ),

        _dropdown<RadioCountry>(
          value: _country,
          items:
              _countries,
          label: 'الدولة',
          text:
              (item) =>
                  '${item.name} (${item.code})',

          onChanged:
              _changeCountry,
        ),

        const SizedBox(
          height: 14,
        ),

        ..._stations.map(
          (station) =>
              _radioCard(
            station,
          ),
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
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 9,
      ),

      decoration:
          BoxDecoration(
        color: _card,

        borderRadius:
            BorderRadius.circular(
          17,
        ),

        border:
            Border.all(
          color:
              Colors.white10,
        ),
      ),

      child: ListTile(
        leading:
            _stationIcon(
          station.favicon,
        ),

        title:
            Text(
          station.name,

          maxLines: 2,

          overflow:
              TextOverflow.ellipsis,

          style:
              const TextStyle(
            color: Colors.white,
            fontWeight:
                FontWeight.w700,
          ),
        ),

        subtitle:
            Text(
          station.tags.isNotEmpty
              ? station.tags
              : 'إذاعة ${_country?.name ?? ''}',

          maxLines: 1,

          overflow:
              TextOverflow.ellipsis,

          style:
              const TextStyle(
            color:
                Colors.white54,
          ),
        ),

        trailing:
            IconButton(
          onPressed:
              () => _playUrl(
            station.url,
            station.name,
            artist:
                _country?.name,
            artwork:
                station.favicon,
          ),

          icon:
              const Icon(
            Icons
                .play_circle_fill_rounded,
            color: _gold,
            size: 38,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SEARCH BOX
  // ============================================================

  Widget _searchBox() {
    return TextField(
      controller:
          _searchController,

      textDirection:
          TextDirection.rtl,

      style:
          const TextStyle(
        color: Colors.white,
      ),

      onSubmitted:
          (_) => _search(),

      decoration:
          InputDecoration(
        hintText:
            'ابحث هنا...',

        hintStyle:
            const TextStyle(
          color:
              Colors.white38,
        ),

        prefixIcon:
            IconButton(
          onPressed:
              _search,

          icon:
              const Icon(
            Icons
                .search_rounded,
            color: _gold,
          ),
        ),

        filled: true,

        fillColor:
            _card,

        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            15,
          ),

          borderSide:
              BorderSide.none,
        ),
      ),
    );
  }

  // ============================================================
  // DROPDOWN
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

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 12,
      ),

      decoration:
          BoxDecoration(
        color: _card,

        borderRadius:
            BorderRadius.circular(
          15,
        ),

        border:
            Border.all(
          color:
              Colors.white10,
        ),
      ),

      child:
          DropdownButtonHideUnderline(
        child:
            DropdownButton<T>(
          value:
              safeValue,

          isExpanded:
              true,

          dropdownColor:
              const Color(
            0xFF17283E,
          ),

          iconEnabledColor:
              _gold,

          hint:
              Text(
            label,

            style:
                const TextStyle(
              color:
                  Colors.white54,
            ),
          ),

          style:
              const TextStyle(
            color:
                Colors.white,
            fontWeight:
                FontWeight.w600,
          ),

          items:
              items.map(
            (item) =>
                DropdownMenuItem<T>(
              value:
                  item,

              child:
                  Text(
                text(item),
                overflow:
                    TextOverflow.ellipsis,
              ),
            ),
          ).toList(),

          onChanged:
              onChanged,
        ),
      ),
    );
  }

  // ============================================================
  // COMMON UI
  // ============================================================

  Widget _sectionTitle(
    String text,
  ) {
    return Text(
      text,

      style:
          const TextStyle(
        color: Colors.white,
        fontSize: 19,
        fontWeight:
            FontWeight.w800,
      ),
    );
  }

  Widget _emptyText(
    String text,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 55,
      ),

      child:
          Center(
        child:
            Text(
          text,

          textAlign:
              TextAlign.center,

          style:
              const TextStyle(
            color:
                Colors.white54,
            height: 1.6,
          ),
        ),
      ),
    );
  }

  Widget _infoCard(
    IconData icon,
    String title,
    String text,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(
        14,
      ),

      decoration:
          BoxDecoration(
        color: _card,

        borderRadius:
            BorderRadius.circular(
          17,
        ),

        border:
            Border.all(
          color:
              Colors.white10,
        ),
      ),

      child:
          Row(
        children: [
          Icon(
            icon,
            color: _gold,
            size: 32,
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child:
                Column(
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
                  text,

                  style:
                      const TextStyle(
                    color:
                        Colors.white60,
                    height: 1.45,
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
  // ARTWORK
  // ============================================================

  Widget _artwork(
    String url,
  ) {
    if (url.trim().isEmpty) {
      return const CircleAvatar(
        backgroundColor:
            Color(0xFF243A55),

        child:
            Icon(
          Icons
              .music_note_rounded,
          color: _gold,
        ),
      );
    }

    return ClipRRect(
      borderRadius:
          BorderRadius.circular(
        10,
      ),

      child:
          Image.network(
        url,

        width: 48,
        height: 48,

        fit:
            BoxFit.cover,

        errorBuilder:
            (
          _,
          __,
          ___,
        ) {
          return const CircleAvatar(
            backgroundColor:
                Color(
              0xFF243A55,
            ),

            child:
                Icon(
              Icons
                  .music_note_rounded,
              color: _gold,
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // RADIO ICON
  // ============================================================

  Widget _stationIcon(
    String url,
  ) {
    if (url.trim().isEmpty) {
      return const CircleAvatar(
        backgroundColor:
            Color(0xFF243A55),

        child:
            Icon(
          Icons
              .radio_rounded,
          color: _gold,
        ),
      );
    }

    return ClipOval(
      child:
          Image.network(
        url,

        width: 48,
        height: 48,

        fit:
            BoxFit.cover,

        errorBuilder:
            (
          _,
          __,
          ___,
        ) {
          return const CircleAvatar(
            backgroundColor:
                Color(
              0xFF243A55,
            ),

            child:
                Icon(
              Icons
                  .radio_rounded,
              color: _gold,
            ),
          );
        },
      ),
    );
  }
}

// ================================================================
// AUDIO RAIN VISUALIZER
// ================================================================

class _AudioRainVisualizer
    extends StatefulWidget {
  const _AudioRainVisualizer();

  @override
  State<_AudioRainVisualizer>
      createState() =>
          _AudioRainVisualizerState();
}

class _AudioRainVisualizerState
    extends State<_AudioRainVisualizer>
    with SingleTickerProviderStateMixin {
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
        milliseconds: 900,
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
      width: 58,
      height: 42,

      child:
          AnimatedBuilder(
        animation:
            _controller,

        builder:
            (
          context,
          child,
        ) {
          return CustomPaint(
            painter:
                _AudioRainPainter(
              progress:
                  _controller.value,
            ),
          );
        },
      ),
    );
  }
}

class _AudioRainPainter
    extends CustomPainter {
  final double progress;

  const _AudioRainPainter({
    required this.progress,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final paint =
        Paint()
          ..color =
              const Color(
            0xFFE6C875,
          )
          ..strokeCap =
              StrokeCap.round
          ..strokeWidth = 2.5;

    const heights = [
      0.32,
      0.52,
      0.78,
      0.42,
      0.92,
      0.58,
      0.36,
      0.70,
      0.48,
    ];

    for (
      var i = 0;
      i < heights.length;
      i++
    ) {
      final x =
          4 +
          (size.width - 8) *
              i /
              (heights.length - 1);

      final wave =
          (progress +
                  i * 0.13) %
              1.0;

      final fall =
          (wave * 1.7) %
              1.0;

      final baseHeight =
          size.height *
              heights[i];

      final y =
          size.height *
              (0.12 +
                  fall * 0.58);

      final lineHeight =
          baseHeight *
              (0.38 +
                  0.62 *
                      (1 -
                          fall));

      canvas.drawLine(
        Offset(
          x,
          y,
        ),
        Offset(
          x,
          y + lineHeight,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant
        _AudioRainPainter
            oldDelegate,
  ) {
    return oldDelegate.progress !=
        progress;
  }
}
