import 'dart:async';

import 'package:flutter/material.dart';

import '../services/hero_face_runtime.dart';
import 'sa7bi_hero_3d.dart';

/// One lightweight, draggable 3D character button shared by every app page.
/// The original GLB is loaded once here; chat messages use GIF previews and
/// open a separate 3D dialog only when the user taps a 3D sticker.
class KhalasanaPortal extends StatefulWidget {
  const KhalasanaPortal({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  State<KhalasanaPortal> createState() => _KhalasanaPortalState();
}

class _KhalasanaPortalState extends State<KhalasanaPortal>
    with WidgetsBindingObserver {
  static const double _width = 76;
  static const double _height = 98;

  static const List<HeroExpression> _idleExpressions = <HeroExpression>[
    HeroExpression.smile,
    HeroExpression.wink,
    HeroExpression.blink,
    HeroExpression.surprise,
    HeroExpression.neutral,
  ];

  final HeroFaceRuntime _faceRuntime = HeroFaceRuntime.instance;

  Offset _dragOffset = Offset.zero;
  String _bodyAnimation = 'Hero_Idle';
  Timer? _bodyTimer;
  Timer? _bodyResetTimer;
  Timer? _faceTimer;
  Timer? _faceResetTimer;
  int _bodyIndex = 0;
  int _faceIndex = 0;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (_foreground) _startMotionTimers();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final nextForeground = state == AppLifecycleState.resumed;
    if (_foreground == nextForeground) return;

    _foreground = nextForeground;
    if (nextForeground) {
      _startMotionTimers();
    } else {
      _stopMotionTimers();
    }
  }

  void _startMotionTimers() {
    _stopMotionTimers();
    _bodyTimer = Timer.periodic(
      const Duration(seconds: 9),
      (_) => _playNextBodyAnimation(),
    );
    _faceTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _playNextIdleExpression(),
    );
  }

  void _stopMotionTimers() {
    _bodyTimer?.cancel();
    _bodyResetTimer?.cancel();
    _faceTimer?.cancel();
    _faceResetTimer?.cancel();
    _bodyTimer = null;
    _bodyResetTimer = null;
    _faceTimer = null;
    _faceResetTimer = null;
  }

  void _playNextBodyAnimation() {
    if (!mounted || !_foreground || _faceRuntime.liteStatus.value.isSpeaking) {
      return;
    }

    final animation = _bodyIndex.isEven ? 'Hero_Welcome' : 'Hero_Power';
    _bodyIndex++;
    setState(() => _bodyAnimation = animation);

    _bodyResetTimer?.cancel();
    _bodyResetTimer = Timer(const Duration(milliseconds: 2600), () {
      if (!mounted || !_foreground) return;
      setState(() => _bodyAnimation = 'Hero_Idle');
    });
  }

  void _playNextIdleExpression() {
    if (!mounted || !_foreground || _faceRuntime.liteStatus.value.isSpeaking) {
      return;
    }

    final expression = _idleExpressions[_faceIndex % _idleExpressions.length];
    _faceIndex++;
    _faceRuntime.playExpression(expression);

    _faceResetTimer?.cancel();
    _faceResetTimer = Timer(const Duration(milliseconds: 1450), () {
      if (!mounted || !_foreground || _faceRuntime.liteStatus.value.isSpeaking) {
        return;
      }
      _faceRuntime.playExpression(HeroExpression.neutral);
    });
  }

  void _move(DragUpdateDetails details, Size screen) {
    const edge = 5.0;
    setState(() {
      final next = _dragOffset + details.delta;
      _dragOffset = Offset(
        next.dx
            .clamp(-screen.width + _width + edge, screen.width - _width - edge)
            .toDouble(),
        next.dy
            .clamp(-screen.height + _height + edge, screen.height - _height - edge)
            .toDouble(),
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopMotionTimers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);

    return Transform.translate(
      offset: _dragOffset,
      child: Semantics(
        button: true,
        label: 'افتح خلصانة أو اسحب لتحريك الشخصية',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onPanUpdate: (details) => _move(details, screen),
          child: Tooltip(
            message: 'خلصانة',
            child: SizedBox(
              width: _width,
              height: _height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF081225).withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0x9972D7FF),
                    width: 1.2,
                  ),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x55000000),
                      blurRadius: 13,
                      offset: Offset(0, 5),
                    ),
                    BoxShadow(
                      color: Color(0x2272D7FF),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(19),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      IgnorePointer(
                        child: Sa7biHero3D(
                          animationName: _bodyAnimation,
                          cameraControls: false,
                          compact: true,
                          enableFaceAnimations: true,
                        ),
                      ),
                      Positioned(
                        left: 7,
                        right: 7,
                        bottom: 4,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD76A),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: const <BoxShadow>[
                              BoxShadow(
                                color: Color(0x99FFD76A),
                                blurRadius: 7,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
