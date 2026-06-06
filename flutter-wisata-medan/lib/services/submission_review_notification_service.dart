import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SubmissionReviewNotificationService {
  SubmissionReviewNotificationService._();

  static final SubmissionReviewNotificationService instance =
      SubmissionReviewNotificationService._();

  final ValueNotifier<int> refreshListenable = ValueNotifier<int>(0);
  final ValueNotifier<bool> hasUnreadNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<Map<String, bool>> unreadStatusNotifier =
      ValueNotifier<Map<String, bool>>(<String, bool>{});

  static const String _prefKeyPrefix = 'history_review_seen_at_';
  static const List<String> _reviewStatuses = <String>[
    'approved',
    'rejected',
  ];

  StreamSubscription<List<Map<String, dynamic>>>? _rowsSubscription;
  String? _subscribedUserId;
  List<Map<String, dynamic>> _cachedRows = const <Map<String, dynamic>>[];

  String? get _currentUserId => Supabase.instance.client.auth.currentUser?.id;

  void ensureTrackingCurrentUser() {
    final userId = _currentUserId;
    if (userId == null) {
      unawaited(stopTracking());
      return;
    }

    if (_subscribedUserId == userId && _rowsSubscription != null) {
      return;
    }

    unawaited(_startTracking(userId));
  }

  Future<void> _startTracking(String userId) async {
    await stopTracking();
    _subscribedUserId = userId;
    _rowsSubscription = Supabase.instance.client
        .from('wisata')
        .stream(primaryKey: ['id'])
        .eq('submitter_user_id', userId)
        .order('reviewed_at', ascending: false)
        .listen((rows) {
      _cachedRows = rows;
      unawaited(_refreshUnreadState(userId));
    });
  }

  Future<void> stopTracking() async {
    await _rowsSubscription?.cancel();
    _rowsSubscription = null;
    _subscribedUserId = null;
    _cachedRows = const <Map<String, dynamic>>[];
    hasUnreadNotifier.value = false;
    unreadStatusNotifier.value = const <String, bool>{};
  }

  String? _buildPrefKey(String? userId, [String? status]) {
    if (userId == null || userId.trim().isEmpty) {
      return null;
    }

    final normalizedStatus = status?.trim().toLowerCase();
    if (normalizedStatus == null || normalizedStatus.isEmpty) {
      return '$_prefKeyPrefix$userId';
    }

    return '$_prefKeyPrefix$userId\_$normalizedStatus';
  }

  Future<bool> hasUnreadReviews(
    List<Map<String, dynamic>> rows, {
    String? userId,
  }) async {
    final resolvedUserId = userId ?? _currentUserId;
    for (final status in _reviewStatuses) {
      final unreadForStatus = await hasUnreadReviewsForStatus(
        rows,
        status,
        userId: resolvedUserId,
      );
      if (unreadForStatus) {
        return true;
      }
    }

    return false;
  }

  Future<bool> hasUnreadReviewsForStatus(
    List<Map<String, dynamic>> rows,
    String status, {
    String? userId,
  }) async {
    final resolvedUserId = userId ?? _currentUserId;
    final prefKey = _buildPrefKey(resolvedUserId, status);
    if (prefKey == null) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final seenSignatures = _readSeenSignatures(prefs, prefKey);

    for (final row in rows) {
      if (row['submitter_user_id'] != resolvedUserId) {
        continue;
      }

      if (row['status']?.toString() != status) {
        continue;
      }

      final signature = _buildRowSignature(row);
      if (!seenSignatures.contains(signature)) {
        return true;
      }
    }

    return false;
  }

  Future<void> markHistoryAsSeenForCurrentUser() async {
    for (final status in _reviewStatuses) {
      await markStatusAsSeenForCurrentUser(status, refreshBadge: false);
    }
    await _refreshUnreadState(_currentUserId);
  }

  Future<void> markStatusAsSeenForCurrentUser(
    String status, {
    bool refreshBadge = true,
  }) async {
    final prefKey = _buildPrefKey(_currentUserId, status);
    if (prefKey == null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    Iterable<Map<String, dynamic>> rows =
        _cachedRows.where((row) => row['status']?.toString() == status);
    if (_cachedRows.isEmpty && _currentUserId != null) {
      final fetchedRows = await Supabase.instance.client
          .from('wisata')
          .select('id, status, reviewed_at, submitter_user_id')
          .eq('submitter_user_id', _currentUserId!)
          .eq('status', status);
      rows = fetchedRows
          .whereType<Map>()
          .map((row) => row.map((key, value) => MapEntry(key.toString(), value)));
    }

    final signatures = rows
        .map((row) => row.map((key, value) => MapEntry(key.toString(), value)))
        .map(_buildRowSignature)
        .toList();

    await prefs.setString(prefKey, jsonEncode(signatures));
    await _refreshUnreadState(_currentUserId);
    if (refreshBadge) {
      refresh();
    }
  }

  Set<String> _readSeenSignatures(SharedPreferences prefs, String prefKey) {
    final raw = prefs.getString(prefKey);
    if (raw == null || raw.trim().isEmpty) {
      return <String>{};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((item) => item.toString()).toSet();
      }
    } catch (_) {
      // Abaikan format lama, anggap belum ada data yang dilihat.
    }

    return <String>{};
  }

  String _buildRowSignature(Map<String, dynamic> row) {
    final id = row['id']?.toString() ?? '';
    final status = row['status']?.toString() ?? '';
    final reviewedAt = row['reviewed_at']?.toString() ?? '';
    return '$id|$status|$reviewedAt';
  }

  Future<void> _refreshUnreadState(String? userId) async {
    if (userId == null) {
      hasUnreadNotifier.value = false;
      unreadStatusNotifier.value = const <String, bool>{};
      refresh();
      return;
    }

    final nextStatusMap = <String, bool>{};
    var hasAnyUnread = false;
    for (final status in _reviewStatuses) {
      final unread = await hasUnreadReviewsForStatus(
        _cachedRows,
        status,
        userId: userId,
      );
      nextStatusMap[status] = unread;
      if (unread) {
        hasAnyUnread = true;
      }
    }

    hasUnreadNotifier.value = hasAnyUnread;
    unreadStatusNotifier.value = nextStatusMap;
    refresh();
  }

  void refresh() {
    refreshListenable.value++;
  }
}
