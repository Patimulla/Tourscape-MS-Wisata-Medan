import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/wisata_model.dart';

class SupabaseWisataService {
  static final SupabaseClient _client = Supabase.instance.client;

  static final Map<int, Future<Wisata?>> _rowCache = {};
  static final Map<int, Future<List<String>>> _galleryCache = {};
  static final Map<int, Future<_ReviewSummary>> _reviewCache = {};

  static const String _detailSelect = '''
id,
nama_tempat,
deskripsi,
alamat,
kecamatan,
kelurahan,
latitude,
longitude,
kategori,
kategori_id,
target_pengunjung,
jam_buka,
jam_tutup,
hari_operasional,
harga_tiket,
keterangan_harga,
no_telepon,
status,
submitter_user_id,
catatan_admin,
rating,
foto,
toilet,
parkir,
area_bermain,
tempat_makan,
mushola,
wifi
''';

  static Future<Wisata?> fetchWisataDetail(
    int wisataId, {
    Wisata? seedWisata,
  }) async {
    final galleryFuture = _fetchGalleryUrls(wisataId);
    final reviewFuture = _fetchReviewSummary(wisataId);

    final baseWisata = seedWisata ?? await _fetchWisataRow(wisataId);
    if (baseWisata == null) {
      return null;
    }

    final galleryUrls = await galleryFuture;
    final reviewSummary = await reviewFuture;

    final mergedPhotos = <String>[
      ...baseWisata.foto,
      ...galleryUrls,
    ]
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();

    return baseWisata.copyWith(
      foto: mergedPhotos,
      ratingAvg: reviewSummary.totalReview > 0
          ? reviewSummary.ratingAvg
          : (baseWisata.ratingAvg ?? baseWisata.rating),
      totalReview: reviewSummary.totalReview > 0
          ? reviewSummary.totalReview
          : baseWisata.totalReview,
    );
  }

  static Future<Wisata?> _fetchWisataRow(int wisataId) {
    return _rowCache.putIfAbsent(wisataId, () async {
      final row = await _client
          .from('wisata')
          .select(_detailSelect)
          .eq('id', wisataId)
          .maybeSingle();

      final normalized = _normalizeMap(row);
      if (normalized.isEmpty) {
        return null;
      }

      return Wisata.fromJson(normalized);
    });
  }

  static Future<List<String>> _fetchGalleryUrls(int wisataId) {
    return _galleryCache.putIfAbsent(wisataId, () async {
      try {
        final rows = await _client
            .from('wisata_foto')
            .select('foto_url')
            .eq('wisata_id', wisataId)
            .order('created_at', ascending: true);

        return rows
            .map(_normalizeMap)
            .map((row) => row['foto_url']?.toString().trim() ?? '')
            .where((url) => url.isNotEmpty)
            .toSet()
            .toList();
      } catch (error) {
        debugPrint('Gallery fetch error for wisata $wisataId: $error');
        return const <String>[];
      }
    });
  }

  static Future<_ReviewSummary> _fetchReviewSummary(int wisataId) {
    return _reviewCache.putIfAbsent(wisataId, () async {
      try {
        final rows = await _client
            .from('review')
            .select('rating')
            .eq('wisata_id', wisataId);

        if (rows.isEmpty) {
          return const _ReviewSummary();
        }

        var total = 0.0;
        var count = 0;

        for (final row in rows) {
          final rating = double.tryParse(
            _normalizeMap(row)['rating']?.toString() ?? '',
          );
          if (rating == null) {
            continue;
          }

          total += rating;
          count++;
        }

        if (count == 0) {
          return const _ReviewSummary();
        }

        return _ReviewSummary(
          ratingAvg: total / count,
          totalReview: count,
        );
      } catch (error) {
        debugPrint('Review summary error for wisata $wisataId: $error');
        return const _ReviewSummary();
      }
    });
  }

  static Map<String, dynamic> _normalizeMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      final normalized = <String, dynamic>{};
      value.forEach((key, entryValue) {
        normalized[key.toString()] = entryValue;
      });
      return normalized;
    }

    return const <String, dynamic>{};
  }

  static void clearCache() {
    _rowCache.clear();
    _galleryCache.clear();
    _reviewCache.clear();
  }

  static Future<void> deleteSubmission(Wisata wisata) async {
    if (!wisata.canEditBySubmitter) {
      throw Exception('Pengajuan ini tidak bisa dibatalkan');
    }

    final detail = await fetchWisataDetail(
      wisata.id,
      seedWisata: wisata,
    );

    final storagePaths = _extractWisataStoragePaths(detail?.foto ?? wisata.foto);

    await _client.rpc(
      'delete_wisata_submission',
      params: {'p_id': wisata.id},
    );

    _rowCache.remove(wisata.id);
    _galleryCache.remove(wisata.id);
    _reviewCache.remove(wisata.id);

    if (storagePaths.isNotEmpty) {
      try {
        await _client.storage.from('wisata').remove(storagePaths);
      } catch (error) {
        debugPrint('Storage cleanup warning for wisata ${wisata.id}: $error');
      }
    }
  }

  static List<String> _extractWisataStoragePaths(List<String> urls) {
    const marker = '/storage/v1/object/public/wisata/';
    final paths = <String>{};

    for (final rawUrl in urls) {
      final url = rawUrl.trim();
      if (url.isEmpty) {
        continue;
      }

      final markerIndex = url.indexOf(marker);
      if (markerIndex < 0) {
        continue;
      }

      final encodedPath = url.substring(markerIndex + marker.length);
      final objectPath = Uri.decodeFull(encodedPath.split('?').first).trim();
      if (objectPath.isNotEmpty) {
        paths.add(objectPath);
      }
    }

    return paths.toList();
  }
}

class _ReviewSummary {
  final double ratingAvg;
  final int totalReview;

  const _ReviewSummary({
    this.ratingAvg = 0,
    this.totalReview = 0,
  });
}
