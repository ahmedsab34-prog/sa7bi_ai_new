// ignore_for_file: invalid_use_of_protected_member

part of 'audio_center_screen.dart';

// ============================================================
// QURAN
// ============================================================

extension _AudioQuranSection on _AudioCenterScreenState {
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

    final availableSuwar = moshaf == null
        ? data.suwar
        : _availableQuranSuwar(moshaf, data);

    setState(() {
      _quran = data;
      _reciter = selectedReciter;
      _moshaf = moshaf;
      _sura = availableSuwar.isNotEmpty
          ? availableSuwar.first
          : data.suwar.first;
      _error = '';
    });
  }

  // ============================================================
  // SUPPORTED SURAS FOR SELECTED MOSHAF
  // ============================================================

  List<QuranSura> _availableQuranSuwar(
    QuranMoshaf moshaf,
    QuranCatalog catalog,
  ) {
    final raw = moshaf.surahList.trim();

    if (raw.isEmpty) {
      return catalog.suwar;
    }

    final supportedIds = <int>{};

    final tokens = raw.split(
      RegExp(r'[,;|\s]+'),
    );

    for (final token in tokens) {
      if (token.isEmpty) {
        continue;
      }

      final directId = int.tryParse(token);

      if (directId != null &&
          directId >= 1 &&
          directId <= 114) {
        supportedIds.add(directId);
        continue;
      }

      final range = RegExp(
        r'^(\d+)-(\d+)$',
      ).firstMatch(token);

      if (range == null) {
        continue;
      }

      final first = int.tryParse(range.group(1) ?? '');
      final last = int.tryParse(range.group(2) ?? '');

      if (first == null || last == null) {
        continue;
      }

      final start = first < last ? first : last;
      final end = first > last ? first : last;

      for (var id = start; id <= end && id <= 114; id++) {
        if (id >= 1) {
          supportedIds.add(id);
        }
      }
    }

    if (supportedIds.isEmpty) {
      return catalog.suwar;
    }

    final filtered = catalog.suwar
        .where((sura) => supportedIds.contains(sura.id))
        .toList();

    return filtered.isEmpty ? catalog.suwar : filtered;
  }

  // ============================================================
  // QURAN URL
  // ============================================================

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

  // ============================================================
  // PLAY QURAN
  // ============================================================

  Future<void> _playQuran() async {
    if (_switchingAudio) {
      return;
    }

    final moshaf = _moshaf;
    final sura = _sura;
    final catalog = _quran;

    if (moshaf == null || sura == null || catalog == null) {
      _message(
        'اختار القارئ والرواية والسورة أولًا.',
      );
      return;
    }

    final availableSuwar = _availableQuranSuwar(
      moshaf,
      catalog,
    );

    final selectedIndex = availableSuwar.indexWhere(
      (item) => item.id == sura.id,
    );

    if (selectedIndex < 0) {
      _message(
        'السورة المختارة غير متاحة في الرواية الحالية.',
      );
      return;
    }

    final selectedUrl = _quranUrl(
      moshaf,
      sura,
    );

    if (selectedUrl == null || selectedUrl.isEmpty) {
      _message(
        'رابط الصوت غير متاح لهذه الرواية.',
      );
      return;
    }

    setState(() {
      _switchingAudio = true;
    });

    try {
      final queueItems = <MediaItem>[];

      // Build the complete queue before playback begins.
      // The selected sura is always the first item.
      for (
        var i = selectedIndex;
        i < availableSuwar.length;
        i++
      ) {
        final nextSura = availableSuwar[i];

        final nextUrl = _quranUrl(
          moshaf,
          nextSura,
        );

        if (nextUrl == null || nextUrl.isEmpty) {
          continue;
        }

        queueItems.add(
          MediaItem(
            id: nextUrl,
            title: nextSura.name,
            artist: _reciter?.name ?? 'القرآن الكريم',
            album: 'القرآن الكريم',
          ),
        );
      }

      if (queueItems.isEmpty ||
          queueItems.first.id != selectedUrl) {
        _message(
          'تعذر تجهيز رابط السورة المختارة.',
        );
        return;
      }

      await AudioController.replaceQueueAndPlay(
        queueItems,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _currentTitle =
            '${sura.name} - ${_reciter?.name ?? 'القرآن'}';
        _playing = true;
        _error = '';
      });
    } catch (error) {
      if (mounted) {
        _message(
          'تعذر تجهيز قائمة تشغيل القرآن. تحقق من الاتصال وحاول مرة أخرى.',
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

  // ============================================================
  // QURAN VIEW
  // ============================================================

  Widget _quranView() {
    final quran = _quran;

    if (quran == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
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

    final availableSuwar = _moshaf == null
        ? quran.suwar
        : _availableQuranSuwar(_moshaf!, quran);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        14,
        8,
        14,
        30,
      ),
      children: [
        _sectionTitle('القرآن الكريم'),
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

            final nextMoshaf = value.moshaf.isNotEmpty
                ? value.moshaf.first
                : null;

            final nextSuwar = nextMoshaf == null
                ? quran.suwar
                : _availableQuranSuwar(
                    nextMoshaf,
                    quran,
                  );

            setState(() {
              _reciter = value;
              _moshaf = nextMoshaf;
              _sura = nextSuwar.isNotEmpty
                  ? nextSuwar.first
                  : quran.suwar.first;
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
                item.name.isEmpty ? 'الرواية' : item.name,
            onChanged: (value) {
              if (value == null) {
                return;
              }

              final nextSuwar = _availableQuranSuwar(
                value,
                quran,
              );

              setState(() {
                _moshaf = value;

                if (!nextSuwar.any(
                  (item) => item.id == _sura?.id,
                )) {
                  _sura = nextSuwar.isNotEmpty
                      ? nextSuwar.first
                      : quran.suwar.first;
                }
              });
            },
          ),

        const SizedBox(height: 10),

        _dropdown<QuranSura>(
          value: availableSuwar.any(
            (item) => item.id == _sura?.id,
          )
              ? _sura
              : availableSuwar.isNotEmpty
                  ? availableSuwar.first
                  : null,
          items: availableSuwar,
          label: 'اختار السورة',
          text: (item) => '${item.id}. ${item.name}',
          onChanged: (value) {
            setState(() {
              _sura = value;
            });
          },
        ),

        const SizedBox(height: 16),

        ElevatedButton.icon(
          onPressed: _switchingAudio ? null : _playQuran,
          icon: _switchingAudio
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(
                  Icons.play_arrow_rounded,
                ),
          label: Text(
            _switchingAudio
                ? 'جاري تجهيز قائمة التشغيل...'
                : 'تشغيل السورة والمتابعة تلقائيًا',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                _AudioCenterScreenState._goldDark,
            foregroundColor: Colors.white,
            minimumSize: const Size(
              double.infinity,
              50,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        ),

        const SizedBox(height: 18),

        _infoCard(
          Icons.queue_music_rounded,
          'تشغيل متواصل',
          'يتم تجهيز السورة المختارة والسور التالية في قائمة واحدة قبل بدء التشغيل.',
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
