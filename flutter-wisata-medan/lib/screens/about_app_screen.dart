import 'package:flutter/material.dart';

import '../config/app_theme.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

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
                          icon: Icons.info_rounded,
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
                              Icons.travel_explore_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Tentang Aplikasi',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tourscape MS membantu admin mobile mengusulkan lokasi wisata, memantau riwayat pengajuan, dan menggunakan peta interaktif untuk validasi titik lokasi.',
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
                  _infoSection(
                    context,
                    title: 'Peran Aplikasi Mobile',
                    icon: Icons.phone_android_rounded,
                    items: const [
                      'Mengajukan lokasi wisata baru dengan status pending.',
                      'Melihat peta, marker wisata, polygon wilayah, dan rute navigasi.',
                      'Memantau riwayat pengajuan milik akun admin mobile yang sedang login.',
                      'Melakukan revisi untuk pengajuan pending atau ditolak.',
                    ],
                  ),
                  const SizedBox(height: 16),
                  _infoSection(
                    context,
                    title: 'Hubungan Dengan Admin Web',
                    icon: Icons.desktop_windows_rounded,
                    items: const [
                      'Admin web melakukan review, approve, reject, edit data approved, dan manajemen data utama.',
                      'Pengajuan dari mobile tidak bergantung pada server CI4 lokal untuk fitur inti pengguna mobile.',
                      'Catatan perbaikan dari admin web akan muncul di detail pengajuan yang ditolak.',
                    ],
                  ),
                  const SizedBox(height: 16),
                  _infoSection(
                    context,
                    title: 'Peta dan Data',
                    icon: Icons.map_rounded,
                    items: const [
                      'Peta memakai OpenStreetMap dan Leaflet pada web, serta Flutter Map pada mobile.',
                      'Data utama mobile memanfaatkan Supabase untuk auth, storage, riwayat, dan detail wisata.',
                      'Filter wilayah membantu memusatkan pencarian wisata pada area polygon tertentu.',
                    ],
                  ),
                  const SizedBox(height: 16),
                  _highlightCard(
                    context,
                    title: 'Tujuan Sistem',
                    description:
                        'Membuat proses pengumpulan, verifikasi, dan publikasi lokasi wisata menjadi lebih rapi, terpantau, dan mudah dipakai oleh admin lapangan maupun admin web.',
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

  Widget _infoSection(
    BuildContext context, {
    required String title,
    required IconData icon,
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primary(context).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.primary(context),
                ),
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
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: AppTheme.primary(context),
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

  Widget _highlightCard(
    BuildContext context, {
    required String title,
    required String description,
  }) {
    return Container(
      width: double.infinity,
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
          const Text(
            'Tujuan Sistem',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              height: 1.7,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
        ],
      ),
    );
  }
}
