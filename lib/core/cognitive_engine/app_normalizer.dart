/// App normalizer — maps Android package names and iOS bundle IDs to
/// canonical cognitive categories.
/// Dart port of @cognitrack/shared/src/appNormalizer.ts
library;

import 'models.dart';

// ─── Android package → canonical ID ─────────────────────────────────────────
const _androidAppMap = <String, String>{
  'com.google.android.youtube': 'android.youtube',
  'com.instagram.android': 'android.instagram',
  'com.facebook.katana': 'android.facebook',
  'com.twitter.android': 'android.twitter',
  'com.zhiliaoapp.musically': 'android.tiktok', // TikTok
  'com.ss.android.ugc.trill': 'android.tiktok',
  'com.reddit.frontpage': 'android.reddit',
  'com.snapchat.android': 'android.snapchat',
  'com.whatsapp': 'android.whatsapp',
  'com.discord': 'android.discord',
  'com.slack': 'android.slack',
  'com.microsoft.teams': 'android.teams',
  'us.zoom.videomeetings': 'android.zoom',
  'com.spotify.music': 'android.spotify',
  'com.netflix.mediaclient': 'android.netflix',
  'com.google.android.apps.maps': 'android.googlemaps',
  'com.google.android.gm': 'android.gmail',
  'com.microsoft.launcher.enterprise': 'android.microsoftlauncher',
  'com.microsoft.office.word': 'android.msword',
  'com.microsoft.office.excel': 'android.msexcel',
  'com.microsoft.office.outlook': 'android.msoutlook',
  'com.google.android.apps.docs': 'android.googledocs',
  'com.google.android.apps.spreadsheets': 'android.googlesheets',
  'com.notion.id': 'android.notion',
  'md.obsidian': 'android.obsidian',
  'com.android.chrome': 'android.chrome',
  'org.mozilla.firefox': 'android.firefox',
  'com.brave.browser': 'android.brave',
  'com.microsoft.emmx': 'android.edge',
  'com.samsung.android.dialer': 'android.phone',
  'com.google.android.dialer': 'android.phone',
  'com.samsung.android.messaging': 'android.messages',
  'com.google.android.apps.messaging': 'android.messages',
  'com.google.android.apps.photos': 'android.photos',
  'com.amazon.mShop.android.shopping': 'android.amazon',
};

// ─── iOS bundle ID → canonical ID ───────────────────────────────────────────
const _iosAppMap = <String, String>{
  'com.google.ios.youtube': 'ios.youtube',
  'com.burbn.instagram': 'ios.instagram',
  'com.facebook.facebook': 'ios.facebook',
  'com.atebits.tweetie2': 'ios.twitter',
  'com.zhiliaoapp.musically': 'ios.tiktok',
  'com.reddit.reddit': 'ios.reddit',
  'com.toyopagroup.picaboo': 'ios.snapchat',
  'net.whatsapp.whatsapp': 'ios.whatsapp',
  'com.hammerandchisel.discord': 'ios.discord',
  'com.tinyspeck.chatlyio': 'ios.slack',
  'com.microsoft.teams': 'ios.teams',
  'us.zoom.videomeetings': 'ios.zoom',
  'com.spotify.client': 'ios.spotify',
  'com.netflix.netflix': 'ios.netflix',
  'com.apple.mobilemail': 'ios.mail',
  'com.apple.mobilesms': 'ios.messages',
  'com.microsoft.office.word': 'ios.msword',
  'com.microsoft.office.excel': 'ios.msexcel',
  'com.microsoft.outlook': 'ios.msoutlook',
  'com.google.docs': 'ios.googledocs',
  'com.notion.id': 'ios.notion',
  'md.obsidian': 'ios.obsidian',
  'com.google.chrome.ios': 'ios.chrome',
  'org.mozilla.ios.firefox': 'ios.firefox',
  'com.brave.ios.browser': 'ios.brave',
  'com.microsoft.msedge': 'ios.edge',
  'com.apple.mobilesafari': 'ios.safari',
  'com.apple.preferences': 'ios.settings',
  'com.apple.photos': 'ios.photos',
  'com.apple.maps': 'ios.maps',
};

// ─── Category map (canonical ID → Category) ──────────────────────────────────
const _categoryMap = <String, Category>{
  // — Productive
  'android.notion': Category.productive,
  'android.obsidian': Category.productive,
  'android.msword': Category.productive,
  'android.msexcel': Category.productive,
  'android.googledocs': Category.productive,
  'android.googlesheets': Category.productive,
  'ios.notion': Category.productive,
  'ios.obsidian': Category.productive,
  'ios.msword': Category.productive,
  'ios.msexcel': Category.productive,
  'ios.googledocs': Category.productive,

  // — Tools (communication, browsers, utilities)
  'android.chrome': Category.tools,
  'android.firefox': Category.tools,
  'android.brave': Category.tools,
  'android.edge': Category.tools,
  'android.gmail': Category.tools,
  'android.msoutlook': Category.tools,
  'android.slack': Category.tools,
  'android.teams': Category.tools,
  'android.zoom': Category.tools,
  'android.whatsapp': Category.tools,
  'android.phone': Category.tools,
  'android.messages': Category.tools,
  'android.googlemaps': Category.tools,
  'ios.chrome': Category.tools,
  'ios.firefox': Category.tools,
  'ios.brave': Category.tools,
  'ios.edge': Category.tools,
  'ios.safari': Category.tools,
  'ios.mail': Category.tools,
  'ios.msoutlook': Category.tools,
  'ios.slack': Category.tools,
  'ios.teams': Category.tools,
  'ios.zoom': Category.tools,
  'ios.whatsapp': Category.tools,
  'ios.messages': Category.tools,
  'ios.settings': Category.tools,
  'ios.maps': Category.tools,
  'ios.photos': Category.tools,

  // — Entertainment
  'android.spotify': Category.entertainment,
  'android.netflix': Category.entertainment,
  'android.youtube': Category.entertainment,
  'ios.spotify': Category.entertainment,
  'ios.netflix': Category.entertainment,
  'ios.youtube': Category.entertainment,

  // — Social
  'android.instagram': Category.social,
  'android.facebook': Category.social,
  'android.twitter': Category.social,
  'android.reddit': Category.social,
  'android.snapchat': Category.social,
  'android.discord': Category.social,
  'ios.instagram': Category.social,
  'ios.facebook': Category.social,
  'ios.twitter': Category.social,
  'ios.reddit': Category.social,
  'ios.snapchat': Category.social,
  'ios.discord': Category.social,

  // — Passive Waste (short-form infinite scroll)
  'android.tiktok': Category.passiveWaste,
  'ios.tiktok': Category.passiveWaste,
};

// ─── Public API ───────────────────────────────────────────────────────────────

/// Normalise a raw package name / bundle ID to a canonical cross-platform ID.
/// Returns e.g. "android.instagram", "ios.safari".
/// Falls back to "{platform}.{sanitised-name}".
String normalizeAppId(String rawName, Platform platform) {
  final key = rawName.toLowerCase().trim();

  if (platform == Platform.android) {
    return _androidAppMap[key] ?? 'android.$key';
  }
  if (platform == Platform.ios) {
    return _iosAppMap[key] ?? 'ios.$key';
  }
  return '${platform.name}.$key';
}

/// Map a canonical app ID to its cognitive category.
/// Defaults to 'tools' for unknown apps (browser-like default, not passive).
Category resolveCategory(String appId) {
  return _categoryMap[appId] ?? Category.tools;
}
