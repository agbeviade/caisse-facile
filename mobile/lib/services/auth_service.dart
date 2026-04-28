import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// Wraps Supabase auth + tracks the active shop_id for RLS.
///
/// All Supabase calls are guarded by [Env.hasSupabase] so the app stays
/// fully usable in offline-only mode (when no SUPABASE_URL is provided
/// at build time).
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  SupabaseClient get _client => Supabase.instance.client;

  String? _shopId;
  String? _shopName;
  String? get shopId => _shopId;
  String? get shopName => _shopName;
  User? get currentUser =>
      Env.hasSupabase ? _client.auth.currentUser : null;
  bool get isSignedIn => Env.hasSupabase && currentUser != null;

  Future<void> signInWithPassword(
      {required String email, required String password}) async {
    await _client.auth
        .signInWithPassword(email: email, password: password);
  }

  Future<void> signUp(
      {required String email, required String password}) async {
    await _client.auth.signUp(email: email, password: password);
  }

  Future<void> signOut() async {
    _shopId = null;
    _shopName = null;
    await _client.auth.signOut();
  }

  /// Fetch shops the user belongs to.
  Future<List<Map<String, dynamic>>> myShops() async {
    final res = await _client
        .from('shop_members')
        .select('shop_id, role, shops(id, name, currency)')
        .eq('user_id', currentUser!.id);
    return List<Map<String, dynamic>>.from(res);
  }

  /// Create a new shop via RPC and remembers it.
  Future<String> createShop(String name, {String currency = 'F'}) async {
    final res = await _client.rpc('create_shop',
        params: {'p_name': name, 'p_currency': currency});
    final id = res as String;
    _shopId = id;
    _shopName = name;
    return id;
  }

  void setShop(String id, {String? name}) {
    _shopId = id;
    if (name != null) _shopName = name;
  }
}
