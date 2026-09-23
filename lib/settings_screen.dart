import 'package:flutter/material.dart';

import 'ai_service.dart';
import 'services/profile_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
  });

  @override
  State<SettingsScreen> createState() =>
      _SettingsScreenState();
}

class _SettingsScreenState
    extends State<SettingsScreen> {
  final ProfileService _profileService =
      ProfileService.instance;

  bool _isChecking = false;
  bool? _isConnected;

  @override
  void initState() {
    super.initState();
    _loadSavedConnection();
  }

  Future<void> _loadSavedConnection() async {
    try {
      await _profileService.initialize();

      if (!mounted) return;

      setState(() {
        _isConnected =
            _profileService.aiConnected;
      });
    } catch (_) {
      // لو التخزين لم يُقرأ، نترك الحالة غير مختبرة.
    }
  }

  Future<void> _checkConnection() async {
    if (_isChecking) return;

    setState(() {
      _isChecking = true;
      _isConnected = null;
    });

    final connected =
        await AiService.checkConnection();

    // حفظ النتيجة بشكل دائم.
    await _profileService.saveAiConnection(
      connected,
    );

    if (!mounted) return;

    setState(() {
      _isChecking = false;
      _isConnected = connected;
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            connected
                ? 'صاحبي AI متصل ويعمل بشكل صحيح ✅'
                : 'تعذر التأكد من جاهزية الذكاء الاصطناعي. تأكد من الإنترنت وإعداد الخادم.',
            textDirection:
                TextDirection.rtl,
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFF080A10),
      appBar: AppBar(
        title: const Text(
          'الإعدادات',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        backgroundColor:
            const Color(0xFF11141D),
        foregroundColor:
            Colors.white,
        elevation: 0,
      ),
      body: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.all(16),
        children: [
          _buildAiConnectionCard(),

          const SizedBox(height: 12),

          _buildSettingTile(
            icon:
                Icons.person_outline_rounded,
            title: 'الحساب',
            subtitle:
                'إعدادات الملف الشخصي',
            onTap: () {
              _showMessage(
                'إعدادات الحساب موجودة في صفحة الملف الشخصي.',
              );
            },
          ),

          _buildSettingTile(
            icon:
                Icons.notifications_none_rounded,
            title: 'الإشعارات',
            subtitle:
                'إدارة التنبيهات والتذكيرات',
            onTap: () {
              _showMessage(
                'نظام الإشعارات والتذكيرات يعمل من صفحة الملف الشخصي.',
              );
            },
          ),

          _buildSettingTile(
            icon:
                Icons.security_outlined,
            title: 'الخصوصية والأمان',
            subtitle:
                'إعدادات الخصوصية وحماية البيانات',
            onTap: () {
              _showMessage(
                'إعدادات الخصوصية والأمان المتقدمة سيتم تطويرها لاحقًا.',
              );
            },
          ),

          _buildSettingTile(
            icon:
                Icons.info_outline_rounded,
            title: 'عن صاحبي AI',
            subtitle:
                'معلومات عن التطبيق',
            onTap: _showAboutDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildAiConnectionCard() {
    final bool connected =
        _isConnected == true;

    final bool failed =
        _isConnected == false;

    final Color statusColor =
        connected
            ? const Color(0xFF69F0AE)
            : failed
                ? const Color(0xFFFF6B6B)
                : Colors.white70;

    final IconData statusIcon =
        connected
            ? Icons.check_circle_rounded
            : failed
                ? Icons.error_outline_rounded
                : Icons.cloud_outlined;

    final String statusText =
        connected
            ? 'الذكاء الاصطناعي جاهز ومتصل'
            : failed
                ? 'تعذر الاتصال بخدمة الذكاء الاصطناعي'
                : 'لم يتم اختبار الاتصال بعد';

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(24),
        gradient:
            LinearGradient(
          begin:
              Alignment.topRight,
          end:
              Alignment.bottomLeft,
          colors: [
            const Color(0xFFFFD54F)
                .withOpacity(0.16),
            const Color(0xFF161923),
            const Color(0xFF10121A),
          ],
        ),
        border: Border.all(
          color:
              const Color(0x55FFD54F),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(0.25),
            blurRadius: 18,
            offset:
                const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration:
                    BoxDecoration(
                  shape:
                      BoxShape.circle,
                  gradient:
                      const LinearGradient(
                    colors: [
                      Color(0xFFFFD54F),
                      Color(0xFFFFA726),
                      Color(0xFFB45CFF),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          const Color(
                        0xFFFFD54F,
                      ).withOpacity(0.20),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.black,
                  size: 30,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'صاحبي AI',
                      textDirection:
                          TextDirection.rtl,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'الاتصال يتم من خلال خادم صاحبي الآمن',
                      textDirection:
                          TextDirection.rtl,
                      textAlign:
                          TextAlign.right,
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 11,
            ),
            decoration:
                BoxDecoration(
              color:
                  connected
                      ? const Color(0x2234C759)
                      : failed
                          ? const Color(0x22FF5252)
                          : const Color(0x221E88E5),
              borderRadius:
                  BorderRadius.circular(15),
              border:
                  Border.all(
                color:
                    connected
                        ? const Color(0x5534C759)
                        : failed
                            ? const Color(0x55FF5252)
                            : const Color(0x335E6B85),
              ),
            ),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Icon(
                  statusIcon,
                  color: statusColor,
                  size: 20,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    statusText,
                    textDirection:
                        TextDirection.rtl,
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            height: 50,
            child:
                ElevatedButton.icon(
              onPressed:
                  _isChecking
                      ? null
                      : _checkConnection,
              icon:
                  _isChecking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(
                          Icons.wifi_tethering_rounded,
                          color: Colors.black,
                        ),
              label: Text(
                _isChecking
                    ? 'جاري اختبار الاتصال...'
                    : 'اختبار اتصال الذكاء الاصطناعي',
                textDirection:
                    TextDirection.rtl,
                style:
                    const TextStyle(
                  color: Colors.black,
                  fontWeight:
                      FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFFFFD54F),
                disabledBackgroundColor:
                    const Color(0x99FFD54F),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(17),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 9,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(0xFF12151E),
        borderRadius:
            BorderRadius.circular(18),
        border:
            Border.all(
          color:
              const Color(0x333A4152),
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 3,
        ),
        onTap: onTap,
        leading: Container(
          width: 45,
          height: 45,
          decoration:
              const BoxDecoration(
            shape:
                BoxShape.circle,
            gradient:
                LinearGradient(
              colors: [
                Color(0xFFFFD54F),
                Color(0xFFB45CFF),
              ],
            ),
          ),
          child: Icon(
            icon,
            color: Colors.black,
            size: 23,
          ),
        ),
        title: Text(
          title,
          textDirection:
              TextDirection.rtl,
          style:
              const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight:
                FontWeight.w900,
          ),
        ),
        subtitle: Text(
          subtitle,
          textDirection:
              TextDirection.rtl,
          style:
              const TextStyle(
            color: Colors.white54,
            fontSize: 10,
          ),
        ),
        trailing:
            const Icon(
          Icons.chevron_left_rounded,
          color: Colors.white54,
        ),
      ),
    );
  }

  void _showMessage(
    String message,
  ) {
    if (!mounted) return;

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

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName:
          'صاحبي AI',
      applicationVersion:
          '1.0.0',
      applicationIcon:
          Container(
        width: 48,
        height: 48,
        decoration:
            const BoxDecoration(
          shape:
              BoxShape.circle,
          gradient:
              LinearGradient(
            colors: [
              Color(0xFFFFD54F),
              Color(0xFFB45CFF),
            ],
          ),
        ),
        child: const Icon(
          Icons.auto_awesome,
          color: Colors.black,
        ),
      ),
      children: const [
        Text(
          'صاحبي AI هو مساعد عربي ذكي يجمع مجموعة من الخدمات في تطبيق واحد.',
          textDirection:
              TextDirection.rtl,
        ),
      ],
    );
  }
}
