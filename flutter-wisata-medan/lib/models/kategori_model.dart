/// ============================================================
/// Tourscape MS — Model Kategori
/// ============================================================

class Kategori {
  final int id;
  final String namaKategori;

  Kategori({
    required this.id,
    required this.namaKategori,
  });

  factory Kategori.fromJson(Map<String, dynamic> json) {
    return Kategori(
      id: int.tryParse(json['id'].toString()) ?? 0,
      namaKategori: json['nama_kategori'] ?? '',
    );
  }

  @override
  String toString() => namaKategori;
}
