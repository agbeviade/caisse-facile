import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/env.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'services/theme_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  await ThemeService.instance.load();
  if (Env.hasSupabase) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
  }
  runApp(const CaisseFacileApp());
  // Remove the splash on the next frame, once the first widget tree is up.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    FlutterNativeSplash.remove();
  });
}

class CaisseFacileApp extends StatelessWidget {
  const CaisseFacileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.instance.mode,
      builder: (_, mode, __) {
        return MaterialApp(
          title: 'Caisse Facile',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: mode,
          home: Env.hasSupabase ? const _AuthGate() : const HomeScreen(),
        );
      },
    );
  }
}

/// Routes between AuthScreen / ShopPicker / HomeScreen based on auth state.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (ctx, snap) {
        final signedIn = AuthService.instance.isSignedIn;
        if (!signedIn) return const AuthScreen();
        if (AuthService.instance.shopId == null) {
          return const _ShopGate();
        }
        return const HomeScreen();
      },
    );
  }
}

class _ShopGate extends StatefulWidget {
  const _ShopGate();
  @override
  State<_ShopGate> createState() => _ShopGateState();
}

class _ShopGateState extends State<_ShopGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ShopPickerScreen()),
      );
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    if (AuthService.instance.shopId != null) return const HomeScreen();
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
