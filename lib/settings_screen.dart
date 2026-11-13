import 'package:flutter/material.dart';

import 'ai_service.dart';
import 'owner_profile_screen.dart';
import 'reminder_settings_screen.dart';
import 'services/profile_service.dart';

/// صفحة إعدادات صاحبي AI.
/// تم ربط قسم الإشعارات مباشرة بخدمة التذكيرات الموجودة بالفعل.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ProfileService _profileService = ProfileService.instance;

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
      setState(() => _isConnected = _profileService.aiConnected);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isConnected = null);
    }
  }

  Future<void> _checkConnection() async {
    if (_isChecking) return;

    setState(() {
      _isChecking = true;
      _isConnected = null;
    });

    try {
      final connected = await AiService.checkConnection();
      await _profileService.saveAiConnection(connected);

      if (!mounted) return;

      setState(() {
        _isChecking = false;
        _isConnected = connected;
      });

      _showMessage(
        connected
            ? 'صاحبي AI متصل ويستجيب لاختبار الاتصال.'
            : 'تعذر الاتصال. راجع الإنترنت وحالة الخادم.',
      );
    } catch (_) {
      await _profileService.saveAiConnection(false);

      if (!mounted) return;

      setState(() {
        _isChecking = false;
        _isConnected = false;
      });

      _showMessage('حدث خطأ أثناء اختبار الاتصال.');
    }
  }

  void _openReminders() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const ReminderSettingsScreen(),
      ),
    );
  }

  void _showPrivacyInformation() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF151D2C),
        title: const Text(
          'الخصوصية والأمان',
          textDirection: TextDirection.rtl,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: const SingleChildScrollView(
          child: Text(
            'محادثات الذكاء الاصطناعي العادية تُحفظ محليًا '
            'داخل بيانات التطبيق.\n\n'
            'الفضفضة السرية توفر حماية للسجل المحفوظ على '
            'الجهاز باستخدام تشفير AES-256-GCM، مع حماية '
            'مفتاح التشفير بواسطة PIN. ويمكن تفعيل البصمة '
            'كوسيلة إضافية لفتح المحادثة.\n\n'
            'هذه الحماية تخص السجل المخزن محليًا على الجهاز، '
            'ولا تعني تشفيرًا طرفًا لطرف للرسائل المرسلة '
            'إلى خدمة الذكاء الاصطناعي.\n\n'
            'الرسائل الاجتماعية الخاصة ورسائل المجموعات '
            'تُحفظ على الخادم، وهي غير مشفرة طرفًا لطرف '
            'في الإصدار الحالي.\n\n'
            'لا تشارك كلمات المرور أو البيانات المالية أو '
            'المعلومات شديدة الحساسية داخل المحادثات.',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              color: Colors.white70,
              height: 1.55,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('فهمت'),
          ),
        ],
      ),
    );
  }

  void _openOwnerProfile() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/about-owner'),
        builder: (_) => const OwnerProfileScreen(),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF080C16),
        appBar: AppBar(
          title: const Text(
            'الإعدادات',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          backgroundColor: const Color(0xFF111827),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(14),
          children: [
            _buildAiConnectionCard(),
            const SizedBox(height: 12),
            _settingTile(
              icon: Icons.person_outline_rounded,
              title: 'الحساب',
              subtitle: 'إدارة الاسم والصورة والبيانات من صفحة حسابي',
              onTap: () => _showMessage(
                'افتح تبويب حسابي لإدارة بيانات الملف الشخصي.',
              ),
            ),
            _settingTile(
              icon: Icons.notifications_active_outlined,
              title: 'الإشعارات والتذكيرات',
              subtitle: 'إضافة المواعيد وتعديلها وإيقافها وحذفها',
              onTap: _openReminders,
            ),
            _settingTile(
              icon: Icons.security_outlined,
              title: 'الخصوصية والأمان',
              subtitle: 'تعرف على طريقة حفظ المحادثات وحدود الحماية الحالية',
              onTap: _showPrivacyInformation,
            ),
            _settingTile(
              icon: Icons.verified_user_outlined,
              title: 'عن صاحبي AI والمؤسس',
              subtitle: 'صاحب المشروع والنبذة والرؤية وحقوق النشر',
              onTap: _openOwnerProfile,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiConnectionCard() {
    final connected = _isConnected == true;
    final failed = _isConnected == false;

    final statusColor = connected
        ? const Color(0xFF61DDAA)
        : failed
            ? const Color(0xFFFF7777)
            : const Color(0xFFB7C5D8);

    final statusIcon = connected
        ? Icons.check_circle_rounded
        : failed
            ? Icons.error_outline_rounded
            : Icons.cloud_outlined;

    final statusText = connected
        ? 'الذكاء الاصطناعي متصل'
        : failed
            ? 'تعذر الاتصال بالخدمة'
            : 'لم يتم اختبار الاتصال بعد';

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFF182A40),
            Color(0xFF111827),
          ],
        ),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFF5DE1E6),
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'حالة صاحبي AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              Icon(statusIcon, color: statusColor),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'الاختبار يتحقق من اتصال الخدمة فقط، ولا ينفذ طلبًا مدفوعًا لإنشاء محتوى.',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _isChecking ? null : _checkConnection,
            icon: _isChecking
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
            label: Text(
              _isChecking
                  ? 'جاري الاختبار...'
                  : 'اختبار الاتصال الآن',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF5DE1E6),
              foregroundColor: const Color(0xFF07111E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 4,
        ),
        leading: Container(
          width: 39,
          height: 39,
          decoration: BoxDecoration(
            color: const Color(0xFF5DE1E6).withValues(alpha: .10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF5DE1E6),
            size: 21,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            height: 1.35,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_left_rounded,
          color: Colors.white54,
        ),
      ),
    );
  }
}
