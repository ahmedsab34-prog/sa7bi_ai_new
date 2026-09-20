import 'package:audio_service/audio_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

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

  List<AudioSearchItem> results = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final result =
          await AudioController.initialize();

      if (!mounted) return;

      setState(() {
        handler = result;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _search() async {
    final query =
        _searchController.text.trim();

    if (query.isEmpty) {
      return;
    }

    setState(() {
      searching = true;
      results = [];
    });

    final data =
        await AiService.searchAudio(query);

    if (!mounted) return;

    setState(() {
      results = data;
      searching = false;
    });
  }

  Future<void> _pickLocalAudio() async {
    final localHandler = handler;

    if (localHandler == null) {
      return;
    }

    try {
      final result =
          await FilePicker.pickFiles(
        type: FileType.audio,
        withData: true,
      );

      if (result == null ||
          result.files.isEmpty) {
        return;
      }

      final picked =
          result.files.first;

      /*
       * بعض أجهزة Android ترجع مسارًا مؤقتًا أو URI.
       * لذلك ننسخ الملف إلى cache الخاص بالتطبيق
       * قبل إعطائه للمشغل.
       */
      String? safePath = picked.path;

      if (picked.bytes != null &&
          picked.bytes!.isNotEmpty) {
        final directory =
            await getTemporaryDirectory();

        final file = File(
          '${directory.path}/sa7bi_audio_${DateTime.now().millisecondsSinceEpoch}_${picked.name}',
        );

        await file.writeAsBytes(
          picked.bytes!,
          flush: true,
        );

        safePath = file.path;
      }

      if (safePath == null ||
          safePath.trim().isEmpty) {
        throw Exception(
          'تعذر الوصول إلى ملف الصوت.',
        );
      }

      await localHandler.playLocalFile(
        path: safePath,
        title: picked.name,
        artist: 'من الهاتف',
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        .showSnackBar(
          SnackBar(
            content: Text(
              'تعذر تشغيل الملف: $e',
              textDirection:
                  TextDirection.rtl,
            ),
          ),
        );
    }
  }

  Future<void> _play(
    AudioSearchItem item,
  ) async {
    final localHandler = handler;

    if (localHandler == null) {
      return;
    }

    try {
      await localHandler.playUrl(
        url: item.url,
        title: item.title,
        artist:
            item.artist ?? 'صاحبي AI',
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        .showSnackBar(
          SnackBar(
            content: Text(
              'تعذر تشغيل الصوت: $e',
              textDirection:
                  TextDirection.rtl,
            ),
          ),
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
            fontWeight:
                FontWeight.w900,
          ),
        ),
      ),
      body: loading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : ListView(
              padding:
                  const EdgeInsets.fromLTRB(
                16,
                14,
                16,
                35,
              ),
              children: [
                _buildHero(),

                const SizedBox(
                  height: 16,
                ),

                _buildSearch(),

                const SizedBox(
                  height: 12,
                ),

                _buildQuickSearches(),

                const SizedBox(
                  height: 18,
                ),

                if (searching)
                  const Padding(
                    padding:
                        EdgeInsets.all(25),
                    child: Center(
                      child:
                          CircularProgressIndicator(),
                    ),
                  )
                else if (results.isNotEmpty)
                  ...results.map(
                    _buildResult,
                  ),

                const SizedBox(
                  height: 12,
                ),

                _buildLocalFiles(),

                const SizedBox(
                  height: 20,
                ),

                const Text(
                  'الصوت يفضل شغال أثناء التنقل داخل التطبيق، ويمكن التحكم فيه من إشعار الهاتف وشاشة القفل عند دعم النظام.',
                  textDirection:
                      TextDirection.rtl,
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    color:
                        Colors.white54,
                    height: 1.5,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding:
          const EdgeInsets.all(20),
      decoration:
          BoxDecoration(
        borderRadius:
            BorderRadius.circular(28),
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
      ),
      child: const Column(
        children: [
          Icon(
            Icons.graphic_eq_rounded,
            color:
                Color(0xFFFFD76A),
            size: 50,
          ),
          SizedBox(height: 8),
          Text(
            'ابحث عن اللي عايز تسمعه',
            textDirection:
                TextDirection.rtl,
            textAlign:
                TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'قرآن • أذكار • موسيقى • بودكاست • راديو',
            textDirection:
                TextDirection.rtl,
            textAlign:
                TextAlign.center,
            style: TextStyle(
              color:
                  Colors.white60,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return TextField(
      controller:
          _searchController,
      textDirection:
          TextDirection.rtl,
      style:
          const TextStyle(
        color: Colors.white,
      ),
      onSubmitted: (_) =>
          _search(),
      decoration:
          InputDecoration(
        hintText:
            'مثلاً: قرآن، ماهر المعيقلي، بودكاست، أغنية...',
        hintTextDirection:
            TextDirection.rtl,
        filled: true,
        fillColor:
            const Color(0xFF151923),
        prefixIcon:
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
              BorderRadius.circular(20),
          borderSide:
              BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildQuickSearches() {
    const items = [
      'القرآن',
      'الأذكار',
      'موسيقى',
      'بودكاست',
      'راديو',
    ];

    return Wrap(
      alignment:
          WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: items.map(
        (item) {
          return ActionChip(
            label: Text(
              item,
              textDirection:
                  TextDirection.rtl,
            ),
            onPressed: () {
              _searchController.text =
                  item;
              _search();
            },
          );
        },
      ).toList(),
    );
  }

  Widget _buildResult(
    AudioSearchItem item,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 9,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(0xFF121620),
        borderRadius:
            BorderRadius.circular(18),
        border:
            Border.all(
          color:
              Colors.white10,
        ),
      ),
      child: ListTile(
        onTap: () =>
            _play(item),
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 5,
        ),
        leading:
            const CircleAvatar(
          backgroundColor:
              Color(0x2238D9FF),
          child: Icon(
            Icons.play_arrow_rounded,
            color:
                Color(0xFFFFD76A),
          ),
        ),
        title: Text(
          item.title,
          textDirection:
              TextDirection.rtl,
          maxLines: 2,
          overflow:
              TextOverflow.ellipsis,
          style:
              const TextStyle(
            fontWeight:
                FontWeight.w800,
          ),
        ),
        subtitle: Text(
          item.artist ??
              item.type,
          textDirection:
              TextDirection.rtl,
          style:
              const TextStyle(
            color:
                Colors.white54,
          ),
        ),
        trailing:
            const Icon(
          Icons.play_circle_fill_rounded,
          color:
              Color(0xFFFFD76A),
        ),
      ),
    );
  }

  Widget _buildLocalFiles() {
    return OutlinedButton.icon(
      onPressed:
          _pickLocalAudio,
      icon:
          const Icon(
        Icons.folder_rounded,
      ),
      label:
          const Text(
        'تشغيل ملف صوت من الهاتف',
        textDirection:
            TextDirection.rtl,
      ),
      style:
          OutlinedButton.styleFrom(
        foregroundColor:
            Colors.white,
        side:
            const BorderSide(
          color:
              Color(0x55FFD76A),
        ),
        padding:
            const EdgeInsets.symmetric(
          vertical: 14,
        ),
      ),
    );
  }
}
