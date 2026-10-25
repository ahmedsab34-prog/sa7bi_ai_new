
 // ignore_for_file: invalid_use_of_protected_member

part of 'audio_center_screen.dart';

// ============================================================
// RADIO
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
        final uri = Uri.tryParse(url);

        // لا نعرض رابطًا فارغًا أو رابطًا لا يحتوي على مضيف صالح.
        // نسمح بـ HTTP لأن بعض محطات الراديو لا توفر HTTPS.
        if (uri == null ||
            !uri.hasAuthority ||
            uri.host.isEmpty ||
            (uri.scheme != 'https' && uri.scheme != 'http')) {
          continue;
        }

        if (seen.add(uri.toString().toLowerCase())) {
          cleanStations.add(station);
        }
      }

      setState(() {
        _stations = cleanStations;
        _error = cleanStations.isEmpty
            ? 'لم نجد محطات بروابط صالحة لهذه الدولة. جرّب دولة أخرى أو حدّث القائمة.'
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

  // ============================================================
  // RADIO VIEW
  // ============================================================

  Widget _radioView() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 30),
      children: [
        Row(
          children: [
            Expanded(child: _sectionTitle('الراديو')),
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
            value: _country,
            dropdownColor: _AudioCenterScreenState._card,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'الدولة',
              labelStyle: const TextStyle(color: Colors.white70),
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
        if (_loading && _stations.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ..._stations.map(_radioCard),
        if (!_loading && _stations.isEmpty)
          _emptyText(
            _error.isNotEmpty
                ? _error
                : 'لا توجد محطات متاحة حاليًا.',
          ),
      ],
    );
  }

  Widget _radioCard(RadioStation station) {
    final favicon = station.favicon.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _AudioCenterScreenState._card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
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
        subtitle: Text(
          [
            if (station.codec.trim().isNotEmpty) station.codec.trim(),
            if (station.bitrate > 0) '${station.bitrate} kbps',
            if (station.tags.trim().isNotEmpty) station.tags.trim(),
          ].join(' • '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 11,
          ),
        ),
        trailing: IconButton(
          tooltip: 'تشغيل المحطة',
          onPressed: _switchingAudio
              ? null
              : () {
                  final uri = Uri.tryParse(station.url.trim());

                  if (uri == null ||
                      !uri.hasAuthority ||
                      uri.host.isEmpty ||
                      (uri.scheme != 'https' && uri.scheme != 'http')) {
                    _message('رابط المحطة غير صالح؛ اختر محطة أخرى.');
                    return;
                  }

                  _playUrl(
                    uri.toString(),
                    station.name,
                    artist: 'راديو ${_country?.name ?? ''}'.trim(),
                    artwork: station.favicon,
                  );
                },
          icon: Icon(
            Icons.play_circle_fill_rounded,
            color: _AudioCenterScreenState._gold,
            size: 36,
          ),
        ),
      ),
    );
  }
}
