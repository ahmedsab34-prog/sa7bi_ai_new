import 'package:flutter/material.dart';

import '../config/credits_config.dart';
import '../services/credits_service.dart';
import '../services/rewarded_ad_service.dart';

/// زر إعلان المكافأة.
///
/// عند اكتمال مشاهدة الإعلان فعليًا:
/// - RewardedAdService يسجل المكافأة.
/// - CreditsService يزيد الرصيد.
/// - الواجهة تعيد قراءة الرصيد فورًا.
/// - يتم تجهيز إعلان جديد تلقائيًا.
class RewardedAdButton extends StatefulWidget {
  const RewardedAdButton({
    super.key,
    this.onRewarded,
    this.compact = false,
    this.label =
        'شاهد إعلان واحصل على Credits',
  });

  final VoidCallback? onRewarded;
  final bool compact;
  final String label;

  @override
  State<RewardedAdButton> createState() =>
      _RewardedAdButtonState();
}

class _RewardedAdButtonState
    extends State<RewardedAdButton>
    with WidgetsBindingObserver {
  final RewardedAdService _rewarded =
      RewardedAdService.instance;

  final CreditsService _credits =
      CreditsService.instance;

  bool _loading = false;
  bool _adReady = false;

  int _remainingAds = 0;
  int _creditsBalance = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance
        .addObserver(this);

    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance
        .removeObserver(this);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    if (state ==
        AppLifecycleState.resumed) {
      _refreshState();
    }
  }

  // ============================================================
  // INITIALIZATION
  // ============================================================

  Future<void> _initialize() async {
    try {
      await _rewarded.initialize();
      await _credits.initialize();
      await _credits.refresh();

      if (!mounted) {
        return;
      }

      await _refreshState(
        loadAd: true,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _adReady = false;
        _remainingAds =
            _credits.remainingRewardedAdsToday;
        _creditsBalance =
            _credits.credits;
      });
    }
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> _refreshState({
    bool loadAd = false,
  }) async {
    try {
      await _credits.refresh();

      bool ready = _adReady;

      if (loadAd || !_adReady) {
        ready =
            await _rewarded
                .preloadRewardedAd();
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _adReady = ready;

        _remainingAds =
            _credits.remainingRewardedAdsToday;

        _creditsBalance =
            _credits.credits;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _adReady = false;

        _remainingAds =
            _credits
                .remainingRewardedAdsToday;

        _creditsBalance =
            _credits.credits;
      });
    }
  }

  // ============================================================
  // WATCH AD
  // ============================================================

  Future<void> _handlePressed() async {
    if (_loading) {
      return;
    }

    await _credits.refresh();

    if (!mounted) {
      return;
    }

    final remaining =
        _credits.remainingRewardedAdsToday;

    if (remaining <= 0) {
      _showMessage(
        'وصلت للحد اليومي للإعلانات المكافِئة.',
      );

      await _refreshState();
      return;
    }

    if (!_adReady) {
      _showMessage(
        'الإعلان لسه بيجهز، حاول بعد لحظات.',
      );

      await _refreshState(
        loadAd: true,
      );

      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final result =
          await _rewarded
              .showRewardedAd();

      if (!mounted) {
        return;
      }

      if (result.success) {
        // قراءة الرصيد بعد تسجيل المكافأة.
        await _credits.refresh();

        if (!mounted) {
          return;
        }

        _showMessage(
          '+${result.rewardCredits} Credits 🎁',
        );

        widget.onRewarded?.call();
      } else {
        _showMessage(
          result.error ??
              'لم تكتمل مشاهدة الإعلان.',
        );
      }

      // تحديث الرصيد والحد اليومي.
      await _credits.refresh();

      if (!mounted) {
        return;
      }

      // تجهيز الإعلان التالي.
      final ready =
          await _rewarded
              .preloadRewardedAd();

      if (!mounted) {
        return;
      }

      setState(() {
        _adReady = ready;

        _remainingAds =
            _credits
                .remainingRewardedAdsToday;

        _creditsBalance =
            _credits.credits;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'حصل خطأ أثناء تشغيل الإعلان. حاول مرة أخرى.',
      );

      setState(() {
        _adReady = false;

        _remainingAds =
            _credits
                .remainingRewardedAdsToday;

        _creditsBalance =
            _credits.credits;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;

          _remainingAds =
              _credits
                  .remainingRewardedAdsToday;

          _creditsBalance =
              _credits.credits;
        });
      }
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textDirection:
                TextDirection.rtl,
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    if (widget.compact) {
      return _buildCompact();
    }

    return _buildFull();
  }

  // ============================================================
  // COMPACT
  // ============================================================

  Widget _buildCompact() {
    final enabled =
        !_loading &&
        _remainingAds > 0 &&
        _adReady;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled
            ? _handlePressed
            : null,
        borderRadius:
            BorderRadius.circular(16),
        child: Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 13,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(16),
            color:
                const Color(0xFFFFD76A)
                    .withOpacity(
              enabled ? 0.13 : 0.04,
            ),
            border: Border.all(
              color:
                  const Color(0xFFFFD76A)
                      .withOpacity(
                enabled ? 0.35 : 0.10,
              ),
            ),
          ),
          child: Row(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              _buildIcon(
                enabled: enabled,
              ),
              const SizedBox(width: 7),
              Text(
                _buttonText(),
                textDirection:
                    TextDirection.ltr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FULL
  // ============================================================

  Widget _buildFull() {
    final enabled =
        !_loading &&
        _remainingAds > 0 &&
        _adReady;

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled
              ? _handlePressed
              : null,
          borderRadius:
              BorderRadius.circular(20),
          child: Container(
            padding:
                const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(20),
              gradient:
                  LinearGradient(
                begin:
                    Alignment.topLeft,
                end:
                    Alignment.bottomRight,
                colors: [
                  const Color(
                    0xFFFFD76A,
                  ).withOpacity(
                    enabled
                        ? 0.16
                        : 0.05,
                  ),
                  const Color(
                    0xFF7C4DFF,
                  ).withOpacity(
                    enabled
                        ? 0.10
                        : 0.03,
                  ),
                ],
              ),
              border: Border.all(
                color:
                    const Color(
                  0xFFFFD76A,
                ).withOpacity(
                  enabled
                      ? 0.32
                      : 0.10,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration:
                      BoxDecoration(
                    shape:
                        BoxShape.circle,
                    color:
                        const Color(
                      0xFFFFD76A,
                    ).withOpacity(
                      enabled
                          ? 0.13
                          : 0.04,
                    ),
                  ),
                  child: _buildIcon(
                    enabled: enabled,
                  ),
                ),

                const SizedBox(
                  width: 12,
                ),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        widget.label,
                        textDirection:
                            TextDirection
                                .rtl,
                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                          fontWeight:
                              FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),

                      const SizedBox(
                        height: 4,
                      ),

                      Text(
                        _statusText(),
                        textDirection:
                            TextDirection
                                .rtl,
                        style:
                            const TextStyle(
                          color:
                              Colors.white60,
                          fontSize: 12,
                        ),
                      ),

                      if (!_loading)
                        Padding(
                          padding:
                              const EdgeInsets
                                  .only(
                            top: 3,
                          ),
                          child: Text(
                            'الرصيد الحالي: '
                            '$_creditsBalance',
                            textDirection:
                                TextDirection
                                    .rtl,
                            style:
                                const TextStyle(
                              color:
                                  Colors.white38,
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(
                  width: 8,
                ),

                const Icon(
                  Icons
                      .chevron_left_rounded,
                  color:
                      Color(0xFFFFD76A),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TEXT
  // ============================================================

  String _buttonText() {
    if (_loading) {
      return 'جارٍ تشغيل الإعلان...';
    }

    if (_remainingAds <= 0) {
      return 'انتهى الحد اليومي';
    }

    if (!_adReady) {
      return 'جارٍ تجهيز الإعلان...';
    }

    return '+${CreditsConfig.rewardedAdCredits} Credits';
  }

  String _statusText() {
    if (_loading) {
      return 'جارٍ تشغيل الإعلان...';
    }

    if (_remainingAds <= 0) {
      return 'وصلت للحد اليومي';
    }

    if (!_adReady) {
      return 'الإعلان غير جاهز حاليًا';
    }

    return 'مكافأة +${CreditsConfig.rewardedAdCredits} Credits'
        ' • متبقي $_remainingAds اليوم';
  }

  // ============================================================
  // ICON
  // ============================================================

  Widget _buildIcon({
    required bool enabled,
  }) {
    if (_loading) {
      return const SizedBox(
        width: 18,
        height: 18,
        child:
            CircularProgressIndicator(
          strokeWidth: 2,
          color:
              Color(0xFFFFD76A),
        ),
      );
    }

    return Icon(
      Icons.play_circle_fill_rounded,
      color: enabled
          ? const Color(
              0xFFFFD76A,
            )
          : Colors.white30,
      size: 25,
    );
  }
}
