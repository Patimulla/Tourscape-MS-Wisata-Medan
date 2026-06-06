import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'ci4_network_info_stub.dart'
    if (dart.library.io) 'ci4_network_info_io.dart';

class Ci4ApiClient {
  static const Duration _requestTimeout = Duration(seconds: 3);
  static const Duration _probeTimeout = Duration(milliseconds: 350);
  static const String _probePath = '/kategori';
  static const int _discoveryPort = 8080;
  static const int _discoveryConcurrency = 24;

  static String? _workingBaseUrl;
  static List<String>? _discoveredLanBaseUrls;
  static Future<List<String>>? _lanDiscoveryFuture;

  static Future<Map<String, dynamic>> getJsonMap(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final decoded = await _getJson(
      path,
      queryParameters: queryParameters,
      headers: headers,
    );

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Response API CI4 bukan object JSON yang valid.');
    }

    return decoded;
  }

  static Future<Uri> resolveUri(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final baseUrl = await _resolveBaseUrl(headers: headers);
    return ApiConfig.buildUri(
      baseUrl: baseUrl,
      path: path,
      queryParameters: queryParameters,
    );
  }

  static Future<void> warmUp() async {
    try {
      await _resolveBaseUrl();
    } catch (_) {
      // Discovery dijalankan best-effort supaya UI awal tidak ikut gagal.
    }
  }

  static Future<dynamic> _getJson(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final attemptedUrls = <String>[];
    Object? lastError;

    for (final baseUrl in ApiConfig.candidateBaseUrls(_workingBaseUrl)) {
      final uri = ApiConfig.buildUri(
        baseUrl: baseUrl,
        path: path,
        queryParameters: queryParameters,
      );

      attemptedUrls.add(uri.toString());

      try {
        final response = await http
            .get(
              uri,
              headers: headers,
            )
            .timeout(_requestTimeout);

        if (response.statusCode != 200) {
          lastError = 'HTTP ${response.statusCode}';
          continue;
        }

        final decoded = jsonDecode(response.body);
        _workingBaseUrl = baseUrl;
        return decoded;
      } on TimeoutException {
        lastError = 'connection timed out';
      } catch (error) {
        lastError = error;
      }
    }

    final discoveredBaseUrl =
        await _discoverReachableLanBaseUrl(headers: headers);
    if (discoveredBaseUrl != null) {
      final uri = ApiConfig.buildUri(
        baseUrl: discoveredBaseUrl,
        path: path,
        queryParameters: queryParameters,
      );
      attemptedUrls.add(uri.toString());

      try {
        final response = await http
            .get(
              uri,
              headers: headers,
            )
            .timeout(_requestTimeout);

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          _workingBaseUrl = discoveredBaseUrl;
          return decoded;
        }

        lastError = 'HTTP ${response.statusCode}';
      } on TimeoutException {
        lastError = 'connection timed out';
      } catch (error) {
        lastError = error;
      }
    }

    final suffix = lastError == null ? '' : ' Error terakhir: $lastError.';
    throw Exception(
      'Gagal terhubung ke server GIS.',
    );
  }

  static Future<String> _resolveBaseUrl({
    Map<String, String>? headers,
  }) async {
    if (_workingBaseUrl != null) {
      return _workingBaseUrl!;
    }

    for (final baseUrl in ApiConfig.candidateBaseUrls()) {
      final reachable = await _probeBaseUrl(
        baseUrl,
        headers: headers,
        timeout: _probeTimeout,
      );
      if (reachable) {
        _workingBaseUrl = baseUrl;
        return baseUrl;
      }
    }

    final discoveredBaseUrl =
        await _discoverReachableLanBaseUrl(headers: headers);
    if (discoveredBaseUrl != null) {
      _workingBaseUrl = discoveredBaseUrl;
      return discoveredBaseUrl;
    }

    throw Exception(
      'Server GIS tidak ditemukan.',
    );
  }

  static Future<String?> _discoverReachableLanBaseUrl({
    Map<String, String>? headers,
  }) async {
    final candidates = await _discoverLanBaseUrls();
    for (final baseUrl in candidates) {
      final reachable = await _probeBaseUrl(
        baseUrl,
        headers: headers,
        timeout: _probeTimeout,
      );
      if (reachable) {
        _workingBaseUrl = baseUrl;
        return baseUrl;
      }
    }
    return null;
  }

  static Future<List<String>> _discoverLanBaseUrls() async {
    if (_discoveredLanBaseUrls != null) {
      return _discoveredLanBaseUrls!;
    }

    final inFlight = _lanDiscoveryFuture;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _runLanDiscovery();
    _lanDiscoveryFuture = future;

    try {
      final result = await future;
      _discoveredLanBaseUrls = result;
      return result;
    } finally {
      _lanDiscoveryFuture = null;
    }
  }

  static Future<List<String>> _runLanDiscovery() async {
    if (kIsWeb) {
      return const [];
    }

    final subnetInfos = await _privateSubnetInfos();
    if (subnetInfos.isEmpty) {
      return const [];
    }

    final discovered = <String>[];
    final seen = <String>{};

    for (final info in subnetInfos) {
      final baseUrls = _candidateLanBaseUrls(info);
      for (var i = 0; i < baseUrls.length; i += _discoveryConcurrency) {
        final chunk = baseUrls.skip(i).take(_discoveryConcurrency).toList();
        final results = await Future.wait(
          chunk.map((baseUrl) async {
            final reachable = await _probeBaseUrl(
              baseUrl,
              timeout: _probeTimeout,
            );
            return reachable ? baseUrl : null;
          }),
        );

        for (final baseUrl in results) {
          if (baseUrl != null && seen.add(baseUrl)) {
            discovered.add(baseUrl);
          }
        }

        if (discovered.isNotEmpty) {
          return discovered;
        }
      }
    }

    return discovered;
  }

  static Future<List<({String prefix, int lastOctet})>> _privateSubnetInfos() {
    return getPrivateSubnetInfos();
  }

  static List<String> _candidateLanBaseUrls(
      ({String prefix, int lastOctet}) info) {
    return _candidateHostOctets(info.lastOctet)
        .map((octet) => 'http://${info.prefix}.$octet:$_discoveryPort/api')
        .toList();
  }

  static List<int> _candidateHostOctets(int ownOctet) {
    final ordered = <int>[];
    final seen = <int>{};

    void add(int value) {
      if (value < 1 || value > 254 || value == ownOctet || !seen.add(value)) {
        return;
      }
      ordered.add(value);
    }

    for (final value in <int>[
      1,
      2,
      3,
      4,
      5,
      10,
      11,
      20,
      50,
      100,
      101,
      102,
      110,
      111,
      120,
      150,
      200,
      201,
      254,
    ]) {
      add(value);
    }

    for (var offset = 1; offset <= 12; offset++) {
      add(ownOctet - offset);
      add(ownOctet + offset);
    }

    for (var value = 1; value <= 254; value++) {
      add(value);
    }

    return ordered;
  }

  static Future<bool> _probeBaseUrl(
    String baseUrl, {
    Map<String, String>? headers,
    Duration timeout = _probeTimeout,
  }) async {
    final uri = ApiConfig.buildUri(
      baseUrl: baseUrl,
      path: _probePath,
    );

    try {
      final response = await http
          .get(
            uri,
            headers: headers ?? const {'Accept': 'application/json'},
          )
          .timeout(timeout);

      if (response.statusCode != 200) {
        return false;
      }

      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> && decoded['status'] == true;
    } catch (_) {
      return false;
    }
  }

  static void clearResolvedBaseUrl() {
    _workingBaseUrl = null;
    _discoveredLanBaseUrls = null;
    _lanDiscoveryFuture = null;
  }
}
