import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_theme.dart';
import '../models/admin_model.dart';
import '../models/wisata_model.dart';
import '../services/admin_presence_service.dart';
import '../utils/network_error_helper.dart';
import '../services/wilayah_api_service.dart';
import 'main_screen.dart';

class AdminDirectoryScreen extends StatefulWidget {
  const AdminDirectoryScreen({super.key});

  @override
  State<AdminDirectoryScreen> createState() => _AdminDirectoryScreenState();
}

class _AdminDirectoryScreenState extends State<AdminDirectoryScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    AdminPresenceService.instance.startTracking();
  }

  void _openAdminDetail(Admin admin) {
    Navigator.push(
      context,
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, __, ___) => AdminDirectoryDetailScreen(admin: admin),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );

          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _currentUserId;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        elevation: 0,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: AppTheme.appBarGradient(context)),
        ),
        title: const Text(
          'Admin Terdaftar',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _supabase
            .from('admin_mobile')
            .stream(primaryKey: ['id'])
            .order('username', ascending: true),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildDirectoryShimmer();
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  NetworkErrorHelper.normalizeMessage(
                    snapshot.error,
                    fallback: 'Gagal memuat daftar admin',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textPrimary(context)),
                ),
              ),
            );
          }

          final admins = (snapshot.data ?? const <Map<String, dynamic>>[])
              .map(Admin.fromJson)
              .toList();

          return ValueListenableBuilder<Set<String>>(
            valueListenable: AdminPresenceService.instance.onlineUserIds,
            builder: (context, onlineIds, _) {
              final onlineAdmins = admins
                  .where((admin) => onlineIds.contains(admin.id))
                  .toList();
              final offlineAdmins = admins
                  .where((admin) => !onlineIds.contains(admin.id))
                  .toList();
              final onlineCount = admins
                  .where((admin) => onlineIds.contains(admin.id))
                  .length;
              final hasAnyAdmin = admins.isNotEmpty;

              return CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: _AnimatedEntrance(
                        duration: const Duration(milliseconds: 520),
                        child: _buildOverviewCard(
                          totalAdmins: admins.length,
                          onlineCount: onlineCount,
                        ),
                      ),
                    ),
                  ),
                  if (!hasAnyAdmin)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _AnimatedEntrance(
                        duration: const Duration(milliseconds: 360),
                        child: _buildEmptyState(),
                      ),
                    )
                  else
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        child: Column(
                          children: [
                            _buildAdminSection(
                              title: 'Online',
                              emptyLabel: 'Belum ada admin yang sedang online.',
                              admins: onlineAdmins,
                              isOnline: true,
                            ),
                            if (onlineAdmins.isNotEmpty && offlineAdmins.isNotEmpty)
                              const SizedBox(height: 18),
                            _buildAdminSection(
                              title: 'Offline',
                              emptyLabel: 'Belum ada admin offline saat ini.',
                              admins: offlineAdmins,
                              isOnline: false,
                              startIndex: onlineAdmins.length,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildOverviewCard({
    required int totalAdmins,
    required int onlineCount,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF97316).withValues(alpha: 0.18),
            AppTheme.primary(context).withValues(alpha: 0.14),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFF97316).withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.surface(context).withValues(alpha: 0.92)
                      : Colors.white.withValues(alpha: 0.74),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? AppTheme.border(context).withValues(alpha: 0.9)
                        : Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: const Icon(
                  Icons.groups_rounded,
                  size: 22,
                  color: Color(0xFFF97316),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jaringan Admin Mobile',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildOverviewStat(
                  label: 'Total Admin',
                  value: '$totalAdmins',
                  icon: Icons.badge_rounded,
                  color: const Color(0xFFF97316),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOverviewStat(
                  label: 'Sedang Online',
                  value: '$onlineCount',
                  icon: Icons.circle_rounded,
                  color: const Color(0xFF22C55E),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewStat({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.surface(context).withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? AppTheme.border(context).withValues(alpha: 0.9)
              : color.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminSection({
    required String title,
    required String emptyLabel,
    required List<Admin> admins,
    required bool isOnline,
    int startIndex = 0,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassDecoration(context).copyWith(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.9),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isOnline
                          ? const Color(0xFF22C55E)
                          : AppTheme.textSecondary(context))
                      .withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isOnline
                      ? Icons.circle_rounded
                      : Icons.pause_circle_filled_rounded,
                  size: 16,
                  color: isOnline
                      ? const Color(0xFF22C55E)
                      : AppTheme.textSecondary(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.card(context),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppTheme.border(context)),
                ),
                child: Text(
                  '${admins.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textSecondary(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (admins.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.card(context).withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border(context)),
              ),
              child: Text(
                emptyLabel,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: AppTheme.textSecondary(context),
                ),
              ),
            )
          else
            ...List.generate(admins.length, (index) {
              final admin = admins[index];
              return Padding(
                padding: EdgeInsets.only(bottom: index == admins.length - 1 ? 0 : 12),
                child: _AnimatedEntrance(
                  key: ValueKey('${title.toLowerCase()}-${admin.id}'),
                  duration: Duration(milliseconds: 320 + ((startIndex + index) * 55)),
                  beginOffset: const Offset(0, 26),
                  child: _buildAdminPreviewCard(
                    admin: admin,
                    isOnline: isOnline,
                    lastSeenAt:
                        AdminPresenceService.instance.lastSeenAt(admin.id) ??
                        admin.lastSeenAt,
                    isCurrentUser: admin.id == _currentUserId,
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildAdminPreviewCard({
    required Admin admin,
    required bool isOnline,
    required DateTime? lastSeenAt,
    required bool isCurrentUser,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openAdminDetail(admin),
        child: Ink(
          decoration: BoxDecoration(
            color: AppTheme.card(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.border(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _AdminAvatar(
                  admin: admin,
                  size: 66,
                  isOnline: isOnline,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    admin.nama.isNotEmpty
                                        ? admin.nama
                                        : 'Tanpa Nama',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.textPrimary(context),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isCurrentUser) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary(context)
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '(You)',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.primary(context),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildStatusPill(isOnline),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.badge_rounded,
                            size: 15,
                            color: AppTheme.textSecondary(context),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              admin.nomorPegawai.isNotEmpty
                                  ? admin.nomorPegawai
                                  : '-',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!isOnline && lastSeenAt != null) ...[
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 14,
                              color: AppTheme.textSecondary(context),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                'Terakhir online ${_formatLastSeen(lastSeenAt)}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary(context),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 15,
                    color: Color(0xFFF97316),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill(bool isOnline) {
    final color = isOnline
        ? const Color(0xFF22C55E)
        : AppTheme.textSecondary(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle_rounded, size: 10, color: color),
          const SizedBox(width: 5),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatLastSeen(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'baru saja';
    }
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} menit lalu';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours} jam lalu';
    }
    return '${difference.inDays} hari lalu';
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 18),
        padding: const EdgeInsets.all(24),
        decoration: AppTheme.glassDecoration(context).copyWith(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.primary(context).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.groups_rounded,
                size: 30,
                color: AppTheme.primary(context),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Belum Ada Admin Lain',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Daftar admin lain akan muncul di sini setelah mereka terdaftar di sistem.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: AppTheme.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectoryShimmer() {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: _ShimmerBox(
              height: 156,
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildAdminCardShimmer(),
              ),
              childCount: 5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdminCardShimmer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        children: [
          const _ShimmerCircle(size: 66),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShimmerBox(height: 16, width: 170),
                SizedBox(height: 10),
                _ShimmerBox(height: 12, width: 110),
                SizedBox(height: 10),
                _ShimmerBox(height: 11, width: double.infinity),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const _ShimmerBox(
            height: 38,
            width: 38,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ],
      ),
    );
  }
}

class AdminDirectoryDetailScreen extends StatefulWidget {
  const AdminDirectoryDetailScreen({
    super.key,
    required this.admin,
  });

  final Admin admin;

  @override
  State<AdminDirectoryDetailScreen> createState() =>
      _AdminDirectoryDetailScreenState();
}

class _AdminDirectoryDetailScreenState extends State<AdminDirectoryDetailScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final Map<int, Future<String>> _kotaKabupatenFutures = {};

  Future<_AdminContributionData> _loadContributionData() async {
    final response = await _supabase
        .from('wisata')
        .select()
        .eq('submitter_user_id', widget.admin.id)
        .order('created_at', ascending: false);

    final wisataList = (response as List)
        .map((item) => Wisata.fromJson(item as Map<String, dynamic>))
        .toList();

    final approvedWisata = wisataList
        .where((wisata) => (wisata.status ?? '').toLowerCase() == 'approved')
        .toList();

    return _AdminContributionData(
      totalSubmitted: wisataList.length,
      totalAccepted: approvedWisata.length,
      acceptedWisata: approvedWisata,
    );
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
    final currentUserId = _supabase.auth.currentUser?.id;
    final isCurrentUser = widget.admin.id == currentUserId;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        elevation: 0,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: AppTheme.appBarGradient(context)),
        ),
        title: const Text(
          'Detail Admin',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
      ),
      body: FutureBuilder<_AdminContributionData>(
        future: _loadContributionData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildDetailShimmer();
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  NetworkErrorHelper.normalizeMessage(
                    snapshot.error,
                    fallback: 'Gagal memuat kontribusi admin',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textPrimary(context)),
                ),
              ),
            );
          }

          final contribution =
              snapshot.data ?? const _AdminContributionData.empty();

          return ValueListenableBuilder<Set<String>>(
            valueListenable: AdminPresenceService.instance.onlineUserIds,
            builder: (context, onlineIds, _) {
              final isOnline = onlineIds.contains(widget.admin.id);
              final lastSeenAt =
                  AdminPresenceService.instance.lastSeenAt(widget.admin.id) ??
                  widget.admin.lastSeenAt;

              return CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: _AnimatedEntrance(
                        duration: const Duration(milliseconds: 520),
                        child: _buildAdminHeroCard(
                          isOnline,
                          lastSeenAt: lastSeenAt,
                          isCurrentUser: isCurrentUser,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                      child: _AnimatedEntrance(
                        duration: const Duration(milliseconds: 640),
                        beginOffset: const Offset(0, 20),
                        child: _buildContributionSection(contribution),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
                      child: _AnimatedEntrance(
                        duration: const Duration(milliseconds: 700),
                        beginOffset: const Offset(0, 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Wisata yang Diterima',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary(context),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.card(context),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: AppTheme.border(context),
                                ),
                              ),
                              child: Text(
                                '${contribution.acceptedWisata.length} wisata',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textSecondary(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (contribution.acceptedWisata.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _AnimatedEntrance(
                        duration: const Duration(milliseconds: 360),
                        child: _buildEmptyAcceptedState(),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final wisata = contribution.acceptedWisata[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _AnimatedEntrance(
                                key: ValueKey('accepted-${wisata.id}'),
                                duration: Duration(
                                  milliseconds: 360 + (index * 55),
                                ),
                                beginOffset: const Offset(0, 24),
                                child: _buildAcceptedWisataCard(wisata),
                              ),
                            );
                          },
                          childCount: contribution.acceptedWisata.length,
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAdminHeroCard(
    bool isOnline, {
    required DateTime? lastSeenAt,
    required bool isCurrentUser,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary(context).withValues(alpha: 0.18),
            const Color(0xFFF97316).withValues(alpha: 0.14),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppTheme.primary(context).withValues(alpha: 0.14),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _AdminAvatar(
            admin: widget.admin,
            size: 104,
            isOnline: isOnline,
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  widget.admin.nama.isNotEmpty
                      ? widget.admin.nama
                      : 'Tanpa Nama',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
              ),
              if (isCurrentUser) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary(context).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '(You)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary(context),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.surface(context).withValues(alpha: 0.92)
                  : Colors.white.withValues(alpha: 0.76),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isDark
                    ? AppTheme.border(context).withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.badge_rounded,
                  size: 15,
                  color: AppTheme.primary(context),
                ),
                const SizedBox(width: 6),
                Text(
                  widget.admin.nomorPegawai.isNotEmpty
                      ? widget.admin.nomorPegawai
                      : '-',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: (isOnline
                      ? const Color(0xFF22C55E)
                      : AppTheme.textSecondary(context))
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.circle_rounded,
                  size: 10,
                  color: isOnline
                      ? const Color(0xFF22C55E)
                      : AppTheme.textSecondary(context),
                ),
                const SizedBox(width: 6),
                Text(
                  isOnline ? 'Sedang Online' : 'Sedang Offline',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isOnline
                        ? const Color(0xFF22C55E)
                        : AppTheme.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          if (!isOnline && lastSeenAt != null) ...[
            const SizedBox(height: 10),
            Text(
              'Terakhir online ${_formatLastSeen(lastSeenAt)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatLastSeen(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'baru saja';
    }
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} menit lalu';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours} jam lalu';
    }
    return '${difference.inDays} hari lalu';
  }

  Widget _buildContributionSection(_AdminContributionData contribution) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.glassDecoration(context).copyWith(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.9),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kontribusi',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary(context),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildContributionStat(
                  icon: Icons.upload_file_rounded,
                  label: 'Total Diajukan',
                  value: '${contribution.totalSubmitted}',
                  color: const Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildContributionStat(
                  icon: Icons.verified_rounded,
                  label: 'Diterima',
                  value: '${contribution.totalAccepted}',
                  color: AppTheme.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContributionStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary(context),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyAcceptedState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 18),
        padding: const EdgeInsets.all(24),
        decoration: AppTheme.glassDecoration(context).copyWith(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.primary(context).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.landscape_rounded,
                size: 30,
                color: AppTheme.primary(context),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Belum Ada Wisata yang Diterima',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Wisata yang sudah disetujui dari admin ini akan muncul di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: AppTheme.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAcceptedWisataCard(Wisata wisata) {
    final coverUrl = wisata.foto.isNotEmpty ? wisata.foto.first : null;
    final categoryColor = AppTheme.primary(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MainScreen(
              initialIndex: 1,
              initialDetailTarget: wisata,
            ),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            color: AppTheme.card(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.border(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
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
                                fontWeight: FontWeight.w800,
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

  Widget _buildDetailShimmer() {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: _ShimmerBox(
              height: 280,
              borderRadius: BorderRadius.circular(28),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: _ShimmerBox(
              height: 174,
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
            child: Row(
              children: const [
                Expanded(child: _ShimmerBox(height: 18, width: 170)),
                SizedBox(width: 12),
                _ShimmerBox(
                  height: 28,
                  width: 80,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildAcceptedCardShimmer(),
              ),
              childCount: 3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAcceptedCardShimmer() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _ShimmerBox(
            height: 92,
            width: 92,
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShimmerBox(height: 16, width: double.infinity),
                SizedBox(height: 8),
                _ShimmerBox(height: 16, width: 160),
                SizedBox(height: 10),
                _ShimmerBox(
                  height: 18,
                  width: 74,
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
                SizedBox(height: 10),
                _ShimmerBox(height: 12, width: 132),
                SizedBox(height: 6),
                _ShimmerBox(height: 12, width: 180),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminAvatar extends StatelessWidget {
  const _AdminAvatar({
    required this.admin,
    required this.size,
    required this.isOnline,
  });

  final Admin admin;
  final double size;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppTheme.primary(context).withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.primary(context).withValues(alpha: 0.2),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipOval(
            child: admin.fotoProfil != null && admin.fotoProfil!.isNotEmpty
                ? Image.network(
                    admin.fotoProfil!,
                    fit: BoxFit.cover,
                    width: size,
                    height: size,
                  )
                : Center(
                    child: Text(
                      admin.nama.isNotEmpty ? admin.nama[0].toUpperCase() : 'A',
                      style: TextStyle(
                        color: AppTheme.primary(context),
                        fontSize: size * 0.38,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
          ),
        ),
        Positioned(
          right: 2,
          bottom: 2,
          child: AnimatedOpacity(
            opacity: isOnline ? 1 : 0.58,
            duration: const Duration(milliseconds: 220),
            child: Container(
              width: size * 0.23,
              height: size * 0.23,
              decoration: BoxDecoration(
                color: isOnline
                    ? const Color(0xFF22C55E)
                    : AppTheme.textSecondary(context).withValues(alpha: 0.7),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AnimatedEntrance extends StatelessWidget {
  const _AnimatedEntrance({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 420),
    this.beginOffset = const Offset(0, 16),
  });

  final Widget child;
  final Duration duration;
  final Offset beginOffset;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(
              beginOffset.dx * (1 - value),
              beginOffset.dy * (1 - value),
            ),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _AdminContributionData {
  const _AdminContributionData({
    required this.totalSubmitted,
    required this.totalAccepted,
    required this.acceptedWisata,
  });

  const _AdminContributionData.empty()
      : totalSubmitted = 0,
        totalAccepted = 0,
        acceptedWisata = const [];

  final int totalSubmitted;
  final int totalAccepted;
  final List<Wisata> acceptedWisata;
}

class _ShimmerBox extends StatefulWidget {
  const _ShimmerBox({
    this.height = 16,
    this.width = double.infinity,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  final double height;
  final double width;
  final BorderRadius borderRadius;

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = AppTheme.border(context).withValues(alpha: 0.46);
    final highlightColor = AppTheme.surface(context).withValues(alpha: 0.96);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = _controller.value;
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment(-1.8 + (value * 2.6), -0.3),
              end: Alignment(-0.6 + (value * 2.6), 0.3),
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: const [0.15, 0.5, 0.85],
            ),
          ),
        );
      },
    );
  }
}

class _ShimmerCircle extends StatelessWidget {
  const _ShimmerCircle({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return _ShimmerBox(
      height: size,
      width: size,
      borderRadius: BorderRadius.circular(size / 2),
    );
  }
}
