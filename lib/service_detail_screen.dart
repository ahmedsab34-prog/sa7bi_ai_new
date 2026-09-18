import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'chat_screen.dart';
import 'service_config.dart';

class ServiceDetailScreen extends StatefulWidget {
  final Sa7biService service;

  const ServiceDetailScreen({
    super.key,
    required this.service,
  });

  @override
  State<ServiceDetailScreen> createState() =>
      _ServiceDetailScreenState();
}

class _ServiceDetailScreenState
    extends State<ServiceDetailScreen> {
  final ImagePicker _picker = ImagePicker();

  bool _cameraBusy = false;
  bool _microphoneBusy = false;

  Future<void> _openAiChat() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          serviceTitle: widget.service.title,
          serviceContext: widget.service.aiRole,
        ),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    if (_cameraBusy) return;

    setState(() {
      _cameraBusy = true;
    });

    try {
      final permission = await Permission.camera.request();

      if (!permission.isGranted) {
        if (!mounted) return;

        _showMessage(
          'صلاحية الكاميرا غير مفعلة. '
          'اسمح للتطبيق باستخدام الكاميرا من إعدادات الهاتف.',
        );
        return;
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (!mounted) return;

      if (image != null) {
        _showMessage(
          'تم التقاط الصورة بنجاح ✅\n'
          'الصورة جاهزة للمرحلة القادمة من تحليل الصور بالذكاء الاصطناعي.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'حدث خطأ أثناء تشغيل الكاميرا.\n$e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _cameraBusy = false;
        });
      }
    }
  }

  Future<void> _pickVideo() async {
    if (_cameraBusy) return;

    setState(() {
      _cameraBusy = true;
    });

    try {
      final permission = await Permission.camera.request();

      if (!permission.isGranted) {
        if (!mounted) return;

        _showMessage(
          'صلاحية الكاميرا غير مفعلة. '
          'اسمح للتطبيق باستخدام الكاميرا من إعدادات الهاتف.',
        );
        return;
      }

      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 2),
      );

      if (!mounted) return;

      if (video != null) {
        _showMessage(
          'تم تسجيل الفيديو بنجاح ✅\n'
          'الفيديو جاهز للمرحلة القادمة من التحليل بالذكاء الاصطناعي.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'حدث خطأ أثناء تشغيل الفيديو.\n$e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _cameraBusy = false;
        });
      }
    }
  }

  Future<void> _testMicrophone() async {
    if (_microphoneBusy) return;

    setState(() {
      _microphoneBusy = true;
    });

    try {
      final permission =
          await Permission.microphone.request();

      if (!mounted) return;

      if (permission.isGranted) {
        _showMessage(
          'الميكروفون يعمل وصلاحيته مفعلة ✅',
        );
      } else {
        _showMessage(
          'صلاحية الميكروفون غير مفعلة. '
          'اسمح للتطبيق باستخدام الميكروفون من إعدادات الهاتف.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'حدث خطأ أثناء اختبار الميكروفون.\n$e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _microphoneBusy = false;
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
          duration: const Duration(seconds: 4),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;

    return Scaffold(
      backgroundColor: const Color(0xFF09090F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF11111A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          service.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              _buildServiceHeader(service),
              const SizedBox(height: 22),

              _buildAiButton(),
              const SizedBox(height: 18),

              _buildActionCard(
                icon: Icons.camera_alt_rounded,
                title: 'التقاط صورة',
                description:
                    'استخدم كاميرا الهاتف داخل هذا القسم.',
                onTap:
                    _cameraBusy ? null : _pickPhoto,
                isLoading: _cameraBusy,
              ),

              const SizedBox(height: 12),

              _buildActionCard(
                icon: Icons.videocam_rounded,
                title: 'تصوير فيديو',
                description:
                    'صوّر فيديو قصير لاستخدامه في المراحل القادمة.',
                onTap:
                    _cameraBusy ? null : _pickVideo,
                isLoading: _cameraBusy,
              ),

              const SizedBox(height: 12),

              _buildActionCard(
                icon: Icons.mic_rounded,
                title: 'اختبار الميكروفون',
                description:
                    'تأكد من أن التطبيق يستطيع الوصول إلى الميكروفون.',
                onTap: _microphoneBusy
                    ? null
                    : _testMicrophone,
                isLoading: _microphoneBusy,
              ),

              const SizedBox(height: 24),

              _buildInfoBox(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceHeader(Sa7biService service) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            service.color.withOpacity(0.30),
            const Color(0xFF171722),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        border: Border.all(
          color: service.color.withOpacity(0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: service.color.withOpacity(0.12),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: service.color.withOpacity(0.18),
              border: Border.all(
                color: service.color.withOpacity(0.5),
                width: 2,
              ),
            ),
            child: Icon(
              service.icon,
              color: service.color,
              size: 42,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            service.title,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            service.description,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiButton() {
    return SizedBox(
      width: double.infinity,
      height: 62,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFFD700),
              Color(0xFFFF8C00),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.20),
              blurRadius: 18,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: _openAiChat,
          icon: const Icon(
            Icons.auto_awesome,
            color: Colors.black,
          ),
          label: const Text(
            'تحدث مع صَحبي AI',
            style: TextStyle(
              color: Colors.black,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback? onTap,
    required bool isLoading,
  }) {
    return Material(
      color: const Color(0xFF15151F),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width
