import 'package:flutter/material.dart';
import '../services/auth_service.dart';

/// Login / sign-up + shop selection. Optional: only shown when Supabase is configured.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isSignUp = false;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isSignUp) {
        await AuthService.instance.signUp(
            email: _email.text.trim(), password: _password.text);
      } else {
        await AuthService.instance.signInWithPassword(
            email: _email.text.trim(), password: _password.text);
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ShopPickerScreen()),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSignUp ? "Créer un compte" : "Connexion"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            const Icon(Icons.storefront, size: 80),
            const SizedBox(height: 16),
            const Text("Caisse Facile",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                  labelText: "Email", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: "Mot de passe", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!,
                    style: const TextStyle(color: Colors.red)),
              ),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: Text(_loading
                  ? "..."
                  : (_isSignUp ? "Créer le compte" : "Se connecter")),
            ),
            TextButton(
              onPressed: () => setState(() => _isSignUp = !_isSignUp),
              child: Text(_isSignUp
                  ? "J'ai déjà un compte"
                  : "Créer un nouveau compte"),
            ),
          ],
        ),
      ),
    );
  }
}

class ShopPickerScreen extends StatefulWidget {
  const ShopPickerScreen({super.key});

  @override
  State<ShopPickerScreen> createState() => _ShopPickerScreenState();
}

class _ShopPickerScreenState extends State<ShopPickerScreen> {
  List<Map<String, dynamic>> _shops = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final s = await AuthService.instance.myShops();
    if (!mounted) return;
    setState(() {
      _shops = s;
      _loading = false;
    });
  }

  Future<void> _create() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Nom de la boutique"),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Annuler")),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Créer")),
        ],
      ),
    );
    if (ok != true || ctrl.text.trim().isEmpty) return;
    await AuthService.instance.createShop(ctrl.text.trim());
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  void _pick(String id, String name) {
    AuthService.instance.setShop(id, name: name);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Choisir la boutique"),
        actions: [
          IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await AuthService.instance.signOut();
                if (!mounted) return;
                Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AuthScreen()));
              }),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _shops.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.storefront, size: 80, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text("Aucune boutique associée à ce compte",
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                            onPressed: _create,
                            icon: const Icon(Icons.add),
                            label: const Text("Créer une boutique")),
                      ],
                    ),
                  ),
                )
              : ListView(
                  children: [
                    ..._shops.map((row) {
                      final shop = row['shops'] as Map<String, dynamic>;
                      return ListTile(
                        leading: const Icon(Icons.store),
                        title: Text(shop['name'] as String),
                        subtitle: Text('Rôle: ${row['role']}'),
                        onTap: () => _pick(
                            shop['id'] as String, shop['name'] as String),
                      );
                    }),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.add),
                      title: const Text("Créer une boutique"),
                      onTap: _create,
                    ),
                  ],
                ),
    );
  }
}
