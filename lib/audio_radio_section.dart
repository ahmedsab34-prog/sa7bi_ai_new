part of 'audio_center_screen.dart';

// ============================================================
// RADIO
// ============================================================

extension _AudioRadioSection
    on _AudioCenterScreenState {
  Future<void> _loadRadio() async {
    final countries =
        await AiService
            .getRadioCountries();

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

    for (final country in countries) {
      final code =
          country.code.toUpperCase();
      final name =
          country.name.toLowerCase();

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

      final seen = <String>{};
      final cleanStations =
          <RadioStation>[];

      for (final station
          in stations) {
        final url =
            station.url.trim();

        if (url.isEmpty) {
          continue;
        }

        final key =
            url.toLowerCase();

        if (seen.add(key)) {
          cleanStations.add(
            station,
          );
        }
      }

      setState(() {
        _stations =
            cleanStations;
        _error =
            cleanStations.isEmpty
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
    if (country == null ||
        _loading) {
      return;
    }

    setState(() {
      _country = country;
      _stations = [];
      _loading = true;
      _error = '';
    });

    try {
      await _loadStations(
        country,
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ============================================================
  // RADIO VIEW
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
                  _loading
                      ? null
                      : _search,
              icon: const Icon(
                Icons
                    .refresh_rounded,
                color: _gold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_countries
            .isNotEmpty)
          DropdownButtonFormField<
              RadioCountry>(
            value: _country,
            dropdownColor:
                _card,
            style:
                const TextStyle(
              color: Colors.white,
            ),
            decoration:
                InputDecoration(
              labelText:
                  'الدولة',
              labelStyle:
                  const TextStyle(
                color:
                    Colors.white70,
              ),
              filled: true,
              fillColor: _card,
              border:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius
                        .circular(
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
          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(
              12,
            ),
            color:
                _goldDark.withValues(
              alpha: 0.22,
            ),
            image: favicon.isEmpty
                ? null
                : DecorationImage(
                    image:
                        NetworkImage(
                      favicon,
                    ),
                    fit:
                        BoxFit.cover,
                  ),
          ),
          child: favicon.isEmpty
              ? const Icon(
                  Icons
                      .radio_rounded,
                  color: _gold,
                )
              : null,
        ),
        title: Text(
          station.name,
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
            if (station.codec
                .trim()
                .isNotEmpty)
              station.codec.trim(),
            if (station.bitrate >
                0)
              '${station.bitrate} kbps',
            if (station.tags
                .trim()
                .isNotEmpty)
              station.tags.trim(),
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
}
