import 'package:flutter/material.dart';

import '../config/credits_config.dart';
import '../services/credits_service.dart';

/// عرض رصيد الـCredits.
///
/// المسؤول عن:
/// - عرض الرصيد الحالي من السيرفر.
/// - عرض عدد إعلانات المكافأة المتبقية اليوم.
/// - توفير زر مكافأة اختياري عبر callback.
/// - تحديث الرصيد عند عودة التطبيق للواجهة.
///
/// مهم:
/// هذا الملف لا يمنح Credits بنفسه.
/// أي مكافأة فعلية تأتي من نظام AdMob SSV + Cloudflare Worker.
class CreditsStatus extends StatefulWidget {
  const CreditsStatus({
    super.key,
    this.compact = false,
    this.showRewardButton = true,
    this.onRewardPressed,
  });

  final bool compact;
  final bool showRewardButton;
  final VoidCallback? onRewardPressed;

  @override
  State<CreditsStatus> createState() =>
      _CreditsStatusState();
}

class _CreditsStatusState
    extends State<CreditsStatus>
    with WidgetsBindingObserver {
  final CreditsService _creditsService =
      CreditsService.instance;

  bool _loading = true;

  int _credits = 0;
  int _remainingRewardedAds = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _loadCredits();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    if (state == AppLifecycleState.resumed) {
      _loadCredits();
    }
  }

  /// قراءة أحدث بيانات الرصيد من السيرفر.
  Future<void> _loadCredits() async {
    try {
      await _creditsService.initialize();
      await _creditsService.refresh();

      if (!mounted) {
        return;
      }

      setState(() {
        _credits = _creditsService.credits;

        _remainingRewardedAds =
            _creditsService.remainingRewardedAdsToday;

        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
      });
    }
  }

  /// تحديث خارجي عند الحاجة.
  Future<void> refresh() async {
    await _loadCredits();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return _buildCompact();
    }

    return _buildFull();
  }

  // ============================================================
  // COMPACT
  // ============================================================

  Widget _buildCompact() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFD76A).withValues(
              alpha: 0.13,
            ),
            Colors.white.withValues(
              alpha: 0.055,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFFD76A).withValues(
            alpha: 0.32,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD76A).withValues(
              alpha: 0.07,
            ),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 27,
            height: 27,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFD76A).withValues(
                alpha: 0.14,
              ),
            ),
            child: const Icon(
              Icons.bolt_rounded,
              size: 17,
              color: Color(0xFFFFD76A),
            ),
          ),

          const SizedBox(width: 7),

          if (_loading)
            const SizedBox(
              width: 35,
              height: 15,
              child: LinearProgressIndicator(
                minHeight: 2,
              ),
            )
          else
            Text(
              '$_credits',
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),

          const SizedBox(width: 5),

          const Text(
            'Credits',
            textDirection: TextDirection.ltr,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FULL
  // ============================================================

  Widget _buildFull() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFD76A).withValues(
              alpha: 0.15,
            ),
            const Color(0xFF7C4DFF).withValues(
              alpha: 0.10,
            ),
            Colors.white.withValues(
              alpha: 0.04,
            ),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFFFD76A).withValues(
            alpha: 0.30,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD76A).withValues(
              alpha: 0.08,
            ),
            blurRadius: 22,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          // ======================================================
          // ICON
          // ======================================================

          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFD76A).withValues(
                alpha: 0.13,
              ),
              border: Border.all(
                color: const Color(0xFFFFD76A).withValues(
                  alpha: 0.35,
                ),
              ),
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: Color(0xFFFFD76A),
              size: 28,
            ),
          ),

          const SizedBox(width: 12),

          // ======================================================
          // BALANCE
          // ======================================================

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'رصيدك',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 3),

                if (_loading)
                  const SizedBox(
                    width: 80,
                    height: 20,
                    child: LinearProgressIndicator(
                      minHeight: 3,
                    ),
                  )
                else
                  Text(
                    '$_credits Credits',
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                const SizedBox(height: 4),

                if (!_loading)
                  Text(
                    'إعلانات المكافأة المتبقية اليوم: '
                    '$_remainingRewardedAds',
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),

          // ======================================================
          // REWARD BUTTON
          // ======================================================

          if (widget.showRewardButton)
            _buildRewardButton(),
        ],
      ),
    );
  }

  // ============================================================
  // REWARD BUTTON
  // ============================================================

  Widget _buildRewardButton() {
    final canReward =
        _remainingRewardedAds > 0 &&
        !_loading &&
        widget.onRewardPressed != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canReward
            ? widget.onRewardPressed
            : null,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: canReward
                ? const Color(0xFFFFD76A).withValues(
                    alpha: 0.14,
                  )
                : Colors.white.withValues(
                    alpha: 0.04,
                  ),
            border: Border.all(
              color: canReward
                  ? const Color(0xFFFFD76A).withValues(
                      alpha: 0.35,
                    )
                  : Colors.white.withValues(
                      alpha: 0.08,
                    ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.play_circle_fill_rounded,
                size: 23,
                color: canReward
                    ? const Color(0xFFFFD76A)
                    : Colors.white30,
              ),

              const SizedBox(height: 3),

              Text(
                canReward
                    ? '+${CreditsConfig.rewardedAdCredits}'
                    : 'خلص',
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  color: canReward
                      ? Colors.white
                      : Colors.white30,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
