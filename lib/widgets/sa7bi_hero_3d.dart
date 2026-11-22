
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/hero_face_runtime.dart';

/// يعرض مجسم HERO المحلي وحركات الجسم الموجودة داخل ملف GLB.
class Sa7biHero3D extends StatefulWidget {
  const Sa7biHero3D({
    super.key,
    this.animationName = 'Hero_Idle',
    this.cameraControls = true,
    this.compact = false,
    this.enableFaceAnimations = true,
  });

  /// تعطيل WebView في اختبار التنقل فقط.
  ///
  /// القيمة الافتراضية false، وبالتالي لا يتغير تشغيل HERO في التطبيق.
  @visibleForTesting
  static bool debugDisableWebViewForTests = false;

  final String animationName;
  final bool cameraControls;
  final bool compact;
  final bool enableFaceAnimations;

  @override
  State<Sa7biHero3D> createState() => _Sa7biHero3DState();
}

class _Sa7biHero3DState extends State<Sa7biHero3D> {
  static const String _viewerId = 'sa7bi-hero-model';
  static const String _channelName = 'Sa7biHeroBridge';

  static const String _bridgeScript = r'''
(() => {
  const viewerId = 'sa7bi-hero-model';
  const channelName = 'Sa7biHeroBridge';

  const post = (payload) => {
    try {
      const channel = window[channelName];
      if (channel && typeof channel.postMessage === 'function') {
        channel.postMessage(JSON.stringify(payload));
      }
    } catch (_) {}
  };

  const install = () => {
    const viewer = document.getElementById(viewerId);
    if (!viewer) {
      window.setTimeout(install, 80);
      return;
    }

    let activeExpression = null;
    let activeViseme = null;
    const reportedMissing = new Set();

    const bridge = {
      animations: [],

      setBodyAnimation(name) {
        if (
          !viewer.loaded ||
          !Array.isArray(viewer.availableAnimations) ||
          !viewer.availableAnimations.includes(name)
        ) {
          post({type: 'missing', animation: name});
          return false;
        }

        viewer.animationName = name;
        viewer.play();
        return true;
      },

      apply(command) {
        if (!viewer.loaded || !command) return false;

        if (command.type === 'reset') {
          if (activeExpression) {
            viewer.detachAnimation(activeExpression, {fade: 0.08});
          }
          if (activeViseme) {
            viewer.detachAnimation(activeViseme, {fade: 0.05});
          }
          activeExpression = null;
          activeViseme = null;
          return true;
        }

        const name = command.animationName;
        if (
          typeof name !== 'string' ||
          !viewer.availableAnimations.includes(name)
        ) {
          if (typeof name === 'string' && !reportedMissing.has(name)) {
            reportedMissing.add(name);
            post({type: 'missing', animation: name});
          }
          return false;
        }

        if (command.type === 'expression') {
          if (activeExpression) {
            viewer.detachAnimation(activeExpression, {fade: 0.08});
          }

          viewer.appendAnimation(name, {
            repetitions: command.loop ? null : 1,
            weight: 1,
            timeScale: 1,
            fade: 0.08
          });
          activeExpression = name;
          return true;
        }

        if (command.type === 'viseme') {
          if (activeViseme) {
            viewer.detachAnimation(activeViseme, {fade: 0.04});
          }

          viewer.appendAnimation(name, {
            repetitions: 1,
            weight: 1,
            timeScale: 1,
            fade: 0.04
          });
          activeViseme = name;
          return true;
        }

        return false;
      }
    };

    window.sa7biHeroBridge = bridge;

    const announceReady = () => {
      if (!viewer.loaded) return;
      bridge.animations = Array.from(viewer.availableAnimations || []);
      post({type: 'ready', animations: bridge.animations});
    };

    viewer.addEventListener('load', announceReady);
    viewer.addEventListener('error', () => post({type: 'error'}));

    if (viewer.loaded) announceReady();
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', install, {once: true});
  } else {
    install();
  }
})();
''';

  WebViewController? _webViewController;
  StreamSubscription<HeroFaceCommand>? _faceSubscription;
  bool _bridgeReady = false;
  String? _lastMissingAnimation;

  @override
  void initState() {
    super.initState();
    _syncFaceSubscription();
  }

  void _syncFaceSubscription() {
    if (widget.enableFaceAnimations) {
      _faceSubscription ??=
          HeroFaceRuntime.instance.commands.listen(_handleFaceCommand);
      return;
    }

    final subscription = _faceSubscription;
    _faceSubscription = null;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }

    if (_bridgeReady) {
      _runJavaScript('window.sa7biHeroBridge?.apply({type: "reset"});');
    }
  }

  @override
  void didUpdateWidget(covariant Sa7biHero3D oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.animationName != widget.animationName) {
      _setBodyAnimation(widget.animationName);
    }

    if (oldWidget.enableFaceAnimations != widget.enableFaceAnimations) {
      _syncFaceSubscription();
      if (widget.enableFaceAnimations && _bridgeReady) {
        final lastCommand = HeroFaceRuntime.instance.lastCommand;
        if (lastCommand != null) _applyFaceCommand(lastCommand);
      }
    }
  }

  void _onWebViewCreated(WebViewController controller) {
    _webViewController = controller;
  }

  void _onBridgeMessage(JavaScriptMessage message) {
    try {
      final decoded = jsonDecode(message.message);
      if (decoded is! Map) return;

      final type = decoded['type'];

      if (type == 'ready') {
        final rawAnimations = decoded['animations'];
        final animations = rawAnimations is List
            ? rawAnimations.whereType<String>().toSet()
            : <String>{};

        _bridgeReady = true;
        HeroFaceRuntime.instance.reportAvailableAnimations(animations);
        _lastMissingAnimation = null;
        _setBodyAnimation(widget.animationName);

        if (widget.enableFaceAnimations) {
          final lastCommand = HeroFaceRuntime.instance.lastCommand;
          if (lastCommand != null) _applyFaceCommand(lastCommand);
        }
      } else if (type == 'missing') {
        final name = decoded['animation'];
        if (name is String && name != _lastMissingAnimation) {
          _lastMissingAnimation = name;
          debugPrint('HERO animation is not present in GLB: $name');
        }
      } else if (type == 'error') {
        _bridgeReady = false;
        HeroFaceRuntime.instance.reportAvailableAnimations(const <String>[]);
      }
    } catch (error) {
      debugPrint('HERO bridge message could not be parsed: $error');
    }
  }

  void _handleFaceCommand(HeroFaceCommand command) {
    if (!widget.enableFaceAnimations || !_bridgeReady) return;
    _applyFaceCommand(command);
  }

  void _applyFaceCommand(HeroFaceCommand command) {
    final controller = _webViewController;
    if (!_bridgeReady || controller == null) return;

    final payload = jsonEncode({
      'type': command.type.name,
      'animationName': command.animationName,
      'loop': command.loop,
    });

    _runJavaScript('window.sa7biHeroBridge?.apply($payload);');
  }

  void _setBodyAnimation(String animationName) {
    if (!_bridgeReady) return;

    final safeName = jsonEncode(animationName);
    _runJavaScript(
      'window.sa7biHeroBridge?.setBodyAnimation($safeName);',
    );
  }

  void _runJavaScript(String script) {
    final controller = _webViewController;
    if (controller == null) return;

    unawaited(
      controller.runJavaScript(script).catchError((Object error) {
        debugPrint('HERO JavaScript command failed: $error');
      }),
    );
  }

  @override
  void dispose() {
    final subscription = _faceSubscription;
    _faceSubscription = null;
    if (subscription != null) unawaited(subscription.cancel());

    if (_bridgeReady && widget.enableFaceAnimations) {
      _runJavaScript('window.sa7biHeroBridge?.apply({type: "reset"});');
    }

    _webViewController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // وضع اختبار التنقل: يحتفظ بعنصر HERO في شجرة الواجهة
    // لكنه لا يشغّل WebView أو محرك 3D داخل المحاكي.
    if (Sa7biHero3D.debugDisableWebViewForTests) {
      return const Semantics(
        label: 'HERO 3D test placeholder',
        child: ColoredBox(
          color: Color(0xFF081225),
          child: Center(
            child: Icon(
              Icons.smart_toy_rounded,
              color: Color(0xFF72D7FF),
              size: 30,
            ),
          ),
        ),
      );
    }

    final compact = widget.compact;

    return ModelViewer(
      id: _viewerId,
      src: 'assets/3d/sa7bi_hero.glb',
      alt: 'صاحبي HERO بالشخصية الأصلية وشعار تطبيق صاحبي على الصدر',
      backgroundColor: const Color(0xFF081225),
      ar: false,
      cameraControls: widget.cameraControls,
      autoRotate: false,
      autoPlay: true,
      animationName: 'Hero_Idle',
      animationCrossfadeDuration: 350,
      disableZoom: !widget.cameraControls,
      disablePan: !widget.cameraControls,
      shadowIntensity: 0.9,
      shadowSoftness: 0.95,
      exposure: 1.1,
      cameraOrbit: compact ? '0deg 78deg 2.35m' : '0deg 78deg 3.55m',
      cameraTarget: compact ? '0m 1.62m 0m' : '0m 1.35m 0m',
      minCameraOrbit: compact ? 'auto 48deg 1.8m' : 'auto 35deg 2.5m',
      maxCameraOrbit: compact ? 'auto 100deg 3.2m' : 'auto 110deg 5m',
      relatedJs: _bridgeScript,
      javascriptChannels: {
        JavascriptChannel(
          _channelName,
          onMessageReceived: _onBridgeMessage,
        ),
      },
      onWebViewCreated: _onWebViewCreated,
      debugLogging: false,
    );
  }
}
