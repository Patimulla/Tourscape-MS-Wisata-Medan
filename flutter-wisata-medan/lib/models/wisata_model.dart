/// ============================================================
/// Tourscape MS — Model Wisata
/// ============================================================

import 'dart:convert';

class Wisata {
  final int id;
  final String namaTempat;
  final String? deskripsi;
  final String? alamat;
  final String? kecamatan;
  final String? kelurahan;
  final double? latitude;
  final double? longitude;
  final String? kategori;
  final int? kategoriId;
  final String? targetPengunjung;
  final String? jamBuka;
  final String? jamTutup;
  final String? hariOperasional;
  final double? hargaTiket;
  final String? keteranganHarga;
  final String? noTelepon;
  final String? status;
  final String? submitterUserId;
  final String? submitterNama;
  final String? submitterNoPegawai;
  final String? catatanAdmin;
  final double? rating;
  final double? ratingAvg;
  final int? totalReview;
  final double? jarakKm;
  final List<String> fasilitas;
  final List<String> foto;
  final bool toilet;
  final bool parkir;
  final bool areaBermain;
  final bool tempatMakan;
  final bool mushola;
  final bool wifi;

  Wisata({
    required this.id,
    required this.namaTempat,
    this.deskripsi,
    this.alamat,
    this.kecamatan,
    this.kelurahan,
    this.latitude,
    this.longitude,
    this.kategori,
    this.kategoriId,
    this.targetPengunjung,
    this.jamBuka,
    this.jamTutup,
    this.hariOperasional,
    this.hargaTiket,
    this.keteranganHarga,
    this.noTelepon,
    this.status,
    this.submitterUserId,
    this.submitterNama,
    this.submitterNoPegawai,
    this.catatanAdmin,
    this.rating,
    this.ratingAvg,
    this.totalReview,
    this.jarakKm,
    this.fasilitas = const [],
    this.foto = const [],
    this.toilet = false,
    this.parkir = false,
    this.areaBermain = false,
    this.tempatMakan = false,
    this.mushola = false,
    this.wifi = false,
  });

  Wisata copyWith({
    int? id,
    String? namaTempat,
    String? deskripsi,
    String? alamat,
    String? kecamatan,
    String? kelurahan,
    double? latitude,
    double? longitude,
    String? kategori,
    int? kategoriId,
    String? targetPengunjung,
    String? jamBuka,
    String? jamTutup,
    String? hariOperasional,
    double? hargaTiket,
    String? keteranganHarga,
    String? noTelepon,
    String? status,
    String? submitterUserId,
    String? submitterNama,
    String? submitterNoPegawai,
    String? catatanAdmin,
    double? rating,
    double? ratingAvg,
    int? totalReview,
    double? jarakKm,
    List<String>? fasilitas,
    List<String>? foto,
    bool? toilet,
    bool? parkir,
    bool? areaBermain,
    bool? tempatMakan,
    bool? mushola,
    bool? wifi,
  }) {
    return Wisata(
      id: id ?? this.id,
      namaTempat: namaTempat ?? this.namaTempat,
      deskripsi: deskripsi ?? this.deskripsi,
      alamat: alamat ?? this.alamat,
      kecamatan: kecamatan ?? this.kecamatan,
      kelurahan: kelurahan ?? this.kelurahan,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      kategori: kategori ?? this.kategori,
      kategoriId: kategoriId ?? this.kategoriId,
      targetPengunjung: targetPengunjung ?? this.targetPengunjung,
      jamBuka: jamBuka ?? this.jamBuka,
      jamTutup: jamTutup ?? this.jamTutup,
      hariOperasional: hariOperasional ?? this.hariOperasional,
      hargaTiket: hargaTiket ?? this.hargaTiket,
      keteranganHarga: keteranganHarga ?? this.keteranganHarga,
      noTelepon: noTelepon ?? this.noTelepon,
      status: status ?? this.status,
      submitterUserId: submitterUserId ?? this.submitterUserId,
      submitterNama: submitterNama ?? this.submitterNama,
      submitterNoPegawai: submitterNoPegawai ?? this.submitterNoPegawai,
      catatanAdmin: catatanAdmin ?? this.catatanAdmin,
      rating: rating ?? this.rating,
      ratingAvg: ratingAvg ?? this.ratingAvg,
      totalReview: totalReview ?? this.totalReview,
      jarakKm: jarakKm ?? this.jarakKm,
      fasilitas: fasilitas ?? this.fasilitas,
      foto: foto ?? this.foto,
      toilet: toilet ?? this.toilet,
      parkir: parkir ?? this.parkir,
      areaBermain: areaBermain ?? this.areaBermain,
      tempatMakan: tempatMakan ?? this.tempatMakan,
      mushola: mushola ?? this.mushola,
      wifi: wifi ?? this.wifi,
    );
  }

  factory Wisata.fromJson(Map<String, dynamic> json) {
    // Parse fasilitas — bisa berupa List<String> atau List<Map>
    List<String> parseFasilitas(dynamic data) {
      if (data == null) return [];
      if (data is List) {
        return data
            .map((e) {
              if (e is String) return e;
              if (e is Map) return e['nama_fasilitas']?.toString() ?? '';
              return '';
            })
            .where((e) => e.isNotEmpty)
            .toList();
      }
      return [];
    }

    // Parse foto
    List<String> parseFoto(dynamic data) {
      if (data == null) return [];
      if (data is String) {
        final text = data.trim();
        if (text.isEmpty) return [];

        if (text.startsWith('[') && text.endsWith(']')) {
          try {
            return parseFoto(jsonDecode(text));
          } catch (_) {
            // Fallback ke parser string biasa.
          }
        }

        final normalized = text.replaceAll('\r\n', '\n');
        final parts = normalized.contains(',')
            ? normalized.split(',')
            : normalized.split('\n');

        return parts
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList();
      }
      if (data is List) {
        return data
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList();
      }
      return [];
    }

    bool parseBool(dynamic value) {
      if (value is bool) return value;
      final normalized = value?.toString().trim().toLowerCase() ?? '';
      return normalized == 'true' ||
          normalized == '1' ||
          normalized == 't' ||
          normalized == 'yes';
    }

    final rawRating = double.tryParse(json['rating']?.toString() ?? '');
    final rawRatingAvg = double.tryParse(json['rating_avg']?.toString() ?? '');

    return Wisata(
      id: int.tryParse(json['id'].toString()) ?? 0,
      namaTempat: json['nama_tempat'] ?? '',
      deskripsi: json['deskripsi'],
      alamat: json['alamat'],
      kecamatan: json['kecamatan'],
      kelurahan: json['kelurahan'],
      latitude: double.tryParse(json['latitude']?.toString() ?? ''),
      longitude: double.tryParse(json['longitude']?.toString() ?? ''),
      kategori: json['kategori'],
      kategoriId: int.tryParse(json['kategori_id']?.toString() ?? ''),
      targetPengunjung: json['target_pengunjung'],
      jamBuka: json['jam_buka'],
      jamTutup: json['jam_tutup'],
      hariOperasional: json['hari_operasional'],
      hargaTiket: double.tryParse(json['harga_tiket']?.toString() ?? ''),
      keteranganHarga: json['keterangan_harga'],
      noTelepon: json['no_telepon'],
      status: json['status'],
      submitterUserId: json['submitter_user_id']?.toString(),
      submitterNama: json['submitter_nama']?.toString(),
      submitterNoPegawai: json['submitter_no_pegawai']?.toString(),
      catatanAdmin: json['catatan_admin']?.toString(),
      rating: rawRating,
      ratingAvg: rawRatingAvg ?? rawRating,
      totalReview: int.tryParse(json['total_review']?.toString() ?? ''),
      jarakKm: double.tryParse(json['jarak_km']?.toString() ?? ''),
      fasilitas: parseFasilitas(json['fasilitas']),
      foto: parseFoto(json['foto']),
      toilet: parseBool(json['toilet']),
      parkir: parseBool(json['parkir']),
      areaBermain: parseBool(json['area_bermain']),
      tempatMakan: parseBool(json['tempat_makan']),
      mushola: parseBool(json['mushola']),
      wifi: parseBool(json['wifi']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nama_tempat': namaTempat,
      'deskripsi': deskripsi,
      'alamat': alamat,
      'kecamatan': kecamatan,
      'kelurahan': kelurahan,
      'latitude': latitude,
      'longitude': longitude,
      'kategori_id': kategoriId,
      'target_pengunjung': targetPengunjung,
      'jam_buka': jamBuka,
      'jam_tutup': jamTutup,
      'hari_operasional': hariOperasional,
      'harga_tiket': hargaTiket,
      'keterangan_harga': keteranganHarga,
      'no_telepon': noTelepon,
      'submitter_user_id': submitterUserId,
      'submitter_nama': submitterNama,
      'submitter_no_pegawai': submitterNoPegawai,
      'catatan_admin': catatanAdmin,
    };
  }

  bool get canEditBySubmitter => status == 'pending' || status == 'rejected';
}
