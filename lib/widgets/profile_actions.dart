import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../audio_center_screen.dart';
import '../chat_screen.dart';
import '../config/service_keys.dart';
import '../khalasana_portal_screen.dart';
import '../monetization_config.dart';
import '../service_config.dart';
import '../service_detail_screen.dart';
import '../settings_screen.dart';

class ProfileActions extends StatelessWidget {
  final void Function(String message) onMessage;

  const ProfileActions({
    super.key,
    required this.onMessage,
  });

  // ============================================================
  // SHARE
  // ============================================================

  Future<void> _shareApp() async {
    try {
      await Share.share(
        'جرّب تطبيق صاحبي AI 🤖\n'
        'مساعدك الذكي في كل يوم.\n\n'
        'رابط التحميل:\n'
        '${MonetizationConfig.appDownloadUrl}',
        subject: 'صاحبي AI',
      );
    } catch (_) {
      onMessage('تعذر فتح المشاركة.');
    }
  }

  // ============================================================
  // GENERAL AI
  // ============================================================

  void _openGeneralAi(
    BuildContext context,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ChatScreen(
          serviceKey:
              ServiceKeys.general,
          serviceTitle:
              'صاحبي AI',
          serviceContext:
              'مساعد عام داخل تطبيق صاحبي AI. '
              'ساعد المستخدم في أي موضوع، ويمكنه الكتابة '
              'والصوت والصور والفيديو وإنشاء الصور.',
        ),
      ),
    );
  }

  // ============================================================
  // AUDIO
  // ============================================================

  void _openAudio(
    BuildContext context,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const AudioCenterScreen(),
      ),
    );
  }

  // ============================================================
  // KHALASANA
  // ============================================================

  void _openKhalasana(
    BuildContext context,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const KhalasanaPortalScreen(),
      ),
    );
  }

  // ============================================================
  // SETTINGS
  // ============================================================

  void _openSettings(
    BuildContext context,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const SettingsScreen(),
      ),
    );
  }

  // ============================================================
  // SERVICE
  // ============================================================

  void _openService(
    BuildContext context,
    Sa7biService service,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ServiceDetailScreen(
          service: service,
        ),
      ),
    );
  }

  // ============================================================
  // SERVICES SHEET
  // ============================================================

  void _showServices(
    BuildContext context,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor:
          const Color(0xFF0D111A),
      isScrollControlled: true,
      builder: (sheetContext) {
        final width =
            MediaQuery.sizeOf(
          sheetContext,
        ).width;

        return SafeArea(
          child: Directionality(
            textDirection:
                TextDirection.rtl,
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                12,
                14,
                12,
                12,
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    sa7biServices.map(
                  (service) {
                    return SizedBox(
                      width:
                          (width - 48) / 3,
                      child:
                          _ServiceMiniCard(
                        service:
                            service,
                        onTap: () {
                          Navigator.pop(
                            sheetContext,
                          );

                          _openService(
                            context,
                            service,
                          );
                        },
                      ),
                    );
                  },
                ).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final tools =
        <_ProfileTool>[
      _ProfileTool(
        icon:
            Icons.auto_awesome_rounded,
        title:
            'صاحبي AI',
        subtitle:
            'المحادثة',
        color:
            const Color(0xFFFFD76A),
        onTap: () =>
            _openGeneralAi(
          context,
        ),
      ),

      _ProfileTool(
        icon:
            Icons.image_rounded,
        title:
            'إنشاء صورة',
        subtitle:
            'توليد وتعديل',
        color:
            const Color(0xFFB45CFF),
        onTap: () =>
            _openGeneralAi(
          context,
        ),
      ),

      _ProfileTool(
        icon:
            Icons.camera_alt_rounded,
        title:
            'الكاميرا',
        subtitle:
            'تحليل الصور',
        color:
            const Color(0xFF63E6FF),
        onTap: () =>
            _openGeneralAi(
          context,
        ),
      ),

      _ProfileTool(
        icon:
            Icons.videocam_rounded,
        title:
            'الفيديو',
        subtitle:
            'تحليل فيديو',
        color:
            const Color(0xFFFF6B9A),
        onTap: () =>
            _openGeneralAi(
          context,
        ),
      ),

      _ProfileTool(
        icon:
            Icons.mic_rounded,
        title:
            'الصوت',
        subtitle:
            'تحدث',
        color:
            const Color(0xFF72E6A6),
        onTap: () =>
            _openGeneralAi(
          context,
        ),
      ),

      _ProfileTool(
        icon:
            Icons.graphic_eq_rounded,
        title:
            'مركز الصوت',
        subtitle:
            'قرآن وأذكار',
        color:
            const Color(0xFFE6C875),
        onTap: () =>
            _openAudio(
          context,
        ),
      ),

      _ProfileTool(
        icon:
            Icons.layers_rounded,
        title:
            'خلصانة AI',
        subtitle:
            'كل الأدوات',
        color:
            const Color(0xFF8EA8FF),
        onTap: () =>
            _openKhalasana(
          context,
        ),
      ),

      _ProfileTool(
        icon:
            Icons.apps_rounded,
        title:
            'الخدمات',
        subtitle:
            'كل الأقسام',
        color:
            const Color(0xFFFF9D5C),
        onTap: () =>
            _showServices(
          context,
        ),
      ),

      _ProfileTool(
        icon:
            Icons.share_rounded,
        title:
            'مشاركة',
        subtitle:
            'رابط التطبيق',
        color:
            const Color(0xFF70D7FF),
        onTap:
            _shareApp,
      ),

      _ProfileTool(
        icon:
            Icons.settings_rounded,
        title:
            'الإعدادات',
        subtitle:
            'التطبيق والحساب',
        color:
            const Color(0xFFBFC7D5),
        onTap: () =>
            _openSettings(
          context,
        ),
      ),
    ];

    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        10,
        8,
        10,
        8,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          const _ToolsTitle(),

          const SizedBox(
            height: 8,
          ),

          GridView.builder(
            shrinkWrap: true,
            physics:
                const NeverScrollableScrollPhysics(),
            itemCount:
                tools.length,
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 7,
              mainAxisSpacing: 7,
              mainAxisExtent: 76,
            ),
            itemBuilder:
                (
              context,
              index,
            ) {
              return _ToolCard(
                tool:
                    tools[index],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TITLE
// ============================================================

class _ToolsTitle
    extends StatelessWidget {
  const _ToolsTitle();

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      textDirection:
          TextDirection.rtl,
      children: const [
        Icon(
          Icons
              .dashboard_customize_rounded,
          color:
              Color(0xFFFFD76A),
          size: 18,
        ),
        SizedBox(
          width: 7,
        ),
        Text(
          'أدوات صاحبي AI',
          style: TextStyle(
            color:
                Colors.white,
            fontSize: 15,
            fontWeight:
                FontWeight.w900,
          ),
        ),
        Spacer(),
        Text(
          'كلها من صفحة واحدة',
          style: TextStyle(
            color:
                Colors.white38,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// PROFILE TOOL MODEL
// ============================================================

class _ProfileTool {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ProfileTool({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}

// ============================================================
// TOOL CARD
// ============================================================

class _ToolCard
    extends StatelessWidget {
  final _ProfileTool tool;

  const _ToolCard({
    required this.tool,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Material(
      color:
          Colors.transparent,
      child: InkWell(
        onTap:
            tool.onTap,
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        child: Ink(
          decoration:
              BoxDecoration(
            color:
                const Color(
              0xFF121722,
            ),
            borderRadius:
                BorderRadius.circular(
              14,
            ),
            border:
                Border.all(
              color:
                  tool.color
                      .withOpacity(
                0.24,
              ),
            ),
          ),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment
                    .center,
            children: [
              Icon(
                tool.icon,
                color:
                    tool.color,
                size: 23,
              ),

              const SizedBox(
                height: 5,
              ),

              Text(
                tool.title,
                maxLines: 1,
                overflow:
                    TextOverflow
                        .ellipsis,
                textDirection:
                    TextDirection
                        .rtl,
                style:
                    const TextStyle(
                  color:
                      Colors.white,
                  fontSize: 10,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              const SizedBox(
                height: 1,
              ),

              Text(
                tool.subtitle,
                maxLines: 1,
                overflow:
                    TextOverflow
                        .ellipsis,
                textDirection:
                    TextDirection
                        .rtl,
                style:
                    const TextStyle(
                  color:
                      Colors.white38,
                  fontSize: 7,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SERVICE MINI CARD
// ============================================================

class _ServiceMiniCard
    extends StatelessWidget {
  final Sa7biService service;
  final VoidCallback onTap;

  const _ServiceMiniCard({
    required this.service,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Material(
      color:
          Colors.transparent,
      child: InkWell(
        onTap:
            onTap,
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        child: Ink(
          height: 74,
          decoration:
              BoxDecoration(
            color:
                const Color(
              0xFF151A25,
            ),
            borderRadius:
                BorderRadius.circular(
              14,
            ),
            border:
                Border.all(
              color:
                  service.color
                      .withOpacity(
                0.24,
              ),
            ),
          ),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment
                    .center,
            children: [
              Icon(
                service.icon,
                color:
                    service.color,
                size: 23,
              ),

              const SizedBox(
                height: 5,
              ),

              Text(
                service.title,
                maxLines: 1,
                overflow:
                    TextOverflow
                        .ellipsis,
                textDirection:
                    TextDirection
                        .rtl,
                style:
                    const TextStyle(
                  color:
                      Colors.white,
                  fontSize: 10,
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
}
