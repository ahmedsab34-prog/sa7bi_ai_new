import 'package:flutter/material.dart';

import 'services/social_games_service.dart';
import 'services/social_guest_session_service.dart';
import 'social_games_hub_screen.dart';
import 'widgets/sa7bi_subpage_app_bar.dart';

/// شاشة استقبال دعوة لعبة، تستعيد جلسة المستخدم أو تنشئ حساب ضيف تلقائيًا.
class SocialGameInviteScreen extends StatefulWidget {
  const SocialGameInviteScreen({
    super.key,
    required this.inviteCode,
  });

  final String inviteCode;

  @override
  State<SocialGameInviteScreen> createState() =>
      _SocialGameInviteScreenState();
}

class _SocialGameInviteScreenState
    extends State<SocialGameInviteScreen> {
  final SocialGamesService _service = SocialGamesService.instance;

  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();

  bool _loading = true;
  bool _busy = false;
  bool _authenticated = false;
  bool _register = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prepareInvite();
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _prepareInvite() async {
    try {
      // Reuse the signed-in account when valid. Otherwise restore or create
      // a secure guest account so accepting an invite does not require signup.
      await SocialGuestSessionService.instance.ensureSession();
      await _service.initialize();
      await _service.getCurrentUser();

      if (!mounted) return;

      setState(() {
        _authenticated = true;
        _loading = false;
        _error = null;
      });

      await _joinRoom();
    } on SocialGamesException catch (error) {
      if (!mounted) return;

      setState(() {
        _authenticated = _service.isSignedIn;
        _loading = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _authenticated = _service.isSignedIn;
        _loading = false;
        _error =
            'تعذر تجهيز حساب الضيف أو قبول الدعوة. تحقق من الاتصال وحاول مرة أخرى.';
      });
    }
  }

  Future<void> _authenticateAndJoin() async {
    if (_busy) return;

    final username = _username.text.trim();
    final password = _password.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = 'اكتب اسم المستخدم وكلمة المرور.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (_register) {
        await _service.register(
          username: username,
          password: password,
        );
      } else {
        await _service.login(
          username: username,
          password: password,
        );
      }

      if (!mounted) return;

      setState(() => _authenticated = true);
      await _joinRoom(alreadyBusy: true);
    } on SocialGamesException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'تعذر تسجيل الدخول. تحقق من الإنترنت وحاول مرة أخرى.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _joinRoom({bool alreadyBusy = false}) async {
    if (_busy && !alreadyBusy) return;

    if (!alreadyBusy) {
      setState(() {
        _busy = true;
        _error = null;
      });
    }

    try {
      final room = await _service.joinRoom(
        inviteCode: widget.inviteCode,
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute<void>(
          builder: (_) => SocialGameRoomScreen(
            initialRoom: room,
          ),
        ),
      );
    } on SocialGamesException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          if (e.code == 'AUTH_REQUIRED' ||
              e.code == 'SESSION_EXPIRED') {
            _authenticated = false;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'تعذر الانضمام للمباراة. تحقق من الاتصال وحاول مرة أخرى.';
        });
      }
    } finally {
      if (!alreadyBusy && mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: const Sa7biSubpageAppBar(
          title: 'دعوة للعب',
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(17),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0x3372D7FF),
                        ),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.sports_esports_rounded,
                            color: Color(0xFF72D7FF),
                            size: 42,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'صاحبك بيدعوك لمباراة',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'هنجهز حساب ضيف آمن تلقائيًا ونفتح المباراة مباشرة. يمكنك استخدام حسابك الحالي أو تسجيل حساب يدويًا عند الحاجة.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF151D2C),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'رمز الدعوة',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          SelectableText(
                            widget.inviteCode,
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(
                              color: Color(0xFFFFD76A),
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A2028),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_authenticated) ...[
                      FilledButton.icon(
                        onPressed: _busy ? null : () => _joinRoom(),
                        icon: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.login_rounded),
                        label: Text(
                          _busy
                              ? 'جارٍ الانضمام...'
                              : 'الانضمام للمباراة',
                        ),
                      ),
                    ] else ...[
                      TextField(
                        controller: _username,
                        textDirection: TextDirection.ltr,
                        textCapitalization: TextCapitalization.none,
                        autofillHints: const [
                          AutofillHints.username,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'اسم المستخدم',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _password,
                        obscureText: true,
                        textDirection: TextDirection.ltr,
                        autofillHints: _register
                            ? const [AutofillHints.newPassword]
                            : const [AutofillHints.password],
                        decoration: const InputDecoration(
                          labelText: 'كلمة المرور',
                          prefixIcon: Icon(Icons.lock_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed:
                            _busy ? null : _authenticateAndJoin,
                        icon: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                _register
                                    ? Icons.person_add_alt_1_rounded
                                    : Icons.login_rounded,
                              ),
                        label: Text(
                          _busy
                              ? 'جارٍ تجهيز الحساب...'
                              : _register
                                  ? 'إنشاء حساب والانضمام'
                                  : 'تسجيل الدخول والانضمام',
                        ),
                      ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () {
                                setState(() {
                                  _register = !_register;
                                  _error = null;
                                });
                              },
                        child: Text(
                          _register
                              ? 'لديك حساب؟ سجّل الدخول'
                              : 'ليس لديك حساب؟ أنشئ حسابًا',
                        ),
                      ),
                      const Text(
                        'اسم المستخدم من 3 إلى 24 حرفًا، وكلمة المرور من 10 أحرف على الأقل.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
