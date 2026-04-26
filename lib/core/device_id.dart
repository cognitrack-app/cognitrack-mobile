/// Device ID — SHA-256 of platform device identifier.
/// Matches the desktop's deviceId.ts approach.
library;

import 'dart:convert';
import 'dart:io' show Platform;
import 'package:crypto/crypto.dart';

/// Returns the hashed device ID for this device.
/// Android: SHA-256 of Android ID (passed in by native layer)
/// iOS: SHA-256 of identifierForVendor (passed in by native layer)
String computeDeviceId(String rawPlatformId) {
  final bytes = utf8.encode(rawPlatformId);
  final digest = sha256.convert(bytes);
  return digest.toString();
}

/// Returns platform string for Firestore device registration.
String get currentPlatformString => Platform.isAndroid ? 'android' : 'ios';
