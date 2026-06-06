import 'dart:convert';

import 'package:latlong2/latlong.dart';

class GeoLineFeature {
  final List<LatLng> points;
  final Map<String, dynamic> properties;

  const GeoLineFeature({
    required this.points,
    this.properties = const {},
  });
}

class GeoPolygonFeature {
  final List<LatLng> points;
  final List<List<LatLng>> holes;
  final Map<String, dynamic> properties;

  const GeoPolygonFeature({
    required this.points,
    this.holes = const [],
    this.properties = const {},
  });
}

class GeoLayerData {
  final List<GeoLineFeature> lines;
  final List<GeoPolygonFeature> polygons;

  const GeoLayerData({
    this.lines = const [],
    this.polygons = const [],
  });

  bool get isEmpty => lines.isEmpty && polygons.isEmpty;

  factory GeoLayerData.fromFeatureCollection(Map<String, dynamic> json) {
    final normalizedRoot = _normalizeJsonMap(json);
    final features = normalizedRoot['features'];
    if (normalizedRoot['type'] != 'FeatureCollection' || features is! List) {
      return const GeoLayerData();
    }

    final parsedLines = <GeoLineFeature>[];
    final parsedPolygons = <GeoPolygonFeature>[];

    for (final feature in features) {
      final normalizedFeature = _normalizeJsonMap(feature);
      if (normalizedFeature.isEmpty) {
        continue;
      }

      final geometry = _normalizeGeometry(normalizedFeature['geometry']);
      if (geometry.isEmpty) {
        continue;
      }

      final properties = _normalizeJsonMap(normalizedFeature['properties']);

      final type = geometry['type'];
      final coordinates = geometry['coordinates'];

      switch (type) {
        case 'LineString':
          final points = _parseLineString(coordinates);
          if (points.length >= 2) {
            parsedLines.add(GeoLineFeature(points: points, properties: properties));
          }
          break;
        case 'MultiLineString':
          if (coordinates is List) {
            for (final line in coordinates) {
              final points = _parseLineString(line);
              if (points.length >= 2) {
                parsedLines.add(GeoLineFeature(points: points, properties: properties));
              }
            }
          }
          break;
        case 'Polygon':
          final polygon = _parsePolygon(coordinates, properties);
          if (polygon != null) {
            parsedPolygons.add(polygon);
          }
          break;
        case 'MultiPolygon':
          if (coordinates is List) {
            for (final polygonCoordinates in coordinates) {
              final polygon = _parsePolygon(polygonCoordinates, properties);
              if (polygon != null) {
                parsedPolygons.add(polygon);
              }
            }
          }
          break;
      }
    }

    return GeoLayerData(lines: parsedLines, polygons: parsedPolygons);
  }

  static List<LatLng> _parseLineString(dynamic coordinates) {
    if (coordinates is! List) {
      return const [];
    }

    final points = <LatLng>[];
    for (final point in coordinates) {
      final latLng = _parseLatLng(point);
      if (latLng != null) {
        points.add(latLng);
      }
    }
    return points;
  }

  static GeoPolygonFeature? _parsePolygon(dynamic coordinates, Map<String, dynamic> properties) {
    if (coordinates is! List || coordinates.isEmpty) {
      return null;
    }

    final outerRing = _parseLineString(coordinates.first);
    if (outerRing.length < 3) {
      return null;
    }

    final holes = <List<LatLng>>[];
    for (var i = 1; i < coordinates.length; i++) {
      final holeRing = _parseLineString(coordinates[i]);
      if (holeRing.length >= 3) {
        holes.add(holeRing);
      }
    }

    return GeoPolygonFeature(
      points: outerRing,
      holes: holes,
      properties: properties,
    );
  }

  static LatLng? _parseLatLng(dynamic point) {
    if (point is! List || point.length < 2) {
      return null;
    }

    final lng = (point[0] as num?)?.toDouble();
    final lat = (point[1] as num?)?.toDouble();

    if (lat == null || lng == null) {
      return null;
    }

    return LatLng(lat, lng);
  }

  static Map<String, dynamic> _normalizeGeometry(dynamic geometry) {
    final normalized = _normalizeJsonMap(geometry);
    if (normalized.isNotEmpty) {
      return normalized;
    }

    if (geometry is String) {
      final trimmed = geometry.trim();
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        try {
          final decoded = jsonDecode(trimmed);
          return _normalizeJsonMap(decoded);
        } catch (_) {
          return const <String, dynamic>{};
        }
      }
    }

    return const <String, dynamic>{};
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
}
