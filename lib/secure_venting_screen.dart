import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/venting_security_service.dart';

/// Keeps the private ChatScreen out of the widget tree until the local vault
/// has been unlocked and any legacy plaintext history has been migrated.
class SecureVentingScreen extends StatefulWidget {
  const SecureVentingScreen({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  SecureVentingScreenState createState() => SecureVentingScreenState();
}

class SecureVentingScreenState extends State<SecureVentingScreen>
    with WidgetsBindingObserver {
  final VentingSecurityService _security = VentingSecurityService.instance;
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();

  bool _loading = true;
  bool _configured = false;
  bool _unlocked = false;
  bool _biometricEnabled = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSecurityState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _security.lock();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Do not lock on 'inactive': Android may briefly enter that state while
    // showing its native biometric prompt. Background/hidden always locks.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      lock();
    }
  }

  Future<void> _loadSecurityState() async {
    try {
      final configured = await _security.hasPin();
      final biometricEnabled = configured
          ? await _security.isBiometricEnabled()
          : false;

      if (!mounted) return;
      setState(() {
        _configured = configured;
        _biometricEnabled = biometricEnabled;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر قراءة إعدادات حماية الفضفضة. لم نفتح المحادثة.';
      });
    }
  }

  /// Called by KhalasanaPortalScreen when the user switches away from venting.
  void lock() {
    _security.lock();
    _pinController.clear();
    _confirmPinController.clear();
    if (!mounted) return;
    setState(() {
      _unlocked = false;
      _error = null;
    });
  }

  Future<void> _submitPin() async {
    if (_busy) return;
    final pin = _pinController.text;

    if (!_configured && pin != _confirmPinController.text) {
      setState(() => _error = 'الرقمان السريان غير متطابقين.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (_configured) {
        await _security.unlockWithPin(pin);
      } else {
        await _security.setupPin(pin);
        _configured = true;
      }

      if (!mounted) {
        _security.lock();
        return;
      }

      _pinController.clear();
      _confirmPinController.clear();
      setState(() {
        _unlocked = true;
        _biometricEnabled = false;
      });
    } on VentingSecurityException catch (error) {
      // setupPin stores the wrapped key before migration. If migration fails,
      // re-read the configuration flag so the next attempt asks for that PIN
      // instead of incorrectly trying to create a second vault.
      try {
        _configured = await _security.hasPin();
        _biometricEnabled = _configured
            ? await _security.isBiometricEnabled()
            : false;
      } catch (_) {}
      if (mounted) {
        setState(() => _error = error.message);
      }
      _security.lock();
    } catch (_) {
      try {
        _configured = await _security.hasPin();
        _biometricEnabled = _configured
            ? await _security.isBiometricEnabled()
            : false;
      } catch (_) {}
      if (mounted) {
        setState(() => _error = 'تعذر فتح الفضفضة. لم نغيّر سجل الرسائل القديم.');
      }
      _security.lock();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unlockWithBiometrics() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await _security.unlockWithBiometrics();
      if (!mounted) {
        _security.lock();
        return;
      }
      setState(() => _unlocked = true);
    } on VentingSecurityException catch (error) {
      if (mounted) setState(() => _error = error.message);
      _security.lock();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذر التحقق بالبصمة. استخدم الرقم السري.');
      }
      _security.lock();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleBiometrics(bool enabled) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (enabled) {
        await _security.enableBiometrics();
      } else {
        await _security.disableBiometrics();
      }
      if (mounted) setState(() => _biometricEnabled = enabled);
    } on VentingSecurityException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر تحديث إعداد البصمة.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF080C16),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_unlocked && _security.isUnlocked) {
      return Column(
        children: [
          Material(
            color: const Color(0xFF101827),
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 38,
                child: Row(
                  children: [
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.lock_rounded,
                      color: Color(0xFF61DDBA),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'الفضفضة محمية على هذا الجهاز',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (!_biometricEnabled)
                      TextButton(
                        onPressed: _busy ? null : () => _toggleBiometrics(true),
                        child: const Text(
                          'تفعيل البصمة',
                          style: TextStyle(fontSize: 10),
                        ),
                      )
                    else
                      IconButton(
                        tooltip: 'إيقاف فتح الفضفضة بالبصمة',
                        visualDensity: VisualDensity.compact,
                        onPressed: _busy ? null : () => _toggleBiometrics(false),
                        icon: const Icon(
                          Icons.fingerprint_rounded,
                          color: Color(0xFF61DDBA),
                          size: 20,
                        ),
                      ),
                    IconButton(
                      tooltip: 'قفل الفضفضة الآن',
                      visualDensity: VisualDensity.compact,
                      onPressed: _busy ? null : lock,
                      icon: const Icon(
                        Icons.lock_outline_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: widget.child),
        ],
      );
    }

    // هذه الشاشة مضمّنة داخل KhalasanaPortalScreen؛ الهيدر والرجوع
    // يأتيان من الشاشة الأم حتى لا يظهر هيدر ثانٍ داخل خلّصانة.
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF080C16),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: const Color(0xFF9C27B0).withValues(alpha: .15),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFFB45CFF).withValues(alpha: .45),
                        ),
                      ),
                      child: const Icon(
                        Icons.lock_person_rounded,
                        color: Color(0xFFD18BFF),
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _configured ? 'افتح فضفضتك الخاصة' : 'أنشئ قفل الفضفضة',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      _configured
                          ? 'أدخل رقمك السري لفتح سجل محادثاتك المشفر.'
                          : 'اختر رقمًا سريًا من 6 أرقام. سيتم تشفير سجل الفضفضة الموجود على هذا الجهاز قبل عرضه.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white60,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.center,
                      obscureText: true,
                      maxLength: 6,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration: InputDecoration(
                        labelText: 'الرقم السري (6 أرقام)',
                        counterText: '',
                        filled: true,
                        fillColor: const Color(0xFF111827),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    if (!_configured) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: _confirmPinController,
                        keyboardType: TextInputType.number,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.center,
                        obscureText: true,
                        maxLength: 6,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: InputDecoration(
                          labelText: 'تأكيد الرقم السري',
                          counterText: '',
                          filled: true,
                          fillColor: const Color(0xFF111827),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFFF8E9E),
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _busy ? null : _submitPin,
                      icon: _busy
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _configured
                                  ? Icons.lock_open_rounded
                                  : Icons.shield_rounded,
                            ),
                      label: Text(
                        _busy
                            ? 'جارٍ تجهيز الحماية…'
                            : _configured
                                ? 'فتح الفضفضة'
                                : 'حفظ الرقم السري ونقل السجل المشفر',
                      ),
                    ),
                    if (_configured && _biometricEnabled) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _unlockWithBiometrics,
                        icon: const Icon(Icons.fingerprint_rounded),
                        label: const Text('فتح بالبصمة'),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Text(
                      'عند مغادرة التطبيق أو الانتقال من قسم الفضفضة سيتم قفلها. تعطل البصمة لا يلغي إمكانية الدخول بالرقم السري.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
