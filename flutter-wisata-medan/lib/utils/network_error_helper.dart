class NetworkErrorHelper {
  static const String offlineMessage =
      'Tidak ada koneksi internet. Periksa koneksi Anda.';
  static DateTime? _lastOfflineMessageAt;

  static bool isConnectivityError(Object? error) {
    if (error == null) {
      return false;
    }

    final text = error.toString().toLowerCase();
    final backendSpecificFailure = text.contains('api ci4') ||
        text.contains('supabase:') ||
        text.contains('ci4:') ||
        text.contains('rpc gis') ||
        text.contains('postgrest');

    if (backendSpecificFailure) {
      return false;
    }

    final hasOfflineHint = text.contains('failed host lookup') ||
        text.contains('network is unreachable') ||
        text.contains('xmlhttprequest error') ||
        text.contains('network request failed') ||
        text.contains('fetch failed') ||
        text.contains('no address associated') ||
        text.contains('unable to resolve host') ||
        text.contains('host lookup') ||
        text.contains('tidak ada koneksi internet');

    if (hasOfflineHint) {
      return true;
    }

    final socketOffline = text.contains('socketexception') &&
        (text.contains('failed host lookup') ||
            text.contains('network is unreachable') ||
            text.contains('no address associated') ||
            text.contains('unable to resolve host'));

    return socketOffline;
  }

  static String normalizeMessage(
    Object? error, {
    required String fallback,
  }) {
    if (isConnectivityError(error)) {
      return offlineMessage;
    }
    return fallback;
  }

  static bool shouldSuppressOfflineMessage([Duration? cooldown]) {
    final now = DateTime.now();
    final effectiveCooldown = cooldown ?? const Duration(seconds: 20);
    final lastShownAt = _lastOfflineMessageAt;
    if (lastShownAt != null && now.difference(lastShownAt) < effectiveCooldown) {
      return true;
    }

    _lastOfflineMessageAt = now;
    return false;
  }
}
