/// iOS Screen Event Reader — reads screen-on events from App Group shared container.
/// These events are written by the NotificationServiceExtension when a silent
/// notification fires on screen unlock.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;

/// Reads screen events written by the iOS NotificationServiceExtension
/// via the shared App Group container.
class IOSScreenEventReader {
  static const String _appGroupId = 'group.cognitrack';
  static const String _screenEventFile = 'screen_events.json';
  
  /// Stream of screen-on timestamps (milliseconds since epoch)
  Stream<int> get screenOnStream {
    final controller = StreamController<int>.broadcast();
    
    Timer.periodic(const Duration(seconds: 10), (_) async {
      final events = await _readEvents();
      for (final event in events) {
        controller.add(event.timestamp);
      }
    });
    
    return controller.stream;
  }
  
  /// Get all screen events since [sinceMs]
  Future<List<int>> getScreenEventsSince(int sinceMs) async {
    final events = await _readEvents();
    return events
        .where((e) => e.timestamp >= sinceMs)
        .map((e) => e.timestamp)
        .toList();
  }
  
  /// Read and parse screen events from App Group container
  Future<List<_ScreenEvent>> _readEvents() async {
    try {
      final containerPath = await _getAppGroupContainerPath();
      if (containerPath == null) return [];
      
      final file = File(path.join(containerPath, _screenEventFile));
      if (!await file.exists()) return [];
      
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
      
      final List<dynamic> jsonList = jsonDecode(content);
      return jsonList
          .map((e) => _ScreenEvent.fromJson(e))
          .where((e) => e.timestamp > 0)
          .toList();
    } catch (e) {
      // Ignore read errors - file may not exist yet or be corrupted
      return [];
    }
  }
  
  /// Get the App Group container path on iOS
  Future<String?> _getAppGroupContainerPath() async {
    // On iOS, the App Group container is accessible via the shared directory
    // We use the standard path structure
    final homeDir = Platform.environment['HOME'] ?? '';
    if (homeDir.isEmpty) return null;
    
    // App Group containers are typically at:
    // ~/Library/Group Containers/group.cognitrack/
    final containerPath = path.join(homeDir, 'Library', 'Group Containers', _appGroupId);
    final dir = Directory(containerPath);
    if (await dir.exists()) return containerPath;
    
    // Fallback: try to find via FileManager (requires native bridge)
    // For now, return the expected path
    return containerPath;
  }
}

/// Internal screen event model
class _ScreenEvent {
  final int timestamp;
  
  _ScreenEvent({required this.timestamp});
  
  factory _ScreenEvent.fromJson(Map<String, dynamic> json) {
    return _ScreenEvent(
      timestamp: (json['timestamp'] as num).toInt(),
    );
  }
}