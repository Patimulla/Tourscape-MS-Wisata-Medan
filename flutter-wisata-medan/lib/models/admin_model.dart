/// ============================================================
/// Tourscape MS — Model Admin
/// ============================================================

class Admin {
  final String id; // UUID from Supabase Auth
  final String nama;
  final String email;
  final String nomorPegawai;
  final String? fotoProfil;
  final DateTime? createdAt;
  final DateTime? lastSeenAt;

  Admin({
    required this.id,
    required this.nama,
    required this.email,
    required this.nomorPegawai,
    this.fotoProfil,
    this.createdAt,
    this.lastSeenAt,
  });

  factory Admin.fromJson(Map<String, dynamic> json) {
    final username = (json['username'] ?? json['nama'] ?? '').toString();
    final email = (json['email'] ?? '').toString();
    final nomorPegawaiValue = json['no_pegawai'] ?? json['nomor_pegawai'] ?? '';

    return Admin(
      id: json['id']?.toString() ?? '',
      nama: username,
      email: email,
      nomorPegawai: nomorPegawaiValue.toString(),
      fotoProfil: json['foto_profil'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())?.toLocal()
          : null,
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.tryParse(json['last_seen_at'].toString())?.toLocal()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': nama,
      'email': email,
      'no_pegawai': nomorPegawai,
      if (fotoProfil != null) 'foto_profil': fotoProfil,
    };
  }
}
