
import 'package:flutter/material.dart';

import 'services/social_games_service.dart';
import 'services/social_guest_session_service.dart';
import 'social_connect_hub_screen.dart';
import 'social_public_chat_screen.dart';

class ChatTabScreen extends StatefulWidget {
  const ChatTabScreen({super.key});

  @override
  State<ChatTabScreen> createState() => _ChatTabScreenState();
}

class _ChatTabScreenState extends State<ChatTabScreen> {
  bool _initializing = true;
  bool _openingPrivate = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await SocialGuestSessionService.instance.ensureSession();

      if (!mounted) return;

      setState(() {
        _initializing = false;
        _error = null;
      });
    } on SocialGamesException catch (error) {
      if (!mounted) return;

      setState(() {
        _initializing = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _initializing = false;
        _error =
            'تعذر تهيئة الاتصال حاليًا. تحقق من الإنترنت وحاول مرة أخرى.';
      });
    }
  }

  Future<void> _openPrivate() async {
    if (_openingPrivate) return;

    setState(() => _openingPrivate = true);

    try {
      await SocialGuestSessionService.instance.ensureSession();

      if (!mounted) return;

      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const SocialConnectHubScreen(),
        ),
      );
    } on SocialGamesException catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showMessage(
          'تعذر فتح المحادثات الخاصة. تحقق من الاتصال وحاول مرة أخرى.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _openingPrivate = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted || message.trim().isEmpty) return;

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
    if (_initializing) {
      return const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: Color(0xFF080B13),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 14),
                Text(
                  'جاري تجهيز الشات العام...',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFF080B13),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.wifi_off_rounded,
                    color: Color(0xFFFFA77B),
                    size: 42,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _initialize,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const SocialPublicChatScreen(),

          Positioned(
            top: MediaQuery.paddingOf(context).top + 62,
            right: 13,
            child: Material(
              color: const Color(0xFF172B45),
              elevation: 8,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                onTap: _openingPrivate ? null : _openPrivate,
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_openingPrivate)
                        const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      else
                        const Icon(
                          Icons.lock_outline_rounded,
                          color: Color(0xFF7FB4FF),
                          size: 17,
                        ),
                      const SizedBox(width: 6),
                      const Text(
                        'خاص',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
