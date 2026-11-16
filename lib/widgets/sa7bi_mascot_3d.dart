import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

/// Interactive, locally bundled 3D model of the Sa7bi AI companion.
///
/// The GLB is loaded from the Flutter asset bundle; no external model URL is
/// required. Users can drag to rotate and pinch to zoom when controls are on.
class Sa7biMascot3D extends StatelessWidget {
  const Sa7biMascot3D({
    super.key,
    this.autoRotate = true,
    this.cameraControls = true,
    this.backgroundColor = const Color(0xFF0B1323),
  });

  final bool autoRotate;
  final bool cameraControls;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return ModelViewer(
      src: 'assets/3d/sa7bi_mascot.glb',
      alt: 'مجسم شخصية صاحبي AI ثلاثي الأبعاد',
      backgroundColor: backgroundColor,
      ar: false,
      cameraControls: cameraControls,
      autoRotate: autoRotate,
      autoRotateDelay: 1800,
      rotationPerSecond: '18deg',
      disableZoom: false,
      disablePan: false,
      shadowIntensity: 0.8,
      shadowSoftness: 0.9,
      exposure: 1.0,
      cameraOrbit: '0deg 75deg 3.5m',
      cameraTarget: '0m 1.38m 0m',
    );
  }
}
