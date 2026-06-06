/// ============================================================
/// Tourscape MS — Main Screen (Bottom Navigation)
/// 3 Tab: Beranda, Peta, Riwayat
/// ============================================================

import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/wisata_model.dart';
import '../widgets/history_notification_badge.dart';
import 'home_screen.dart';
import 'map_screen.dart';
import 'history_screen.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;
  final Wisata? initialRouteTarget;
  final Wisata? initialDetailTarget;

  const MainScreen({
    super.key,
    this.initialIndex = 0,
    this.initialRouteTarget,
    this.initialDetailTarget,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;
  late final List<Widget?> _pageCache;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageCache = List<Widget?>.filled(3, null, growable: false);
    _pageCache[_currentIndex] = _buildPage(_currentIndex);
  }

  void _switchTab(int index) {
    if (_currentIndex == index) return;
    setState(() {
      _currentIndex = index;
      _pageCache[index] ??= _buildPage(index);
    });
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return const HomeScreen();
      case 1:
        return MapScreen(
          initialRouteTarget: widget.initialRouteTarget,
          initialDetailTarget: widget.initialDetailTarget,
        );
      case 2:
        return const HistoryScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: List<Widget>.generate(
          _pageCache.length,
          (index) => _pageCache[index] ?? const SizedBox.shrink(),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
          border: Border(
            top: BorderSide(color: AppTheme.border(context), width: 0.5),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, 'Beranda'),
                _buildNavItem(1, Icons.map_rounded, Icons.map_outlined, 'Peta'),
                _buildNavItem(2, Icons.history_rounded, Icons.history_outlined, 'Riwayat'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => _switchTab(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary(context).withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: index == 2
                  ? HistoryNotificationBadge(
                      key: ValueKey('history-$isActive'),
                      top: -1,
                      right: -2,
                      child: Icon(
                        isActive ? activeIcon : inactiveIcon,
                        key: ValueKey(isActive),
                        color: isActive
                            ? AppTheme.primary(context)
                            : AppTheme.textSecondary(context),
                        size: 24,
                      ),
                    )
                  : Icon(
                      isActive ? activeIcon : inactiveIcon,
                      key: ValueKey(isActive),
                      color: isActive
                          ? AppTheme.primary(context)
                          : AppTheme.textSecondary(context),
                      size: 24,
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? AppTheme.primary(context) : AppTheme.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
