import 'dart:convert';
import 'lib/models/wisata_model.dart';

void main() {
  String jsonStr = '''
  {
      "id": "1",
      "nama_tempat": "Taman Sri Deli",
      "deskripsi": "Taman bersejarah",
      "alamat": "Jl. Brigjen Katamso",
      "kecamatan": "Medan Maimun",
      "kelurahan": "Aur",
      "kategori": "Taman",
      "target_pengunjung": "umum",
      "jam_buka": "07:00:00",
      "jam_tutup": "22:00:00",
      "hari_operasional": "Senin-Minggu",
      "harga_tiket": "0",
      "keterangan_harga": "Gratis",
      "foto": [
          "https://example.com/foto.jpg"
      ],
      "rating": null,
      "no_telepon": "-",
      "latitude": "3.5752",
      "longitude": "98.6837",
      "fasilitas": [
          "Toilet",
          "Parkir"
      ]
  }
  ''';

  try {
    Map<String, dynamic> data = jsonDecode(jsonStr);
    Wisata w = Wisata.fromJson(data);
    print("Success: \${w.namaTempat}, Fasilitas: \${w.fasilitas}");
  } catch (e) {
    print("Error parsing: \$e");
  }
}
