import '../models/wilayah_model.dart';
import 'ci4_api_client.dart';
import 'supabase_gis_service.dart';

class WilayahApiService {
  static Future<List<WilayahOption>> fetchTopLevelWilayah() async {
    return _preferSupabase(
      supabaseCall: SupabaseGisService.fetchTopLevelWilayah,
      ci4Call: () => _fetchList(
        '/wilayah',
        queryParameters: const {
          'kategori': 'kota,kabupaten',
          'per_page': '20',
        },
      ),
      label: 'daftar wilayah',
    );
  }

  static Future<List<WilayahOption>> fetchChildren(
    int parentId, {
    String? kategori,
  }) async {
    return _preferSupabase(
      supabaseCall: () => SupabaseGisService.fetchChildren(
        parentId,
        kategori: kategori,
      ),
      ci4Call: () => _fetchList(
        '/wilayah/children/$parentId',
        queryParameters: kategori == null || kategori.isEmpty
            ? null
            : {'kategori': kategori},
      ),
      label: 'children wilayah',
    );
  }

  static Future<List<WilayahOption>> fetchKecamatan({
    int? wilayahId,
    String? wilayah,
  }) async {
    final query = <String, String>{};
    if (wilayahId != null) {
      query['wilayah_id'] = wilayahId.toString();
    }
    if (wilayah != null && wilayah.isNotEmpty) {
      query['wilayah'] = wilayah;
    }

    return _preferSupabase(
      supabaseCall: () => SupabaseGisService.fetchKecamatan(
        wilayahId: wilayahId,
        wilayah: wilayah,
      ),
      ci4Call: () => _fetchList('/wilayah/kecamatan', queryParameters: query),
      label: 'daftar kecamatan',
    );
  }

  static Future<List<WilayahOption>> fetchKelurahan({
    required int kecamatanId,
  }) async {
    return _preferSupabase(
      supabaseCall: () => SupabaseGisService.fetchKelurahan(
        kecamatanId: kecamatanId,
      ),
      ci4Call: () => _fetchList(
        '/wilayah/kelurahan',
        queryParameters: {
          'kecamatan_id': kecamatanId.toString(),
        },
      ),
      label: 'daftar kelurahan/desa',
    );
  }

  static Future<WilayahHierarchyResolution> resolveFromPoint({
    required double lat,
    required double lng,
  }) {
    return SupabaseGisService.resolveWilayahFromPoint(
      lat: lat,
      lng: lng,
    );
  }

  static Future<List<WilayahOption>> _fetchList(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final decoded = await Ci4ApiClient.getJsonMap(
      path,
      queryParameters: queryParameters,
      headers: const {
        'Accept': 'application/json',
      },
    );

    final data = decoded['data'];
    if (data is! List) {
      return const [];
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(WilayahOption.fromJson)
        .where((item) => item.id > 0 && item.nama.isNotEmpty)
        .toList();
  }

  static Future<T> _preferSupabase<T>({
    required Future<T> Function() supabaseCall,
    required Future<T> Function() ci4Call,
    required String label,
  }) async {
    Object? supabaseError;

    try {
      return await supabaseCall();
    } catch (error) {
      supabaseError = error;
    }

    try {
      return await ci4Call();
    } catch (ci4Error) {
      if (supabaseError != null) {
        rethrow;
      }
      throw Exception('Gagal memuat $label.');
    }
  }
}
