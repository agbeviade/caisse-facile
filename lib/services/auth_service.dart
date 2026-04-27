import 'package:supabase_flutter/supabase_flutter.dart';

/// Wraps Supabase auth + tracks the active shop_id for RLS.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  SupabaseClient get _client => Supabase.instance.client;

  String? _shopId;
  String? get shopId => _shopId;
  User? get currentUser => _client.auth.currentUser;
  bool get isSignedIn => currentUser != null;

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
    return id;
  }

  void setShop(String id) => _shopId = id;
}
