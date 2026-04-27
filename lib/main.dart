import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/env.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Env.hasSupabase) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
  }
  runApp(const CaisseFacileApp());
}

class CaisseFacileApp extends StatelessWidget {
  const CaisseFacileApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0E7C3A),
      brightness: Brightness.light,
    );
    return MaterialApp(
      title: 'Caisse Facile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
        cardTheme: CardTheme(
          elevation: 1,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
      ),
      home: Env.hasSupabase ? const _AuthGate() : const HomeScreen(),
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
