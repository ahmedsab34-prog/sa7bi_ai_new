import 'package:flutter/material.dart';

import '../profile_screen.dart';
import '../theme/sa7bi_theme.dart';
import 'app_header.dart';
import 'audio_center_with_header.dart';

/// الهيدر الموحد للصفحات الداخلية في صاحبي AI.
/// يجمع الهيدر الرئيسي والعنوان وزر الرجوع والإجراءات
/// مع دعم TabBar عند الحاجة.
class Sa7biSubpageAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const Sa7biSubpageAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const <Widget>[],
    this.bottom,
    this.showBackButton = true,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final PreferredSizeWidget? bottom;
  final bool showBackButton;

  static const double _toolbarHeight = 104;

  @override
  Size get preferredSize => Size.fromHeight(
        _toolbarHeight + (bottom?.preferredSize.height ?? 0),
      );

  void _openProfile(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (profileContext) => Scaffold(
          backgroundColor: Sa7biTheme.background,
          body: ProfileScreen(
            onProfileTap: () {},
            onAudio: () {
              Navigator.of(profileContext).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => AudioCenterWithHeader(
                    onProfileTap: () {},
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _openAudio(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AudioCenterWithHeader(
          onProfileTap: () => _openProfile(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      leading: const SizedBox.shrink(),
      leadingWidth: 0,
      toolbarHeight: _toolbarHeight,
      titleSpacing: 0,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Sa7biTheme.background,
      foregroundColor: Sa7biTheme.textPrimary,
      surfaceTintColor: Colors.transparent,
      iconTheme: const IconThemeData(
        color: Sa7biTheme.textPrimary,
        size: 21,
      ),
      title: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          8,
          2,
          8,
          2,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 54,
              child: AppHeader(
                onProfileTap: () => _openProfile(context),
                onAudioTap: () => _openAudio(context),
              ),
            ),
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  if (showBackButton)
                    SizedBox(
                      width: 40,
                      child: IconButton(
                        tooltip: 'رجوع',
                        onPressed: () {
                          Navigator.of(context).maybePop();
                        },
                        icon: const Icon(
                          Icons.arrow_forward_rounded,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 40),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: 5,
                        end: 5,
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
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (actions.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: actions,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottom: bottom,
    );
  }
}
