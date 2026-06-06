import 'package:flutter/material.dart';

import '../config/app_theme.dart';

class UsageGuideScreen extends StatelessWidget {
  const UsageGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              decoration: BoxDecoration(
                gradient: AppTheme.appBarGradient(context),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _topIconButton(
                          context,
                          icon: Icons.arrow_back_rounded,
                          onTap: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        _topIconButton(
                          context,
                          icon: Icons.menu_book_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.route_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Panduan Penggunaan',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Ikuti alur pengajuan, revisi, pemilihan titik map, dan pemakaian riwayat agar proses input lokasi wisata berjalan rapi.',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.65,
                              color: Colors.white.withValues(alpha: 0.86),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  _stepSection(
                    context,
                    title: '1. Membuat Pengajuan Baru',
                    icon: Icons.add_location_alt_rounded,
                    accent: const Color(0xFF22C55E),
                    items: const [
                      'Buka Input Wisata dari halaman beranda, drawer, atau pintasan dari peta.',
                      'Isi nama tempat, kategori, deskripsi, alamat, kontak, dan informasi operasional dengan lengkap.',
                      'Tambahkan foto utama dan foto tambahan agar admin web lebih mudah meninjau pengajuan.',
                    ],
                  ),
                  const SizedBox(height: 16),
                  _stepSection(
                    context,
                    title: '2. Menentukan Titik Lokasi',
                    icon: Icons.place_rounded,
                    accent: const Color(0xFF3B82F6),
                    items: const [
                      'Gunakan GPS untuk mengambil posisi saat ini, atau isi koordinat secara manual.',
                      'Di halaman peta, tekan dan tahan area yang valid untuk membuka pintasan Input Lokasi Baru.',
                      'Gunakan preview map di form input untuk menggeser titik dengan marker tetap di tengah hingga koordinat sesuai.',
                    ],
                  ),
                  const SizedBox(height: 16),
                  _stepSection(
                    context,
                    title: '3. Memantau Riwayat Pengajuan',
                    icon: Icons.history_rounded,
                    accent: const Color(0xFFA855F7),
                    items: const [
                      'Riwayat hanya menampilkan pengajuan dari akun admin mobile yang sedang login.',
                      'Filter status dan filter waktu membantu memusatkan pengajuan berdasarkan tahap review atau periode terbaru.',
                      'Status disetujui akan membuka panel detail wisata di map dan dapat langsung memulai navigasi.',
                    ],
                  ),
                  const SizedBox(height: 16),
                  _stepSection(
                    context,
                    title: '4. Revisi dan Ajukan Ulang',
                    icon: Icons.edit_rounded,
                    accent: const Color(0xFFF97316),
                    items: const [
                      'Pengajuan pending masih dapat diedit atau dibatalkan oleh pengaju.',
                      'Pengajuan ditolak akan menampilkan catatan admin web saat detail dibuka.',
                      'Gunakan tombol perbaiki untuk membuka kembali form dengan data lama yang sudah terisi.',
                    ],
                  ),
                  const SizedBox(height: 16),
                  _tipCard(
                    context,
                    title: 'Tips Cepat',
                    tips: const [
                      'Pastikan titik lokasi berada di area polygon wilayah yang benar saat melakukan input.',
                      'Lengkapi deskripsi dan foto dengan jelas agar peluang approve lebih tinggi.',
                      'Gunakan fitur navigasi di map untuk mengecek kembali apakah titik tujuan sudah sesuai.',
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topIconButton(
    BuildContext context, {
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
          ),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  Widget _stepSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color accent,
    required List<String> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.glassDecoration(context).copyWith(
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.65,
                        color: AppTheme.textSecondary(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tipCard(
    BuildContext context, {
    required String title,
    required List<String> tips,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.vibrantGradient(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.vibrantPrimary.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.lightbulb_rounded,
                color: Colors.white,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Tips Cepat',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...tips.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tip,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.65,
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
