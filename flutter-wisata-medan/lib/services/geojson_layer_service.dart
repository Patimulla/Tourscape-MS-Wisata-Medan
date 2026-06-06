import 'package:flutter_map/flutter_map.dart';

import '../models/geojson_layer_model.dart';
import 'ci4_api_client.dart';
import 'supabase_gis_service.dart';

class GeoJsonLayerService {
  static final Map<String, Future<GeoLayerData>> _cache = {};
  static const int _minimumRoadZoom = 12;

  static Future<GeoLayerData> fetchRoadsMedan({
    required LatLngBounds bounds,
    required double zoom,
  }) {
    return _fetchRoadViewport(
      regionKey: 'roads_medan',
      path: '/roads/medan',
      bounds: bounds,
      zoom: zoom,
    );
  }

  static Future<GeoLayerData> fetchRoadsDeliSerdang({
    required LatLngBounds bounds,
    required double zoom,
  }) {
    return _fetchRoadViewport(
      regionKey: 'roads_deli_serdang',
      path: '/roads/deli-serdang',
      bounds: bounds,
      zoom: zoom,
    );
  }

  static Future<GeoLayerData> fetchBoundariesMedan() {
    return _cache.putIfAbsent('boundaries_medan', () async {
      final decoded = await _fetchFeatureCollectionPreferSupabase(
        supabaseCall: () => SupabaseGisService.fetchBoundaryFeatureCollection(
          'medan',
          zoom: 12,
        ),
        ci4Path: '/boundaries/medan',
        label: 'boundary Medan',
      );
      return GeoLayerData.fromFeatureCollection(decoded);
    });
  }

  static Future<GeoLayerData> fetchBoundariesDeliSerdang() {
    return _cache.putIfAbsent('boundaries_deli_serdang', () async {
      final decoded = await _fetchFeatureCollectionPreferSupabase(
        supabaseCall: () => SupabaseGisService.fetchBoundaryFeatureCollection(
          'deli_serdang',
          zoom: 12,
        ),
        ci4Path: '/boundaries/deli-serdang',
        label: 'boundary Deli Serdang',
      );
      return GeoLayerData.fromFeatureCollection(decoded);
    });
  }

  static Future<GeoLayerData> fetchKecamatanPolygon(int kecamatanId) {
    return _cache.putIfAbsent('kecamatan_polygon_$kecamatanId', () {
      return _fetchLayerPreferSupabase(
        supabaseCall: () => SupabaseGisService.fetchWilayahFeatureCollection(
          kecamatanId,
          zoom: 15,
        ),
        ci4Path: '/kecamatan/$kecamatanId',
        label: 'polygon kecamatan',
      );
    });
  }

  static Future<GeoLayerData> fetchWilayahPolygon(
    int wilayahId, {
    double? zoom,
  }) {
    return _cache
        .putIfAbsent('wilayah_polygon_${wilayahId}_${zoom?.round() ?? 15}', () {
      final roundedZoom = zoom?.round() ?? 15;
      return _fetchLayerPreferSupabase(
        supabaseCall: () => SupabaseGisService.fetchWilayahFeatureCollection(
          wilayahId,
          zoom: roundedZoom,
        ),
        ci4Path: '/wilayah/$wilayahId',
        queryParameters: {
          'zoom': roundedZoom.toString(),
        },
        label: 'polygon wilayah',
      );
    });
  }

  static Future<GeoLayerData> fetchRoadsByKecamatan({
    required int kecamatanId,
    required double zoom,
  }) {
    final roundedZoom = zoom.round();
    final cacheKey = 'roads_kecamatan_${kecamatanId}_$roundedZoom';

    return _cache.putIfAbsent(cacheKey, () {
      return _fetchLayerPreferSupabase(
        supabaseCall: () => SupabaseGisService.fetchRoadsByWilayah(
          kecamatanId,
          zoom: roundedZoom,
        ),
        ci4Path: '/roads/by-kecamatan/$kecamatanId',
        queryParameters: {
          'zoom': roundedZoom.toString(),
        },
        label: 'jalan kecamatan',
      );
    });
  }

  static Future<GeoLayerData> fetchRoadsByWilayah({
    required int wilayahId,
    required double zoom,
  }) {
    final roundedZoom = zoom.round();
    final cacheKey = 'roads_wilayah_${wilayahId}_$roundedZoom';

    return _cache.putIfAbsent(cacheKey, () {
      return _fetchLayerPreferSupabase(
        supabaseCall: () => SupabaseGisService.fetchRoadsByWilayah(
          wilayahId,
          zoom: roundedZoom,
        ),
        ci4Path: '/roads/by-wilayah/$wilayahId',
        queryParameters: {
          'zoom': roundedZoom.toString(),
        },
        label: 'jalan wilayah',
      );
    });
  }

  static Future<GeoLayerData> _fetchRoadViewport({
    required String regionKey,
    required String path,
    required LatLngBounds bounds,
    required double zoom,
  }) {
    if (zoom < _minimumRoadZoom) {
      return Future.value(const GeoLayerData());
    }

    final roundedZoom = zoom.round();
    final cacheKey = _buildRoadCacheKey(regionKey, bounds, roundedZoom);

    return _cache.putIfAbsent(cacheKey, () {
      return _fetchLayer(
        path,
        queryParameters: {
          'minLng': bounds.west.toStringAsFixed(6),
          'minLat': bounds.south.toStringAsFixed(6),
          'maxLng': bounds.east.toStringAsFixed(6),
          'maxLat': bounds.north.toStringAsFixed(6),
          'zoom': roundedZoom.toString(),
        },
      );
    });
  }

  static String _buildRoadCacheKey(
    String regionKey,
    LatLngBounds bounds,
    int zoom,
  ) {
    final precision = zoom >= 15 ? 4 : 3;

    String round(double value) => value.toStringAsFixed(precision);

    return [
      regionKey,
      zoom,
      round(bounds.west),
      round(bounds.south),
      round(bounds.east),
      round(bounds.north),
    ].join(':');
  }

  static Future<GeoLayerData> _fetchLayer(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final decoded = await Ci4ApiClient.getJsonMap(
      path,
      queryParameters: queryParameters,
      headers: const {
        'Accept': 'application/geo+json, application/json',
      },
    );

    return GeoLayerData.fromFeatureCollection(decoded);
  }

  static Future<GeoLayerData> _fetchLayerPreferSupabase({
    required Future<Map<String, dynamic>> Function() supabaseCall,
    required String ci4Path,
    required String label,
    Map<String, String>? queryParameters,
  }) async {
    final decoded = await _fetchFeatureCollectionPreferSupabase(
      supabaseCall: supabaseCall,
      ci4Path: ci4Path,
      queryParameters: queryParameters,
      label: label,
    );

    return GeoLayerData.fromFeatureCollection(decoded);
  }

  static Future<Map<String, dynamic>> _fetchFeatureCollectionPreferSupabase({
    required Future<Map<String, dynamic>> Function() supabaseCall,
    required String ci4Path,
    required String label,
    Map<String, String>? queryParameters,
  }) async {
    Object? supabaseError;

    try {
      return await supabaseCall();
    } catch (error) {
      supabaseError = error;
    }

    try {
      return await Ci4ApiClient.getJsonMap(
        ci4Path,
        queryParameters: queryParameters,
        headers: const {
          'Accept': 'application/geo+json, application/json',
        },
      );
    } catch (ci4Error) {
      if (supabaseError != null) {
        rethrow;
      }
      throw Exception('Gagal memuat $label.');
    }
  }

  static void clearCache() {
    _cache.clear();
    SupabaseGisService.clearCache();
  }
}
