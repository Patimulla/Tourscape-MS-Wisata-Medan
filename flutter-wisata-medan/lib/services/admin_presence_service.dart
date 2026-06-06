import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminPresenceService {
  AdminPresenceService._();

  static final AdminPresenceService instance = AdminPresenceService._();
  static const Duration _heartbeatInterval = Duration(minutes: 5);

  final SupabaseClient _supabase = Supabase.instance.client;
  final ValueNotifier<Set<String>> onlineUserIds = ValueNotifier(<String>{});
  final ValueNotifier<Map<String, DateTime>> lastSeenByUserId =
      ValueNotifier(<String, DateTime>{});

  RealtimeChannel? _channel;
  String? _trackedUserId;
  DateTime? _currentOnlineAt;
  DateTime? _lastPersistedAt;
  Timer? _heartbeatTimer;

  Future<void> startTracking() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      await stopTracking();
      return;
    }

    if (_trackedUserId == user.id && _channel != null) {
      _markUserOnlineLocally(user.id);
      _maybePersistLastSeen(user.id, DateTime.now());
      return;
    }

    await stopTracking(clearOnlineIds: false);

    _trackedUserId = user.id;
    _currentOnlineAt = DateTime.now();
    _lastPersistedAt = null;
    _markUserOnlineLocally(user.id);
    _updateLastSeenLocally(user.id, _currentOnlineAt!);
    _maybePersistLastSeen(user.id, _currentOnlineAt!, force: true);

    final channel = _supabase.channel(
      'admin-online-presence',
      opts: const RealtimeChannelConfig(self: true),
    );
    _channel = channel;

    channel
        .onPresenceSync((_) => _syncOnlineUserIds())
        .onPresenceJoin((_) => _syncOnlineUserIds())
        .onPresenceLeave((_) => _syncOnlineUserIds())
        .subscribe((status, [_]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        await channel.track({
          'user_id': user.id,
          'online_at': _currentOnlineAt!.toIso8601String(),
        });
        _syncOnlineUserIds();
        _startHeartbeat(user.id);
      }
    });
  }

  Future<void> stopTracking({bool clearOnlineIds = true}) async {
    final channel = _channel;
    _channel = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    final trackedUserId = _trackedUserId;
    _trackedUserId = null;
    if (trackedUserId != null) {
      final now = DateTime.now();
      _updateLastSeenLocally(trackedUserId, now);
      _removeUserOnlineLocally(trackedUserId);
      _maybePersistLastSeen(trackedUserId, now, force: true);
    }
    _currentOnlineAt = null;
    _lastPersistedAt = null;

    if (clearOnlineIds) {
      onlineUserIds.value = <String>{};
    }

    if (channel == null) {
      return;
    }

    try {
      await channel.untrack();
    } catch (_) {}

    try {
      await _supabase.removeChannel(channel);
    } catch (_) {}
  }

  bool isOnline(String userId) => onlineUserIds.value.contains(userId);

  DateTime? lastSeenAt(String userId) => lastSeenByUserId.value[userId];

  void _syncOnlineUserIds() {
    final channel = _channel;
    if (channel == null) {
      return;
    }

    final ids = <String>{};
    final lastSeen = Map<String, DateTime>.from(lastSeenByUserId.value);
    for (final state in channel.presenceState()) {
      for (final presence in state.presences) {
        final userId = presence.payload['user_id']?.toString().trim();
        if (userId != null && userId.isNotEmpty) {
          ids.add(userId);
          final onlineAtRaw = presence.payload['online_at']?.toString();
          final onlineAt = onlineAtRaw == null
              ? null
              : DateTime.tryParse(onlineAtRaw)?.toLocal();
          if (onlineAt != null) {
            lastSeen[userId] = onlineAt;
          }
        }
      }
    }

    if (!_sameIds(ids, onlineUserIds.value)) {
      onlineUserIds.value = ids;
    }
    if (!_sameLastSeen(lastSeen, lastSeenByUserId.value)) {
      lastSeenByUserId.value = lastSeen;
    }
  }

  void _markUserOnlineLocally(String userId) {
    final ids = <String>{...onlineUserIds.value, userId};
    if (!_sameIds(ids, onlineUserIds.value)) {
      onlineUserIds.value = ids;
    }
  }

  void _removeUserOnlineLocally(String userId) {
    if (!onlineUserIds.value.contains(userId)) {
      return;
    }

    final ids = <String>{...onlineUserIds.value}..remove(userId);
    onlineUserIds.value = ids;
  }

  void _updateLastSeenLocally(String userId, DateTime value) {
    final next = Map<String, DateTime>.from(lastSeenByUserId.value);
    next[userId] = value;
    if (!_sameLastSeen(next, lastSeenByUserId.value)) {
      lastSeenByUserId.value = next;
    }
  }

  void _startHeartbeat(String userId) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      final now = DateTime.now();
      _updateLastSeenLocally(userId, now);
      _maybePersistLastSeen(userId, now);
    });
  }

  void _maybePersistLastSeen(
    String userId,
    DateTime value, {
    bool force = false,
  }) {
    final lastPersistedAt = _lastPersistedAt;
    final shouldPersist = force ||
        lastPersistedAt == null ||
        value.difference(lastPersistedAt) >= _heartbeatInterval;

    if (!shouldPersist) {
      return;
    }

    _lastPersistedAt = value;
    unawaited(_persistLastSeen(userId, value));
  }

  Future<void> _persistLastSeen(String userId, DateTime value) async {
    try {
      await _supabase
          .from('admin_mobile')
          .update({'last_seen_at': value.toIso8601String()}).eq('id', userId);
    } catch (_) {}
  }

  bool _sameLastSeen(Map<String, DateTime> a, Map<String, DateTime> b) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }
    for (final entry in a.entries) {
      final other = b[entry.key];
      if (other == null || other != entry.value) {
        return false;
      }
    }
    return true;
  }

  bool _sameIds(Set<String> a, Set<String> b) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }
    for (final value in a) {
      if (!b.contains(value)) {
        return false;
      }
    }
    return true;
  }
}
