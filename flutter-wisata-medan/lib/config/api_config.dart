/// ============================================================
/// Tourscape MS — Flutter Mobile App
/// API Configuration
/// ============================================================

import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _localhostBaseUrl = 'http://localhost:8080/api';
  static const String _loopbackBaseUrl = 'http://127.0.0.1:8080/api';
  static const String _androidEmulatorBaseUrl = 'http://10.0.2.2:8080/api';
  static const String _genymotionBaseUrl = 'http://10.0.3.2:8080/api';

  // Override saat runtime:
  // flutter run --dart-define=CI4_API_BASE_URL=http://192.168.1.5:8080/api
  static const String _overrideBaseUrl = String.fromEnvironment(
    'CI4_API_BASE_URL',
    defaultValue: '',
  );

  // Opsional untuk device fisik di jaringan lokal:
  // flutter run --dart-define=CI4_API_LAN_BASE_URL=http://192.168.1.19:8080/api
  static const String _lanBaseUrl = String.fromEnvironment(
    'CI4_API_LAN_BASE_URL',
    defaultValue: '',
  );

  static String get defaultBaseUrl {
    if (_overrideBaseUrl.isNotEmpty) {
      return _overrideBaseUrl;
    }

    if (_lanBaseUrl.isNotEmpty) {
      return _lanBaseUrl;
    }

    if (kIsWeb) {
      return _localhostBaseUrl;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _androidEmulatorBaseUrl;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return _localhostBaseUrl;
    }
  }

  static String get baseUrl => defaultBaseUrl;

  static Iterable<String> candidateBaseUrls([String? preferredBaseUrl]) sync* {
    final emitted = <String>{};

    void emit(String value) {
      final normalized = value.trim().replaceFirst(RegExp(r'/$'), '');
      if (normalized.isEmpty || emitted.contains(normalized)) {
        return;
      }

      emitted.add(normalized);
    }

    if (preferredBaseUrl != null && preferredBaseUrl.isNotEmpty) {
      emit(preferredBaseUrl);
    }

    emit(defaultBaseUrl);

    if (_overrideBaseUrl.isNotEmpty) {
      emit(_overrideBaseUrl);
    }

    if (_lanBaseUrl.isNotEmpty) {
      emit(_lanBaseUrl);
    }

    if (kIsWeb) {
      emit(_localhostBaseUrl);
      emit(_loopbackBaseUrl);
    } else {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          emit(_loopbackBaseUrl);
          emit(_localhostBaseUrl);
          // Umum untuk Android emulator.
          emit(_androidEmulatorBaseUrl);
          // Umum untuk Genymotion.
          emit(_genymotionBaseUrl);
          break;
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
        case TargetPlatform.windows:
        case TargetPlatform.linux:
        case TargetPlatform.fuchsia:
          emit(_localhostBaseUrl);
          emit(_loopbackBaseUrl);
          break;
      }
    }
    yield* emitted;
  }

  static Uri buildUri({
    required String baseUrl,
    required String path,
    Map<String, String>? queryParameters,
  }) {
    final normalizedBase = baseUrl.replaceFirst(RegExp(r'/$'), '');
    final normalizedPath = path.startsWith('/') ? path : '/$path';

    return Uri.parse('$normalizedBase$normalizedPath').replace(
      queryParameters: queryParameters == null || queryParameters.isEmpty
          ? null
          : queryParameters,
    );
  }

  // Endpoint lama tetap dipertahankan untuk fitur wisata yang sudah ada.
  static String get wisata => '$baseUrl/wisata';
  static String get wisataNearby => '$baseUrl/wisata/nearby';
  static String get kategori => '$baseUrl/kategori';
  static String get fasilitas => '$baseUrl/fasilitas';
  static String get roadsMedan => '$baseUrl/roads/medan';
  static String get roadsDeliSerdang => '$baseUrl/roads/deli-serdang';
  static String get boundariesMedan => '$baseUrl/boundaries/medan';
  static String get boundariesDeliSerdang => '$baseUrl/boundaries/deli-serdang';
  static String get kecamatan => '$baseUrl/kecamatan';
  static String get wilayah => '$baseUrl/wilayah';

  static String wisataDetail(int id) => '$baseUrl/wisata/$id';
  static String kecamatanDetail(int id) => '$baseUrl/kecamatan/$id';
  static String roadsByKecamatan(int id) => '$baseUrl/roads/by-kecamatan/$id';
  static String wilayahDetail(int id) => '$baseUrl/wilayah/$id';
  static String wilayahChildren(int id) => '$baseUrl/wilayah/children/$id';
  static String roadsByWilayah(int id) => '$baseUrl/roads/by-wilayah/$id';
  static String wisataReview(int id) => '$baseUrl/wisata/$id/review';
}
