# Sa7bi AI 3D companion asset

Place `sa7bi_mascot.glb` in this folder exactly as named. The app registers it as a Flutter asset in `pubspec.yaml` and loads it from `lib/widgets/sa7bi_mascot_3d.dart`.

## Model details

- Format: binary glTF 2.0 (`.glb`)
- Meshes: 56
- Geometry: stylized, friendly human-like companion with a navy/cyan outfit
- Coordinate system: Y-up; the face points toward positive Z
- Delivery size: approximately 0.9 MB
- Rendering: `model_viewer_plus` with local bundled asset loading

This is a static 3D mesh. It supports camera rotation and zoom in the app, but it does not include a skeleton, facial rig, or built-in character animation. Auto-rotation is a viewer camera effect, not a body animation.

## Required Android setting

`AndroidManifest.xml` already references `@xml/network_security_config`. The matching XML file allows cleartext traffic only for the local loopback hosts used by the model viewer; cleartext connections to remote hosts remain disabled.
