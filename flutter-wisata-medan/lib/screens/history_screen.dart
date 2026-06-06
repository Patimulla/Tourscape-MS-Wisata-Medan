/// ============================================================
/// Tourscape MS — History Screen
/// Riwayat pengajuan penambahan wisata
/// ============================================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_theme.dart';
import '../models/wisata_model.dart';
import '../services/submission_review_notification_service.dart';
import '../services/supabase_wisata_service.dart';
import '../services/wilayah_api_service.dart';
import '../utils/network_error_helper.dart';
import '../widgets/app_shimmer.dart';
import '../widgets/history_notification_badge.dart';
import 'input_wisata_screen.dart';
import 'main_screen.dart';
import 'wisata_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with AutomaticKeepAliveClientMixin {
  final _supabase = Supabase.instance.client;
  String _filterStatus = 'all'; // all, pending, approved, rejected
  String _timeFilter = 'all'; // all, today, week, month
  final Set<int> _deletingSubmissionIds = <int>{};
  final Map<int, Future<String>> _kotaKabupatenFutures = {};

  @override
  bool get wantKeepAlive => true;

  bool get _hasActiveHeaderFilters =>
      _timeFilter != 'all' || _filterStatus != 'all';

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
    super.build(context);
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: CustomScrollView(slivers: [
        // Header
        SliverToBoxAdapter(
            child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          decoration: BoxDecoration(
            gradient: AppTheme.appBarGradient(context),
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ],
          ),
          child: SafeArea(
              bottom: false,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          child: Text('Riwayat Pengajuan',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.5)),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Filter waktu',
                          color: AppTheme.surface(context),
                          icon: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.22),
                              ),
                            ),
                            child: const Icon(
                              Icons.calendar_month_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          onSelected: (value) {
                            setState(() => _timeFilter = value);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'today',
                              child: Text('Hari ini'),
                            ),
                            PopupMenuItem(
                              value: 'week',
                              child: Text('Minggu ini'),
                            ),
                            PopupMenuItem(
                              value: 'month',
                              child: Text('Bulan ini'),
                            ),
                            PopupMenuDivider(),
                            PopupMenuItem(
                              value: 'all',
                              child: Text('Reset Filter Waktu'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (_hasActiveHeaderFilters) ...[
                      const SizedBox(height: 12),
                      _buildActiveFilterSummaryPanel(),
                    ],
                    const SizedBox(height: 16),
                    // Filter chips
                    SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          _filterChip('Semua', 'all'),
                          const SizedBox(width: 8),
                          _filterChip('Pending', 'pending'),
                          const SizedBox(width: 8),
                          _filterChip('Disetujui', 'approved'),
                          const SizedBox(width: 8),
                          _filterChip('Ditolak', 'rejected'),
                        ])),
                  ])),
        )),

        // List
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          sliver: _buildList(),
        ),
      ]),
    );
  }

  Widget _filterChip(String label, String status) {
    final isSelected = _filterStatus == status;
    final chip = GestureDetector(
      onTap: () {
        setState(() => _filterStatus = status);
        if (status == 'approved' || status == 'rejected') {
          SubmissionReviewNotificationService.instance
              .markStatusAsSeenForCurrentUser(status);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected ? Colors.white : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? AppTheme.primaryLight
                  : Colors.white.withValues(alpha: 0.9),
            )),
      ),
    );

    if (status != 'approved' && status != 'rejected') {
      return chip;
    }

    return HistoryNotificationBadge(
      top: -2,
      right: -2,
      statusFilter: status,
      child: chip,
    );
  }

  Widget _buildList() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return SliverFillRemaining(
        child: Center(
          child: Text(
            'Sesi login tidak ditemukan',
            style: TextStyle(color: AppTheme.textPrimary(context)),
          ),
        ),
      );
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase
          .from('wisata')
          .stream(primaryKey: ['id'])
          .eq('submitter_user_id', userId)
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildHistoryShimmerSliver();
        }
        if (snapshot.hasError) {
          return SliverFillRemaining(
              child: Center(
                  child: Text(
                      NetworkErrorHelper.normalizeMessage(
                        snapshot.error,
                        fallback: 'Error memuat data',
                      ),
                      style: TextStyle(color: AppTheme.textPrimary(context)))));
        }

        final rawData = snapshot.data ?? const <Map<String, dynamic>>[];
        final data = rawData.where((row) {
          final matchesStatus =
              _filterStatus == 'all' || row['status'] == _filterStatus;
          final matchesTimeFilter =
              _matchesTimeFilter(_resolveHistoryTimestamp(row));
          return matchesStatus && matchesTimeFilter;
        }).toList();

        if (data.isEmpty) {
          return SliverFillRemaining(
              child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.history_rounded,
                size: 60,
                color: AppTheme.textSecondary(context).withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'Belum ada riwayat pengajuan',
              style: TextStyle(
                  color: AppTheme.textSecondary(context), fontSize: 15),
              textAlign: TextAlign.center,
            ),
          ])));
        }

        return SliverList(
            delegate: SliverChildBuilderDelegate(
          (context, index) {
            final w = Wisata.fromJson(data[index]);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildHistoryCard(
                w,
                timelineInfo: _resolveHistoryTimelineInfo(data[index]),
              ),
            );
          },
          childCount: data.length,
        ));
      },
    );
  }

  Widget _buildHistoryShimmerSliver() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildHistoryCardShimmer(),
        ),
        childCount: 5,
      ),
    );
  }

  Widget _buildHistoryCardShimmer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppShimmerBox(
                height: 20,
                width: 76,
                borderRadius: BorderRadius.all(Radius.circular(6)),
              ),
              Spacer(),
              AppShimmerBox(
                height: 24,
                width: 94,
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
            ],
          ),
          SizedBox(height: 12),
          AppShimmerBox(height: 16, width: 210),
          SizedBox(height: 10),
          AppShimmerBox(height: 12, width: 130),
          SizedBox(height: 6),
          AppShimmerBox(height: 12, width: 190),
          SizedBox(height: 6),
          AppShimmerBox(height: 12, width: 150),
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: AppShimmerBox(
                  height: 42,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: AppShimmerBox(
                  height: 42,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(
    Wisata w, {
    required _HistoryTimelineInfo timelineInfo,
  }) {
    final statusColor = _getStatusColor(w.status);
    final statusLabel = _getStatusLabel(w.status);
    final statusIcon = _getStatusIcon(w.status);
    final isDeleting = _deletingSubmissionIds.contains(w.id);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          if (w.status == 'approved' || w.status == 'rejected') {
            await SubmissionReviewNotificationService.instance
                .markStatusAsSeenForCurrentUser(w.status!);
          }

          if (w.status == 'approved') {
            if (!mounted) {
              return;
            }

            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MainScreen(
                  initialIndex: 1,
                  initialDetailTarget: w,
                ),
              ),
            );
            return;
          }

          final updated = await Navigator.push<dynamic>(
            context,
            MaterialPageRoute(
              builder: (_) => WisataDetailScreen(
                wisataId: w.id,
                initialWisata: w,
              ),
            ),
          );

          if (updated == true && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  w.status == 'rejected'
                      ? 'Revisi pengajuan berhasil diajukan ulang'
                      : 'Pengajuan berhasil diperbarui',
                ),
                backgroundColor: AppTheme.primary(context),
              ),
            );
          }
        },
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Top row: kategori + status badge
              Row(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppTheme.primary(context).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(w.kategori ?? 'Umum',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.primary(context),
                          fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: statusColor.withValues(alpha: 0.3))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(statusLabel,
                        style: TextStyle(
                            fontSize: 11,
                            color: statusColor,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ]),
              const SizedBox(height: 10),

              // Nama
              Text(w.namaTempat,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary(context))),
              const SizedBox(height: 6),
              if (timelineInfo.dateTime != null) ...[
                Row(
                  children: [
                    Icon(
                      timelineInfo.icon,
                      size: 14,
                      color: AppTheme.textSecondary(context),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${timelineInfo.label}: ${_formatSubmissionDateTime(timelineInfo.dateTime!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary(context),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],

              FutureBuilder<String>(
                future: _resolveKotaKabupaten(w),
                builder: (context, snapshot) {
                  final cityName = snapshot.data ?? '-';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.apartment_rounded,
                            size: 14, color: AppTheme.textSecondary(context)),
                        const SizedBox(width: 4),
                        Expanded(
                            child: Text(cityName,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary(context)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis)),
                      ]),
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.location_on_rounded,
                            size: 14, color: AppTheme.textSecondary(context)),
                        const SizedBox(width: 4),
                        Expanded(
                            child: Text(
                                '${w.kecamatan ?? '-'}, ${w.kelurahan ?? '-'}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary(context)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis)),
                      ]),
                    ],
                  );
                },
              ),

              if (w.latitude != null && w.longitude != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.explore_rounded,
                      size: 14, color: AppTheme.textSecondary(context)),
                  const SizedBox(width: 4),
                  Text(
                      '${w.latitude!.toStringAsFixed(4)}, ${w.longitude!.toStringAsFixed(4)}',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary(context),
                          fontFamily: 'monospace')),
                ]),
              ],
              if (w.canEditBySubmitter) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isDeleting
                            ? null
                            : () async {
                                final updated = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        InputWisataScreen(existingWisata: w),
                                  ),
                                );

                                if (updated == true && mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        w.status == 'rejected'
                                            ? 'Revisi pengajuan berhasil diajukan ulang'
                                            : 'Pengajuan berhasil diperbarui',
                                      ),
                                      backgroundColor:
                                          AppTheme.primary(context),
                                    ),
                                  );
                                }
                              },
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: Text(
                          w.status == 'rejected'
                              ? 'Perbaiki'
                              : 'Edit Pengajuan',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary(context),
                          side: BorderSide(color: AppTheme.primary(context)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            isDeleting ? null : () => _cancelSubmission(w),
                        icon: isDeleting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.delete_outline_rounded,
                                size: 18),
                        label: Text(
                          isDeleting
                              ? 'Membatalkan...'
                              : 'Batalkan Pengajuan',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.error,
                          side: BorderSide(color: AppTheme.error),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ])),
      ),
    );
  }

  Future<void> _cancelSubmission(Wisata wisata) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface(ctx),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.error),
            const SizedBox(width: 10),
            Text(
              'Batalkan Pengajuan',
              style: TextStyle(
                color: AppTheme.textPrimary(ctx),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Text(
          'Pengajuan "${wisata.namaTempat}" akan dihapus dan tidak lagi masuk ke admin web. Lanjutkan?',
          style: TextStyle(
            color: AppTheme.textSecondary(ctx),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Tutup',
              style: TextStyle(color: AppTheme.textSecondary(ctx)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _deletingSubmissionIds.add(wisata.id));

    try {
      await SupabaseWisataService.deleteSubmission(wisata);
      SubmissionReviewNotificationService.instance.refresh();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Pengajuan berhasil dibatalkan'),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            NetworkErrorHelper.normalizeMessage(
              error,
              fallback: 'Gagal membatalkan pengajuan',
            ),
          ),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _deletingSubmissionIds.remove(wisata.id));
      }
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'approved':
        return AppTheme.success;
      case 'rejected':
        return AppTheme.error;
      case 'pending':
        return const Color(0xFFF59E0B);
      default:
        return AppTheme.textSecondaryLight;
    }
  }

  String _getStatusLabel(String? status) {
    switch (status) {
      case 'approved':
        return 'Disetujui';
      case 'rejected':
        return 'Ditolak';
      case 'pending':
        return 'Pending';
      default:
        return 'Unknown';
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      case 'pending':
        return Icons.schedule_rounded;
      default:
        return Icons.help_rounded;
    }
  }

  Widget _buildActiveFilterSummaryPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.tune_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_filterStatus != 'all')
                  _buildHeaderFilterPill(
                    icon: Icons.flag_rounded,
                    label: _getStatusLabel(_filterStatus),
                  ),
                if (_timeFilter != 'all')
                  _buildHeaderFilterPill(
                    icon: Icons.calendar_today_rounded,
                    label: _getTimeFilterLabel(_timeFilter),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: () {
              setState(() {
                _filterStatus = 'all';
                _timeFilter = 'all';
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.16),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.restart_alt_rounded, size: 14, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'Reset',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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

  Widget _buildHeaderFilterPill({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  _HistoryTimelineInfo _resolveHistoryTimelineInfo(Map<String, dynamic> row) {
    final status = row['status']?.toString();
    final createdAt = _parseRowDate(row['created_at']);
    final updatedAt = _parseRowDate(row['updated_at']);
    final reviewedAt = _parseRowDate(row['reviewed_at']);

    if (status == 'approved') {
      return _HistoryTimelineInfo(
        label: 'Disetujui',
        icon: Icons.check_circle_rounded,
        dateTime: reviewedAt ?? updatedAt ?? createdAt,
      );
    }

    if (status == 'rejected') {
      return _HistoryTimelineInfo(
        label: 'Ditolak',
        icon: Icons.cancel_rounded,
        dateTime: reviewedAt ?? updatedAt ?? createdAt,
      );
    }

    final isUpdated = createdAt != null &&
        updatedAt != null &&
        updatedAt.difference(createdAt).inMinutes.abs() >= 1;

    return _HistoryTimelineInfo(
      label: isUpdated ? 'Diperbarui' : 'Diajukan',
      icon: isUpdated ? Icons.edit_calendar_rounded : Icons.schedule_rounded,
      dateTime: updatedAt ?? createdAt,
    );
  }

  DateTime? _resolveHistoryTimestamp(Map<String, dynamic> row) {
    return _resolveHistoryTimelineInfo(row).dateTime;
  }

  DateTime? _parseRowDate(dynamic rawValue) {
    if (rawValue == null) {
      return null;
    }

    return DateTime.tryParse(rawValue.toString())?.toLocal();
  }

  bool _matchesTimeFilter(DateTime? date) {
    if (_timeFilter == 'all') {
      return true;
    }
    if (date == null) {
      return false;
    }

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    switch (_timeFilter) {
      case 'today':
        return !date.isBefore(todayStart);
      case 'week':
        final startOfWeek = todayStart.subtract(
          Duration(days: todayStart.weekday - 1),
        );
        return !date.isBefore(startOfWeek);
      case 'month':
        final startOfMonth = DateTime(now.year, now.month, 1);
        return !date.isBefore(startOfMonth);
      default:
        return true;
    }
  }

  String _getTimeFilterLabel(String value) {
    switch (value) {
      case 'today':
        return 'Hari ini';
      case 'week':
        return 'Minggu ini';
      case 'month':
        return 'Bulan ini';
      default:
        return 'Semua waktu';
    }
  }

  String _formatSubmissionDateTime(DateTime dateTime) {
    const monthNames = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];

    final day = dateTime.day.toString().padLeft(2, '0');
    final month = monthNames[dateTime.month - 1];
    final year = dateTime.year.toString();
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$day $month $year, $hour:$minute';
  }
}

class _HistoryTimelineInfo {
  const _HistoryTimelineInfo({
    required this.label,
    required this.icon,
    required this.dateTime,
  });

  final String label;
  final IconData icon;
  final DateTime? dateTime;
}
