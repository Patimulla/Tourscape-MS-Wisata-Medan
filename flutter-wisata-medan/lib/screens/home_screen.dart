/// ============================================================
/// Tourscape MS — Home Screen (Dashboard)
/// ============================================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/auth_redirect_config.dart';
import '../config/app_theme.dart';
import '../models/admin_model.dart';
import '../services/admin_presence_service.dart';
import '../services/submission_review_notification_service.dart';
import '../utils/network_error_helper.dart';
import '../widgets/app_shimmer.dart';
import '../widgets/history_notification_badge.dart';
import 'admin_directory_screen.dart';
import 'about_app_screen.dart';
import 'input_wisata_screen.dart';
import 'history_screen.dart';
import 'usage_guide_screen.dart';
import 'wisata_list_screen.dart';
import 'login_screen.dart';
import '../main.dart';

enum _StatsScope { all, mine }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _supabase = Supabase.instance.client;
  Admin? _admin;
  bool _isUploadingProfile = false;
  _StatsScope _statsScope = _StatsScope.all;
  Future<List<Map<String, dynamic>>>? _statsFuture;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    AdminPresenceService.instance.startTracking();
    _loadProfile();
    _statsFuture = _loadStatsRows();
    _animCtrl.forward();
  }

  @override
  void dispose() { _animCtrl.dispose(); super.dispose(); }

  Future<List<Map<String, dynamic>>> _loadStatsRows() async {
    final response = await _supabase
        .from('wisata')
        .select('status, submitter_user_id')
        .order('created_at', ascending: false);

    return response
        .whereType<Map>()
        .map((row) => row.map((key, value) => MapEntry(key.toString(), value)))
        .toList();
  }

  Future<void> _refreshHomeData() async {
    final statsFuture = _loadStatsRows();
    setState(() {
      _statsFuture = statsFuture;
    });
    await Future.wait([
      _loadProfile(),
      statsFuture,
    ]);
  }

  Future<void> _loadProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final data = await _supabase
            .from('admin_mobile')
            .select('id, username, no_pegawai, foto_profil, created_at')
            .eq('id', user.id)
            .maybeSingle();

        if (!mounted) return;

        if (data != null) {
          setState(() {
            _admin = Admin.fromJson({
              ...data,
              'email': user.email ?? '',
            });
          });
          return;
        }

        setState(() {
          _admin = Admin(
            id: user.id,
            nama: user.email?.split('@').first ?? 'Admin',
            email: user.email ?? '',
            nomorPegawai: '-',
          );
        });
      }
    } catch (e) { print('Error loading profile: $e'); }
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.logout_rounded, color: AppTheme.error, size: 24),
          const SizedBox(width: 10),
          Text('Keluar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary(context))),
        ]),
        content: Text('Apakah Anda yakin ingin keluar?', style: TextStyle(color: AppTheme.textSecondary(context))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Batal', style: TextStyle(color: AppTheme.textSecondary(context)))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white), child: const Text('Keluar')),
        ],
      ),
    );
    if (shouldLogout == true) {
      await AdminPresenceService.instance.stopTracking();
      await _supabase.auth.signOut();
      if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
    }
  }

  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Selamat Pagi';
    if (h < 15) return 'Selamat Siang';
    if (h < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }


  Widget _buildHeaderGreeting(String name, bool isProfileLoading) {
    if (isProfileLoading) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AppShimmerBox(
          height: 14,
          width: 108,
          color: Colors.white.withValues(alpha: 0.18),
          highlightColor: Colors.white.withValues(alpha: 0.3),
        ),
        const SizedBox(height: 8),
        AppShimmerBox(
          height: 24,
          width: 176,
          color: Colors.white.withValues(alpha: 0.16),
          highlightColor: Colors.white.withValues(alpha: 0.28),
        ),
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_getGreeting(), style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7))),
      const SizedBox(height: 4),
      Text('Halo, $name!', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5)),
    ]);
  }

  Widget _buildHeaderAvatar(String name, bool isProfileLoading) {
    if (_admin?.fotoProfil != null && _admin!.fotoProfil!.isNotEmpty) {
      return Image.network(_admin!.fotoProfil!, fit: BoxFit.cover, width: 46, height: 46);
    }

    if (isProfileLoading) {
      return AppShimmerBox(
        width: 46,
        height: 46,
        borderRadius: BorderRadius.zero,
        color: Colors.white.withValues(alpha: 0.16),
        highlightColor: Colors.white.withValues(alpha: 0.26),
      );
    }

    return Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'A', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final name = _admin?.nama ?? 'Admin';
    final isProfileLoading = _admin == null;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.bg(context),
      drawer: _buildDrawer(),
      body: RefreshIndicator(
        color: AppTheme.primary(context),
        onRefresh: _refreshHomeData,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: CustomScrollView(slivers: [
            // Header
            SliverToBoxAdapter(child: Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              decoration: BoxDecoration(
                gradient: AppTheme.appBarGradient(context),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 15, offset: const Offset(0, 5))],
              ),
              child: SafeArea(bottom: false, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  GestureDetector(
                    onTap: () => _scaffoldKey.currentState?.openDrawer(),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.menu_rounded, color: Colors.white, size: 24),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: _buildHeaderGreeting(name, isProfileLoading)),
                  GestureDetector(
                    onTap: () => _scaffoldKey.currentState?.openDrawer(),
                    child: Container(width: 46, height: 46, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2)),
                      child: ClipOval(
                        child: _buildHeaderAvatar(name, isProfileLoading),
                      ),
                    ),
                  ),
                ]),
                if (isProfileLoading) ...[
                  const SizedBox(height: 8),
                  AppShimmerBox(
                    height: 12,
                    width: 96,
                    color: Colors.white.withValues(alpha: 0.16),
                    highlightColor: Colors.white.withValues(alpha: 0.24),
                  ),
                ] else if (_admin != null) ...[const SizedBox(height: 8), Text('NIP: ${_admin!.nomorPegawai}', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)))],
              ])),
            )),

            // Stats
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: _buildStatsSection(),
              ),
            ),

            // Quick Actions
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 28, 20, 0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Aksi Cepat', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary(context))),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _actionCard(Icons.add_location_alt_rounded, 'Input\nWisata', const Color(0xFF22C55E), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InputWisataScreen())))),
                const SizedBox(width: 12),
                Expanded(child: _actionCard(Icons.history_rounded, 'Riwayat\nPengajuan', const Color(0xFFA855F7), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen())), withHistoryBadge: true)),
                const SizedBox(width: 12),
                Expanded(child: _actionCard(Icons.place_rounded, 'Wisata\nTersedia', const Color(0xFF3B82F6), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WisataListScreen())))),
              ]),
              const SizedBox(height: 12),
              _wideActionCard(
                icon: Icons.groups_rounded,
                title: 'Admin Terdaftar',
                subtitle: 'Lihat admin lain, status online, dan kontribusi wisata mereka',
                color: const Color(0xFFF97316),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminDirectoryScreen(),
                  ),
                ),
              ),
            ]))),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Informasi & Panduan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _wideActionCard(
                      icon: Icons.info_rounded,
                      title: 'Tentang Aplikasi',
                      subtitle:
                          'Kenali peran mobile, peta, riwayat pengajuan, dan hubungan sistem dengan admin web.',
                      color: AppTheme.primary(context),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AboutAppScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _wideActionCard(
                      icon: Icons.menu_book_rounded,
                      title: 'Panduan Penggunaan',
                      subtitle:
                          'Lihat alur pengajuan, revisi, navigasi peta, dan cara input lokasi baru dengan benar.',
                      color: const Color(0xFF3B82F6),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const UsageGuideScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    final currentUserId = _supabase.auth.currentUser?.id;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _statsFuture,
      builder: (context, snapshot) {
        final rawRows = snapshot.data ?? const <Map<String, dynamic>>[];
        final isLoading = snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null;
        final scopedRows = rawRows.where((row) {
          final status = row['status']?.toString();
          final isActiveRecord = status == 'pending' || status == 'approved';
          if (!isActiveRecord) {
            return false;
          }

          if (_statsScope == _StatsScope.all) {
            return true;
          }

          return currentUserId != null && row['submitter_user_id'] == currentUserId;
        }).toList();

        final totalWisata = scopedRows.length;
        final pendingWisata =
            scopedRows.where((w) => w['status'] == 'pending').length;
        final approvedWisata =
            scopedRows.where((w) => w['status'] == 'approved').length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Statistik Wisata', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary(context))),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _statsScopeChip(
                    icon: Icons.groups_rounded,
                    label: 'Semua',
                    isSelected: _statsScope == _StatsScope.all,
                    onTap: () => setState(() => _statsScope = _StatsScope.all),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statsScopeChip(
                    icon: Icons.person_rounded,
                    label: 'Saya',
                    isSelected: _statsScope == _StatsScope.mine,
                    onTap: () => setState(() => _statsScope = _StatsScope.mine),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _statsScope == _StatsScope.all
                  ? 'Menampilkan total pengajuan dari seluruh admin mobile.'
                  : 'Menampilkan seluruh pengajuan dari akun Anda.',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary(context),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _statCard(Icons.place_rounded, 'Total Diajukan', isLoading ? '...' : '$totalWisata', AppTheme.primary(context))),
              const SizedBox(width: 12),
              Expanded(child: _statCard(Icons.pending_actions_rounded, 'Pending', isLoading ? '...' : '$pendingWisata', const Color(0xFFF59E0B))),
              const SizedBox(width: 12),
              Expanded(child: _statCard(Icons.check_circle_rounded, 'Disetujui', isLoading ? '...' : '$approvedWisata', AppTheme.success)),
            ]),
          ],
        );
      },
    );
  }

  Widget _statsScopeChip({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary(context).withValues(alpha: 0.12)
              : AppTheme.card(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary(context)
                : AppTheme.border(context),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? AppTheme.primary(context)
                  : AppTheme.textSecondary(context),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? AppTheme.primary(context)
                    : AppTheme.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(IconData icon, String label, String value, Color color) {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppTheme.card(context), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border(context)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle), child: Icon(icon, color: color, size: 22)),
        const SizedBox(height: 10),
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context), fontWeight: FontWeight.w500), textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _actionCard(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap, {
    bool withHistoryBadge = false,
  }) {
    return GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12), decoration: BoxDecoration(color: AppTheme.card(context), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border(context)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(children: [
        withHistoryBadge
            ? HistoryNotificationBadge(
                top: -2,
                right: -2,
                child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]), borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))]),
                  child: Icon(icon, color: Colors.white, size: 26)),
              )
            : Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]), borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))]),
                child: Icon(icon, color: Colors.white, size: 26)),
        const SizedBox(height: 10),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary(context)), textAlign: TextAlign.center),
      ]),
    ));
  }

  Widget _wideActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.card(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.72)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.26),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textSecondary(context),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadProfilePhoto() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1200,
      maxHeight: 1200,
    );

    if (image == null || _admin == null) return;

    setState(() => _isUploadingProfile = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final file = File(image.path);
      final fileExt = image.path.split('.').last.toLowerCase();
      final fileName =
          'avatar_${user.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final path = 'admin-mobile/${user.id}/$fileName';

      await _supabase.storage.from('profiles').upload(
            path,
            file,
            fileOptions: const FileOptions(upsert: true),
          );

      final imageUrl = _supabase.storage.from('profiles').getPublicUrl(path);

      await _supabase.from('admin_mobile').update({
        'foto_profil': imageUrl,
      }).eq('id', user.id);

      await _loadProfile();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Foto profil berhasil diperbarui'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            NetworkErrorHelper.normalizeMessage(
              e,
              fallback: 'Gagal mengunggah foto profil',
            ),
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingProfile = false);
      }
    }
  }

  Future<void> _sendPasswordResetEmail() async {
    final user = _supabase.auth.currentUser;
    final email = user?.email ?? _admin?.email ?? '';

    if (email.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Email akun admin tidak ditemukan.'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: AuthRedirectConfig.passwordResetRedirectTo,
      );
      

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Email ganti password sudah dikirim ke $email'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            NetworkErrorHelper.normalizeMessage(
              e.message,
              fallback: e.message,
            ),
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            NetworkErrorHelper.normalizeMessage(
              e,
              fallback: 'Gagal mengirim email ganti password',
            ),
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showAdminDetails() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        final surface = AppTheme.surface(context);
        final name = _admin?.nama ?? 'Admin';
        final nip = _admin?.nomorPegawai ?? '-';
        final email = _admin?.email ?? '-';

        return Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.border(context),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppTheme.appBarGradient(context),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () async {
                            Navigator.pop(context);
                            await _pickAndUploadProfilePhoto();
                            if (mounted) {
                              _showAdminDetails();
                            }
                          },
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                width: 92,
                                height: 92,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.28),
                                    width: 2.5,
                                  ),
                                ),
                                child: ClipOval(
                                  child: _isUploadingProfile
                                      ? const Center(
                                          child: SizedBox(
                                            width: 28,
                                            height: 28,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.4,
                                            ),
                                          ),
                                        )
                                      : _admin?.fotoProfil != null &&
                                              _admin!.fotoProfil!.isNotEmpty
                                          ? Image.network(
                                              _admin!.fotoProfil!,
                                              fit: BoxFit.cover,
                                              width: 92,
                                              height: 92,
                                            )
                                          : Center(
                                              child: Text(
                                                name.isNotEmpty
                                                    ? name[0].toUpperCase()
                                                    : 'A',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 34,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.camera_alt_rounded,
                                  size: 14,
                                  color: AppTheme.primary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
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
                              Icon(
                                Icons.badge_rounded,
                                size: 14,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                nip,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.95),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildAdminActionButton(
                          icon: Icons.edit_rounded,
                          label: 'Edit Profil',
                          onTap: () {
                            Navigator.pop(context);
                            _showEditProfileDialog();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildAdminActionButton(
                          icon: Icons.lock_reset_rounded,
                          label: 'Reset Password',
                          onTap: () {
                            Navigator.pop(context);
                            _sendPasswordResetEmail();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: AppTheme.glassDecoration(context).copyWith(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Informasi Admin',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildDetailRow(
                          Icons.badge_rounded,
                          'No. Pegawai',
                          nip,
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          Icons.person_rounded,
                          'Nama (Username)',
                          name,
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          Icons.email_rounded,
                          'Email',
                          email,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showEditProfileDialog() {
    if (_admin == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Tidak ada koneksi internet. Periksa koneksi Anda.'), backgroundColor: AppTheme.error));
      return;
    }
    
    final namaCtrl = TextEditingController(text: _admin!.nama);
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            contentPadding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            titlePadding: EdgeInsets.zero,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface(context),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 24,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                        decoration: BoxDecoration(
                          gradient: AppTheme.appBarGradient(context),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.22),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.edit_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Edit Profil Admin',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.18),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.badge_rounded,
                                    size: 14,
                                    color: Colors.white.withValues(alpha: 0.92),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _admin!.nomorPegawai,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.95),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nama (Username)',
                              style: TextStyle(
                                color: AppTheme.textPrimary(context),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: namaCtrl,
                              style: TextStyle(color: AppTheme.textPrimary(context)),
                              decoration: InputDecoration(
                                hintText: 'Masukkan nama admin',
                                hintStyle: TextStyle(
                                  color: AppTheme.textSecondary(context),
                                ),
                                filled: true,
                                fillColor: AppTheme.card(context),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: AppTheme.border(context),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: AppTheme.primary(context),
                                    width: 1.4,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: isLoading ? null : () => Navigator.pop(ctx),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.textSecondary(context),
                                      side: BorderSide(color: AppTheme.border(context)),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: const Text(
                                      'Batal',
                                      style: TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: isLoading ? null : () async {
                                      if (namaCtrl.text.trim().isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Username tidak boleh kosong'), backgroundColor: AppTheme.error));
                                        return;
                                      }
                                      
                                      setDialogState(() => isLoading = true);
                                      try {
                                        final user = _supabase.auth.currentUser;
                                        if (user != null) {
                                          await _supabase
                                              .from('admin_mobile')
                                              .update({
                                                'username': namaCtrl.text.trim(),
                                              })
                                              .eq('id', user.id);
                                          
                                          await _loadProfile();
                                          
                                          if (mounted) {
                                            Navigator.pop(ctx);
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Profil berhasil diperbarui!'), backgroundColor: AppTheme.success, behavior: SnackBarBehavior.floating));
                                          }
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(NetworkErrorHelper.normalizeMessage(e, fallback: 'Gagal menyimpan')), backgroundColor: AppTheme.error));
                                        }
                                      } finally {
                                        if (mounted) setDialogState(() => isLoading = false);
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primary(context),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: isLoading
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.2,
                                            ),
                                          )
                                        : const Text(
                                            'Simpan',
                                            style: TextStyle(fontWeight: FontWeight.w700),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.border(context),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary(context).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: AppTheme.primary(context)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.card(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border(context)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: AppTheme.primary(context)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    final name = _admin?.nama ?? 'Admin';
    final email = _admin?.email ?? '-';
    
    return Drawer(
      backgroundColor: AppTheme.bg(context),
      child: Column(
        children: [
          // Custom Drawer Header
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              _showAdminDetails();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 24),
              decoration: BoxDecoration(
                gradient: AppTheme.appBarGradient(context),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: _pickAndUploadProfilePhoto,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: ClipOval(
                            child: _isUploadingProfile
                                ? const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : _admin?.fotoProfil != null && _admin!.fotoProfil!.isNotEmpty
                                    ? Image.network(_admin!.fotoProfil!, fit: BoxFit.cover, width: 72, height: 72)
                                    : Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'A', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700))),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: Icon(Icons.camera_alt_rounded, size: 14, color: AppTheme.primary(context)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.email_rounded, size: 14, color: Colors.white.withValues(alpha: 0.8)),
                      const SizedBox(width: 6),
                      Text(email, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 12, bottom: 12),
              child: Column(
                children: [
                  _buildDrawerSectionLabel('Pintasan'),
                  _buildDrawerNavTile(
                    icon: Icons.add_location_alt_rounded,
                    label: 'Input Wisata',
                    color: const Color(0xFF22C55E),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const InputWisataScreen()),
                      );
                    },
                  ),
                  _buildDrawerNavTile(
                    icon: Icons.history_rounded,
                    label: 'Riwayat Pengajuan',
                    color: const Color(0xFFA855F7),
                    withHistoryBadge: true,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HistoryScreen()),
                      );
                    },
                  ),
                  _buildDrawerNavTile(
                    icon: Icons.place_rounded,
                    label: 'Wisata Tersedia',
                    color: const Color(0xFF3B82F6),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const WisataListScreen()),
                      );
                    },
                  ),
                  _buildDrawerNavTile(
                    icon: Icons.groups_rounded,
                    label: 'Admin Terdaftar',
                    color: const Color(0xFFF97316),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminDirectoryScreen()),
                      );
                    },
                  ),
                  _buildDrawerSectionLabel('Panduan'),
                  _buildDrawerNavTile(
                    icon: Icons.info_rounded,
                    label: 'Tentang Aplikasi',
                    color: AppTheme.primary(context),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AboutAppScreen()),
                      );
                    },
                  ),
                  _buildDrawerNavTile(
                    icon: Icons.menu_book_rounded,
                    label: 'Panduan Penggunaan',
                    color: const Color(0xFF3B82F6),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const UsageGuideScreen()),
                      );
                    },
                  ),
                  _buildDrawerSectionLabel('Pengaturan'),
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: themeNotifier,
                    builder: (_, ThemeMode currentMode, __) {
                      final isDark = currentMode == ThemeMode.dark;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: AppTheme.textPrimary(context).withValues(alpha: 0.05), shape: BoxShape.circle),
                          child: Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: AppTheme.textPrimary(context), size: 20),
                        ),
                        title: Text('Mode Gelap', style: TextStyle(color: AppTheme.textPrimary(context), fontWeight: FontWeight.w600, fontSize: 15)),
                        trailing: Switch(
                          value: isDark,
                          activeColor: AppTheme.primary(context),
                          onChanged: (val) => themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const Divider(),

          _buildDrawerSectionLabel('Akun'),

          // Logout
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(Icons.logout_rounded, color: AppTheme.error, size: 20),
            ),
            title: Text('Keluar', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.w600, fontSize: 15)),
            onTap: () {
              Navigator.pop(context); // Close drawer
              _logout();
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDrawerSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            color: AppTheme.textSecondary(context),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerNavTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool withHistoryBadge = false,
  }) {
    final iconWidget = Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: withHistoryBadge
          ? HistoryNotificationBadge(
              top: -1,
              right: -2,
              child: iconWidget,
            )
          : iconWidget,
      title: Text(
        label,
        style: TextStyle(
          color: AppTheme.textPrimary(context),
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: AppTheme.textSecondary(context),
        size: 20,
      ),
      onTap: onTap,
    );
  }
}
