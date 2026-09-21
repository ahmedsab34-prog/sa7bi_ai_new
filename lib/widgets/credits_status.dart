import 'package:flutter/material.dart';

import '../config/credits_config.dart';
import '../services/credits_service.dart';

/// ويدجت صغيرة لعرض رصيد المستخدم.
///
/// لا تحتوي على منطق الإعلان نفسه.
/// عند الضغط على زر المكافأة نستدعي onRewardPressed،
/// وسيتم ربطه لاحقًا بخدمة Rewarded Ads.
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
  State<CreditsStatus> createState() => _CreditsStatusState();
}

class _CreditsStatusState extends State<CreditsStatus> {
  final CreditsService _creditsService =
      CreditsService.instance;

  bool _loading = true;
  int _credits = 0;
  int _remainingRewardedAds = 0;

  @override
  void initState() {
    super.initState();
    _loadCredits();
  }

  Future<void> _loadCredits() async {
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
  }

  Future<void> refresh() async {
    await _loadCredits();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.compact) {
      return _buildCompact(theme);
    }

    return _buildFull(theme);
  }

  Widget _buildCompact(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFFD76A)
              .withOpacity(0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.bolt_rounded,
            size: 18,
            color: Color(0xFFFFD76A),
          ),
          const SizedBox(width: 6),
          if (_loading)
            const SizedBox(
              width: 32,
              height: 14,
              child: LinearProgressIndicator(
                minHeight: 2,
              ),
            )
          else
            Text(
              '$_credits',
              style: theme.textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          const SizedBox(width: 5),
          Text(
            'Credits',
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFull(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFD76A)
                .withOpacity(0.14),
            const Color(0xFF7C4DFF)
                .withOpacity(0.10),
            Colors.white.withOpacity(0.04),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFFFD76A)
              .withOpacity(0.30),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD76A)
                .withOpacity(0.08),
            blurRadius: 22,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFD76A)
                  .withOpacity(0.12),
              border: Border.all(
                color: const Color(0xFFFFD76A)
                    .withOpacity(0.35),
              ),
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: Color(0xFFFFD76A),
              size: 27,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'رصيدك',
                  style:
                      theme.textTheme.labelMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 2),
                if (_loading)
                  const SizedBox(
                    width: 70,
                    height: 18,
                    child: LinearProgressIndicator(
                      minHeight: 3,
                    ),
                  )
                else
                  Text(
                    '$_credits Credits',
                    style:
                        theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                if (!_loading &&
                    widget.showRewardButton)
                  Text(
                    'متاح $ _remainingRewardedAds إعلان مكافأة اليوم'
                        .replaceFirst(
                          r'$ ',
                          '',
                        ),
                    style:
                        theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white54,
                    ),
                  ),
              ],
            ),
          ),
          if (widget.showRewardButton)
            _buildRewardButton(theme),
        ],
      ),
    );
  }

  Widget _buildRewardButton(ThemeData theme) {
    final canReward =
        _remainingRewardedAds > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: canReward
            ? widget.onRewardPressed
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: canReward
                ? const Color(0xFFFFD76A)
                    .withOpacity(0.14)
                : Colors.white.withOpacity(0.04),
            border: Border.all(
              color: canReward
                  ? const Color(0xFFFFD76A)
                      .withOpacity(0.35)
                  : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.play_circle_fill_rounded,
                size: 22,
                color: canReward
                    ? const Color(0xFFFFD76A)
                    : Colors.white30,
              ),
              const SizedBox(height: 3),
              Text(
                canReward
                    ? '+${CreditsConfig.rewardedAdCredits}'
                    : 'خلص',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: canReward
                      ? Colors.white
                      : Colors.white30,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
