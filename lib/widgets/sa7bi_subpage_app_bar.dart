
import 'package:flutter/material.dart';

import '../profile_screen.dart';
import '../theme/sa7bi_theme.dart';
import 'app_header.dart';
import 'audio_center_with_header.dart';

/// شريط موحد للشاشات الفرعية، يحافظ على هوية التطبيق وأزرار الحساب والصوت.
class Sa7biSubpageAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const Sa7biSubpageAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const <Widget>[],
    this.bottom,
    this.bottomHeight = 48,
    this.showBackButton = true,
    this.onBack,
    this.onProfileTap,
    this.onAudioTap,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? bottom;
  final double bottomHeight;
  final bool showBackButton;
  final VoidCallback? onBack;
  final VoidCallback? onProfileTap;
  final VoidCallback? onAudioTap;

  static const double _toolbarHeight = 108;

  @override
  Size get preferredSize => Size.fromHeight(
        _toolbarHeight + (bottom == null ? 0 : bottomHeight),
      );

  void _openProfile(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (profileContext) => ProfileScreen(
          onProfileTap: () => Navigator.of(profileContext).maybePop(),
          onAudio: () => _openAudio(
            profileContext,
            profileAction: () {},
          ),
        ),
      ),
    );
  }

  void _openAudio(
    BuildContext context, {
    VoidCallback? profileAction,
  }) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AudioCenterWithHeader(
          onProfileTap: profileAction ?? () => _openProfile(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AppBar(
        toolbarHeight: _toolbarHeight,
        titleSpacing: 0,
        automaticallyImplyLeading: false,
        backgroundColor: Sa7biTheme.background,
        foregroundColor: Sa7biTheme.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 56,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    10,
                    0,
                    10,
                    0,
                  ),
                  child: AppHeader(
                    onProfileTap:
                        onProfileTap ?? () => _openProfile(context),
                    onAudioTap: onAudioTap ?? () => _openAudio(context),
                  ),
                ),
              ),
              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    if (showBackButton)
                      IconButton(
                        tooltip: 'رجوع',
                        onPressed: onBack ??
                            () => Navigator.of(context).maybePop(),
                        icon: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 18,
                          color: Sa7biTheme.cyan,
                        ),
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: 5,
                          end: 8,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Sa7biTheme.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (subtitle != null &&
                                subtitle!.trim().isNotEmpty)
                              Text(
                                subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Sa7biTheme.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    ...actions,
                    const SizedBox(width: 5),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottom: bottom == null
            ? null
            : PreferredSize(
                preferredSize: Size.fromHeight(bottomHeight),
                child: Material(
                  color: Sa7biTheme.surface,
                  child: SizedBox(
                    height: bottomHeight,
                    child: bottom!,
                  ),
                ),
              ),
      ),
    );
  }
}
