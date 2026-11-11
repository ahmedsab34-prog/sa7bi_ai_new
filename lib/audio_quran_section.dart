
// ignore_for_file: invalid_use_of_protected_member

part of 'audio_center_screen.dart';

// ============================================================
// QURAN
// ============================================================

extension _AudioQuranSection on _AudioCenterScreenState {
  Future<void> _loadQuran() async {
    // نحفظ اختيارات المستخدم قبل تحديث الكتالوج.
    final previousReciterId = _reciter?.id;
    final previousMoshafId = _moshaf?.id;
    final previousSuraId = _sura?.id;

    try {
      final data = await AiService.getQuranCatalog()
          .timeout(const Duration(seconds: 25));

      if (!mounted) return;

      if (data == null || data.suwar.isEmpty) {
        setState(() {
          _quran = null;
          _reciter = null;
          _moshaf = null;
          _sura = null;
          _error = 'تعذر تحميل قائمة القرآن حاليًا. حاول التحديث.';
        });
        return;
      }

      final validReciters = data.reciters
          .where((reciter) => reciter.moshaf.isNotEmpty)
          .toList(growable: false);

      if (validReciters.isEmpty) {
        setState(() {
          _quran = null;
          _reciter = null;
          _moshaf = null;
          _sura = null;
          _error =
              'قائمة القراء وصلت، لكن لا توجد روايات صوتية متاحة حاليًا.';
        });
        return;
      }

      // استعادة القارئ السابق إن كان ما زال متاحًا.
      final selectedReciter = validReciters.firstWhere(
        (reciter) => reciter.id == previousReciterId,
        orElse: () => validReciters.first,
      );

      // استعادة الرواية السابقة لهذا القارئ.
      final selectedMoshaf = selectedReciter.moshaf.firstWhere(
        (moshaf) => moshaf.id == previousMoshafId,
        orElse: () => selectedReciter.moshaf.first,
      );

      final availableSuwar = _availableQuranSuwar(
        selectedMoshaf,
        data,
      );

      if (availableSuwar.isEmpty) {
        setState(() {
          _quran = null;
          _reciter = null;
          _moshaf = null;
          _sura = null;
          _error = 'لا توجد سور متاحة للرواية المختارة.';
        });
        return;
      }

      // الاحتفاظ بالسورة المختارة إن كانت مدعومة في الرواية الجديدة.
      final selectedSura = availableSuwar.firstWhere(
        (sura) => sura.id == previousSuraId,
        orElse: () => availableSuwar.first,
      );

      setState(() {
        _quran = data;
        _reciter = selectedReciter;
        _moshaf = selectedMoshaf;
        _sura = selectedSura;
        _error = '';
      });
    } on TimeoutException {
      if (!mounted) return;

      setState(() {
        _error =
            'الاتصال بطيء؛ انتهت مهلة تحميل قائمة القرآن. حاول مرة أخرى.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'تعذر تحميل القرآن بسبب مشكلة في الاتصال.';
      });
    }
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
      if (token.isEmpty) continue;

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

      if (range == null) continue;

      final first = int.tryParse(range.group(1) ?? '');
      final last = int.tryParse(range.group(2) ?? '');

      if (first == null || last == null) continue;

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
        .toList(growable: false);

    return filtered.isEmpty ? catalog.suwar : filtered;
  }

  // ============================================================
  // VALIDATE QURAN AUDIO URL
  // ============================================================

  String? _quranUrl(
    QuranMoshaf moshaf,
    QuranSura sura,
  ) {
    final server = moshaf.server.trim();

    if (server.isEmpty || sura.id < 1 || sura.id > 114) {
      return null;
    }

    final baseUri = Uri.tryParse(server);

    if (baseUri == null ||
        baseUri.scheme.toLowerCase() != 'https' ||
        !baseUri.hasAuthority ||
        baseUri.host.isEmpty ||
        baseUri.userInfo.isNotEmpty) {
      return null;
    }

    final basePath = baseUri.path.endsWith('/')
        ? baseUri.path
        : '${baseUri.path}/';

    final audioUri = baseUri.replace(
      path:
          '$basePath${sura.id.toString().padLeft(3, '0')}.mp3',
      query: null,
      fragment: null,
    );

    if (audioUri.scheme != 'https' ||
        audioUri.host.isEmpty) {
      return null;
    }

    return audioUri.toString();
  }

  // ============================================================
  // PLAY QURAN
  // ============================================================

  Future<void> _playQuran() async {
    if (_switchingAudio) return;

    final moshaf = _moshaf;
    final sura = _sura;
    final catalog = _quran;

    if (moshaf == null || sura == null || catalog == null) {
      _message('اختار القارئ والرواية والسورة أولًا.');
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
      _message('السورة المختارة غير متاحة في الرواية الحالية.');
      return;
    }

    final selectedUrl = _quranUrl(moshaf, sura);

    if (selectedUrl == null) {
      _message(
        'رابط السورة غير صالح أو لا يستخدم اتصال HTTPS آمنًا.',
      );
      return;
    }

    setState(() {
      _switchingAudio = true;
      _error = '';
    });

    try {
      final queueItems = <MediaItem>[];
      final addedUrls = <String>{};

      // السورة المختارة تكون أول عنصر دائمًا.
      // السور التالية تُضاف بالترتيب المتاح في الرواية.
      for (var i = selectedIndex; i < availableSuwar.length; i++) {
        final nextSura = availableSuwar[i];
        final nextUrl = _quranUrl(moshaf, nextSura);

        if (nextUrl == null || !addedUrls.add(nextUrl)) {
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
        _message('تعذر تجهيز قائمة السور المختارة.');
        return;
      }

      // يوقف أي TTS نشط في أي شاشة قبل بدء تلاوة القرآن.
      await _voice.stopSpeaking();

      await AudioController.replaceQueueAndPlay(queueItems);

      if (!mounted) return;

      setState(() {
        _currentTitle =
            '${sura.name} - ${_reciter?.name ?? 'القرآن الكريم'}';
        _playing = true;
        _error = '';
      });
    } catch (_) {
      if (mounted) {
        _playing = false;
        _message(
          'تعذر بدء تشغيل القرآن. قد يكون رابط الصوت غير متاح أو الاتصال ضعيفًا.',
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
            onPressed: _loading || _switchingAudio
                ? null
                : _loadQuran,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('تحديث قائمة القرآن'),
          ),
        ],
      );
    }

    final validReciters = quran.reciters
        .where((reciter) => reciter.moshaf.isNotEmpty)
        .toList(growable: false);

    if (validReciters.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _emptyText(
            'لا توجد روايات صوتية متاحة حاليًا لهذا المصدر.',
          ),
        ],
      );
    }

    final availableSuwar = _moshaf == null
        ? quran.suwar
        : _availableQuranSuwar(_moshaf!, quran);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 30),
      children: [
        _sectionTitle('القرآن الكريم'),
        const SizedBox(height: 12),

        _dropdown<QuranReciter>(
          value: validReciters.contains(_reciter)
              ? _reciter
              : validReciters.first,
          items: validReciters,
          label: 'اختار القارئ',
          text: (item) => item.name,
          onChanged: (value) {
            if (value == null) return;

            final nextMoshaf = value.moshaf.first;
            final nextSuwar = _availableQuranSuwar(
              nextMoshaf,
              quran,
            );

            if (nextSuwar.isEmpty) {
              _message('لا توجد سور متاحة للرواية المختارة.');
              return;
            }

            setState(() {
              _reciter = value;
              _moshaf = nextMoshaf;
              _sura = nextSuwar.first;
            });
          },
        ),

        const SizedBox(height: 10),

        if (_reciter != null)
          _dropdown<QuranMoshaf>(
            value: _reciter!.moshaf.contains(_moshaf)
                ? _moshaf
                : _reciter!.moshaf.first,
            items: _reciter!.moshaf,
            label: 'اختار الرواية',
            text: (item) =>
                item.name.isEmpty ? 'الرواية' : item.name,
            onChanged: (value) {
              if (value == null) return;

              final nextSuwar = _availableQuranSuwar(
                value,
                quran,
              );

              if (nextSuwar.isEmpty) {
                _message('لا توجد سور متاحة لهذه الرواية.');
                return;
              }

              setState(() {
                _moshaf = value;

                if (!nextSuwar.any(
                  (item) => item.id == _sura?.id,
                )) {
                  _sura = nextSuwar.first;
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
            if (value == null) return;
            setState(() => _sura = value);
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
              : const Icon(Icons.play_arrow_rounded),
          label: Text(
            _switchingAudio
                ? 'جاري تجهيز قائمة التشغيل...'
                : 'تشغيل السورة والمتابعة تلقائيًا',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _AudioCenterScreenState._goldDark,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
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

        const SizedBox(height: 10),

        _infoCard(
          Icons.security_rounded,
          'روابط آمنة',
          'يتم التحقق من رابط الصوت قبل إضافته إلى قائمة التشغيل.',
        ),
      ],
    );
  }
}
