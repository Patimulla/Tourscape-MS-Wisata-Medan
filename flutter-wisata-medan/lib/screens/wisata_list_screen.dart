/// ============================================================
/// Tourscape MS - Wisata List Screen
/// Menampilkan daftar wisata approved dengan filter kategori
/// ============================================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_theme.dart';
import '../models/kategori_model.dart';
import '../models/wisata_model.dart';
import '../services/wilayah_api_service.dart';
import '../utils/network_error_helper.dart';
import '../widgets/app_shimmer.dart';
import 'main_screen.dart';

class WisataListScreen extends StatefulWidget {
  const WisataListScreen({super.key});

  @override
  State<WisataListScreen> createState() => _WisataListScreenState();
}

class _WisataListScreenState extends State<WisataListScreen> {
  final _supabase = Supabase.instance.client;
  final Map<int, Future<String>> _kotaKabupatenFutures = {};
  final ValueNotifier<String?> _selectedKategoriNotifier = ValueNotifier<String?>(
    null,
  );

  List<String> _kategoriNames = const [];

  @override
  void initState() {
    super.initState();
    _loadKategoriOptions();
  }

  @override
  void dispose() {
    _selectedKategoriNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadKategoriOptions() async {
    try {
      final response = await _supabase
          .from('kategori')
          .select('id, nama_kategori')
          .order('nama_kategori', ascending: true);

      final kategoriNames = (response as List)
          .map((item) => Kategori.fromJson(item).namaKategori.trim())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      if (!mounted) {
        return;
      }

      setState(() {
        _kategoriNames = kategoriNames;
      });
    } catch (error) {
      debugPrint('loadKategoriOptions error: $error');
    }
  }

  Future<String> _resolveKotaKabupaten(Wisata wisata) {
    return _kotaKabupatenFutures.putIfAbsent(wisata.id, () async {
      final lat = wisata.latitude;
      final lng = wisata.longitude;
      if (lat == null || lng == null) {
        return '-';
      }

      try {
        final resolution = await WilayahApiService.resolveFromPoint(
          lat: lat,
          lng: lng,
        );
        final topLevelName = resolution.topLevel?.nama?.trim();
        if (topLevelName == null || topLevelName.isEmpty) {
          return '-';
        }

        return topLevelName;
      } catch (_) {
        return '-';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: AppTheme.appBarGradient(context)),
        ),
        title: const Text(
          'Wisata Tersedia',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _supabase
            .from('wisata')
            .stream(primaryKey: ['id'])
            .eq('status', 'approved')
            .order('nama_tempat', ascending: true),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingShimmer();
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                NetworkErrorHelper.normalizeMessage(
                  snapshot.error,
                  fallback: 'Error memuat data',
                ),
                style: TextStyle(color: AppTheme.textPrimary(context)),
              ),
            );
          }

          final data = snapshot.data;
          if (data == null || data.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_off_rounded,
                    size: 60,
                    color: AppTheme.textSecondary(context)
                        .withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada wisata yang tersedia',
                    style: TextStyle(
                      color: AppTheme.textSecondary(context),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            );
          }

          final wisataList = data.map(Wisata.fromJson).toList();
          final categoryOptions = <String>{
            ..._kategoriNames,
            ...wisataList
                .map((w) => w.kategori?.trim() ?? '')
                .where((item) => item.isNotEmpty),
          }.toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

          return Column(
            children: [
              ValueListenableBuilder<String?>(
                valueListenable: _selectedKategoriNotifier,
                builder: (context, selectedKategori, _) {
                  final filteredList = wisataList.where((w) {
                    if (selectedKategori == null) {
                      return true;
                    }
                    return (w.kategori?.trim() ?? '') == selectedKategori;
                  }).toList();

                  return WisataListFilterPanel(
                    categories: categoryOptions,
                    selectedKategori: selectedKategori,
                    totalVisible: filteredList.length,
                    onSelectedKategoriChanged: (value) {
                      _selectedKategoriNotifier.value = value;
                    },
                  );
                },
              ),
              Expanded(
                child: ValueListenableBuilder<String?>(
                  valueListenable: _selectedKategoriNotifier,
                  builder: (context, selectedKategori, _) {
                    final filteredList = wisataList.where((w) {
                      if (selectedKategori == null) {
                        return true;
                      }
                      return (w.kategori?.trim() ?? '') == selectedKategori;
                    }).toList();

                    if (filteredList.isEmpty) {
                      return Center(
                        child: Text(
                          'Tidak ada wisata untuk kategori ini',
                          style: TextStyle(
                            color: AppTheme.textSecondary(context),
                            fontSize: 14,
                          ),
                        ),
                      );
                    }

                    final animationSeed = selectedKategori ?? '__all__';

                    return ListView.builder(
                      key: ValueKey(animationSeed),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                      itemCount: filteredList.length,
                      itemBuilder: (context, index) {
                        final wisata = filteredList[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildAnimatedWisataCard(
                            wisata: wisata,
                            index: index,
                            animationSeed: animationSeed,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAnimatedWisataCard({
    required Wisata wisata,
    required int index,
    required String animationSeed,
  }) {
    final duration = Duration(
      milliseconds: 320 + (index * 55).clamp(0, 220),
    );

    return TweenAnimationBuilder<double>(
      key: ValueKey('$animationSeed-${wisata.id}'),
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final clamped = value.clamp(0.0, 1.0);
        return Opacity(
          opacity: clamped,
          child: Transform.translate(
            offset: Offset(0, (1 - clamped) * 18),
            child: child,
          ),
        );
      },
      child: _buildWisataCard(wisata),
    );
  }

  Widget _buildLoadingShimmer() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.glassDecoration(context).copyWith(
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppShimmerBox(
                    height: 40,
                    width: 40,
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppShimmerBox(height: 15, width: 120),
                        SizedBox(height: 8),
                        AppShimmerBox(height: 12, width: 220),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AppShimmerBox(
                    height: 34,
                    width: 82,
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                  ),
                  AppShimmerBox(
                    height: 34,
                    width: 96,
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                  ),
                  AppShimmerBox(
                    height: 34,
                    width: 88,
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            itemCount: 5,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildWisataCardShimmer(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWisataCardShimmer() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          AppShimmerBox(
            height: 92,
            width: 92,
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppShimmerBox(height: 16, width: double.infinity),
                SizedBox(height: 8),
                AppShimmerBox(height: 16, width: 170),
                SizedBox(height: 10),
                Row(
                  children: [
                    AppShimmerBox(
                      height: 18,
                      width: 76,
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                    ),
                    SizedBox(width: 6),
                    AppShimmerBox(
                      height: 18,
                      width: 96,
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                AppShimmerBox(height: 12, width: 136),
                SizedBox(height: 6),
                AppShimmerBox(height: 12, width: 190),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWisataCard(Wisata wisata) {
    final coverUrl = wisata.foto.isNotEmpty ? wisata.foto.first : null;
    final categoryColor = AppTheme.primary(context);
    final ratingValue = wisata.ratingAvg ?? wisata.rating ?? 0;
    final hasRating = (wisata.totalReview ?? 0) > 0 || ratingValue > 0;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MainScreen(
              initialIndex: 1,
              initialDetailTarget: wisata,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCoverImage(coverUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            wisata.namaTempat,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary(context),
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildRouteButton(wisata),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: categoryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            wisata.kategori ?? 'Umum',
                            style: TextStyle(
                              fontSize: 10,
                              color: categoryColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _buildWisataPreviewRating(
                          hasRating: hasRating,
                          ratingValue: ratingValue,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<String>(
                      future: _resolveKotaKabupaten(wisata),
                      builder: (context, snapshot) {
                        final cityName = snapshot.data ?? '-';
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.apartment_rounded,
                                  size: 14,
                                  color: AppTheme.textSecondary(context),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    cityName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary(context),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  size: 14,
                                  color: AppTheme.textSecondary(context),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${wisata.kecamatan ?? '-'}, ${wisata.kelurahan ?? '-'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary(context),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverImage(String? imageUrl) {
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: AppTheme.card(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl == null || imageUrl.trim().isEmpty
          ? Icon(
              Icons.landscape_rounded,
              color: AppTheme.textSecondary(context),
              size: 34,
            )
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.low,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => Icon(
                Icons.broken_image_rounded,
                color: AppTheme.textSecondary(context),
                size: 30,
              ),
            ),
    );
  }

  Widget _buildRouteButton(Wisata wisata) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MainScreen(
                initialIndex: 1,
                initialRouteTarget: wisata,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: AppTheme.vibrantPrimary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppTheme.vibrantPrimary.withValues(alpha: 0.2),
            ),
          ),
          child: Icon(
            Icons.navigation_rounded,
            size: 18,
            color: AppTheme.vibrantPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildWisataPreviewRating({
    required bool hasRating,
    required double ratingValue,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppTheme.border(context),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            size: 12,
            color: hasRating
                ? const Color(0xFFF59E0B)
                : AppTheme.textSecondary(context),
          ),
          const SizedBox(width: 3),
          Text(
            hasRating ? ratingValue.toStringAsFixed(1) : 'Belum ada rating',
            style: TextStyle(
              fontSize: 10,
              color: hasRating
                  ? AppTheme.textPrimary(context)
                  : AppTheme.textSecondary(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class WisataListFilterPanel extends StatefulWidget {
  final List<String> categories;
  final String? selectedKategori;
  final int totalVisible;
  final ValueChanged<String?> onSelectedKategoriChanged;

  const WisataListFilterPanel({
    super.key,
    required this.categories,
    required this.selectedKategori,
    required this.totalVisible,
    required this.onSelectedKategoriChanged,
  });

  @override
  State<WisataListFilterPanel> createState() => _WisataListFilterPanelState();
}

class _WisataListFilterPanelState extends State<WisataListFilterPanel> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: AppTheme.glassDecoration(context).copyWith(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary(context).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      color: AppTheme.primary(context),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Filter Wisata',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.selectedKategori == null
                              ? '${widget.totalVisible} wisata ditampilkan dari semua kategori'
                              : '${widget.totalVisible} wisata ditampilkan untuk kategori ${widget.selectedKategori}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ClipRect(
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              heightFactor: _isExpanded ? 1 : 0,
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChip(context, 'Semua', null),
                      ...widget.categories.map(
                        (category) =>
                            _buildFilterChip(context, category, category),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, String label, String? value) {
    final isSelected = widget.selectedKategori == value;
    return GestureDetector(
      onTap: () => widget.onSelectedKategoriChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary(context).withValues(alpha: 0.12)
              : AppTheme.card(context),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary(context)
                : AppTheme.border(context),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected
                ? AppTheme.primary(context)
                : AppTheme.textSecondary(context),
          ),
        ),
      ),
    );
  }
}
