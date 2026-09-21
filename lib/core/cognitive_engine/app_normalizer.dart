/// App normalizer — maps Android package names and iOS bundle IDs to
/// canonical cognitive categories.
/// Dart port of @cognitrack/shared/src/appNormalizer.ts
/// MUST stay in sync with TS version for cross-platform category consistency.
library;

import 'models.dart';

// ─── Android package → canonical ID ─────────────────────────────────────────
// Format: android.<app> to match TS: android.<app>
const _androidAppMap = <String, String>{
  // Browsers
  'com.android.chrome': 'android.chrome',
  'com.google.android.apps.chrome': 'android.chrome',
  'org.mozilla.firefox': 'android.firefox',
  'com.brave.browser': 'android.brave',
  'com.microsoft.emmx': 'android.edge',
  'com.microsoft.edgemobile': 'android.edge',

  // Development / Productive
  'com.microsoft.vscode': 'android.vscode', // VS Code mobile/remote
  'com.jetbrains.pycharm': 'android.pycharm',
  'com.google.android.studio': 'android.androidstudio',

  // Communication (Tools)
  'com.slack': 'android.slack',
  'com.discord': 'android.discord',
  'com.microsoft.teams': 'android.teams',
  'us.zoom.videomeetings': 'android.zoom',
  'com.whatsapp': 'android.whatsapp',
  'com.google.android.gm': 'android.gmail',
  'com.microsoft.office.outlook': 'android.msoutlook',

  // Terminal / Shell (Tools)
  'com.termux': 'android.terminal',
  'jackpal.androidterm': 'android.terminal',

  // Utilities (Tools)
  'com.docker.android': 'android.docker',
  'com.agilebits.onepassword': 'android.1password',
  'com.google.android.apps.photos': 'android.photos',
  'com.google.android.apps.maps': 'android.googlemaps',

  // Social
  'com.instagram.android': 'android.instagram',
  'com.facebook.katana': 'android.facebook',
  'com.twitter.android': 'android.twitter',
  'com.reddit.frontpage': 'android.reddit',
  'com.snapchat.android': 'android.snapchat',

  // Entertainment
  'com.spotify.music': 'android.spotify',
  'com.netflix.mediaclient': 'android.netflix',
  'com.google.android.youtube': 'android.youtube',
  'com.valvesoftware.android.steam.community': 'android.steam',

  // Passive Waste (short-form infinite scroll)
  'com.zhiliaoapp.musically': 'android.tiktok',
  'com.ss.android.ugc.trill': 'android.tiktok',
};

// ─── iOS bundle ID → canonical ID ───────────────────────────────────────────
// Format: ios.<app> to match TS: ios.<app>
const _iosAppMap = <String, String>{
  // Browsers
  'com.google.chrome.ios': 'ios.chrome',
  'org.mozilla.ios.firefox': 'ios.firefox',
  'com.brave.ios.browser': 'ios.brave',
  'com.microsoft.msedge': 'ios.edge',
  'com.apple.mobilesafari': 'ios.safari',

  // Development / Productive
  'com.microsoft.vscode': 'ios.vscode',
  'com.jetbrains.pycharm': 'ios.pycharm',
  'com.apple.dt.Xcode': 'ios.xcode',

  // Communication (Tools)
  'com.tinyspeck.chatlyio': 'ios.slack',
  'com.microsoft.teams': 'ios.teams',
  'us.zoom.videomeetings': 'ios.zoom',
  'net.whatsapp.whatsapp': 'ios.whatsapp',
  'com.apple.mobilemail': 'ios.mail',
  'com.microsoft.outlook': 'ios.msoutlook',

  // Terminal / Shell (Tools)
  'com.termux.ios': 'ios.terminal',
  'com.google.android.apps.terminal': 'ios.terminal',

  // Utilities (Tools)
  'com.docker.docker': 'ios.docker',
  'com.agilebits.onepassword': 'ios.1password',
  'com.apple.photos': 'ios.photos',
  'com.apple.maps': 'ios.maps',
  'com.apple.preferences': 'ios.settings',

  // Social
  'com.burbn.instagram': 'ios.instagram',
  'com.facebook.facebook': 'ios.facebook',
  'com.atebits.tweetie2': 'ios.twitter',
  'com.reddit.reddit': 'ios.reddit',
  'com.toyopagroup.picaboo': 'ios.snapchat',
  'com.hammerandchisel.discord': 'ios.discord',
  'com.apple.mobilesms': 'ios.messages',

  // Entertainment
  'com.spotify.client': 'ios.spotify',
  'com.netflix.netflix': 'ios.netflix',
  'com.google.ios.youtube': 'ios.youtube',
  'com.valvesoftware.steam': 'ios.steam',

  // Passive Waste
  'com.zhiliaoapp.musically': 'ios.tiktok',
};

// ─── Category map (canonical ID → Category) ──────────────────────────────────
// MUST match @cognitrack/shared/src/appNormalizer.ts CATEGORY_MAP exactly
// for cross-platform cognitive engine parity.
const _categoryMap = <String, Category>{
  // — Productive (coding, writing, design)
  'android.vscode': Category.productive,
  'android.pycharm': Category.productive,
  'android.androidstudio': Category.productive,
  'ios.vscode': Category.productive,
  'ios.pycharm': Category.productive,
  'ios.xcode': Category.productive,

  // — Tools (browsers, communication, shell, AI assistants, utilities)
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
  'android.terminal': Category.tools,
  'android.docker': Category.tools,
  'android.1password': Category.tools,
  'android.photos': Category.tools,
  'android.googlemaps': Category.tools,
  'ios.chrome': Category.tools,
  'ios.safari': Category.tools,
  'ios.firefox': Category.tools,
  'ios.brave': Category.tools,
  'ios.edge': Category.tools,
  'ios.mail': Category.tools,
  'ios.msoutlook': Category.tools,
  'ios.slack': Category.tools,
  'ios.teams': Category.tools,
  'ios.zoom': Category.tools,
  'ios.whatsapp': Category.tools,
  'ios.messages': Category.tools,
  'ios.terminal': Category.tools,
  'ios.docker': Category.tools,
  'ios.1password': Category.tools,
  'ios.photos': Category.tools,
  'ios.maps': Category.tools,
  'ios.settings': Category.tools,

  // — Entertainment
  'android.spotify': Category.entertainment,
  'android.netflix': Category.entertainment,
  'android.youtube': Category.entertainment,
  'android.steam': Category.entertainment,
  'ios.spotify': Category.entertainment,
  'ios.netflix': Category.entertainment,
  'ios.youtube': Category.entertainment,
  'ios.steam': Category.entertainment,

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
/// Returns e.g. "android.chrome", "ios.safari", "android.instagram".
/// Falls back to "{platform}.{sanitised-name}".
/// MUST match @cognitrack/shared/src/appNormalizer.ts normalizeAppId() format.
String normalizeAppId(String rawName, Platform platform) {
  final key = rawName.toLowerCase().trim();

  if (platform == Platform.android) {
    return _androidAppMap[key] ?? 'android.${_sanitize(key)}';
  }
  if (platform == Platform.ios) {
    return _iosAppMap[key] ?? 'ios.${_sanitize(key)}';
  }
  if (platform == Platform.win32) {
    return 'win.${_sanitize(key)}';
  }
  if (platform == Platform.darwin) {
    return 'mac.${_sanitize(key)}';
  }
  return '${platform.name}.${_sanitize(key)}';
}

/// Sanitize string for canonical ID: lowercase, alphanumeric only.
String _sanitize(String s) {
  return s.replaceAll(RegExp(r'[^a-z0-9]'), '');
}

/// Map a canonical app ID to its cognitive category.
/// Defaults to 'tools' for unknown apps (browser-like default, not passive).
/// MUST match @cognitrack/shared/src/appNormalizer.ts resolveCategory().
Category resolveCategory(String appId) {
  return _categoryMap[appId] ?? Category.tools;
}