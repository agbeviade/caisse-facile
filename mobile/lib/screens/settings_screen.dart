import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final email = AuthService.instance.currentUser?.email ?? '—';
    final shopName = AuthService.instance.shopName ?? '—';
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _section('Compte'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Email'),
            subtitle: Text(email),
          ),
          ListTile(
            leading: const Icon(Icons.storefront),
            title: const Text('Boutique active'),
            subtitle: Text(shopName),
          ),
          const Divider(),
          _section('Apparence'),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeService.instance.mode,
            builder: (_, mode, __) {
              return Column(
                children: [
                  RadioListTile<ThemeMode>(
                    title: const Text('Système'),
                    subtitle: const Text('Suit le réglage du téléphone'),
                    value: ThemeMode.system,
                    groupValue: mode,
                    onChanged: (v) =>
                        v == null ? null : ThemeService.instance.set(v),
                  ),
                  RadioListTile<ThemeMode>(
                    title: const Text('Clair'),
                    value: ThemeMode.light,
                    groupValue: mode,
                    onChanged: (v) =>
                        v == null ? null : ThemeService.instance.set(v),
                  ),
                  RadioListTile<ThemeMode>(
                    title: const Text('Sombre'),
                    value: ThemeMode.dark,
                    groupValue: mode,
                    onChanged: (v) =>
                        v == null ? null : ThemeService.instance.set(v),
                  ),
                ],
              );
            },
          ),
          const Divider(),
          _section('À propos'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Caisse Facile'),
            subtitle: Text('Version 1.0.0'),
          ),
        ],
      ),
    );
  }

  Widget _section(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
        child: Text(label.toUpperCase(),
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: Colors.grey)),
      );
}
