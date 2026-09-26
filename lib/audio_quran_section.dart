part of 'audio_center_screen.dart';

// ============================================================
// QURAN
// ============================================================

extension _AudioQuranSection
    on _AudioCenterScreenState {
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
        _reciter = null;
        _moshaf = null;
        _sura = null;
        _error =
            'تعذر تحميل قائمة القرآن حاليًا.';
      });
      return;
    }

    QuranReciter? selectedReciter;

    for (final reciter
        in data.reciters) {
      if (reciter.moshaf.isNotEmpty) {
        selectedReciter = reciter;
        break;
      }
    }

    selectedReciter ??=
        data.reciters.first;

    final moshaf =
        selectedReciter
                .moshaf
                .isNotEmpty
            ? selectedReciter
                .moshaf
                .first
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
    if (_switchingAudio) {
      return;
    }

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

    if (url == null ||
        url.isEmpty) {
      _message(
        'رابط الصوت غير متاح لهذه الرواية.',
      );
      return;
    }

    setState(() {
      _switchingAudio = true;
    });

    try {
      final handler =
          await AudioController
              .initialize();

      final first = MediaItem(
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
        final selectedIndex =
            catalog.suwar.indexWhere(
          (item) =>
              item.id == sura.id,
        );

        final start =
            selectedIndex < 0
                ? 0
                : selectedIndex + 1;

        final remaining =
            <MediaItem>[];

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

          if (nextUrl == null ||
              nextUrl.isEmpty) {
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
          try {
            await handler.addQueueItems(
              remaining,
            );
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
            label:
                const Text('تحديث'),
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
          text: (item) =>
              item.name,
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
          onPressed:
              _switchingAudio
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
            backgroundColor:
                _AudioCenterScreenState
                    ._goldDark,
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
                  BorderRadius.circular(
                15,
              ),
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
}
