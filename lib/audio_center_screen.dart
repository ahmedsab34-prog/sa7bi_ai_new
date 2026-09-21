import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'ai_service.dart';
import 'audio_player_service.dart';

class AudioCenterScreen extends StatefulWidget {
  const AudioCenterScreen({super.key});

  @override
  State<AudioCenterScreen> createState() =>
      _AudioCenterScreenState();
}

class _AudioCenterScreenState extends State<AudioCenterScreen>
    with TickerProviderStateMixin {
  int _categoryIndex = 0;

  final List<String> _categories = const [
    'القرآن',
    'الأذكار',
    'موسيقى',
    'بودكاست',
    'الراديو',
  ];

  final TextEditingController _searchController =
      TextEditingController();

  bool _loading = false;
  String _error = '';

  List<AudioSearchItem> _audioItems = [];

  QuranCatalog? _quranCatalog;
  QuranReciter? _selectedReciter;
  QuranMoshaf? _selectedMoshaf;
  QuranSura? _selectedSura;

  List<RadioCountry> _countries = [];
  RadioCountry? _selectedCountry;
  List<RadioStation> _stations = [];

  StreamSubscription? _playbackSubscription;

  bool _isPlaying = false;
  String _currentTitle = '';

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.88,
      upperBound: 1.12,
    );

    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await AudioController.initialize();

      _playbackSubscription =
          AudioController.playbackStateStream.listen((state) {
        if (!mounted) return;

        final playing = state.playing;

        setState(() {
          _isPlaying = playing;
        });

        if (playing) {
          if (!_pulseController.isAnimating) {
            _pulseController.repeat(reverse: true);
          }
        } else {
          _pulseController.stop();
          _pulseController.value = 1;
        }
      });
    } catch (_) {
      // الصوت يظل متاحًا للمحاولة من الشاشة.
    }

    await _loadCategory();
  }

  @override
  void dispose() {
    _playbackSubscription?.cancel();
    _searchController.dispose();
    _pulseController.dispose();
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
    });

    await _loadCategory();
  }

  Future<void> _loadCategory() async {
    if (!mounted) return;

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
      if (!mounted) return;

      setState(() {
        _error =
            'حصلت مشكلة أثناء تحميل المحتوى. جرّب التحديث مرة أخرى.';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  // ============================================================
  // QURAN
  // ============================================================

  Future<void> _loadQuran() async {
    final catalog = await AiService.getQuranCatalog();

    if (!mounted) return;

    if (catalog == null) {
      setState(() {
        _quranCatalog = null;
        _selectedReciter = null;
        _selectedMoshaf = null;
        _selectedSura = null;
        _error = 'تعذر تحميل قائمة القراء حاليًا.';
      });
      return;
    }

    setState(() {
      _quranCatalog = catalog;

      if (catalog.reciters.isNotEmpty) {
        _selectedReciter = catalog.reciters.first;

        if (_selectedReciter!.moshaf.isNotEmpty) {
          _selectedMoshaf =
              _selectedReciter!.moshaf.first;
        } else {
          _selectedMoshaf = null;
        }
      } else {
        _selectedReciter = null;
        _selectedMoshaf = null;
      }

      if (catalog.suwar.isNotEmpty) {
        _selectedSura = catalog.suwar.first;
      } else {
        _selectedSura = null;
      }
    });
  }

  void _onReciterChanged(QuranReciter? reciter) {
    if (reciter == null) return;

    setState(() {
      _selectedReciter = reciter;

      if (reciter.moshaf.isNotEmpty) {
        _selectedMoshaf = reciter.moshaf.first;
      } else {
        _selectedMoshaf = null;
      }
    });
  }

  void _onMoshafChanged(QuranMoshaf? moshaf) {
    if (moshaf == null) return;

    setState(() {
      _selectedMoshaf = moshaf;
    });
  }

  void _onSuraChanged(QuranSura? sura) {
    if (sura == null) return;

    setState(() {
      _selectedSura = sura;
    });
  }

  String? _buildQuranUrl(
    QuranMoshaf moshaf,
    QuranSura sura,
  ) {
    final server = moshaf.server.trim();

    if (server.isEmpty) {
      return null;
    }

    var base = server;

    if (!base.endsWith('/')) {
      base = '$base/';
    }

    final number =
        sura.id.toString().padLeft(3, '0');

    return '${base} $number.mp3'.replaceAll(' ', '');
  }

  Future<void> _playSelectedSura() async {
    final moshaf = _selectedMoshaf;
    final sura = _selectedSura;

    if (moshaf == null || sura == null) {
      _showMessage(
        'اختار القارئ والرواية والسورة أولًا.',
      );
      return;
    }

    final url = _buildQuranUrl(
      moshaf,
      sura,
    );

    if (url == null) {
      _showMessage(
        'رابط الصوت الخاص بهذه الرواية غير متاح.',
      );
      return;
    }

    final title =
        '${sura.name} - ${_selectedReciter?.name ?? 'القرآن'}';

    await _playUrl(
      url: url,
      title: title,
      artist: _selectedReciter?.name,
    );
  }

  // ============================================================
  // ADHKAR
  // ============================================================

  Future<void> _loadAdhkar() async {
    final query =
        _searchController.text.trim();

    final items = await AiService.searchAudio(
      query.isEmpty ? 'أذكار' : query,
      type: 'adhkar',
    );

    if (!mounted) return;

    setState(() {
      _audioItems = items;
    });

    if (items.isEmpty) {
      setState(() {
        _error =
            'لم يتم العثور على أذكار حاليًا. جرّب التحديث.';
      });
    }
  }

  // ============================================================
  // MUSIC
  // ============================================================

  Future<void> _loadMusic() async {
    final query =
        _searchController.text.trim();

    final items = await AiService.searchAudio(
      query.isEmpty ? 'Arabic music' : query,
      type: 'music',
    );

    if (!mounted) return;

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

    final items = await AiService.searchAudio(
      query.isEmpty ? 'Arabic podcast' : query,
      type: 'podcast',
    );

    if (!mounted) return;

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

    if (!mounted) return;

    if (countries.isEmpty) {
      setState(() {
        _countries = [];
        _selectedCountry = null;
        _stations = [];
        _error =
            'تعذر تحميل قائمة الدول والإذاعات حاليًا.';
      });
      return;
    }

    RadioCountry selected =
        countries.first;

    for (final country in countries) {
      final name =
          country.name.toLowerCase();

      final code =
          country.code.toUpperCase();

      if (code == 'EG' ||
          name.contains('egypt') ||
          name.contains('مصر')) {
        selected = country;
        break;
      }
    }

    setState(() {
      _countries = countries;
      _selectedCountry = selected;
      _stations = [];
    });

    await _loadStations(
      selected,
    );
  }

  Future<void> _changeCountry(
    RadioCountry? country,
  ) async {
    if (country == null) return;

    setState(() {
      _selectedCountry = country;
      _stations = [];
      _error = '';
      _loading = true;
    });

    await _loadStations(country);

    if (!mounted) return;

    setState(() {
      _loading = false;
    });
  }

  Future<void> _loadStations(
    RadioCountry country,
  ) async {
    try {
      final stations =
          await AiService.getRadioStations(
        country.code,
      );

      if (!mounted) return;

      setState(() {
        _stations = stations;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _stations = [];
        _error =
            'تعذر تحميل محطات هذه الدولة.';
      });
    }
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Future<void> _search() async {
    switch (_categoryIndex) {
      case 0:
        return;

      case 1:
        await _loadAdhkar();
        return;

      case 2:
        await _loadMusic();
        return;

      case 3:
        await _loadPodcast();
        return;

      case 4:
        if (_selectedCountry != null) {
          await _loadStations(
            _selectedCountry!,
          );
        }
        return;
    }
  }

  // ============================================================
  // AUDIO CONTROL
  // ============================================================

  Future<void> _playUrl({
    required String url,
    required String title,
    String? artist,
    String? artwork,
  }) async {
    final cleanUrl = url.trim();

    if (cleanUrl.isEmpty) {
      _showMessage(
        'المصدر الصوتي غير متاح لهذا العنصر.',
      );
      return;
    }

    try {
      Uri? artUri;

      if (artwork != null &&
          artwork.trim().isNotEmpty) {
        artUri = Uri.tryParse(
          artwork.trim(),
        );
      }

      await AudioController.playUrl(
        url: cleanUrl,
        title: title,
        artist: artist,
        artUri: artUri,
      );

      if (!mounted) return;

      setState(() {
        _currentTitle = title;
        _isPlaying = true;
      });
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        'تعذر تشغيل الصوت. جرّب عنصرًا آخر.',
      );
    }
  }

  Future<void> _stopAudio() async {
    try {
      await AudioController.stop();

      if (!mounted) return;

      setState(() {
        _isPlaying = false;
      });
    } catch (_) {}
  }

  Future<void> _pickLocalAudio() async {
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
        _showMessage(
          'تعذر الوصول إلى الملف.',
        );
        return;
      }

      await AudioController.playLocalFile(
        path: path,
        title: file.name,
      );

      if (!mounted) return;

      setState(() {
        _currentTitle = file.name;
        _isPlaying = true;
      });
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        'تعذر تشغيل الملف الصوتي.',
      );
    }
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
            const Color(0xFF07111F),
        appBar: AppBar(
          backgroundColor:
              Colors.transparent,
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
              onPressed: _pickLocalAudio,
              icon: const Icon(
                Icons.folder_open_rounded,
                color: Colors.white,
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            _buildCategoryBar(),
            if (_isPlaying)
              _buildPlayingBar(),
            Expanded(
              child: RefreshIndicator(
                color: Colors.white,
                backgroundColor:
                    const Color(0xFF17283E),
                onRefresh: _loadCategory,
                child: _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBar() {
    return SizedBox(
      height: 58,
      child: ListView.separated(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 7,
        ),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected =
              index == _categoryIndex;

          return GestureDetector(
            onTap: () =>
                _changeCategory(index),
            child: AnimatedContainer(
              duration:
                  const Duration(milliseconds: 220),
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 18,
              ),
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(18),
                color: selected
                    ? const Color(0xFFB9913E)
                    : const Color(0xFF132238),
                border: Border.all(
                  color: selected
                      ? const Color(0xFFE6C875)
                      : Colors.white10,
                ),
              ),
              child: Center(
                child: Text(
                  _categories[index],
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: selected
                        ? FontWeight.w800
                        : FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlayingBar() {
    return Container(
      margin:
          const EdgeInsets.fromLTRB(
        12,
        4,
        12,
        8,
      ),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF182D46),
            Color(0xFF0D1A2C),
          ],
        ),
        border: Border.all(
          color: Colors.white12,
        ),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (_, child) {
              return Transform.scale(
                scale:
                    _isPlaying
                        ? _pulseController.value
                        : 1,
                child: child,
              );
            },
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    const Color(0xFFB9913E)
                        .withOpacity(.18),
                border: Border.all(
                  color:
                      const Color(0xFFE6C875)
                          .withOpacity(.45),
                ),
              ),
              child: const Icon(
                Icons.graphic_eq_rounded,
                color: Color(0xFFE6C875),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _currentTitle.isEmpty
                  ? 'يتم تشغيل الصوت'
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
            onPressed: _stopAudio,
            icon: const Icon(
              Icons.stop_circle_outlined,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 90),
          Center(
            child: CircularProgressIndicator(
              color: Color(0xFFE6C875),
            ),
          ),
        ],
      );
    }

    if (_error.isNotEmpty) {
      return ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          const Icon(
            Icons.cloud_off_rounded,
            size: 54,
            color: Colors.white38,
          ),
          const SizedBox(height: 16),
          Text(
            _error,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: ElevatedButton.icon(
              onPressed: _loadCategory,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text(
                'إعادة المحاولة',
              ),
            ),
          ),
        ],
      );
    }

    switch (_categoryIndex) {
      case 0:
        return _buildQuran();

      case 1:
        return _buildAdhkar();

      case 2:
        return _buildSearchAudioList(
          title: 'الموسيقى',
          emptyText:
              'ابحث عن فنان أو أغنية.',
        );

      case 3:
        return _buildSearchAudioList(
          title: 'البودكاست',
          emptyText:
              'ابحث عن بودكاست أو برنامج.',
        );

      case 4:
        return _buildRadio();

      default:
        return const SizedBox.shrink();
    }
  }

  // ============================================================
  // QURAN UI
  // ============================================================

  Widget _buildQuran() {
    final catalog = _quranCatalog;

    if (catalog == null ||
        catalog.reciters.isEmpty) {
      return ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          Center(
            child: Text(
              'لا توجد قائمة قراء متاحة حاليًا.',
              style: TextStyle(
                color: Colors.white70,
              ),
            ),
          ),
        ],
      );
    }

    final reciters =
        catalog.reciters;

    final moshaf =
        _selectedReciter?.moshaf ?? [];

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
        _buildSectionIntro(
          icon: Icons.menu_book_rounded,
          title: 'القرآن الكريم',
          subtitle:
              'اختار القارئ أولًا ثم الرواية والسورة.',
        ),
        const SizedBox(height: 14),
        _buildDropdown<QuranReciter>(
          label: 'القارئ',
          value: _selectedReciter,
          items: reciters,
          labelBuilder: (item) =>
              item.name,
          onChanged: _onReciterChanged,
        ),
        const SizedBox(height: 12),
        if (moshaf.isNotEmpty)
          _buildDropdown<QuranMoshaf>(
            label: 'الرواية / المصحف',
            value: _selectedMoshaf,
            items: moshaf,
            labelBuilder: (item) =>
                item.name.isEmpty
                    ? 'رواية'
                    : item.name,
            onChanged:
                _onMoshafChanged,
          ),
        if (catalog.suwar.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildDropdown<QuranSura>(
            label: 'السورة',
            value: _selectedSura,
            items: catalog.suwar,
            labelBuilder: (item) =>
                '${item.id}. ${item.name}',
            onChanged: _onSuraChanged,
          ),
        ],
        const SizedBox(height: 18),
        SizedBox(
          height: 54,
          child: ElevatedButton.icon(
            onPressed:
                _selectedMoshaf != null &&
                        _selectedSura != null
                    ? _playSelectedSura
                    : null,
            icon: const Icon(
              Icons.play_arrow_rounded,
            ),
            label: const Text(
              'تشغيل السورة',
              style: TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        _buildInfoCard(
          icon: Icons.people_alt_rounded,
          title:
              'عدد القراء المتاحين',
          value:
              '${reciters.length} قارئ',
        ),
      ],
    );
  }

  // ============================================================
  // ADHKAR UI
  // ============================================================

  Widget _buildAdhkar() {
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
        _buildSearchBox(
          hint:
              'ابحث في الأذكار...',
          onSearch: _search,
        ),
        const SizedBox(height: 14),
        _buildSectionIntro(
          icon: Icons.favorite_rounded,
          title: 'الأذكار',
          subtitle:
              'محتوى الأذكار متاح داخل التطبيق.',
        ),
        const SizedBox(height: 12),
        if (_audioItems.isEmpty)
          _buildEmptyCard(
            'لا توجد نتائج أذكار حاليًا.',
          )
        else
          ..._audioItems.map(
            _buildAdhkarCard,
          ),
      ],
    );
  }

  Widget _buildAdhkarCard(
    AudioSearchItem item,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(bottom: 10),
      padding:
          const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            style: const TextStyle(
              color: Color(0xFFE6C875),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            item.text.isEmpty
                ? item.title
                : item.text,
            textDirection:
                TextDirection.rtl,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.8,
            ),
          ),
          if (item.url.isNotEmpty) ...[
            const SizedBox(height: 10),
            Align(
              alignment:
                  Alignment.centerLeft,
              child: IconButton(
                onPressed: () =>
                    _playUrl(
                  url: item.url,
                  title: item.title,
                ),
                icon: const Icon(
                  Icons.play_circle_fill_rounded,
                  color:
                      Color(0xFFE6C875),
                  size: 34,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // MUSIC / PODCAST UI
  // ============================================================

  Widget _buildSearchAudioList({
    required String title,
    required String emptyText,
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
        _buildSearchBox(
          hint:
              'ابحث في $title...',
          onSearch: _search,
        ),
        const SizedBox(height: 14),
        _buildSectionIntro(
          icon: title == 'الموسيقى'
              ? Icons.music_note_rounded
              : Icons.podcasts_rounded,
          title: title,
          subtitle:
              'نتائج متاحة من المصادر الصوتية.',
        ),
        const SizedBox(height: 12),
        if (_audioItems.isEmpty)
          _buildEmptyCard(emptyText)
        else
          ..._audioItems.map(
            _buildAudioCard,
          ),
      ],
    );
  }

  Widget _buildAudioCard(
    AudioSearchItem item,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(bottom: 10),
      decoration: _cardDecoration(),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ),
        leading: _buildArtwork(
          item.artwork,
        ),
        title: Text(
          item.title,
          maxLines: 2,
          overflow:
              TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: item.artist == null ||
                item.artist!.isEmpty
            ? null
            : Text(
                item.artist!,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white54,
                ),
              ),
        trailing: item.url.isEmpty
            ? null
            : IconButton(
                onPressed: () =>
                    _playUrl(
                  url: item.url,
                  title: item.title,
                  artist: item.artist,
                  artwork:
                      item.artwork,
                ),
                icon: const Icon(
                  Icons.play_circle_fill_rounded,
                  color:
                      Color(0xFFE6C875),
                  size: 36,
                ),
              ),
      ),
    );
  }

  // ============================================================
  // RADIO UI
  // ============================================================

  Widget _buildRadio() {
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
        _buildSectionIntro(
          icon: Icons.radio_rounded,
          title: 'الراديو',
          subtitle:
              'اختار الدولة أولًا ثم اختار المحطة.',
        ),
        const SizedBox(height: 14),
        if (_countries.isNotEmpty)
          _buildDropdown<RadioCountry>(
            label: 'الدولة',
            value: _selectedCountry,
            items: _countries,
            labelBuilder: (item) =>
                '${item.name} (${item.stationCount})',
            onChanged:
                _changeCountry,
          ),
        const SizedBox(height: 16),
        if (_stations.isEmpty)
          _buildEmptyCard(
            'لا توجد محطات متاحة لهذه الدولة حاليًا.',
          )
        else
          ..._stations.map(
            _buildRadioStationCard,
          ),
      ],
    );
  }

  Widget _buildRadioStationCard(
    RadioStation station,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(bottom: 10),
      decoration: _cardDecoration(),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ),
        leading: _buildArtwork(
          station.favicon,
        ),
        title: Text(
          station.name,
          maxLines: 2,
          overflow:
              TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          [
            if (station.codec.isNotEmpty)
              station.codec,
            if (station.bitrate > 0)
              '${station.bitrate} kbps',
          ].join(' • '),
          style: const TextStyle(
            color: Colors.white54,
          ),
        ),
        trailing: IconButton(
          onPressed: station.url.isEmpty
              ? null
              : () => _playUrl(
                    url: station.url,
                    title: station.name,
                    artwork:
                        station.favicon,
                  ),
          icon: const Icon(
            Icons.play_circle_fill_rounded,
            color: Color(0xFFE6C875),
            size: 36,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // COMMON WIDGETS
  // ============================================================

  Widget _buildSearchBox({
    required String hint,
    required VoidCallback onSearch,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101E31),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: TextField(
        controller: _searchController,
        textDirection: TextDirection.rtl,
        style: const TextStyle(
          color: Colors.white,
        ),
        onSubmitted: (_) => onSearch(),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: Colors.white38,
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          prefixIcon: IconButton(
            onPressed: onSearch,
            icon: const Icon(
              Icons.search_rounded,
              color: Color(0xFFE6C875),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionIntro({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  const Color(0xFFE6C875)
                      .withOpacity(.12),
            ),
            child: Icon(
              icon,
              color:
                  const Color(0xFFE6C875),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight:
                        FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white54,
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

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(15),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFFE6C875),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(String text) {
    return Container(
      padding:
          const EdgeInsets.all(22),
      decoration: _cardDecoration(),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white54,
          height: 1.6,
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T item)
        labelBuilder,
    required ValueChanged<T?> onChanged,
  }) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final safeValue =
        items.contains(value)
            ? value
            : items.first;

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF101E31),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: safeValue,
          isExpanded: true,
          dropdownColor:
              const Color(0xFF14243A),
          iconEnabledColor:
              const Color(0xFFE6C875),
          style: const TextStyle(
            color: Colors.white,
          ),
          hint: Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
            ),
          ),
          items: items.map(
            (item) {
              return DropdownMenuItem<T>(
                value: item,
                child: Text(
                  labelBuilder(item),
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                ),
              );
            },
          ).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildArtwork(String url) {
    final clean = url.trim();

    if (clean.isEmpty) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius:
              BorderRadius.circular(13),
          color: Colors.white10,
        ),
        child: const Icon(
          Icons.music_note_rounded,
          color: Colors.white54,
        ),
      );
    }

    return ClipRRect(
      borderRadius:
          BorderRadius.circular(13),
      child: Image.network(
        clean,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder:
            (_, __, ___) {
          return Container(
            width: 48,
            height: 48,
            color: Colors.white10,
            child: const Icon(
              Icons.music_note_rounded,
              color: Colors.white54,
            ),
          );
        },
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: const Color(0xFF101E31),
      borderRadius:
          BorderRadius.circular(18),
      border: Border.all(
        color: Colors.white10,
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textAlign: TextAlign.right,
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
  }
}
