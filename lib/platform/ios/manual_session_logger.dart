import 'package:flutter/foundation.dart';
import '../../core/database/sqlite_store.dart';

class ManualSessionLogger {
  final SQLiteStore store;
  ManualSessionLogger({required this.store});

  void start() {
    debugPrint('[ManualSessionLogger] iOS manual logger ready.');
  }

  Future<void> logFocusSession(int durationMinutes) async {
    final end = DateTime.now().millisecondsSinceEpoch;
    final start = end - (durationMinutes * 60000);
    
    // Insert synthetic events for the session
    await store.insertEvent(RawEventInsert(
      timestamp: start,
      appId: 'com.apple.Preferences', // Dummy app id mapped to productive
      category: 'productive',
      eventType: 'switch',
      durationMs: durationMinutes * 60000,
      deviceType: 'phone',
    ));
    // Insert the end-of-session idle marker.
    // IMPORTANT:
    //   eventType must be 'idle' (not 'switch') so the cognitive engine
    //   applies wmBreakGain and resets the velocity window. Using 'switch'
    //   adds a spurious switch cost to every manually logged session.
    //
    //   category must be a valid Category enum value. 'idle' is NOT in the
    //   enum — Category.fromString('idle') falls through to Category.tools,
    //   corrupting the category breakdown. For idle events the category field
    //   is semantically irrelevant; 'productive' is used as a neutral value.
    await store.insertEvent(RawEventInsert(
      timestamp: end,
      appId: 'idle',
      category: 'productive',
      eventType: 'idle',
      durationMs: 0,
      deviceType: 'phone',
    ));
  }
}
