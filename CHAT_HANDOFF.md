Sa7bi AI — Chat Handoff
Repository target
Repository: ahmedsab34-prog/sa7bi_ai_new
Working branch: fix/build-692-network-client-lifecycle
Last verified commit: 97fd02c96a8218664d9a82e68f2de47255cb26f9
Do not modify main.
Do not deploy either Worker, update Production settings/secrets, or publish a Release without explicit approval.
Last successful build
Android APK Build #404 succeeded.
Android UI Smoke #167 succeeded.
App version 1.0.1, version code 200404, application ID com.example.sa7bi_ai_new.
145 Flutter tests passed.
APK Artifact: sa7bi-ai-release-404-97fd02c96a82.
APK and Android UI used the same source commit.
Worker deployment and stable Release publication were skipped.
HERO references and required identity
The two saved Library images are:
صاحبي HERO: بطل الذكاء الاصطناعي.png
بطل صاحبي AI في ملصق مستقبلي.png
They define one and the same character. Preserve the current blue/gold armor, red cape, original chest emblem, body proportions, and the three existing body clips Hero_Idle, Hero_Welcome, and Hero_Power.
The current branch's GLB has no facial morph targets, no facial skin joints, and no facial animation clips. The Flutter runtime is only a bridge; it does not build the 3D face. The exact required clips and shape controls are documented in assets/3d/HERO_FACE_RIG_SPEC_AR.md.
Current code batch
Replace lib/services/hero_face_runtime.dart with the supplied full file to align runtime names to the rig specification and add the reference-image wink.
Add test/hero_face_runtime_test.dart at the supplied path.
Replace lib/sa7bi_hero_3d_screen.dart with the supplied full file to expose neutral, smile, sad, surprise, angry, wink, and blink controls.
Replace assets/3d/README.md and add assets/3d/HERO_FACE_RIG_SPEC_AR.md as supplied.
Replace PROJECT_STATE.md and CHAT_HANDOFF.md with the current verified state.
Existing lib/widgets/sa7bi_hero_3d.dart, lib/services/chat_voice_service.dart, and lib/widgets/chat_screen_body.dart already connect the 3D model to chat/TTS; they do not need duplication.
Remaining production gates
Edit the actual existing assets/3d/sa7bi_hero.glb in a real 3D workflow (Blender or equivalent), preserving the body and chest texture while adding facial geometry/controls and the required clips.
Run GLB validation and face expression/viseme playback inside the Android app.
Clean two non-fatal analyzer notices: the null-aware fallback expression in app_diagnostics_v5_service.dart and the unused cross_file import in social_connect_attachment_message.dart.
Run all Flutter tests, Android UI smoke, dedicated navigation test, and backend provider/route tests.
Test real network failover and real services on a phone/two devices. Do not replay non-idempotent social POST writes automatically.
Freeze one candidate commit and create one APK. After user approval, deploy both Workers from that same commit, verify both live source identities, then update apk-latest with the exact candidate APK.
Do not claim complete
Face rig and lip-sync are not complete while the GLB reports zero morph targets and no face clips.
A green build proves compilation/tests for the source commit, not real-world provider availability or successful live Worker deployment.
The existing permanent apk-latest link is older than Build #404.
