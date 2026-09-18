import 'package:flutter/material.dart';

import 'ai_service.dart';

class SettingsScreen extends StatefulWidget {
const SettingsScreen({super.key});

@override
State<SettingsScreen> createState() =>
_SettingsScreenState();
}

class _SettingsScreenState
extends State<SettingsScreen> {
bool _isChecking = false;
bool? _isConnected;

Future<void> _checkConnection() async {
if (_isChecking) return;

setState(() {
  _isChecking = true;
  _isConnected = null;
});

final connected =
    await AiService.checkConnection();

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
            : 'تعذر الاتصال بصاحبي AI. تأكد من الإنترنت وحاول مرة أخرى.',
        textDirection: TextDirection.rtl,
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );

}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: const Color(0xFF080A10),
appBar: AppBar(
title: const Text(
'الإعدادات',
style: TextStyle(
fontWeight: FontWeight.w900,
),
),
backgroundColor: const Color(0xFF11141D),
foregroundColor: Colors.white,
elevation: 0,
),
body: ListView(
padding: const EdgeInsets.all(18),
children: [
_buildAiConnectionCard(),
const SizedBox(height: 16),
_buildSettingTile(
icon: Icons.person_outline,
title: 'الحساب',
subtitle: 'إعدادات الملف الشخصي',
onTap: () {
_showMessage(
'إعدادات الحساب سيتم تطويرها في المرحلة القادمة.',
);
},
),
_buildSettingTile(
icon: Icons.notifications_none,
title: 'الإشعارات',
subtitle: 'إدارة التنبيهات والتذكيرات',
onTap: () {
_showMessage(
'نظام الإشعارات سيتم تفعيله في المرحلة القادمة.',
);
},
),
_buildSettingTile(
icon: Icons.security_outlined,
title: 'الخصوصية والأمان',
subtitle: 'إعدادات الخصوصية وحماية البيانات',
onTap: () {
_showMessage(
'إعدادات الخصوصية والأمان المتقدمة سيتم إضافتها لاحقًا.',
);
},
),
_buildSettingTile(
icon: Icons.info_outline,
title: 'عن صاحبي AI',
subtitle: 'معلومات عن التطبيق',
onTap: () {
_showAboutDialog();
},
),
],
),
);
}

Widget _buildAiConnectionCard() {
final bool connected = _isConnected == true;

return Container(
  width: double.infinity,
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(26),
    gradient: LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [
        const Color(0xFFFFD54F).withOpacity(0.18),
        const Color(0xFF161923),
        const Color(0xFF10121A),
      ],
    ),
    border: Border.all(
      color: const Color(0x55FFD54F),
    ),
    boxShadow: const [
      BoxShadow(
        color: Color(0x22000000),
        blurRadius: 18,
        offset: Offset(0, 8),
      ),
    ],
  ),
  child: Column(
    children: [
      Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFFD54F),
              Color(0xFFFFA726),
              Color(0xFFB45CFF),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD54F)
                  .withOpacity(0.25),
              blurRadius: 22,
              spreadRadius: 3,
            ),
          ],
        ),
        child: const Icon(
          Icons.auto_awesome,
          color: Colors.black,
          size: 38,
        ),
      ),
      const SizedBox(height: 15),
      const Text(
        'صاحبي AI',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'الذكاء الاصطناعي متصل من خلال الخادم الآمن.',
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white70,
          fontSize: 14,
          height: 1.5,
        ),
      ),
      const SizedBox(height: 16),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: connected
              ? const Color(0x2234C759)
              : const Color(0x221E88E5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: connected
                ? const Color(0x5534C759)
                : const Color(0x335E6B85),
          ),
        ),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              connected
                  ? Icons.check_circle
                  : Icons.cloud_outlined,
              color: connected
                  ? const Color(0xFF69F0AE)
                  : Colors.white70,
              size: 21,
            ),
            const SizedBox(width: 8),
            Text(
              connected
                  ? 'متصل ويعمل'
                  : 'حالة الاتصال غير مختبرة',
              style: TextStyle(
                color: connected
                    ? const Color(0xFF69F0AE)
                    : Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed:
              _isChecking ? null : _checkConnection,
          icon: _isChecking
              ? const SizedBox(
                  width: 19,
                  height: 19,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                )
              : const Icon(
                  Icons.wifi_tethering,
                  color: Colors.black,
                ),
          label: Text(
            _isChecking
                ? 'جاري اختبار الاتصال...'
                : 'اختبار اتصال الذكاء الاصطناعي',
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                const Color(0xFFFFD54F),
            disabledBackgroundColor:
                const Color(0x99FFD54F),
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(18),
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
margin: const EdgeInsets.only(bottom: 12),
decoration: BoxDecoration(
color: const Color(0xFF12151E),
borderRadius: BorderRadius.circular(22),
border: Border.all(
color: const Color(0x333A4152),
),
),
child: ListTile(
contentPadding: const EdgeInsets.symmetric(
horizontal: 18,
vertical: 6,
),
onTap: onTap,
leading: Container(
width: 52,
height: 52,
decoration: const BoxDecoration(
shape: BoxShape.circle,
gradient: LinearGradient(
colors: [
Color(0xFFFFD54F),
Color(0xFFB45CFF),
],
),
),
child: Icon(
icon,
color: Colors.black,
size: 27,
),
),
title: Text(
title,
style: const TextStyle(
color: Colors.white,
fontSize: 18,
fontWeight: FontWeight.w900,
),
),
subtitle: Text(
subtitle,
textDirection: TextDirection.rtl,
style: const TextStyle(
color: Colors.white54,
fontSize: 13,
),
),
trailing: const Icon(
Icons.chevron_left_rounded,
color: Colors.white54,
),
),
);
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

void _showAboutDialog() {
showAboutDialog(
context: context,
applicationName: 'صاحبي AI',
applicationVersion: '1.0.0',
applicationIcon: Container(
width: 48,
height: 48,
decoration: const BoxDecoration(
shape: BoxShape.circle,
gradient: LinearGradient(
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
textDirection: TextDirection.rtl,
),
],
);
}
}
