import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'ai_service.dart';
import 'audio_player_service.dart';

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
  final TextEditingController _searchController =
      TextEditingController();

  Sa7biAudioHandler? handler;

  bool loading = true;
  bool searching = false;
  bool radioLoading = false;

  List<AudioSearchItem> results = [];
  List<_RadioStation> radioStations = [];

  String selectedCategory = 'القرآن';

  @override
  void initState() {
    super.initState();
    _initializeAudio();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeAudio() async {
    try {
      final audioHandler =
          await AudioController.initialize();

      if (!mounted) return;

      setState(() {
        handler = audioHandler;
        loading = false;
      });

      await _loadRadioStations(
        query: 'Egypt',
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تعذر تشغيل نظام الصوت حاليًا.',
            textDirection: TextDirection.rtl,
          ),
        ),
      );
    }
  }

  Future<void> _search() async {
    final query =
        _searchController.text.trim();

    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();

    if (selectedCategory == 'الراديو') {
      await _searchRadio(query);
      return;
    }

    setState(() {
      searching = true;
      results = [];
    });

    try {
      final data =
          await AiService.searchAudio(query);

      if (!mounted) return;

      setState(() {
        results = data;
        searching = false;
      });

      if (data.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'ملقتش نتائج صوتية متاحة للبحث ده حاليًا.',
              textDirection: TextDirection.rtl,
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        results = [];
        searching = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تعذر البحث عن الصوت حاليًا.',
            textDirection: TextDirection.rtl,
          ),
        ),
      );
    }
  }

  Future<void> _searchRadio(
    String query,
  ) async {
    await _loadRadioStations(
      query: query,
    );
  }

  Future<void> _loadRadioStations({
    required String query,
  }) async {
    if (!mounted) return;

    setState(() {
      radioLoading = true;
    });

    try {
      final uri = Uri.https(
        'de1.api.radio-browser.info',
        '/json/stations/search',
        {
          'name': query,
          'limit': '20',
          'hidebroken': 'true',
          'order': 'clickcount',
          'reverse': 'true',
        },
      );

      final response = await http
          .get(
            uri,
            headers: const {
              'User-Agent':
                  'Sa7biAI/1.0',
            },
          )
          .timeout(
            const Duration(seconds: 15),
          );

      if (response.statusCode != 200) {
        throw Exception(
          'Radio Browser HTTP ${response.statusCode}',
        );
      }

      final decoded =
          jsonDecode(response.body);

      if (decoded is! List) {
        throw Exception(
          'Invalid radio response',
        );
      }

      final stations = <_RadioStation>[];

      for (final item in decoded) {
        if (item is! Map) continue;

        final name =
            '${item['name'] ?? ''}'.trim();

        final url =
            '${item['url_resolved'] ?? item['url'] ?? ''}'
                .trim();

        if (name.isEmpty ||
            url.isEmpty) {
          continue;
        }

        stations.add(
          _RadioStation(
            name: name,
            url: url,
            country:
                '${item['country'] ?? ''}'.trim(),
            language:
                '${item['language'] ?? ''}'.trim(),
            codec:
                '${item['codec'] ?? ''}'.trim(),
          ),
        );

        if (stations.length >= 20) {
          break;
        }
      }

      if (!mounted) return;

      setState(() {
        radioStations = stations;
        radioLoading = false;
      });

      if (stations.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'ملقتش محطات راديو متاحة حاليًا.',
              textDirection: TextDirection.rtl,
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        radioStations = [];
        radioLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تعذر تحميل محطات الراديو حاليًا.',
            textDirection: TextDirection.rtl,
          ),
        ),
      );
    }
  }

  Future<void> _pickLocalAudio() async {
    final localHandler = handler;

    if (localHandler == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'نظام الصوت لم يجهز بعد.',
            textDirection: TextDirection.rtl,
          ),
        ),
      );
      return;
    }

    try {
      final FilePickerResult? result =
          await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result == null ||
          result.files.isEmpty) {
        return;
      }

      final PlatformFile picked =
          result.files.first;

      final safePath = picked.path;

      if (safePath == null ||
          safePath.trim().isEmpty) {
        throw Exception(
          'تعذر الوصول إلى مسار ملف الصوت.',
        );
      }

      await localHandler.playLocalFile(
        path: safePath,
        title: picked.name,
        artist: 'من الهاتف',
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تعذر تشغيل الملف: $e',
            textDirection: TextDirection.rtl,
          ),
        ),
      );
    }
  }

  Future<void> _play(
    AudioSearchItem item,
  ) async {
    final localHandler = handler;

    if (localHandler == null ||
        item.url.trim().isEmpty) {
      return;
    }

    try {
      await localHandler.playUrl(
        url: item.url,
        title: item.title,
        artist:
            item.artist ?? 'صحبي AI',
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تعذر تشغيل الصوت: $e',
            textDirection: TextDirection.rtl,
          ),
        ),
      );
    }
  }

  Future<void> _playRadio(
    _RadioStation station,
  ) async {
    final localHandler = handler;

    if (localHandler == null) return;

    if (station.url.trim().isEmpty) {
      return;
    }

    try {
      await localHandler.playUrl(
        url: station.url,
        title: station.name,
        artist:
            station.country.isEmpty
                ? 'راديو مباشر'
                : 'راديو مباشر • ${station.country}',
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'المحطة دي مش قابلة للتشغيل حاليًا. جرّب محطة تانية.',
            textDirection: TextDirection.rtl,
          ),
        ),
      );
    }
  }

  void _selectCategory(
    String category,
  ) {
    setState(() {
      selectedCategory = category;
      results = [];
      radioStations = [];
      _searchController.clear();
    });

    if (category == 'الراديو') {
      _loadRadioStations(
        query: 'Egypt',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFF080A10),
      appBar: AppBar(
        backgroundColor:
            const Color(0xFF0D1018),
        foregroundColor:
            Colors.white,
        centerTitle: true,
        title: const Text(
          'صوت صاحبي',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: loading
          ? const Center(
              child:
                  CircularProgressIndicator(
                color:
                    Color(0xFFFFD76A),
              ),
            )
          : ListView(
              padding:
                  const EdgeInsets.fromLTRB(
                14,
                14,
                14,
                35,
              ),
              children: [
                _buildHero(),

                const SizedBox(height: 14),

                _buildCategories(),

                const SizedBox(height: 13),

                _buildSearch(),

                const SizedBox(height: 12),

                if (selectedCategory ==
                    'الراديو')
                  _buildRadioContent()
                else
                  _buildAudioContent(),

                const SizedBox(height: 18),

                _buildLocalFiles(),

                const SizedBox(height: 20),

                const Text(
                  'الصوت يقدر يفضل شغال أثناء التنقل داخل التطبيق، ومع إعدادات النظام المناسبة يظهر في إشعار الهاتف وشاشة القفل.',
                  textDirection:
                      TextDirection.rtl,
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    color:
                        Colors.white54,
                    height: 1.5,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding:
          const EdgeInsets.all(19),
      decoration:
          BoxDecoration(
        borderRadius:
            BorderRadius.circular(26),
        gradient:
            const LinearGradient(
          begin:
              Alignment.topRight,
          end:
              Alignment.bottomLeft,
          colors: [
            Color(0xFF30210A),
            Color(0xFF17182A),
            Color(0xFF10131C),
          ],
        ),
        border:
            Border.all(
          color:
              const Color(0x55FFD76A),
        ),
        boxShadow: const [
          BoxShadow(
            color:
                Color(0x18000000),
            blurRadius: 18,
            offset:
                Offset(0, 7),
          ),
        ],
      ),
      child: const Column(
        children: [
          Icon(
            Icons.graphic_eq_rounded,
            color:
                Color(0xFFFFD76A),
            size: 46,
          ),
          SizedBox(height: 7),
          Text(
            'صوت صاحبي',
            textDirection:
                TextDirection.rtl,
            style:
                TextStyle(
              fontSize: 23,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'قرآن • أذكار • راديو • موسيقى • بودكاست',
            textDirection:
                TextDirection.rtl,
            textAlign:
                TextAlign.center,
            style:
                TextStyle(
              color:
                  Colors.white60,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    const categories = [
      'القرآن',
      'الأذكار',
      'موسيقى',
      'بودكاست',
      'الراديو',
    ];

    return Wrap(
      alignment:
          WrapAlignment.center,
      spacing: 7,
      runSpacing: 7,
      children:
          categories.map(
        (category) {
          final selected =
              category ==
                  selectedCategory;

          return ChoiceChip(
            selected: selected,
            label: Text(
              category,
              textDirection:
                  TextDirection.rtl,
            ),
            selectedColor:
                const Color(0xFFFFD76A),
            backgroundColor:
                const Color(0xFF151923),
            labelStyle:
                TextStyle(
              color: selected
                  ? Colors.black
                  : Colors.white,
              fontWeight:
                  FontWeight.w700,
              fontSize: 11,
            ),
            side:
                BorderSide(
              color: selected
                  ? const Color(
                      0xFFFFD76A,
                    )
                  : Colors.white12,
            ),
            onSelected: (_) {
              _selectCategory(
                category,
              );
            },
          );
        },
      ).toList(),
    );
  }

  Widget _buildSearch() {
    final hint =
        selectedCategory ==
                'الراديو'
            ? 'ابحث عن محطة: مصر، أخبار، قرآن، FM...'
            : 'مثلاً: قرآن، ماهر المعيقلي، أذكار...';

    return TextField(
      controller:
          _searchController,
      textDirection:
          TextDirection.rtl,
      style:
          const TextStyle(
        color:
            Colors.white,
      ),
      onSubmitted: (_) {
        _search();
      },
      decoration:
          InputDecoration(
        hintText: hint,
        hintTextDirection:
            TextDirection.rtl,
        filled: true,
        fillColor:
            const Color(0xFF151923),
        suffixIcon:
            IconButton(
          onPressed:
              _search,
          icon:
              const Icon(
            Icons.search_rounded,
            color:
                Color(0xFFFFD76A),
          ),
        ),
        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            19,
          ),
          borderSide:
              BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildAudioContent() {
    if (searching) {
      return const Padding(
        padding:
            EdgeInsets.all(25),
        child: Center(
          child:
              CircularProgressIndicator(
            color:
                Color(0xFFFFD76A),
          ),
        ),
      );
    }

    if (results.isNotEmpty) {
      return Column(
        children:
            results
                .map(_buildResult)
                .toList(),
      );
    }

    return Container(
      padding:
          const EdgeInsets.all(16),
      decoration:
          BoxDecoration(
        color:
            const Color(0xFF11141D),
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border:
            Border.all(
          color:
              Colors.white10,
        ),
      ),
      child: Column(
        children: [
          Icon(
            selectedCategory ==
                    'القرآن'
                ? Icons.menu_book_rounded
                : Icons.graphic_eq_rounded,
            color:
                const Color(
              0xFF63E6FF,
            ),
            size: 34,
          ),
          const SizedBox(
            height: 7,
          ),
          Text(
            selectedCategory ==
                    'القرآن'
                ? 'ابحث عن سورة أو قارئ'
                : 'اكتب اللي عايز تسمعه',
            textDirection:
                TextDirection.rtl,
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(
            height: 4,
          ),
          const Text(
            'النتائج الحقيقية المتاحة من مصادر الصوت المتصلة بالتطبيق.',
            textDirection:
                TextDirection.rtl,
            textAlign:
                TextAlign.center,
            style:
                TextStyle(
              color:
                  Colors.white54,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(
    AudioSearchItem item,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 8,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(0xFF151923),
        borderRadius:
            BorderRadius.circular(
          17,
        ),
        border:
            Border.all(
          color:
              const Color(0x2238D9FF),
        ),
      ),
      child: ListTile(
        onTap: () {
          _play(item);
        },
        leading:
            const _PlayCircle(),
        title: Text(
          item.title,
          textDirection:
              TextDirection.rtl,
          textAlign:
              TextAlign.right,
          maxLines: 2,
          overflow:
              TextOverflow.ellipsis,
          style:
              const TextStyle(
            fontWeight:
                FontWeight.w800,
            fontSize: 12,
          ),
        ),
        subtitle:
            item.artist == null
                ? null
                : Text(
                    item.artist!,
                    textDirection:
                        TextDirection.rtl,
                    textAlign:
                        TextAlign.right,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      color:
                          Colors.white54,
                      fontSize: 10,
                    ),
                  ),
        trailing:
            const Icon(
          Icons
              .chevron_left_rounded,
          color:
              Color(0xFFFFD76A),
        ),
      ),
    );
  }

  Widget _buildRadioContent() {
    if (radioLoading) {
      return const Padding(
        padding:
            EdgeInsets.all(25),
        child: Center(
          child:
              CircularProgressIndicator(
            color:
                Color(0xFFFFD76A),
          ),
        ),
      );
    }

    if (radioStations.isEmpty) {
      return Container(
        padding:
            const EdgeInsets.all(18),
        decoration:
            BoxDecoration(
          color:
              const Color(0xFF11141D),
          borderRadius:
              BorderRadius.circular(
            18,
          ),
          border:
              Border.all(
            color:
                Colors.white10,
          ),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.radio_rounded,
              color:
                  Color(0xFF63E6FF),
              size: 36,
            ),
            const SizedBox(
              height: 7,
            ),
            const Text(
              'محطات الراديو',
              textDirection:
                  TextDirection.rtl,
              style:
                  TextStyle(
                fontWeight:
                    FontWeight.w900,
              ),
            ),
            const SizedBox(
              height: 5,
            ),
            TextButton(
              onPressed: () {
                _loadRadioStations(
                  query: 'Egypt',
                );
              },
              child:
                  const Text(
                'إعادة تحميل',
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children:
          radioStations
              .map(
                _buildRadioStation,
              )
              .toList(),
    );
  }

  Widget _buildRadioStation(
    _RadioStation station,
  ) {
    final details = [
      station.country,
      station.language,
      station.codec,
    ]
        .where(
          (value) =>
              value.trim().isNotEmpty,
        )
        .join(' • ');

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 8,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(0xFF151923),
        borderRadius:
            BorderRadius.circular(
          17,
        ),
        border:
            Border.all(
          color:
              const Color(0x3338D9FF),
        ),
      ),
      child: ListTile(
        onTap: () {
          _playRadio(station);
        },
        leading:
            const _PlayCircle(
          icon:
              Icons.radio_rounded,
        ),
        title: Text(
          station.name,
          textDirection:
              TextDirection.rtl,
          textAlign:
              TextAlign.right,
          maxLines: 2,
          overflow:
              TextOverflow.ellipsis,
          style:
              const TextStyle(
            fontWeight:
                FontWeight.w800,
            fontSize: 12,
          ),
        ),
        subtitle:
            details.isEmpty
                ? const Text(
                    'بث مباشر',
                    textDirection:
                        TextDirection.rtl,
                    textAlign:
                        TextAlign.right,
                  )
                : Text(
                    details,
                    textDirection:
                        TextDirection.rtl,
                    textAlign:
                        TextAlign.right,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      color:
                          Colors.white54,
                      fontSize: 9,
                    ),
                  ),
        trailing:
            const Icon(
          Icons
              .play_circle_outline_rounded,
          color:
              Color(0xFFFFD76A),
        ),
      ),
    );
  }

  Widget _buildLocalFiles() {
    return Container(
      padding:
          const EdgeInsets.all(15),
      decoration:
          BoxDecoration(
        borderRadius:
            BorderRadius.circular(
          19,
        ),
        color:
            const Color(0xFF11141D),
        border:
            Border.all(
          color:
              const Color(0x3357D9FF),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.folder_rounded,
            color:
                Color(0xFF63E6FF),
            size: 32,
          ),
          const SizedBox(
            height: 6,
          ),
          const Text(
            'ملفات الصوت من الهاتف',
            textDirection:
                TextDirection.rtl,
            style:
                TextStyle(
              fontWeight:
                  FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(
            height: 4,
          ),
          const Text(
            'اختار MP3 أو أي ملف صوتي من جهازك.',
            textDirection:
                TextDirection.rtl,
            textAlign:
                TextAlign.center,
            style:
                TextStyle(
              color:
                  Colors.white54,
              fontSize: 10,
            ),
          ),
          const SizedBox(
            height: 9,
          ),
          FilledButton.icon(
            onPressed:
                _pickLocalAudio,
            icon:
                const Icon(
              Icons.audio_file_rounded,
            ),
            label:
                const Text(
              'اختيار ملف صوتي',
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayCircle
    extends StatelessWidget {
  final IconData icon;

  const _PlayCircle({
    this.icon =
        Icons.play_arrow_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 45,
      height: 45,
      decoration:
          const BoxDecoration(
        shape:
            BoxShape.circle,
        gradient:
            LinearGradient(
          colors: [
            Color(0xFFFFD76A),
            Color(0xFF7164FF),
          ],
        ),
      ),
      child:
          Icon(
        icon,
        color:
            Colors.black,
      ),
    );
  }
}

class _RadioStation {
  final String name;
  final String url;
  final String country;
  final String language;
  final String codec;

  const _RadioStation({
    required this.name,
    required this.url,
    required this.country,
    required this.language,
    required this.codec,
  });
}
