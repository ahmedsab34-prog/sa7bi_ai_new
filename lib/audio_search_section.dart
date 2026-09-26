part of 'audio_center_screen.dart';

// ============================================================
// ADHKAR
// MUSIC
// PODCAST
// SEARCH
// ============================================================

extension _AudioSearchSection
    on _AudioCenterScreenState {
  Future<void> _loadAdhkar() async {
    final query =
        _searchController.text
            .trim();

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

    try {
      await AudioController.stop();
    } catch (_) {}

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
        _searchController.text
            .trim();

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
    final query =
        _searchController.text
            .trim();

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

      if (items.isEmpty) {
        _error =
            'لم يتم العثور على بودكاست متاح حاليًا.';
      }
    });
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
          await _loadStations(
            _country!,
          );
        }
        break;
    }
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
                  _loading
                      ? null
                      : _search,
              icon: Icon(
                Icons
                    .refresh_rounded,
                color:
                    _AudioCenterScreenState
                        ._gold,
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
    required List<AudioSearchItem>
        items,
    required Future<void>
        Function(AudioSearchItem)
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
                  _loading
                      ? null
                      : _search,
              icon: Icon(
                Icons
                    .refresh_rounded,
                color:
                    _AudioCenterScreenState
                        ._gold,
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
        color:
            _AudioCenterScreenState
                ._card,
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
          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(
              12,
            ),
            color:
                _AudioCenterScreenState
                    ._goldDark
                    .withValues(
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
                        fit:
                            BoxFit.cover,
                      ),
          ),
          child: item.artwork
                  .trim()
                  .isEmpty
              ? Icon(
                  Icons
                      .music_note_rounded,
                  color:
                      _AudioCenterScreenState
                          ._gold,
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
            if (item.artist !=
                    null &&
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
          style:
              const TextStyle(
            color: Colors.white60,
            fontSize: 11,
          ),
        ),
        trailing:
            IconButton(
          tooltip:
              hasUrl
                  ? 'تشغيل'
                  : 'قراءة',
          onPressed:
              _switchingAudio
                  ? null
                  : onPlay,
          icon: Icon(
            Icons
                .play_circle_fill_rounded,
            color:
                _AudioCenterScreenState
                    ._gold,
            size: 36,
          ),
        ),
      ),
    );
  }
}
