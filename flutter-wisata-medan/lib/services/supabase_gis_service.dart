import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/wilayah_model.dart';

class SupabaseGisService {
  static final SupabaseClient _client = Supabase.instance.client;

  static final Map<String, Future<List<WilayahOption>>> _listCache = {};
  static final Map<String, Future<Map<String, dynamic>>> _featureCache = {};
  static final Map<String, Future<WilayahHierarchyResolution>> _resolutionCache = {};

  static Future<List<WilayahOption>> fetchTopLevelWilayah() {
    return _listCache.putIfAbsent('top_level_wilayah', () async {
      final rows = await _client
          .from('wilayah_administrasi')
          .select('id,nama,tipe,parent_id,wilayah')
          .order('wilayah')
          .order('tipe')
          .order('nama');

      return _parseWilayahList(rows).where((item) {
        return item.tipe == 'kota' || item.tipe == 'kabupaten';
      }).toList();
    });
  }

  static Future<List<WilayahOption>> fetchChildren(
    int parentId, {
    String? kategori,
  }) {
    final normalizedKategori = _normalizeKategori(kategori);
    final cacheKey = 'children:$parentId:${normalizedKategori.join(",")}';

    return _listCache.putIfAbsent(cacheKey, () async {
      final rows = await _client
          .from('wilayah_administrasi')
          .select('id,nama,tipe,parent_id,wilayah')
          .eq('parent_id', parentId)
          .order('tipe')
          .order('nama');

      var items = _parseWilayahList(rows);

      if (normalizedKategori.isNotEmpty) {
        items = items.where((item) => normalizedKategori.contains(item.tipe)).toList();
      }

      return items;
    });
  }

  static Future<List<WilayahOption>> fetchKecamatan({
    int? wilayahId,
    String? wilayah,
  }) {
    final cacheKey = 'kecamatan:${wilayahId ?? 0}:${wilayah ?? ""}';

    return _listCache.putIfAbsent(cacheKey, () async {
      final rows = await _client
          .from('wilayah_administrasi')
          .select('id,nama,tipe,parent_id,wilayah')
          .eq('tipe', 'kecamatan')
          .order('nama');

      return _parseWilayahList(rows).where((item) {
        if (wilayahId != null) {
          return item.parentId == wilayahId;
        }

        if (wilayah != null && wilayah.isNotEmpty) {
          return item.wilayah == wilayah;
        }

        return true;
      }).toList();
    });
  }

  static Future<List<WilayahOption>> fetchKelurahan({
    required int kecamatanId,
  }) {
    final cacheKey = 'kelurahan:$kecamatanId';

    return _listCache.putIfAbsent(cacheKey, () async {
      final rows = await _client
          .from('wilayah_administrasi')
          .select('id,nama,tipe,parent_id,wilayah')
          .eq('parent_id', kecamatanId)
          .order('tipe')
          .order('nama');

      return _parseWilayahList(rows).where((item) {
        return item.tipe == 'kelurahan' || item.tipe == 'desa';
      }).toList();
    });
  }

  static Future<Map<String, dynamic>> fetchBoundaryFeatureCollection(
    String wilayah, {
    int zoom = 12,
  }) {
    final cacheKey = 'boundary:$wilayah:$zoom';

    return _featureCache.putIfAbsent(cacheKey, () async {
      final roots = await fetchTopLevelWilayah();
      final root = roots.cast<WilayahOption?>().firstWhere(
            (item) => item?.wilayah == wilayah,
            orElse: () => null,
          );

      if (root == null) {
        return _emptyFeatureCollection();
      }

      return fetchWilayahFeatureCollection(root.id, zoom: zoom);
    });
  }

  static Future<Map<String, dynamic>> fetchWilayahFeatureCollection(
    int wilayahId, {
    int zoom = 15,
  }) {
    final cacheKey = 'wilayah_feature:$wilayahId:$zoom';

    return _featureCache.putIfAbsent(cacheKey, () async {
      final response = await _client.rpc(
        'mobile_wilayah_feature',
        params: {
          'p_id': wilayahId,
          'p_zoom': zoom,
        },
      );
      return _normalizeFeatureCollection(response);
    });
  }

  static Future<Map<String, dynamic>> fetchRoadsByWilayah(
    int wilayahId, {
    int zoom = 15,
  }) {
    final cacheKey = 'roads_by_wilayah:$wilayahId:$zoom';

    return _featureCache.putIfAbsent(cacheKey, () async {
      final response = await _client.rpc(
        'mobile_roads_by_wilayah',
        params: {
          'p_id': wilayahId,
          'p_zoom': zoom,
        },
      );
      return _normalizeFeatureCollection(response);
    });
  }

  static Future<WilayahHierarchyResolution> resolveWilayahFromPoint({
    required double lat,
    required double lng,
  }) {
    final cacheKey = 'resolve_point:${lat.toStringAsFixed(6)}:${lng.toStringAsFixed(6)}';

    return _resolutionCache.putIfAbsent(cacheKey, () async {
      final response = await _client.rpc(
        'mobile_resolve_wilayah_from_point',
        params: {
          'p_lat': lat,
          'p_lng': lng,
        },
      );

      final normalized = _normalizeJsonMap(response);
      if (normalized.isEmpty) {
        return const WilayahHierarchyResolution(
          matched: false,
          topLevel: null,
          kecamatan: null,
          leaf: null,
        );
      }

      return WilayahHierarchyResolution.fromJson(normalized);
    });
  }

  static void clearCache() {
    _listCache.clear();
    _featureCache.clear();
    _resolutionCache.clear();
  }

  static List<String> _normalizeKategori(String? kategori) {
    if (kategori == null || kategori.trim().isEmpty) {
      return const [];
    }

    return kategori
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  static List<WilayahOption> _parseWilayahList(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value
        .map(_normalizeJsonMap)
        .where((item) => item.isNotEmpty)
        .map(WilayahOption.fromJson)
        .where((item) => item.id > 0 && item.nama.isNotEmpty)
        .toList();
  }

  static Map<String, dynamic> _normalizeFeatureCollection(dynamic value) {
    final normalized = _normalizeJsonMap(value);
    if (normalized.isNotEmpty) {
      return normalized;
    }

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        try {
          return _normalizeJsonMap(jsonDecode(trimmed));
        } catch (_) {
          return _emptyFeatureCollection();
        }
      }
    }

    return _emptyFeatureCollection();
  }

  static Map<String, dynamic> _normalizeJsonMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      final result = <String, dynamic>{};
      value.forEach((key, entryValue) {
        result[key.toString()] = entryValue;
      });
      return result;
    }

    return const <String, dynamic>{};
  }

  static Map<String, dynamic> _emptyFeatureCollection() {
    return const <String, dynamic>{
      'type': 'FeatureCollection',
      'features': <dynamic>[],
    };
  }
}
