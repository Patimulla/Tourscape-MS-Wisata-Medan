/// ============================================================
/// Tourscape MS - Wisata Detail Screen
/// Menampilkan detail lengkap wisata
/// ============================================================

import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/wisata_model.dart';
import 'main_screen.dart';
import '../services/supabase_wisata_service.dart';
import '../services/wilayah_api_service.dart';
import 'input_wisata_screen.dart';

class WisataDetailScreen extends StatefulWidget {
  final int wisataId;
  final Wisata? initialWisata;

  const WisataDetailScreen({
    super.key,
    required this.wisataId,
    this.initialWisata,
  });

  @override
  State<WisataDetailScreen> createState() => _WisataDetailScreenState();
}

class _WisataDetailScreenState extends State<WisataDetailScreen> {
  Wisata? _wisata;
  bool _isLoading = true;
  int _activePhotoIndex = 0;
  final PageController _photoController = PageController();
  String? _resolvedKotaKabupaten;

  @override
  void initState() {
    super.initState();
    _wisata = widget.initialWisata;
    _isLoading = widget.initialWisata == null;
    _loadDetail();
  }

  @override
  void dispose() {
    _photoController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    try {
      final wisata = await SupabaseWisataService.fetchWisataDetail(
        widget.wisataId,
        seedWisata: widget.initialWisata,
      );
      if (!mounted) return;

      final merged = wisata ?? _wisata;

      setState(() {
        _wisata = merged;
        _isLoading = false;
      });
      _precachePhotos(merged?.foto ?? const []);
      _resolveKotaKabupaten(merged);
    } catch (e) {
      debugPrint('loadDetail error: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _precachePhotos(List<String> photos) {
    if (!mounted || photos.isEmpty) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      for (final url in photos.take(3)) {
        precacheImage(NetworkImage(url), context);
      }
    });
  }

  Future<void> _resolveKotaKabupaten(Wisata? wisata) async {
    final lat = wisata?.latitude;
    final lng = wisata?.longitude;
    if (lat == null || lng == null) {
      return;
    }

    try {
      final resolution = await WilayahApiService.resolveFromPoint(
        lat: lat,
        lng: lng,
      );
      if (!mounted) {
        return;
      }

      final topLevelName = resolution.topLevel?.nama?.trim();
      if (topLevelName == null || topLevelName.isEmpty) {
        return;
      }

      setState(() {
        _resolvedKotaKabupaten = topLevelName;
      });
    } catch (error) {
      debugPrint('resolveKotaKabupaten error: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _wisata == null
              ? Center(
                  child: Text(
                    'Data wisata tidak ditemukan',
                    style: TextStyle(color: AppTheme.textPrimary(context)),
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final w = _wisata!;
    final photos = w.foto.where((item) => item.trim().isNotEmpty).toList();
    final ratingValue = w.ratingAvg ?? w.rating ?? 0;
    final canReviseSubmission = w.status == 'pending' || w.status == 'rejected';

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: AppTheme.surface(context),
          title: Text(
            w.namaTempat,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppTheme.textPrimary(context),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPhotoGallery(photos),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppTheme.glassDecoration(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _buildChip(
                            w.kategori?.isNotEmpty == true
                                ? w.kategori!
                                : 'Lainnya',
                            AppTheme.primary(context),
                          ),
                          _buildChip(
                            w.targetPengunjung?.isNotEmpty == true
                                ? w.targetPengunjung!
                                : 'Umum',
                            const Color(0xFFD4A855),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  color: Colors.amber.shade700,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${ratingValue.toStringAsFixed(1)}${(w.totalReview ?? 0) > 0 ? ' (${w.totalReview})' : ''}',
                                  style: TextStyle(
                                    color: Colors.amber.shade800,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        w.deskripsi?.trim().isNotEmpty == true
                            ? w.deskripsi!
                            : 'Tidak ada deskripsi.',
                        style: TextStyle(
                          fontSize: 15,
                          color: AppTheme.textSecondary(context),
                          height: 1.7,
                        ),
                      ),
                    ],
                  ),
                ),
                if (w.status == 'rejected' &&
                    (w.catatanAdmin?.trim().isNotEmpty == true)) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.error.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.feedback_rounded,
                              size: 18,
                              color: AppTheme.error,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Catatan Admin Web',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.error,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          w.catatanAdmin!.trim(),
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.6,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                _buildInfoSection(w),
                const SizedBox(height: 24),
                _buildFacilitiesSection(w),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.glassDecoration(context),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        color: AppTheme.primary(context),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Koordinat',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Lat: ${w.latitude?.toStringAsFixed(6) ?? '-'}\nLng: ${w.longitude?.toStringAsFixed(6) ?? '-'}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textSecondary(context),
                                fontFamily: 'monospace',
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: AppTheme.vibrantGradient(context),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.vibrantGlow,
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => _handlePrimaryAction(w),
                    icon: Icon(
                      canReviseSubmission
                          ? Icons.edit_note_rounded
                          : Icons.navigation_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    label: Text(
                      canReviseSubmission
                          ? 'Perbaiki & Ajukan Ulang'
                          : 'Mulai Navigasi',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handlePrimaryAction(Wisata wisata) async {
    if (wisata.status == 'pending' || wisata.status == 'rejected') {
      final updated = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => InputWisataScreen(existingWisata: wisata),
        ),
      );

      if (updated == true && mounted) {
        Navigator.pop(context, true);
      }
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MainScreen(
          initialIndex: 1,
          initialRouteTarget: wisata,
        ),
      ),
    );
  }

  Widget _buildPhotoGallery(List<String> photos) {
    return Container(
      decoration: AppTheme.glassDecoration(context).copyWith(
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: photos.isEmpty
                ? Container(
                    color: AppTheme.card(context),
                    child: Icon(
                      Icons.landscape_rounded,
                      size: 84,
                      color:
                          AppTheme.textPrimary(context).withValues(alpha: 0.24),
                    ),
                  )
                : PageView.builder(
                    controller: _photoController,
                    itemCount: photos.length,
                    onPageChanged: (index) {
                      setState(() => _activePhotoIndex = index);
                    },
                    itemBuilder: (context, index) {
                      return Container(
                        color: Colors.black,
                        child: InteractiveViewer(
                          child: Image.network(
                            photos[index],
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.low,
                            gaplessPlayback: true,
                            frameBuilder: (context, child, frame, _) {
                              if (frame != null) {
                                return child;
                              }

                              return Container(
                                color: AppTheme.card(context),
                                alignment: Alignment.center,
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: AppTheme.primary(context),
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) => Container(
                              color: AppTheme.card(context),
                              child: Icon(
                                Icons.broken_image_rounded,
                                size: 70,
                                color: AppTheme.textPrimary(context)
                                    .withValues(alpha: 0.24),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (photos.length > 1) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              color: AppTheme.surface(context).withValues(alpha: 0.92),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Wrap(
                      spacing: 6,
                      children: List.generate(
                        photos.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: _activePhotoIndex == index ? 18 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _activePhotoIndex == index
                                ? AppTheme.primary(context)
                                : AppTheme.border(context),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 58,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: photos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final isActive = _activePhotoIndex == index;
                        return GestureDetector(
                          onTap: () {
                            _photoController.animateToPage(
                              index,
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: Container(
                            width: 72,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isActive
                                    ? AppTheme.primary(context)
                                    : AppTheme.border(context),
                                width: isActive ? 2 : 1,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.network(
                              photos[index],
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.low,
                              gaplessPlayback: true,
                              errorBuilder: (_, __, ___) => Container(
                                color: AppTheme.card(context),
                                child: Icon(
                                  Icons.image_not_supported_rounded,
                                  color: AppTheme.textSecondary(context),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoSection(Wisata w) {
    final infoItems = <MapEntry<String, String>>[
      MapEntry('Alamat', _fallbackText(w.alamat)),
      MapEntry('Kota / Kabupaten', _buildKotaKabupatenText()),
      MapEntry('Kecamatan', _fallbackText(w.kecamatan)),
      MapEntry('Kelurahan / Desa', _fallbackText(w.kelurahan)),
      MapEntry('Target Pengunjung', _fallbackText(w.targetPengunjung)),
      MapEntry('Jam Operasional', _buildJamOperasional(w)),
      MapEntry('Hari Operasional', _fallbackText(w.hariOperasional)),
      MapEntry('Harga Tiket', _buildHarga(w)),
      MapEntry('Telepon', _fallbackText(w.noTelepon)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Informasi Detail',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary(context),
          ),
        ),
        const SizedBox(height: 12),
        ...infoItems.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildInfoCard(item.key, item.value),
          ),
        ),
      ],
    );
  }

  String _buildKotaKabupatenText() {
    final text = _resolvedKotaKabupaten?.trim();
    if (text != null && text.isNotEmpty) {
      return text;
    }

    return '-';
  }

  Widget _buildFacilitiesSection(Wisata w) {
    final facilityItems = <MapEntry<String, bool>>[
      MapEntry('Toilet', w.toilet),
      MapEntry('Parkir', w.parkir),
      MapEntry('Area Bermain Anak', w.areaBermain),
      MapEntry('Tempat Makan', w.tempatMakan),
      MapEntry('Mushola', w.mushola),
      MapEntry('WiFi', w.wifi),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fasilitas',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary(context),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: facilityItems.map((item) {
            final isActive = item.value;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isActive
                    ? AppTheme.primary(context).withValues(alpha: 0.12)
                    : AppTheme.card(context),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isActive
                      ? AppTheme.primary(context).withValues(alpha: 0.4)
                      : AppTheme.border(context),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isActive
                        ? Icons.check_circle_rounded
                        : Icons.remove_circle_outline_rounded,
                    size: 16,
                    color: isActive
                        ? AppTheme.primary(context)
                        : AppTheme.textSecondary(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.key,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isActive
                          ? AppTheme.primary(context)
                          : AppTheme.textSecondary(context),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassDecoration(context).copyWith(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary(context),
            ),
            softWrap: true,
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  String _buildJamOperasional(Wisata w) {
    final buka = _formatTime(w.jamBuka);
    final tutup = _formatTime(w.jamTutup);

    if (buka == '-' && tutup == '-') {
      return '-';
    }

    return '$buka - $tutup';
  }

  String _formatTime(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '-';
    return text.length >= 5 ? text.substring(0, 5) : text;
  }

  String _buildHarga(Wisata w) {
    final harga = w.hargaTiket ?? 0;
    if (harga <= 0) {
      return 'Gratis';
    }

    final rounded =
        harga % 1 == 0 ? harga.toStringAsFixed(0) : harga.toString();
    return 'Rp $rounded';
  }

  String _fallbackText(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? '-' : text;
  }
}
