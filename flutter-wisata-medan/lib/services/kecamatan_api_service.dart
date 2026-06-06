import '../models/kecamatan_model.dart';
import 'ci4_api_client.dart';
import 'supabase_gis_service.dart';

class KecamatanApiService {
  static Future<List<KecamatanOption>> fetchKecamatanList() async {
    Object? supabaseError;

    try {
      final items = await SupabaseGisService.fetchKecamatan();
      return items
          .map(
            (item) => KecamatanOption(
              id: item.id,
              namaKecamatan: item.nama,
              wilayah: item.wilayah,
            ),
          )
          .where((item) => item.id > 0 && item.namaKecamatan.isNotEmpty)
          .toList();
    } catch (error) {
      supabaseError = error;
    }

    try {
      final decoded = await Ci4ApiClient.getJsonMap(
        '/kecamatan',
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
          .map(KecamatanOption.fromJson)
          .where((item) => item.id > 0 && item.namaKecamatan.isNotEmpty)
          .toList();
    } catch (ci4Error) {
      if (supabaseError != null) {
        rethrow;
      }
      throw Exception('Gagal memuat daftar kecamatan.');
    }
  }
}
