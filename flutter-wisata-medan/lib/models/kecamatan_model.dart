class KecamatanOption {
  final int id;
  final String namaKecamatan;
  final String wilayah;

  const KecamatanOption({
    required this.id,
    required this.namaKecamatan,
    required this.wilayah,
  });

  String get wilayahLabel => wilayah == 'medan' ? 'Medan' : 'Deli Serdang';

  factory KecamatanOption.fromJson(Map<String, dynamic> json) {
    return KecamatanOption(
      id: (json['id'] as num?)?.toInt() ?? 0,
      namaKecamatan: (json['nama_kecamatan'] ?? '').toString(),
      wilayah: (json['wilayah'] ?? '').toString(),
    );
  }
}
