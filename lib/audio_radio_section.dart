// ignore_for_file: invalid_use_of_protected_member

part of 'audio_center_screen.dart';

// ============================================================
// RADIO - SA7BI AI
// Unified radio directory, remote search, favorites and cache.
// ============================================================

extension _AudioRadioSection on _AudioCenterScreenState {
  // ----------------------------------------------------------
  // LOAD COUNTRIES AND INITIAL STATIONS
  // ----------------------------------------------------------

  Future<void> _loadRadio() async {
    try {
      final countries = await RadioDirectoryService.getCountries()
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (countries.isEmpty) {
        const fallbackCountry = RadioCountry(
          name: 'مصر',
          code: 'EG',
          stationCount: 0,
        );

        setState(() {
          _countries = [fallbackCountry];
          _country = fallbackCountry;
          _stations = [];
          _error = 'تعذر تحميل قائمة الدول. سنحاول تحميل محطات مصر.';
        });

        await _loadStations(
          fallbackCountry,
          query: _searchController.text.trim(),
        );
        return;
      }

      RadioCountry? selected;

      final previousCode =
          _country?.code.trim().toUpperCase() ?? '';

      // Keep the user's selected country after refresh.
      if (previousCode.isNotEmpty) {
        for (final country in countries) {
          if (country.code.trim().toUpperCase() == previousCode) {
            selected = country;
            break;
          }
        }
      }

      // Default to Egypt when no previous selection exists.
      selected ??= countries.firstWhere(
        (country) {
          final code = country.code.trim().toUpperCase();
          final name = country.name.toLowerCase();

          return code == 'EG' ||
              name.contains('egypt') ||
              name.contains('مصر');
        },
        orElse: () => countries.first,
      );

      final selectedCountry = selected ?? countries.first;

      setState(() {
        _countries = countries;
        _country = selectedCountry;
        _stations = [];
        _error = '';
      });

      await _loadStations(
        selectedCountry,
        query: _searchController.text.trim(),
      );
    } on TimeoutException {
      if (!mounted) return;

      setState(() {
        _error =
            'الاتصال بطيء؛ انتهت مهلة تحميل الدول. حاول مرة أخرى.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error =
            'تعذر تحميل الدول بسبب مشكلة في الاتصال أو الخادم.';
      });
    }
  }

  // ----------------------------------------------------------
  // LOAD STATIONS THROUGH THE UNIFIED DIRECTORY SERVICE
  // ----------------------------------------------------------

  Future<void> _loadStations(
    RadioCountry country, {
    String query = '',
  }) async {
    final cleanQuery = query.trim();

    try {
      final result = await RadioDirectoryService.loadStations(
        country.code,
        query: cleanQuery,
        limit: RadioDirectoryService.maximumStations,
      ).timeout(const Duration(seconds: 25));

      if (!mounted) return;

      setState(() {
        _stations = result.stations;

        if (result.fromCache) {
          _error =
              'الاتصال بدليل المحطات غير متاح الآن. '
              'نعرض آخر قائمة محفوظة على الجهاز، '
              'وقد لا تكون المحطات المحفوظة متاحة للبث حاليًا.';
        } else if (result.stations.isEmpty) {
          _error = cleanQuery.isEmpty
              ? 'لم تصل محطات HTTPS صالحة لهذه الدولة. '
                  'جرّب دولة أخرى أو أعد التحديث.'
              : 'لم يتم العثور على محطات تطابق البحث في هذه الدولة.';
        } else {
          _error = '';
        }
      });
    } on TimeoutException {
      if (!mounted) return;

      setState(() {
        _stations = [];
        _error = cleanQuery.isEmpty
            ? 'تحميل المحطات استغرق وقتًا طويلًا بسبب بطء الاتصال.'
            : 'انتهت مهلة البحث عن المحطات. حاول مرة أخرى.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _stations = [];
        _error = cleanQuery.isEmpty
            ? 'تعذر تحميل المحطات. تحقق من الإنترنت وحاول مرة أخرى.'
            : 'تعذر البحث في المحطات بسبب مشكلة في الاتصال.';
      });
    }
  }

  // ----------------------------------------------------------
  // COUNTRY CHANGE
  // ----------------------------------------------------------

  Future<void> _changeCountry(RadioCountry? country) async {
    if (country == null || _loading) return;

    setState(() {
      _country = country;
      _stations = [];
      _loading = true;
      _error = '';
    });

    try {
      await _loadStations(
        country,
        query: _searchController.text.trim(),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ----------------------------------------------------------
  // REMOTE SEARCH
  // ----------------------------------------------------------

  Future<void> _searchRadioStations() async {
    if (_loading) return;

    final country = _country;

    if (country == null) {
      _message('اختر دولة أولًا للبحث عن المحطات.');
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
      _stations = [];
    });

    try {
      await _loadStations(
        country,
        query: _searchController.text.trim(),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ----------------------------------------------------------
  // REFRESH
  // ----------------------------------------------------------

  Future<void> _refreshRadio() async {
    if (_loading) return;

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
  }

  // ----------------------------------------------------------
  // PLAY STATION
  // ----------------------------------------------------------

  Future<void> _playRadioStation(
    RadioStation station,
  ) async {
    if (_switchingAudio) return;

    RadioResolvedStream? resolved;

    setState(() {
      _switchingAudio = true;
    });

    try {
      // Register the station click and resolve its current HTTPS URL.
      // The service returns the original HTTPS URL if registration
      // or resolution fails, without pretending registration succeeded.
      resolved = await RadioDirectoryService.resolveStream(station);
    } on FormatException {
      _message('رابط المحطة غير آمن أو غير صالح.');
      return;
    } catch (_) {
      _message('تعذر تجهيز رابط المحطة للتشغيل.');
      return;
    } finally {
      if (mounted) {
        setState(() {
          _switchingAudio = false;
        });
      }
    }

    if (!mounted || resolved == null) return;

    final streamUrl = resolved.url.trim();

    if (streamUrl.isEmpty) {
      _message('لم يوفر المصدر رابط تشغيل صالحًا لهذه المحطة.');
      return;
    }

    // Use the app's existing central AudioController through _playUrl.
    // Do not create a second audio player.
    await _playUrl(
      streamUrl,
      station.name,
      artist: 'راديو ${_country?.name ?? ''}'.trim(),
      artwork: station.favicon.trim().isEmpty
          ? null
          : station.favicon.trim(),
    );

    if (!mounted) return;

    // If the stream was resolved through its original HTTPS URL,
    // do not claim that the provider click was registered.
    if (!resolved.registeredClick && _playing) {
      _message(
        'تم تشغيل الرابط المباشر، لكن تعذر تسجيل الاستماع '
        'لدى دليل المحطات.',
      );
    }
  }

  // ----------------------------------------------------------
  // RADIO VIEW
  // ----------------------------------------------------------

  Widget _radioView() {
    return _RadioDirectoryView(
      countries: _countries,
      selectedCountry: _country,
      stations: _stations,
      error: _error,
      searchController: _searchController,
      onCountryChanged: _changeCountry,
      onSearch: _searchRadioStations,
      onRefresh: _refreshRadio,
      onPlay: _playRadioStation,
      onMessage: _message,
    );
  }
}

// ============================================================
// RADIO DIRECTORY VIEW
// ============================================================

class _RadioDirectoryView extends StatefulWidget {
  final List<RadioCountry> countries;
  final RadioCountry? selectedCountry;
  final List<RadioStation> stations;
  final String error;
  final TextEditingController searchController;

  final Future<void> Function(RadioCountry?) onCountryChanged;
  final Future<void> Function() onSearch;
  final Future<void> Function() onRefresh;
  final Future<void> Function(RadioStation) onPlay;
  final ValueChanged<String> onMessage;

  const _RadioDirectoryView({
    required this.countries,
    required this.selectedCountry,
    required this.stations,
    required this.error,
    required this.searchController,
    required this.onCountryChanged,
    required this.onSearch,
    required this.onRefresh,
    required this.onPlay,
    required this.onMessage,
  });

  @override
  State<_RadioDirectoryView> createState() =>
      _RadioDirectoryViewState();
}

class _RadioDirectoryViewState
    extends State<_RadioDirectoryView> {
  List<RadioStation> _favorites = [];

  final Set<String> _busyFavoriteKeys = {};

  bool _showFavorites = false;
  bool _favoritesLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  // ----------------------------------------------------------
  // FAVORITES
  // ----------------------------------------------------------

  String _stationKey(RadioStation station) {
    final id = station.id.trim();

    if (id.isNotEmpty) {
      return 'id:$id';
    }

    return 'url:${station.url.trim().toLowerCase()}';
  }

  bool _isFavorite(RadioStation station) {
    return _favorites.any((favorite) {
      if (favorite.id.trim().isNotEmpty &&
          station.id.trim().isNotEmpty) {
        return favorite.id.trim() == station.id.trim();
      }

      return favorite.url.trim().toLowerCase() ==
          station.url.trim().toLowerCase();
    });
  }

  Future<void> _loadFavorites() async {
    try {
      final favorites =
          await RadioDirectoryService.getFavorites();

      if (!mounted) return;

      setState(() {
        _favorites = favorites;
        _favoritesLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _favorites = [];
        _favoritesLoading = false;
      });
    }
  }

  Future<void> _toggleFavorite(
    RadioStation station,
  ) async {
    final key = _stationKey(station);

    if (_busyFavoriteKeys.contains(key)) return;

    setState(() {
      _busyFavoriteKeys.add(key);
    });

    try {
      final saved =
          await RadioDirectoryService.toggleFavorite(station);

      if (!mounted) return;

      if (!saved) {
        widget.onMessage(
          'تعذر حفظ المفضلة على الجهاز. حاول مرة أخرى.',
        );
        return;
      }

      await _loadFavorites();

      if (!mounted) return;

      widget.onMessage(
        _isFavorite(station)
            ? 'تمت إضافة المحطة إلى المفضلة.'
            : 'تمت إزالة المحطة من المفضلة.',
      );
    } catch (_) {
      if (mounted) {
        widget.onMessage('حدث خطأ أثناء تحديث المفضلة.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _busyFavoriteKeys.remove(key);
        });
      }
    }
  }

  // ----------------------------------------------------------
  // FAVORITES FILTER
  // ----------------------------------------------------------

  List<RadioStation> _visibleStations() {
    if (!_showFavorites) {
      // Normal station search is performed by the Worker.
      // Do not silently turn a remote search into local-only filtering.
      return widget.stations;
    }

    final query =
        widget.searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return _favorites;
    }

    return _favorites.where((station) {
      final searchable = [
        station.name,
        station.tags,
        station.codec,
        station.homepage,
      ].join(' ').toLowerCase();

      return searchable.contains(query);
    }).toList();
  }

  // ----------------------------------------------------------
  // SEARCH BOX
  // ----------------------------------------------------------

  Widget _searchBox() {
    return TextField(
      controller: widget.searchController,
      textDirection: TextDirection.rtl,
      textInputAction: TextInputAction.search,
      onChanged: (_) {
        if (mounted) {
          setState(() {});
        }
      },
      onSubmitted: (_) {
        if (!_showFavorites) {
          widget.onSearch();
        }
      },
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: _showFavorites
            ? 'ابحث داخل المحطات المفضلة...'
            : 'ابحث عن محطة أو نوع المحتوى...',
        hintStyle: const TextStyle(
          color: Colors.white54,
          fontSize: 13,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: _AudioCenterScreenState._gold,
        ),
        suffixIcon: SizedBox(
          width: widget.searchController.text.isEmpty ? 48 : 96,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.searchController.text.isNotEmpty)
                IconButton(
                  tooltip: 'مسح البحث',
                  onPressed: () {
                    widget.searchController.clear();

                    if (mounted) {
                      setState(() {});
                    }

                    if (!_showFavorites) {
                      widget.onSearch();
                    }
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white70,
                  ),
                ),
              IconButton(
                tooltip: _showFavorites
                    ? 'البحث داخل المفضلة'
                    : 'بحث في دليل المحطات',
                onPressed: _showFavorites
                    ? null
                    : () {
                        widget.onSearch();
                      },
                icon: const Icon(
                  Icons.arrow_forward_rounded,
                  color: _AudioCenterScreenState._gold,
                ),
              ),
            ],
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

  // ----------------------------------------------------------
  // COUNTRY SELECTOR
  // ----------------------------------------------------------

  Widget _countrySelector() {
    if (_showFavorites || widget.countries.isEmpty) {
      return const SizedBox.shrink();
    }

    return DropdownButtonFormField<RadioCountry>(
      value: widget.countries.contains(widget.selectedCountry)
          ? widget.selectedCountry
          : null,
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
      items: widget.countries.map((country) {
        return DropdownMenuItem<RadioCountry>(
          value: country,
          child: Text(
            '${country.name} (${country.stationCount})',
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (country) {
        widget.onCountryChanged(country);
      },
    );
  }

  // ----------------------------------------------------------
  // STATION VALIDATION
  // ----------------------------------------------------------

  bool _isSecureRadioStream(String value) {
    final uri = Uri.tryParse(value.trim());

    return uri != null &&
        uri.scheme.toLowerCase() == 'https' &&
        uri.hasAuthority &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }

  bool _isSecureArtwork(String value) {
    final uri = Uri.tryParse(value.trim());

    return uri != null &&
        uri.scheme.toLowerCase() == 'https' &&
        uri.hasAuthority &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }

  // ----------------------------------------------------------
  // STATION CARD
  // ----------------------------------------------------------

  Widget _stationCard(RadioStation station) {
    final favicon = station.favicon.trim();
    final streamUrl = station.url.trim();

    final secure = _isSecureRadioStream(streamUrl);
    final favorite = _isFavorite(station);
    final favoriteKey = _stationKey(station);
    final favoriteBusy =
        _busyFavoriteKeys.contains(favoriteKey);

    final artworkIsSafe =
        favicon.isNotEmpty && _isSecureArtwork(favicon);

    final metadata = <String>[];

    if (station.codec.trim().isNotEmpty) {
      metadata.add(station.codec.trim());
    }

    if (station.bitrate > 0) {
      metadata.add('${station.bitrate} kbps');
    }

    if (station.tags.trim().isNotEmpty) {
      metadata.add(station.tags.trim());
    }

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
          horizontal: 10,
          vertical: 5,
        ),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: _AudioCenterScreenState._goldDark
                .withValues(alpha: 0.22),
          ),
          child: !artworkIsSafe
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
            metadata.isEmpty
                ? 'محطة إذاعية'
                : metadata.join(' • '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
            ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: favorite
                  ? 'إزالة من المفضلة'
                  : 'إضافة إلى المفضلة',
              onPressed: favoriteBusy
                  ? null
                  : () => _toggleFavorite(station),
              icon: Icon(
                favorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: favorite
                    ? Colors.redAccent
                    : Colors.white70,
                size: 21,
              ),
            ),
            IconButton(
              tooltip: secure
                  ? 'تشغيل المحطة'
                  : 'رابط المحطة غير آمن',
              onPressed: !secure
                  ? null
                  : () {
                      widget.onPlay(station);
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
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // EMPTY STATE
  // ----------------------------------------------------------

  Widget _emptyText(String message) {
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _AudioCenterScreenState._card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white70,
          height: 1.6,
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // BUILD
  // ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final visibleStations = _visibleStations();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 30),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _showFavorites ? 'محطاتي المفضلة' : 'الراديو',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            IconButton(
              tooltip: _showFavorites
                  ? 'عرض كل المحطات'
                  : 'عرض المحطات المفضلة',
              onPressed: () {
                setState(() {
                  _showFavorites = !_showFavorites;
                  widget.searchController.clear();
                });
              },
              icon: Icon(
                _showFavorites
                    ? Icons.radio_rounded
                    : Icons.favorite_rounded,
                color: _AudioCenterScreenState._gold,
              ),
            ),
            IconButton(
              tooltip: 'تحديث الراديو',
              onPressed: () {
                widget.onRefresh();
              },
              icon: Icon(
                Icons.refresh_rounded,
                color: _AudioCenterScreenState._gold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        _countrySelector(),

        if (!_showFavorites) const SizedBox(height: 12),

        _searchBox(),

        const SizedBox(height: 12),

        if (_showFavorites)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'المحطات المحفوظة: ${_favorites.length}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        else if (widget.stations.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.radio_rounded,
                  color: _AudioCenterScreenState._gold,
                  size: 17,
                ),
                const SizedBox(width: 7),
                Text(
                  'المحطات: ${visibleStations.length} من ${widget.stations.length}',
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

        if (_showFavorites && _favoritesLoading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          )
        else if (visibleStations.isEmpty)
          _emptyText(
            _showFavorites
                ? 'لا توجد محطات محفوظة في المفضلة حتى الآن.'
                : widget.error.isNotEmpty
                    ? widget.error
                    : 'لا توجد محطات متاحة حاليًا.',
          )
        else
          ...visibleStations.map(_stationCard),

        if (!_showFavorites &&
            widget.stations.isNotEmpty &&
            widget.error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              widget.error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.orangeAccent,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
      ],
    );
  }
}
