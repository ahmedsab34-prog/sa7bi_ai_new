import 'package:flutter/material.dart';

import '../services/rewarded_ad_service.dart';

/// زر الحصول على Credits من إعلان مكافأة.
///
/// ملاحظة:
/// الزر هنا مسؤول عن الواجهة والحالة فقط.
/// عرض إعلان AdMob الفعلي سيتم ربطه لاحقًا داخل
/// RewardedAdService بدون تغيير الواجهة.
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

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _rewarded.initialize();

    if (!mounted) {
      return;
    }

    setState(() {
      _remainingAds =
          _rewarded.remainingToday;
    });
  }

  Future<void> _handlePressed() async {
    if (_loading) {
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final started =
          await _rewarded.beginRewardedAd();

      if (!started) {
        if (mounted) {
          _showMessage(
            'الإعلان المكافأة غير متاح حاليًا أو وصلت للحد اليومي.',
          );
        }
        return;
      }

      // --------------------------------------------------------
      // هنا سيتم عرض Rewarded Ad الحقيقي.
      //
      // مهم جدًا:
      // لا نستدعي completeReward() هنا الآن تلقائيًا.
      //
      // عند ربط google_mobile_ads لاحقًا:
      // يتم استدعاء completeReward() فقط داخل callback
      // الذي يؤكد أن المستخدم حصل فعليًا على المكافأة.
      // --------------------------------------------------------

      await _rewarded.cancelRewardedAd();

      if (mounted) {
        _showMessage(
          'إعلان المكافأة سيتم تفعيله عند ربط شبكة الإعلانات.',
        );
      }
    } catch (_) {
      await _rewarded.cancelRewardedAd();

      if (mounted) {
        _showMessage(
          'حصل خطأ. حاول مرة أخرى.',
        );
      }
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

  Widget _buildCompact() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _loading ||
                _remainingAds <= 0
            ? null
            : _handlePressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 11,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFFFFD76A)
                .withOpacity(
              _remainingAds > 0
                  ? 0.12
                  : 0.04,
            ),
            border: Border.all(
              color: const Color(0xFFFFD76A)
                  .withOpacity(
                _remainingAds > 0
                    ? 0.35
                    : 0.10,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIcon(),
              const SizedBox(width: 8),
              Text(
                _loading
                    ? 'جارٍ التحضير...'
                    : '+${_rewarded.rewardCredits} Credits',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFull() {
    final enabled =
        _remainingAds > 0 && !_loading;

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
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFFFD76A)
                      .withOpacity(
                    enabled ? 0.16 : 0.05,
                  ),
                  const Color(0xFF7C4DFF)
                      .withOpacity(
                    enabled ? 0.10 : 0.03,
                  ),
                ],
              ),
              border: Border.all(
                color: const Color(0xFFFFD76A)
                    .withOpacity(
                  enabled ? 0.32 : 0.10,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(
                      0xFFFFD76A,
                    ).withOpacity(
                      enabled ? 0.13 : 0.04,
                    ),
                  ),
                  child: _buildIcon(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.label,
                        textDirection:
                            TextDirection.rtl,
                        style:
                            const TextStyle(
                          color: Colors.white,
                          fontWeight:
                              FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _loading
                            ? 'جارٍ التحضير...'
                            : 'مكافأة: +${_rewarded.rewardCredits} Credits • متبقي اليوم: $_remainingAds',
                        textDirection:
                            TextDirection.rtl,
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
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_left_rounded,
                  color: Color(0xFFFFD76A),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    if (_loading) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Color(0xFFFFD76A),
        ),
      );
    }

    return const Icon(
      Icons.play_circle_fill_rounded,
      color: Color(0xFFFFD76A),
      size: 25,
    );
  }
}
