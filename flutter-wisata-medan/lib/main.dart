/// ============================================================
/// Tourscape MS — Main Entry Point
/// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/reset_password_screen.dart';

// Global notifier for dark mode toggle
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Supabase
  await Supabase.initialize(
    url: 'https://ekslfvczghsmiqkothdm.supabase.co', // Ganti URL Anda
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVrc2xmdmN6Z2hzbWlxa290aGRtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5ODc3ODYsImV4cCI6MjA5MDU2Mzc4Nn0.uFwuatl1DX8Xlhdb70fhgc7AJrD-OVb5xczOUQ4503Y', // Ganti KEY Anda
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();

    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        final navigator = appNavigatorKey.currentState;
        if (navigator == null) return;

        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
          (_) => false,
        );
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        // Check if user is already logged in
        final session = Supabase.instance.client.auth.currentSession;
        final isLoggedIn = session != null;

        return MaterialApp(
          navigatorKey: appNavigatorKey,
          title: 'Tourscape MS',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          home: isLoggedIn ? const MainScreen() : const LoginScreen(),
        );
      },
    );
  }
}
