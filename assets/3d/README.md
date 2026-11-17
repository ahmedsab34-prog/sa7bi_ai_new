Sa7bi AI HERO 3D asset
Asset identity
The application uses one character only: assets/3d/sa7bi_hero.glb. Keep the existing superhero body, blue/gold armor, red cape, embedded original chest logo, and all material textures. Do not add a duplicate character or replace the model with a still image.
Existing body clips
Hero_Idle
Hero_Welcome
Hero_Power
These clips must remain present and working after every face-rig revision.
Face reference and required clips
Use the two saved HERO reference images in the project Library. The visual target is the same short-dark-haired, oval-faced character in neutral, smile, surprise, sad, angry, and one-eye-wink poses.
Face expression clips required by Flutter:
HERO_FACE_SMILE
HERO_FACE_SAD
HERO_FACE_SURPRISE
HERO_FACE_ANGRY
HERO_FACE_WINK
HERO_FACE_BLINK
Neutral is the rest pose (all facial weights zero).
The fifteen viseme clip names are HERO_VISEME_sil, HERO_VISEME_PP, HERO_VISEME_FF, HERO_VISEME_TH, HERO_VISEME_DD, HERO_VISEME_kk, HERO_VISEME_CH, HERO_VISEME_SS, HERO_VISEME_nn, HERO_VISEME_RR, HERO_VISEME_aa, HERO_VISEME_E, HERO_VISEME_I, HERO_VISEME_O, and HERO_VISEME_U.
Full modeling and export instructions are in HERO_FACE_RIG_SPEC_AR.md.
Current asset status at source commit 97fd02c96a82
The latest successful APK build reports the three existing body animations and the embedded chest-logo texture. It reports zero facial morph targets, no facial skin joints, and no facial animation clips (SA7BI_HERO_FACE_RIG=NOT_FOUND). The Dart runtime can send animation names, but it cannot create face geometry or a rig. Therefore the face likeness, expressions, and live lip movement are not complete until the same GLB is updated and validated.
Runtime constraints
The Flutter runtime uses model_viewer_plus and the Google Model Viewer animation API to append face clips over the base body animation. Only enable a UI action when the exact animation name is reported by availableAnimations. Flutter TTS word-boundary events are approximate, not phoneme-accurate timing.
