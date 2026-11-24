
#!/usr/bin/env bash

set -uo pipefail

DIAG="build/android-ui-smoke"
mkdir -p "${DIAG}"

LOGCAT_PID=""

echo "=== Emulator startup ==="

adb wait-for-device
adb devices -l > "${DIAG}/adb-before-tests.txt" 2>&1 || true
adb shell getprop > "${DIAG}/android-getprop.txt" 2>&1 || true
adb shell dumpsys meminfo > "${DIAG}/memory-before-tests.txt" 2>&1 || true

echo "=== Starting continuous Android logcat ==="

adb logcat -b all -v threadtime \
  > "${DIAG}/android-logcat-live.txt" 2>&1 &
LOGCAT_PID=$!

echo "${LOGCAT_PID}" > "${DIAG}/logcat-pid.txt"

finish_diagnostics() {
  echo "=== Collecting final emulator diagnostics ==="

  adb devices -l > "${DIAG}/adb-after-tests.txt" 2>&1 || true

  adb logcat -d -b all -v threadtime \
    > "${DIAG}/android-logcat-final.txt" 2>&1 || true

  adb shell dumpsys meminfo \
    > "${DIAG}/memory-after-tests.txt" 2>&1 || true

  adb shell dumpsys activity processes \
    > "${DIAG}/processes-after-tests.txt" 2>&1 || true

  if [[ -n "${LOGCAT_PID}" ]] && kill -0 "${LOGCAT_PID}" 2>/dev/null; then
    kill "${LOGCAT_PID}" 2>/dev/null || true
    wait "${LOGCAT_PID}" 2>/dev/null || true
  fi
}

trap finish_diagnostics EXIT

run_test() {
  local TEST_NAME="$1"
  local OUTPUT_FILE="$2"
  local TEST_STATUS=0

  echo "=== START: ${TEST_NAME} ==="

  if flutter test \
    integration_test/sa7bi_app_smoke_test.dart \
    --no-pub \
    -d emulator-5554 \
    --reporter expanded \
    --plain-name "${TEST_NAME}" \
    2>&1 | tee "${DIAG}/${OUTPUT_FILE}"; then

    echo "PASS: ${TEST_NAME}" | tee -a "${DIAG}/test-summary.txt"
    return 0
  else
    TEST_STATUS=$?
    echo "FAIL: ${TEST_NAME} (exit ${TEST_STATUS})" \
      | tee -a "${DIAG}/test-summary.txt"
    return "${TEST_STATUS}"
  fi
}

NAV_STATUS=0
HERO_STATUS=0

run_test \
  "Sa7bi AI main navigation and HERO smoke test" \
  "flutter-test-navigation.txt" || NAV_STATUS=$?

echo "=== Checking emulator connection between tests ==="

adb devices -l > "${DIAG}/adb-between-tests.txt" 2>&1 || true
adb reconnect offline > "${DIAG}/adb-reconnect.txt" 2>&1 || true

if timeout 90s adb wait-for-device; then
  echo "Emulator connection available for HERO test."
else
  echo "Emulator did not reconnect before HERO test."
fi

run_test \
  "HERO GLB loads all body, expression and viseme clips on Android" \
  "flutter-test-hero.txt" || HERO_STATUS=$?

{
  echo "Navigation test exit: ${NAV_STATUS}"
  echo "HERO test exit: ${HERO_STATUS}"
} > "${DIAG}/exit-status.txt"

if [[ "${NAV_STATUS}" -ne 0 || "${HERO_STATUS}" -ne 0 ]]; then
  exit 1
fi

echo "Both Android integration tests passed."
