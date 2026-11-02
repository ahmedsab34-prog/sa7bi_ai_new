import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const backendDirectory = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(backendDirectory, "..");

async function readProjectFile(relativePath) {
  const absolutePath = resolve(projectRoot, relativePath);

  try {
    return await readFile(absolutePath, "utf8");
  } catch (error) {
    throw new Error(
      `تعذر قراءة الملف المطلوب ${relativePath}: ${error.message}`,
    );
  }
}

function extractDartString(source, name, fileName) {
  const escapedName = name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const expression = new RegExp(
    `static\\s+const\\s+String\\s+${escapedName}\\s*=\\s*'([^']+)'`,
  );
  const match = source.match(expression);

  assert.ok(
    match,
    `لم يتم العثور على ${name} في ${fileName}`,
  );

  return match[1];
}

function extractDartInteger(source, name, fileName) {
  const escapedName = name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const expression = new RegExp(
    `static\\s+const\\s+int\\s+${escapedName}\\s*=\\s*(\\d+)\\s*;`,
  );
  const match = source.match(expression);

  assert.ok(
    match,
    `لم يتم العثور على ${name} في ${fileName}`,
  );

  return Number(match[1]);
}

function extractJavaScriptInteger(source, name, fileName) {
  const escapedName = name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const expression = new RegExp(
    `export\\s+const\\s+${escapedName}\\s*=\\s*(\\d+)\\s*;`,
  );
  const match = source.match(expression);

  assert.ok(
    match,
    `لم يتم العثور على ${name} في ${fileName}`,
  );

  return Number(match[1]);
}

function extractTomlString(source, name, fileName) {
  const escapedName = name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const expression = new RegExp(
    `^${escapedName}\\s*=\\s*"([^"]+)"\\s*$`,
    "m",
  );
  const match = source.match(expression);

  assert.ok(
    match,
    `لم يتم العثور على ${name} في ${fileName}`,
  );

  return match[1];
}

async function main() {
  const adsService = await readProjectFile(
    "lib/services/ads_service.dart",
  );
  const creditsConfig = await readProjectFile(
    "lib/config/credits_config.dart",
  );
  const androidManifest = await readProjectFile(
    "android/app/src/main/AndroidManifest.xml",
  );
  const wranglerConfig = await readProjectFile(
    "backend/wrangler.toml",
  );
  const ssvSource = await readProjectFile(
    "backend/src/admob-ssv.js",
  );
  const creditsSource = await readProjectFile(
    "backend/src/credits.js",
  );

  const appId = extractDartString(
    adsService,
    "appId",
    "lib/services/ads_service.dart",
  );

  const bannerId = extractDartString(
    adsService,
    "bannerAdUnitId",
    "lib/services/ads_service.dart",
  );

  const interstitialId = extractDartString(
    adsService,
    "interstitialAdUnitId",
    "lib/services/ads_service.dart",
  );

  const rewardedId = extractDartString(
    adsService,
    "rewardedAdUnitId",
    "lib/services/ads_service.dart",
  );

  assert.match(
    appId,
    /^ca-app-pub-\d+~\d+$/,
    "معرّف تطبيق AdMob غير صالح.",
  );

  assert.match(
    bannerId,
    /^ca-app-pub-\d+\/\d+$/,
    "معرّف Banner Ad غير صالح.",
  );

  assert.match(
    interstitialId,
    /^ca-app-pub-\d+\/\d+$/,
    "معرّف Interstitial Ad غير صالح.",
  );

  assert.match(
    rewardedId,
    /^ca-app-pub-\d+\/\d+$/,
    "معرّف Rewarded Ad غير صالح.",
  );

  const manifestMatch = androidManifest.match(
    /<meta-data\s+android:name="com\.google\.android\.gms\.ads\.APPLICATION_ID"\s+android:value="([^"]+)"\s*\/>/s,
  );

  assert.ok(
    manifestMatch,
    "لم يتم العثور على APPLICATION_ID الخاص بـ AdMob في AndroidManifest.xml.",
  );

  assert.equal(
    manifestMatch[1],
    appId,
    "معرّف AdMob في AndroidManifest لا يطابق AdsService.appId.",
  );

  const workerRewardedId = extractTomlString(
    wranglerConfig,
    "ADMOB_REWARDED_AD_UNIT_ID",
    "backend/wrangler.toml",
  );

  const workerRewardItem = extractTomlString(
    wranglerConfig,
    "ADMOB_REWARD_ITEM",
    "backend/wrangler.toml",
  );

  assert.equal(
    workerRewardedId,
    rewardedId,
    "معرّف Rewarded Ad في Worker لا يطابق معرّف Flutter.",
  );

  assert.equal(
    workerRewardItem,
    "credits",
    "قيمة ADMOB_REWARD_ITEM يجب أن تكون credits.",
  );

  assert.match(
    ssvSource,
    /ADMOB_REWARDED_AD_UNIT_ID/,
    "كود AdMob SSV لا يقرأ معرّف الوحدة من إعدادات Worker.",
  );

  assert.match(
    ssvSource,
    /ADMOB_SSV_AD_UNIT_NOT_CONFIGURED/,
    "كود AdMob SSV يجب أن يرفض منح المكافأة عند غياب معرّف الإعلان.",
  );

  const flutterReward = extractDartInteger(
    creditsConfig,
    "rewardedAdCredits",
    "lib/config/credits_config.dart",
  );

  const flutterDailyLimit = extractDartInteger(
    creditsConfig,
    "rewardedAdDailyLimit",
    "lib/config/credits_config.dart",
  );

  const workerReward = extractJavaScriptInteger(
    creditsSource,
    "REWARDED_AD_CREDITS",
    "backend/src/credits.js",
  );

  const workerDailyLimit = extractJavaScriptInteger(
    creditsSource,
    "REWARDED_AD_DAILY_LIMIT",
    "backend/src/credits.js",
  );

  assert.equal(
    workerReward,
    flutterReward,
    "قيمة مكافأة Credits مختلفة بين Flutter وWorker.",
  );

  assert.equal(
    workerDailyLimit,
    flutterDailyLimit,
    "الحد اليومي للمكافآت مختلف بين Flutter وWorker.",
  );

  console.log("AdMob configuration verification passed.");
  console.log(`Application ID: ${appId}`);
  console.log(`Banner Ad Unit: ${bannerId}`);
  console.log(`Interstitial Ad Unit: ${interstitialId}`);
  console.log(`Rewarded Ad Unit: ${rewardedId}`);
  console.log(`Reward Credits: ${flutterReward}`);
  console.log(`Daily Reward Limit: ${flutterDailyLimit}`);
  console.log("AndroidManifest and Worker configuration match.");
}

main().catch((error) => {
  console.error("AdMob configuration verification failed:");
  console.error(error.message);
  process.exitCode = 1;
});
