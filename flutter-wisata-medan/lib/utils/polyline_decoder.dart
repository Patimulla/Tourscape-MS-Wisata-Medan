/// ============================================================
/// Tourscape MS — Polyline Decoder
/// Decode encoded polyline string (Google format) to List<LatLng>
/// Used for OSRM route geometry decoding
/// ============================================================

import 'package:latlong2/latlong.dart' as latlng;

class PolylineDecoder {
  /// Decode an encoded polyline string into a list of LatLng coordinates.
  /// Algorithm reference: https://developers.google.com/maps/documentation/utilities/polylinealgorithm
  static List<latlng.LatLng> decode(String encoded) {
    final List<latlng.LatLng> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      // Decode latitude
      int shift = 0;
      int result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      // Decode longitude
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add(latlng.LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }
}
