import 'dart:async';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

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

  List<Map<String, dynamic>> _items = [];

  List<QuranReciter> _reciters = [];
  List<RadioCountry> _countries = [];
  List<RadioStation> _stations = [];

  QuranReciter? _selectedReciter;
  QuranMoshaf? _selectedMoshaf;
  RadioCountry? _selectedCountry;

  StreamSubscription<PlaybackState>? _playbackSubscription;

  bool _isPlaying = false;
  String _currentTitle = '';

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
      lowerBound: 0.85,
      upperBound: 1.15,
    );

    _initialize();
  }

  Future<void> _initialize() async {
    await AudioController.initialize();

    _playbackSubscription =
        AudioController.playbackStateStream.listen((state) {
      if (!mounted) return;

      setState(() {
        _isPlaying = state.playing;
      });

      if (state.playing) {
        if (!_pulseController.isAnimating) {
          _pulseController.repeat(reverse: true);
        }
      } else {
        _pulseController.stop();
        _pulseController.value = 1;
      }
    });

    await _loadCategory();
  }

  @override
  void dispose() {
    _playbackSubscription?.cancel();
    _searchController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadCategory() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = '';
      _items = [];
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
          await _loadRadioCountries();
          break;
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'حصلت مشكلة في تحميل المحتوى.';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loadQuran() async {
    final catalog = await AiService.getQuranCatalog();

    if (!mounted) return;

    setState(() {
      _reciters = catalog.reciters;

      if (_reciters.isNotEmpty) {
        _selectedReciter = _reciters.first;

        if (_selectedReciter!.moshaf.isNotEmpty) {
          _selectedMoshaf =
              _selectedReciter!.moshaf.first;
        }
      }
    });
  }

  Future<void> _loadAdhkar() async {
    final items = await AiService.searchAudio(
      _searchController.text.trim(),
      type: 'adhkar',
    );

    if (!mounted) return;

    setState(() {
      _items = items;
    });
  }

  Future<void> _loadMusic() async {
    final items = await AiService.searchAudio(
      _searchController.text.trim(),
      type: 'music',
    );

    if (!mounted) return;

    setState(() {
      _items = items;
    });
  }

  Future<void> _loadPodcast() async {
    final items = await AiService.searchAudio(
      _searchController.text.trim(),
      type: 'podcast',
    );

    if (!mounted) return;

    setState(() {
      _items = items;
    });
  }

  Future<void> _loadRadioCountries() async {
    final countries =
        await AiService.getRadioCountries();

    if (!mounted) return;

    setState(() {
      _countries = countries;

      if (_countries.isNotEmpty) {
        _selectedCountry =
            _findEgyptOrFirst(_countries);
      }
    });

    if (_selectedCountry != null) {
      await _loadRadioStations(
        _selectedCountry!,
      );
    }
  }

  RadioCountry _findEgyptOrFirst(
    List<RadioCountry> countries,
  ) {
    for (final country in countries) {
      final name =
          country.name.toLowerCase();

      final iso =
          country.iso.toUpperCase();

      if (
        iso == 'EG' ||
        name.contains('egypt') ||
        name.contains('مصر')
      ) {
        return country;
      }
    }

    return countries.first;
  }

  Future<void> _loadRadioStations(
    RadioCountry country,
  ) async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = '';
      _stations = [];
    });

    try {
      final stations =
          await AiService.getRadioStations(
        country.iso,
      );

      if (!mounted) return;

      setState(() {
        _stations = stations;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error =
            'تعذر تحميل محطات هذه الدولة.';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

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
          await _loadRadioStations(
            _selectedCountry!,
          );
        }
        return;
    }
  }

  Future<void> _playUrl({
    required String url,
    required String title,
    String? artist,
    String? artwork,
  }) async {
    if (url.trim().isEmpty) {
      _showMessage(
        'المصدر الصوتي غير متاح حاليًا.',
      );
      return;
    }

    try {
      await AudioController.playUrl(
        url: url,
        title: title,
        artist: artist,
        artUri: artwork,
      );

      if (!mounted) return;

      setState(() {
        _currentTitle = title;
      });
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        'تعذر تشغيل الصوت. جرّب عنصرًا آخر.',
      );
    }
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

      final path =
          result.files.single.path;

      if (path == null || path.isEmpty) {
        return;
      }

      final title =
          result.files.single.name;

      await AudioController.playLocalFile(
        path: path,
        title: title,
      );

      if (!mounted) return;

      setState(() {
        _currentTitle = title;
      });
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        'تعذر تشغيل الملف الصوتي.',
      );
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
            textAlign: TextAlign.right,
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
  }

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
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'ملف صوتي من الجهاز',
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
        separatorBuilder:
            (_, __) =>
                const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected =
              index == _categoryIndex;

          return GestureDetector(
            onTap: () async {
              if (_categoryIndex == index) {
                return;
              }

              setState(() {
                _categoryIndex = index;
                _selectedReciter = null;
                _selectedMoshaf = null;
                _selectedCountry = null;
                _items = [];
                _stations = [];
                _error = '';
              });

              await _loadCategory();
            },
            child: AnimatedContainer(
              duration:
                  const Duration(
                milliseconds: 250,
              ),
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 18,
              ),
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(
                  22,
                ),
                gradient: selected
                    ? const LinearGradient(
                        colors: [
                          Color(0xFF8B5CF6),
                          Color(0xFF06B6D4),
                        ],
                      )
                    : null,
                color: selected
                    ? null
                    : const Color(
                        0xFF142338,
                      ),
                border: Border.all(
                  color: Colors.white
                      .withOpacity(0.08),
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
        2,
        12,
        8,
      ),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(18),
        color:
            const Color(0xFF122238),
        border: Border.all(
          color:
              const Color(0xFF8B5CF6)
                  .withOpacity(0.35),
        ),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale:
                    _pulseController.value,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration:
                      BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:
                            const Color(
                              0xFF8B5CF6,
                            ).withOpacity(
                              _isPlaying
                                  ? 0.55
                                  : 0,
                            ),
                        blurRadius: 18,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.graphic_eq_rounded,
                    color:
                        Color(0xFF67E8F9),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _currentTitle.isEmpty
                  ? 'جاري التشغيل'
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
            onPressed: () async {
              try {
                await AudioController.stop();
              } catch (_) {}
            },
            icon: const Icon(
              Icons.stop_circle_outlined,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const ListView(
        physics:
            AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: 180),
          Center(
            child:
                CircularProgressIndicator(),
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
          const SizedBox(height: 100),
          const Icon(
            Icons.cloud_off_rounded,
            color: Colors.white54,
            size: 54,
          ),
          const SizedBox(height: 16),
          Text(
            _error,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: FilledButton.icon(
              onPressed: _loadCategory,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label:
                  const Text('إعادة المحاولة'),
            ),
          ),
        ],
      );
    }

    switch (_categoryIndex) {
      case 0:
        return _buildQuran();

      case 1:
        return _buildGenericList(
          emptyText:
              'لم يتم العثور على أذكار.',
        );

      case 2:
        return _buildGenericList(
          emptyText:
              'ابحث عن أغنية أو فنان.',
        );

      case 3:
        return _buildGenericList(
          emptyText:
              'ابحث عن بودكاست أو برنامج.',
        );

      case 4:
        return _buildRadio();

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildQuran() {
    if (_reciters.isEmpty) {
      return ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 80),
          Icon(
            Icons.menu_book_rounded,
            color: Colors.white54,
            size: 64,
          ),
          SizedBox(height: 18),
          Text(
            'تعذر تحميل القرّاء حاليًا.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
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
        12,
        8,
        12,
        30,
      ),
      children: [
        _buildSectionTitle(
          'اختر القارئ',
          Icons.record_voice_over_rounded,
        ),
        const SizedBox(height: 8),
        _buildReciterSelector(),
        const SizedBox(height: 18),
        if (_selectedReciter != null)
          _buildMoshafSelector(),
        const SizedBox(height: 18),
        _buildLocalAudioCard(),
      ],
    );
  }

  Widget _buildReciterSelector() {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
      ),
      decoration: BoxDecoration(
        color:
            const Color(0xFF122238),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white
              .withOpacity(0.08),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<QuranReciter>(
          value: _selectedReciter,
          isExpanded: true,
          dropdownColor:
              const Color(0xFF122238),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white70,
          ),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
          items: _reciters.map(
            (reciter) {
              return DropdownMenuItem<
                  QuranReciter>(
                value: reciter,
                child: Text(
                  reciter.name,
                  overflow:
                      TextOverflow.ellipsis,
                ),
              );
            },
          ).toList(),
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              _selectedReciter = value;

              _selectedMoshaf =
                  value.moshaf.isNotEmpty
                      ? value.moshaf.first
                      : null;
            });
          },
        ),
      ),
    );
  }

  Widget _buildMoshafSelector() {
    final reciter = _selectedReciter;

    if (reciter == null ||
        reciter.moshaf.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle(
          'اختر الرواية',
          Icons.library_music_rounded,
        ),
        const SizedBox(height: 8),
        Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 14,
          ),
          decoration: BoxDecoration(
            color:
                const Color(0xFF122238),
            borderRadius:
                BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white
                  .withOpacity(0.08),
            ),
          ),
          child:
              DropdownButtonHideUnderline(
            child:
                DropdownButton<QuranMoshaf>(
              value: _selectedMoshaf,
              isExpanded: true,
              dropdownColor:
                  const Color(0xFF122238),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.white70,
              ),
              style:
                  const TextStyle(
                color: Colors.white,
                fontWeight:
                    FontWeight.w700,
              ),
              items:
                  reciter.moshaf.map(
                (moshaf) {
                  return DropdownMenuItem<
                      QuranMoshaf>(
                    value: moshaf,
                    child: Text(
                      moshaf.name,
                      overflow:
                          TextOverflow
                              .ellipsis,
                    ),
                  );
                },
              ).toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _selectedMoshaf =
                      value;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'يمكنك اختيار السورة من القائمة القادمة عند اكتمال الكتالوج.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white
                .withOpacity(0.5),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildLocalAudioCard() {
    return Container(
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(20),
        gradient:
            const LinearGradient(
          colors: [
            Color(0xFF162A45),
            Color(0xFF102036),
          ],
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.audio_file_rounded,
            color: Color(0xFF67E8F9),
            size: 34,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'عندك ملف صوتي على الموبايل؟ شغّله مباشرة داخل التطبيق.',
              style: TextStyle(
                color: Colors.white70,
                height: 1.4,
              ),
            ),
          ),
          IconButton(
            onPressed: _pickLocalAudio,
            icon: const Icon(
              Icons.play_circle_fill_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadio() {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding:
          const EdgeInsets.fromLTRB(
        12,
        8,
        12,
        30,
      ),
      children: [
        _buildSectionTitle(
          'اختر الدولة أولًا',
          Icons.public_rounded,
        ),
        const SizedBox(height: 8),
        _buildCountrySelector(),
        const SizedBox(height: 18),
        if (_selectedCountry != null)
          _buildSectionTitle(
            'محطات ${_selectedCountry!.name}',
            Icons.radio_rounded,
          ),
        const SizedBox(height: 8),
        if (_stations.isEmpty)
          _buildEmptyCard(
            'لا توجد محطات متاحة حاليًا لهذه الدولة.',
          )
        else
          ..._stations.map(
            _buildStationCard,
          ),
      ],
    );
  }

  Widget _buildCountrySelector() {
    if (_countries.isEmpty) {
      return _buildEmptyCard(
        'لم يتم تحميل قائمة الدول.',
      );
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
      ),
      decoration: BoxDecoration(
        color:
            const Color(0xFF122238),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white
              .withOpacity(0.08),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child:
            DropdownButton<RadioCountry>(
          value: _selectedCountry,
          isExpanded: true,
          dropdownColor:
              const Color(0xFF122238),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white70,
          ),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
          items: _countries.map(
            (country) {
              return DropdownMenuItem<
                  RadioCountry>(
                value: country,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        country.name,
                        overflow:
                            TextOverflow
                                .ellipsis,
                      ),
                    ),
                    Text(
                      '${country.stationCount}',
                      style:
                          const TextStyle(
                        color:
                            Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            },
          ).toList(),
          onChanged: (value) async {
            if (value == null) return;

            setState(() {
              _selectedCountry =
                  value;
              _stations = [];
            });

            await _loadRadioStations(
              value,
            );
          },
        ),
      ),
    );
  }

  Widget _buildStationCard(
    RadioStation station,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      decoration: BoxDecoration(
        color:
            const Color(0xFF122238),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white
              .withOpacity(0.07),
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 5,
        ),
        leading: _buildStationImage(
          station.favicon,
        ),
        title: Text(
          station.name,
          maxLines: 1,
          overflow:
              TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight:
                FontWeight.w800,
          ),
        ),
        subtitle: Text(
          station.tags.isEmpty
              ? station.codec
              : station.tags,
          maxLines: 1,
          overflow:
              TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white54,
          ),
        ),
        trailing: IconButton(
          onPressed: () {
            _playUrl(
              url: station.streamUrl,
              title: station.name,
              artwork:
                  station.favicon,
            );
          },
          icon: const Icon(
            Icons.play_circle_fill_rounded,
            color: Color(0xFF67E8F9),
            size: 38,
          ),
        ),
      ),
    );
  }

  Widget _buildGenericList({
    required String emptyText,
  }) {
    return Column(
      children: [
        Padding(
          padding:
              const EdgeInsets.fromLTRB(
            12,
            8,
            12,
            8,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller:
                      _searchController,
                  style:
                      const TextStyle(
                    color: Colors.white,
                  ),
                  textDirection:
                      TextDirection.rtl,
                  onSubmitted: (_) =>
                      _search(),
                  decoration:
                      InputDecoration(
                    hintText:
                        _searchHint(),
                    hintStyle:
                        const TextStyle(
                      color:
                          Colors.white38,
                    ),
                    filled: true,
                    fillColor:
                        const Color(
                      0xFF122238,
                    ),
                    border:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        18,
                      ),
                      borderSide:
                          BorderSide.none,
                    ),
                    prefixIcon:
                        const Icon(
                      Icons.search_rounded,
                      color:
                          Colors.white54,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _search,
                style:
                    IconButton.styleFrom(
                  backgroundColor:
                      const Color(
                    0xFF8B5CF6,
                  ),
                  foregroundColor:
                      Colors.white,
                ),
                icon: const Icon(
                  Icons.arrow_forward_rounded,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _items.isEmpty
              ? ListView(
                  physics:
                      const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(
                      height: 120,
                    ),
                    const Icon(
                      Icons.library_music_rounded,
                      color:
                          Colors.white30,
                      size: 60,
                    ),
                    const SizedBox(
                      height: 15,
                    ),
                    Text(
                      emptyText,
                      textAlign:
                          TextAlign.center,
                      style:
                          const TextStyle(
                        color:
                            Colors.white60,
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  physics:
                      const AlwaysScrollableScrollPhysics(),
                  padding:
                      const EdgeInsets
                          .fromLTRB(
                    12,
                    0,
                    12,
                    30,
                  ),
                  itemCount:
                      _items.length,
                  itemBuilder:
                      (context, index) {
                    return _buildAudioItem(
                      _items[index],
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _searchHint() {
    switch (_categoryIndex) {
      case 1:
        return 'ابحث عن ذكر أو قسم...';
      case 2:
        return 'اسم أغنية أو فنان...';
      case 3:
        return 'اسم بودكاست أو برنامج...';
      default:
        return 'بحث...';
    }
  }

  Widget _buildAudioItem(
    Map<String, dynamic> item,
  ) {
    final title =
        String(item['title'] ?? 'بدون عنوان');

    final artist =
        String(item['artist'] ?? '');

    final artwork =
        String(item['artwork'] ?? '');

    final previewUrl =
        String(item['previewUrl'] ?? '');

    final text =
        String(item['text'] ?? '');

    final type =
        String(item['type'] ?? '');

    final playable =
        previewUrl.isNotEmpty;

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      padding:
          const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            const Color(0xFF122238),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white
              .withOpacity(0.07),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _buildArtwork(
            artwork,
            type,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
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
                if (artist.isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets
                            .only(
                      top: 4,
                    ),
                    child: Text(
                      artist,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        color:
                            Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (text.isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets
                            .only(
                      top: 7,
                    ),
                    child: Text(
                      text,
                      maxLines: 3,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        color:
                            Colors.white70,
                        height: 1.4,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (playable)
            IconButton(
              onPressed: () {
                _playUrl(
                  url: previewUrl,
                  title: title,
                  artist: artist,
                  artwork: artwork,
                );
              },
              icon: const Icon(
                Icons.play_circle_fill_rounded,
                color:
                    Color(0xFF67E8F9),
                size: 38,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildArtwork(
    String url,
    String type,
  ) {
    if (url.isNotEmpty) {
      return ClipRRect(
        borderRadius:
            BorderRadius.circular(14),
        child: Image.network(
          url,
          width: 62,
          height: 62,
          fit: BoxFit.cover,
          errorBuilder:
              (_, __, ___) {
            return _defaultArtwork(type);
          },
        ),
      );
    }

    return _defaultArtwork(type);
  }

  Widget _defaultArtwork(
    String type,
  ) {
    IconData icon;

    switch (type) {
      case 'music':
        icon = Icons.music_note_rounded;
        break;
      case 'podcast':
        icon = Icons.podcasts_rounded;
        break;
      case 'adhkar':
        icon = Icons.auto_awesome_rounded;
        break;
      default:
        icon = Icons.graphic_eq_rounded;
    }

    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(14),
        gradient:
            const LinearGradient(
          colors: [
            Color(0xFF8B5CF6),
            Color(0xFF06B6D4),
          ],
        ),
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: 30,
      ),
    );
  }

  Widget _buildStationImage(
    String url,
  ) {
    if (url.isEmpty) {
      return _defaultArtwork(
        'radio',
      );
    }

    return ClipRRect(
      borderRadius:
          BorderRadius.circular(12),
      child: Image.network(
        url,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        errorBuilder:
            (_, __, ___) {
          return _defaultArtwork(
            'radio',
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(
    String title,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          color: const Color(
            0xFF67E8F9,
          ),
          size: 21,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight:
                FontWeight.w900,
            fontSize: 17,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCard(
    String message,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color:
            const Color(0xFF122238),
        borderRadius:
            BorderRadius.circular(18),
      ),
      child: Text(
        message,
        textAlign:
            TextAlign.center,
        style: const TextStyle(
          color: Colors.white60,
        ),
      ),
    );
  }
}
