/// Firestore client — typed write of PhoneSyncPayload to Firestore.
/// Write path: users/{uid}/sessions/{YYYY-MM-DD} → phoneMetrics field.
/// Device registration: users/{uid}/devices/{deviceId}.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../cognitive_engine/models.dart';

class FirestoreClient {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  FirestoreClient({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  bool get isAuthenticated => _uid != null;

  // ── Session writes ─────────────────────────────────────────────────────────

  /// Write PhoneSyncPayload to users/{uid}/sessions/{date}.
  /// Merges into the existing session document (preserves desktopSessions).
  Future<void> writePhoneMetrics(PhoneSyncPayload payload) async {
    final uid = _uid;
    if (uid == null) throw StateError('Not authenticated');

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('sessions')
        .doc(payload.date)
        .set({'phoneMetrics': payload.toFirestore()}, SetOptions(merge: true));
  }

  // ── Device registration ────────────────────────────────────────────────────

  /// Register this device on first launch.
  /// Path: users/{uid}/devices/{deviceId}
  ///
  /// Only sets `registeredAt` when the document is being created for the
  /// first time — SetOptions(merge:true) alone does NOT protect existing
  /// fields from being overwritten, mirroring the fix in desktop device.ts.
  Future<void> registerDevice({
    required String deviceId,
    required String platform,
    required String displayName,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Not authenticated');

    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('devices')
        .doc(deviceId);

    // BUG-07: use a transaction so the existence check + conditional write are
    // atomic. Concurrent rapid relaunches can no longer both see !exists and
    // both stamp registeredAt, which would overwrite the original timestamp.
    await _firestore.runTransaction((txn) async {
      final snapshot = await txn.get(docRef);

      final data = <String, dynamic>{
        'platform': platform,
        'displayName': displayName,
        'lastSeen': FieldValue.serverTimestamp(),
        'agentType': 'phone',
      };

      if (!snapshot.exists) {
        // First registration — stamp registeredAt once and only once.
        data['registeredAt'] = FieldValue.serverTimestamp();
      }

      txn.set(docRef, data, SetOptions(merge: true));
    });
  }

  /// Update lastSeen on every sync.
  Future<void> updateDeviceLastSeen(String deviceId) async {
    final uid = _uid;
    if (uid == null) return;

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('devices')
        .doc(deviceId)
        .update({'lastSeen': FieldValue.serverTimestamp()});
  }

  // ── User config ────────────────────────────────────────────────────────────

  /// Fetch user config preferences (thresholds, calibration data).
  Future<Map<String, dynamic>?> getUserConfig() async {
    final uid = _uid;
    if (uid == null) return null;

    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('config')
        .doc('preferences')
        .get();

    return doc.exists ? doc.data() : null;
  }

  // ── Session reads (for dashboard) ─────────────────────────────────────────

  /// Stream the derived metrics for today (written by Cloud Function).
  Stream<Map<String, dynamic>?> streamDerivedMetrics(String date) {
    final uid = _uid;
    if (uid == null) return Stream.value(null);

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('derived')
        .doc(date)
        .snapshots()
        .map((snap) => snap.exists ? snap.data() : null);
  }
}
