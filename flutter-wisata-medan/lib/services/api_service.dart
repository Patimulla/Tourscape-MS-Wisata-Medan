/// ============================================================
/// Tourscape MS — API Service
/// HTTP service untuk semua komunikasi dengan backend CI4
/// ============================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import '../models/kategori_model.dart';
import '../models/wisata_model.dart';
import 'ci4_api_client.dart';

class ApiService {
  // ============================================================
  // WISATA
  // ============================================================

  /// Ambil semua wisata (approved)
  /// Optional: filter berdasarkan kategori
  static Future<List<Wisata>> getWisataList({String? kategori}) async {
    try {
      final json = await Ci4ApiClient.getJsonMap(
        '/wisata',
        queryParameters: kategori != null && kategori.isNotEmpty
            ? {'kategori': kategori}
            : null,
        headers: {'Accept': 'application/json'},
      );

      if (json['status'] == true && json['data'] is List) {
        return (json['data'] as List)
            .map((item) => Wisata.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error getWisataList: $e');
      return [];
    }
  }

  /// Ambil detail wisata berdasarkan ID
  static Future<Wisata?> getWisataDetail(
    int id, {
    bool logErrors = true,
  }) async {
    try {
      final json = await Ci4ApiClient.getJsonMap(
        '/wisata/$id',
        headers: {'Accept': 'application/json'},
      );

      if (json['status'] == true && json['data'] is Map<String, dynamic>) {
        return Wisata.fromJson(json['data'] as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      if (logErrors) {
        print('Error getWisataDetail: $e');
      }
      return null;
    }
  }

  /// Cari wisata terdekat dari koordinat user
  static Future<List<Wisata>> getNearbyWisata({
    required double lat,
    required double lng,
    int limit = 5,
  }) async {
    try {
      final json = await Ci4ApiClient.getJsonMap(
        '/wisata/nearby',
        queryParameters: {
          'lat': '$lat',
          'lng': '$lng',
          'limit': '$limit',
        },
        headers: {'Accept': 'application/json'},
      );

      if (json['status'] == true && json['data'] is List) {
        return (json['data'] as List)
            .map((item) => Wisata.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error getNearbyWisata: $e');
      return [];
    }
  }

  /// Kirim data wisata baru (POST) — status = pending
  static Future<Map<String, dynamic>> postWisata({
    required String namaTempat,
    String? deskripsi,
    String? alamat,
    String? kecamatan,
    String? kelurahan,
    required double latitude,
    required double longitude,
    String? kategori,
    String? targetPengunjung,
    String? jamBuka,
    String? jamTutup,
    String? hariOperasional,
    double? hargaTiket,
    String? keteranganHarga,
    String? noTelepon,
    bool toilet = false,
    bool parkir = false,
    bool areaBermain = false,
    bool tempatMakan = false,
    bool mushola = false,
    bool wifi = false,
    String? fotoPath,
  }) async {
    try {
      final uri = await Ci4ApiClient.resolveUri(
        '/wisata',
        headers: {'Accept': 'application/json'},
      );
      var request = http.MultipartRequest('POST', uri);

      // Tambahkan headers
      request.headers.addAll({
        'Accept': 'application/json',
      });

      // Tambahkan fields data text
      request.fields['nama_tempat'] = namaTempat;
      if (deskripsi != null) request.fields['deskripsi'] = deskripsi;
      if (alamat != null) request.fields['alamat'] = alamat;
      if (kecamatan != null) request.fields['kecamatan'] = kecamatan;
      if (kelurahan != null) request.fields['kelurahan'] = kelurahan;
      request.fields['latitude'] = latitude.toString();
      request.fields['longitude'] = longitude.toString();
      if (kategori != null) request.fields['kategori'] = kategori;
      if (targetPengunjung != null)
        request.fields['target_pengunjung'] = targetPengunjung;
      if (jamBuka != null) request.fields['jam_buka'] = jamBuka;
      if (jamTutup != null) request.fields['jam_tutup'] = jamTutup;
      if (hariOperasional != null)
        request.fields['hari_operasional'] = hariOperasional;
      if (hargaTiket != null)
        request.fields['harga_tiket'] = hargaTiket.toString();
      if (keteranganHarga != null)
        request.fields['keterangan_harga'] = keteranganHarga;
      if (noTelepon != null) request.fields['no_telepon'] = noTelepon;

      // Boolean fasilitas
      if (toilet) request.fields['toilet'] = '1';
      if (parkir) request.fields['parkir'] = '1';
      if (areaBermain) request.fields['area_bermain'] = '1';
      if (tempatMakan) request.fields['tempat_makan'] = '1';
      if (mushola) request.fields['mushola'] = '1';
      if (wifi) request.fields['wifi'] = '1';

      // Tambahkan file foto jika ada
      if (fotoPath != null && fotoPath.isNotEmpty) {
        final mimeTypeData =
            lookupMimeType(fotoPath, headerBytes: [0xFF, 0xD8])?.split('/');
        request.files.add(
          await http.MultipartFile.fromPath(
            'foto',
            fotoPath,
            contentType: mimeTypeData != null
                ? MediaType(mimeTypeData[0], mimeTypeData[1])
                : MediaType('image', 'jpeg'),
          ),
        );
      }

      // Kirim request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      try {
        final json = jsonDecode(response.body);
        return {
          'success': response.statusCode == 201 || response.statusCode == 200,
          'message': json['message'] ?? 'Unknown error',
          'data': json['data'],
        };
      } catch (e) {
        String errorSnippet = response.body.length > 200
            ? response.body.substring(0, 200)
            : response.body;
        return {
          'success': false,
          'message':
              'Server error (Format/HTML). Code: ${response.statusCode}. Body: $errorSnippet',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Gagal mengirim data: $e',
      };
    }
  }

  // ============================================================
  // KATEGORI
  // ============================================================

  /// Ambil semua kategori
  static Future<List<Kategori>> getKategoriList() async {
    try {
      final json = await Ci4ApiClient.getJsonMap(
        '/kategori',
        headers: {'Accept': 'application/json'},
      );

      if (json['status'] == true && json['data'] is List) {
        return (json['data'] as List)
            .map((item) => Kategori.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error getKategoriList: $e');
      return [];
    }
  }
}
