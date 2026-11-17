Project State — Sa7bi AI
Last verified source commit: 97fd02c96a8218664d9a82e68f2de47255cb26f9 Branch: fix/build-692-network-client-lifecycle Last verified build: Android APK Build #404 (17 November 2026) Last verified Android UI smoke: #167
Verified build results
Release APK built and signature/manifest/archive checks passed.
Application ID: com.example.sa7bi_ai_new.
App version: 1.0.1.
Build/version code: 200404.
Flutter tests: 145 passed.
Android integration smoke: passed on the first successful emulator attempt.
Flutter analyzer: no errors; one warning and one informational unused-import notice remain.
Build and Android UI workflows used the same source commit.
App structure present on the branch
Four main tabs: Home, Chat, Games, Profile.
Home news cache/refresh and a short-video card after each five news items.
Khalasana general chat plus ten specializations with separate preserved chat screens.
One HERO GLB viewer embedded in chat, with the existing Idle/Welcome/Power body clips.
Chat text, image analysis, multiple images, video-frame analysis, image generation/editing, speech input and TTS.
Central AudioService/AudioController for Quran, radio, hadith, tafsir, podcasts, and local downloads.
Connect services for sessions, private/public messaging, groups, invitations, attachments, and online games.
Local games and local progress/achievements.
Private venting with encrypted local history, PIN and optional biometric unlock.
Server-authoritative credits and AdMob SSV verification flow.
Primary/secondary Worker networking and commit-identity checks in the release/deploy workflows.
Remaining before a final public build
Update the same assets/3d/sa7bi_hero.glb with the face geometry, morph targets, six expression clips, and fifteen viseme clips described in assets/3d/HERO_FACE_RIG_SPEC_AR.md.
Run the face-runtime contract test and the GLB validation after the rigged model is added. The current GLB still has no face rig.
Clean the one analyzer warning in app_diagnostics_v5_service.dart and remove the unused cross_file import from social_connect_attachment_message.dart.
Run the complete Flutter suite, Android UI smoke, dedicated navigation test, and backend provider/route checks on the candidate commit.
Perform phone-level checks for weak-Wi-Fi/mobile-data behavior, AI request/credit idempotency, Quran/radio playback and interruptions, Connect between two accounts/devices, private venting migration/biometric unlock, and a real AdMob SSV reward.
Build one candidate APK from a frozen commit. Do not change the stable apk-latest tag or publish until the candidate passes.
Only after explicit user approval, deploy primary and fallback Workers from the exact APK source commit, verify both live sourceCommit values, then publish that exact APK artifact.
Network safety policy
GET/HEAD requests can use the configured fallback path. AI POST requests are eligible for fallback only when they carry the device ID and stable request ID, and timeout does not cause automatic replay. Do not automatically replay social write POSTs until their backend handlers support verified idempotency; avoiding duplicate messages, groups, invitations, or matches is more important than a blind retry.
Production state
Build #404 created a verified Actions artifact, not a new stable GitHub Release. Worker deployment was skipped. The existing apk-latest release link still points to the older published commit and must not be represented as Build #404.
