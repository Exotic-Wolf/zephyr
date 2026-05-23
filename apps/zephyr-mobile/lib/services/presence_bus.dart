import 'dart:async';

/// Singleton bus for real-time user presence (online/offline/busy/live).
///
/// Fed by home_screen's feed socket (`feed:user-status` events).
/// Any page can subscribe to status changes or query current status.
class PresenceBus {
  PresenceBus._();
  static final PresenceBus instance = PresenceBus._();

  final Map<String, String> _cache = <String, String>{};

  final StreamController<PresenceEvent> _ctrl =
      StreamController<PresenceEvent>.broadcast();

  Stream<PresenceEvent> get stream => _ctrl.stream;

  /// Update a user's status and notify subscribers.
  void update(String userId, String status) {
    final String prev = _cache[userId] ?? 'offline';
    if (prev == status) return; // no-op dedup
    _cache[userId] = status;
    _ctrl.add(PresenceEvent(userId: userId, status: status));
  }

  /// Bulk-seed from feed card data (initial load).
  void seed(Map<String, String> statuses) {
    for (final MapEntry<String, String> entry in statuses.entries) {
      _cache[entry.key] = entry.value;
    }
  }

  /// Get current known status for a user.
  String statusOf(String userId) => _cache[userId] ?? 'offline';
}

class PresenceEvent {
  const PresenceEvent({required this.userId, required this.status});
  final String userId;
  final String status;
}
