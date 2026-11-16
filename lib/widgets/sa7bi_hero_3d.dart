import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

/// Sa7bi HERO: a local animated GLB with the exact Sa7bi app icon embedded
/// as the chest energy-core texture.
class Sa7biHero3D extends StatelessWidget {
  const Sa7biHero3D({
    super.key,
    this.animationName = 'Hero_Idle',
    this.cameraControls = true,
  });

  final String animationName;
  final bool cameraControls;

  @override
  Widget build(BuildContext context) {
    return ModelViewer(
      src: 'assets/3d/sa7bi_hero.glb',
      alt: 'صاحبي HERO بشعار تطبيق صاحبي الأصلي المضيء على الصدر',
      backgroundColor: const Color(0xFF081225),
      ar: false,
      cameraControls: cameraControls,
      autoRotate: false,
      autoPlay: true,
      animationName: animationName,
      animationCrossfadeDuration: 350,
      disableZoom: false,
      disablePan: false,
      shadowIntensity: 0.9,
      shadowSoftness: 0.95,
      exposure: 1.1,
      cameraOrbit: '0deg 78deg 3.55m',
      cameraTarget: '0m 1.35m 0m',
      minCameraOrbit: 'auto 35deg 2.5m',
      maxCameraOrbit: 'auto 110deg 5m',
    );
  }
}
