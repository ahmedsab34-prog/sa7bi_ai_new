import 'package:flutter/material.dart';

import '../services/rewarded_ad_service.dart';

/// زر مشاهدة إعلان Rewarded والحصول على Credits.
///
/// الإعلان الحقيقي يتم تشغيله من RewardedAdService.
/// الـCredits لا تضاف إلا إذا أكدت AdMob حصول المستخدم
/// على المكافأة فعلًا.
class RewardedAdButton extends StatefulWidget {
  const RewardedAdButton({
    super.key,
    this.onRewarded,
    this.compact = false,
    this.label = 'شاهد إعلان واحصل على Credits',
  });

  final VoidCallback? onRewarded;
  final bool compact;
  final String label;

  @override
  State<RewardedAdButton> createState() =>
      _RewardedAdButtonState();
}

class _RewardedAdButtonState
    extends State<RewardedAdButton> {
  final RewardedAdService _rewarded =
      RewardedAdService.instance;

  bool _loading = false;
  int _remainingAds = 0;
  bool _adReady = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _rewarded.initialize();

      if (!mounted) {
        return;
      }

      setState(() {
        _remainingAds =
            _rewarded.remainingToday;
      });

      // تجهيز الإعلان مسبقًا بدون عرضه.
      final ready =
          await _rewarded.preloadRewardedAd();

      if (!mounted) {
        return;
      }

      setState(() {
        _adReady = ready;
        _remainingAds =
            _rewarded.remainingToday;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _adReady = false;
        _remainingAds =
            _rewarded.remainingToday;
      });
    }
  }

  Future<void> _handlePressed() async {
    if (_loading) {
      return;
    }

    if (_remainingAds <= 0) {
      _showMessage(
        'وصلت للحد اليومي للإعلانات المكافِئة.',
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final result =
          await _rewarded.showRewardedAd();

      if (!mounted) {
        return;
      }

      if (result.success) {
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

      // تجهيز الإعلان التالي مسبقًا.
      final ready =
          await _rewarded.preloadRewardedAd();

      if (!mounted) {
        return;
      }

      setState(() {
        _adReady = ready;
        _remainingAds =
            _rewarded.remainingToday;
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
            _rewarded.remainingToday;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _remainingAds =
              _rewarded.remainingToday;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textDirection: TextDirection.rtl,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return _buildCompact();
    }

    return _buildFull();
  }

  // ============================================================
  // Compact
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
            horizontal: 14,
            vertical: 11,
          ),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(16),
            color:
                const Color(0xFFFFD76A)
                    .withOpacity(
              enabled ? 0.12 : 0.04,
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
              const SizedBox(width: 8),
              Text(
                _buttonText(),
                style:
                    const TextStyle(
                  color: Colors.white,
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
  // Full
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
            decoration:
                BoxDecoration(
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
                              FontWeight
                                  .w800,
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
  // Text
  // ============================================================

  String _buttonText() {
    if (_loading) {
      return 'جارٍ التحضير...';
    }

    if (_remainingAds <= 0) {
      return 'انتهى الحد اليومي';
    }

    if (!_adReady) {
      return 'جارٍ تجهيز الإعلان...';
    }

    return '+${_rewarded.rewardCredits} Credits';
  }

  String _statusText() {
    if (_loading) {
      return 'جارٍ تشغيل الإعلان...';
    }

    if (_remainingAds <= 0) {
      return 'وصلت للحد اليومي';
    }

    if (!_adReady) {
      return 'جارٍ تجهيز الإعلان';
    }

    return 'مكافأة: +${_rewarded.rewardCredits} Credits • متبقي اليوم: $_remainingAds';
  }

  // ============================================================
  // Icon
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
