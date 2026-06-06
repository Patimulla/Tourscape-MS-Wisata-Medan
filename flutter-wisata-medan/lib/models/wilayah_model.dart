class WilayahOption {
  final int id;
  final String nama;
  final String tipe;
  final int? parentId;
  final String wilayah;

  const WilayahOption({
    required this.id,
    required this.nama,
    required this.tipe,
    required this.parentId,
    required this.wilayah,
  });

  String get wilayahLabel => wilayah == 'medan' ? 'Medan' : 'Deli Serdang';

  String get tipeLabel {
    switch (tipe) {
      case 'kota':
        return 'Kota';
      case 'kabupaten':
        return 'Kabupaten';
      case 'kecamatan':
        return 'Kecamatan';
      case 'kelurahan':
        return 'Kelurahan';
      case 'desa':
        return 'Desa';
      default:
        return tipe;
    }
  }

  factory WilayahOption.fromJson(Map<String, dynamic> json) {
    return WilayahOption(
      id: (json['id'] as num?)?.toInt() ?? 0,
      nama: (json['nama'] ?? '').toString(),
      tipe: (json['tipe'] ?? '').toString(),
      parentId: (json['parent_id'] as num?)?.toInt(),
      wilayah: (json['wilayah'] ?? '').toString(),
    );
  }
}

class WilayahHierarchyResolution {
  final bool matched;
  final WilayahOption? topLevel;
  final WilayahOption? kecamatan;
  final WilayahOption? leaf;

  const WilayahHierarchyResolution({
    required this.matched,
    required this.topLevel,
    required this.kecamatan,
    required this.leaf,
  });

  bool get hasResolvedHierarchy => topLevel != null || kecamatan != null || leaf != null;

  String get summaryLabel {
    final parts = <String>[
      if (topLevel != null) topLevel!.nama,
      if (kecamatan != null) kecamatan!.nama,
      if (leaf != null) leaf!.nama,
    ];

    return parts.join(' -> ');
  }

  factory WilayahHierarchyResolution.fromJson(Map<String, dynamic> json) {
    return WilayahHierarchyResolution(
      matched: json['matched'] == true,
      topLevel: _parseWilayahOption(json['top_level']),
      kecamatan: _parseWilayahOption(json['kecamatan']),
      leaf: _parseWilayahOption(json['leaf']),
    );
  }

  static WilayahOption? _parseWilayahOption(dynamic value) {
    if (value is Map<String, dynamic>) {
      return WilayahOption.fromJson(value);
    }

    if (value is Map) {
      final normalized = <String, dynamic>{};
      value.forEach((key, entryValue) {
        normalized[key.toString()] = entryValue;
      });
      return WilayahOption.fromJson(normalized);
    }

    return null;
  }
}
