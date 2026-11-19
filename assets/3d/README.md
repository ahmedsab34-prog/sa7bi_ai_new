Sa7bi AI HERO 3D asset
Production asset
The application uses one character only:
assets/3d/sa7bi_hero.glb
The rigged update is based on the original sa7bi_hero (2).glb supplied in the project Library. It preserves the original body geometry, costume, embedded chest-logo texture, and body animation clips. Do not add a second HERO model or replace this file with a still image.
Existing body clips preserved
Hero_Idle
Hero_Welcome
Hero_Power
Embedded facial rig
The updated GLB contains an embedded mouth rig with 21 morph targets:
15 viseme targets: HERO_VISEME_sil, HERO_VISEME_PP, HERO_VISEME_FF, HERO_VISEME_TH, HERO_VISEME_DD, HERO_VISEME_kk, HERO_VISEME_CH, HERO_VISEME_SS, HERO_VISEME_nn, HERO_VISEME_RR, HERO_VISEME_aa, HERO_VISEME_E, HERO_VISEME_I, HERO_VISEME_O, HERO_VISEME_U.
6 expression targets: HERO_FACE_SMILE, HERO_FACE_SAD, HERO_FACE_SURPRISE, HERO_FACE_ANGRY, HERO_FACE_WINK, HERO_FACE_BLINK.
The mouth uses embedded geometry and morph-target animation. The existing eye and eyebrow meshes are independently animated for blink, wink, surprise, sadness and anger. No external rig or texture files are required at runtime.
Runtime integration
HeroFaceRuntime publishes the required animation names. Sa7biHero3D reports availableAnimations from Model Viewer and applies the exact clips through its JavaScript bridge. The Home 3D Lite panel must set enableFaceAnimations: true.
Flutter TTS currently reports word-boundary progress. The viseme mapping therefore selects an approximate mouth shape per word; it is not phoneme-accurate lip synchronization. Do not describe it as phoneme-accurate.
Acceptance checks
test/sa7bi_hero_asset_test.dart verifies:
Valid GLB 2.0 structure and preserved embedded PNG logo.
The three original body clips.
All six expression clips.
All fifteen viseme clips.
Exactly 21 named morph targets.
The embedded HeroMouthRoot, HeroMouthCavity, HeroMouthTeeth, and HeroMouthTongue nodes.
Each viseme clip animates the mouth morph weights.
The final runtime acceptance test must still be performed inside the Android app to verify that Model Viewer plays the clips while TTS is speaking.
