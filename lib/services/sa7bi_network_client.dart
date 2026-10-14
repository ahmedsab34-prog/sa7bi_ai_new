name: Network lifecycle regression checks

on:
  push:
    branches:
      - fix/build-692-network-client-lifecycle

  pull_request:
    branches:
      - fix/build-692-network-client-lifecycle

  workflow_dispatch:

permissions:
  contents: read

jobs:
  flutter-validation:
    name: Format, analyze, tests and Android build
    runs-on: ubuntu-latest
    timeout-minutes: 45

    steps:
      - name: Checkout exact branch commit
        uses: actions/checkout@v4

      - name: Set up Java
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.38.1'
          channel: stable
          cache: true

      - name: Install dependencies
        run: flutter pub get

      - name: Check Dart formatting
        run: >
          dart format --output=none --set-exit-if-changed
          lib/services/sa7bi_network_client.dart
          test/sa7bi_network_client_lifecycle_test.dart

      - name: Analyze Flutter project
        run: flutter analyze

      - name: Run all Flutter tests
        run: flutter test

      - name: Build release APK
        run: flutter build apk --release

      - name: Verify APK and record SHA256
        shell: bash
        run: |
          set -euo pipefail

          APK='build/app/outputs/flutter-apk/app-release.apk'

          test -s "$APK"

          echo "Commit: $GITHUB_SHA"
          echo "Run ID: $GITHUB_RUN_ID"

          sha256sum "$APK"
          stat -c 'APK_SIZE_BYTES=%s' "$APK"
