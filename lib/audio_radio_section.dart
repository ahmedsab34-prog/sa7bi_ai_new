
// ignore_for_file: invalid_use_of_protected_member

part of 'audio_center_screen.dart';

// ============================================================
// RADIO - SA7BI AI
// Searchable HTTPS radio stations with safe playback.
// ============================================================

extension _AudioRadioSection on _AudioCenterScreenState {
  Future<void> _loadRadio() async {
    try {
      final countries = await AiService.getRadioCountries()
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (countries.isEmpty) {
        setState(() {
          _countries = [];
          _country = null;
          _stations = [];
          _error = 'لم تصل قائمة الدول. تحقق من الاتصال وحاول التحديث.';
        });
        return;
      }

      var selected = countries.first;

      for (final country in countries) {
        final code = country.code.trim().toUpperCase();
        final name = country.name.toLowerCase();

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
        _stations = [];
        _error = '';
      });

      await _loadStations(selected);
    } on TimeoutException {
      if (!mounted) return;

      setState(() {
        _error = 'الاتصال بطيء؛ انتهت مهلة تحميل الدول. حاول مرة أخرى.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'تعذر تحميل الدول بسبب مشكلة في الاتصال أو الخادم.';
      });
    }
  }

  Future<void> _loadStations(RadioCountry country) async {
    try {
      final stations = await AiService.getRadioStations(country.code)
          .timeout(const Duration(seconds: 25));

      if (!mounted) return;

      final seen = <String>{};
      final cleanStations = <RadioStation>[];

      for (final station in stations) {
        final url = station.url.trim();

        if (!_isSecureRadioStream(url)) {
          continue;
        }

        final key = url.toLowerCase();

        if (seen.add(key)) {
          cleanStations.add(station);
        }
      }

      cleanStations.sort((a, b) {
        final aName = a.name.toLowerCase();
        final bName = b.name.toLowerCase();
        return aName.compareTo(bName);
      });

      setState(() {
        _stations = cleanStations;
        _error = cleanStations.isEmpty
            ? 'لم تصل محطات HTTPS صالحة لهذه الدولة. جرّب التحديث أو دولة أخرى.'
            : '';
      });
    } on TimeoutException {
      if (!mounted) return;

      setState(() {
        _stations = [];
        _error = 'تحميل المحطات استغرق وقتًا طويلًا بسبب بطء الاتصال.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _stations = [];
        _error = 'تعذر تحميل المحطات. تحقق من الإنترنت وحاول مرة أخرى.';
      });
    }
  }

  bool _isSecureRadioStream(String value) {
    final uri = Uri.tryParse(value.trim());

    return uri != null &&
        uri.scheme.toLowerCase() == 'https' &&
        uri.hasAuthority &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }

  Future<void> _changeCountry(RadioCountry? country) async {
    if (country == null || _loading) return;

    setState(() {
      _country = country;
      _stations = [];
      _loading = true;
      _error = '';
    });

    try {
      await _loadStations(country);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  List<RadioStation> _filteredRadioStations() {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return _stations;
    }

    return _stations.where((station) {
      final searchable = [
        station.name,
        station.tags,
        station.codec,
        station.homepage,
      ].join(' ').toLowerCase();

      return searchable.contains(query);
    }).toList();
  }

  Widget _radioSearchBox() {
    return TextField(
      controller: _searchController,
      onChanged: (_) {
        if (mounted) setState(() {});
      },
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
      ),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'ابحث عن محطة أو نوع المحتوى...',
        hintStyle: const TextStyle(
          color: Colors.white54,
          fontSize: 13,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: _AudioCenterScreenState._gold,
        ),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'مسح البحث',
                onPressed: () {
                  _searchController.clear();
                  if (mounted) setState(() {});
                },
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white70,
                ),
              ),
        filled: true,
        fillColor: _AudioCenterScreenState._card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // ============================================================
  // RADIO VIEW
  // ============================================================

  Widget _radioView() {
    final visibleStations = _filteredRadioStations();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 30),
      children: [
        Row(
          children: [
            Expanded(
              child: _sectionTitle('الراديو'),
            ),
            IconButton(
              tooltip: 'تحديث الراديو',
              onPressed: _loading
                  ? null
                  : () async {
                      setState(() {
                        _loading = true;
                        _error = '';
                      });

                      try {
                        await _loadRadio();
                      } finally {
                        if (mounted) {
                          setState(() {
                            _loading = false;
                          });
                        }
                      }
                    },
              icon: Icon(
                Icons.refresh_rounded,
                color: _AudioCenterScreenState._gold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_countries.isNotEmpty)
          DropdownButtonFormField<RadioCountry>(
            value: _countries.contains(_country) ? _country : null,
            isExpanded: true,
            dropdownColor: _AudioCenterScreenState._card,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              labelText: 'الدولة',
              labelStyle: const TextStyle(
                color: Colors.white70,
              ),
              filled: true,
              fillColor: _AudioCenterScreenState._card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            items: _countries.map((country) {
              return DropdownMenuItem<RadioCountry>(
                value: country,
                child: Text(
                  '${country.name} (${country.stationCount})',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: _loading ? null : _changeCountry,
          ),

        const SizedBox(height: 12),

        _radioSearchBox(),

        const SizedBox(height: 12),

        if (!_loading && _stations.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.radio_rounded,
                  color: _AudioCenterScreenState._gold,
                  size: 17,
                ),
                const SizedBox(width: 7),
                Text(
                  'المحطات: ${visibleStations.length} من ${_stations.length}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                const Text(
                  'روابط HTTPS فقط',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

        if (_loading && _stations.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),

        if (!_loading && _stations.isNotEmpty && visibleStations.isEmpty)
          _emptyText('لا توجد محطة تطابق كلمة البحث.'),

        ...visibleStations.map(_radioCard),

        if (!_loading && _stations.isEmpty)
          _emptyText(
            _error.isNotEmpty
                ? _error
                : 'لا توجد محطات متاحة حاليًا.',
          ),

        if (!_loading && _stations.isNotEmpty && _error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.orangeAccent,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // RADIO STATION CARD
  // ============================================================

  Widget _radioCard(RadioStation station) {
    final favicon = station.favicon.trim();
    final streamUrl = station.url.trim();
    final secure = _isSecureRadioStream(streamUrl);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _AudioCenterScreenState._card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 5,
        ),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: _AudioCenterScreenState._goldDark
                .withValues(alpha: 0.22),
          ),
          child: favicon.isEmpty
              ? Icon(
                  Icons.radio_rounded,
                  color: _AudioCenterScreenState._gold,
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    favicon,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.radio_rounded,
                      color: _AudioCenterScreenState._gold,
                    ),
                  ),
                ),
        ),
        title: Text(
          station.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            [
              if (station.codec.trim().isNotEmpty)
                station.codec.trim(),
              if (station.bitrate > 0)
                '${station.bitrate} kbps',
              if (station.tags.trim().isNotEmpty)
                station.tags.trim(),
            ].join(' • '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
            ),
          ),
        ),
        trailing: IconButton(
          tooltip: secure ? 'تشغيل المحطة' : 'رابط غير آمن',
          onPressed: !secure || _switchingAudio
              ? null
              : () {
                  final uri = Uri.tryParse(streamUrl);

                  if (uri == null ||
                      !_isSecureRadioStream(uri.toString())) {
                    _message(
                      'رابط المحطة غير آمن. اختر محطة HTTPS.',
                    );
                    return;
                  }

                  _playUrl(
                    uri.toString(),
                    station.name,
                    artist: 'راديو ${_country?.name ?? ''}'.trim(),
                    artwork: favicon.isEmpty ? null : favicon,
                  );
                },
          icon: Icon(
            secure
                ? Icons.play_circle_fill_rounded
                : Icons.block_rounded,
            color: secure
                ? _AudioCenterScreenState._gold
                : Colors.white24,
            size: 36,
          ),
        ),
      ),
    );
  }
}
