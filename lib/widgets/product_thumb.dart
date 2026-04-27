import 'dart:io';
import 'package:flutter/material.dart';

/// Square thumbnail showing the product image or a colored placeholder
/// derived from the product name (so each product has a stable visual identity).
class ProductThumb extends StatelessWidget {
  final String? imagePath;
  final String name;
  final double size;
  final double radius;

  const ProductThumb({
    super.key,
    required this.imagePath,
    required this.name,
    this.size = 56,
    this.radius = 10,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    if (imagePath != null && imagePath!.isNotEmpty) {
      final file = File(imagePath!);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: r,
          child: Image.file(file,
              width: size, height: size, fit: BoxFit.cover),
        );
      }
    }
    return _placeholder(context, r);
  }

  Widget _placeholder(BuildContext context, BorderRadius r) {
    final color = _colorFor(name);
    final initials = _initials(name);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, borderRadius: r),
      alignment: Alignment.center,
      child: Text(initials,
          style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.36,
              fontWeight: FontWeight.bold)),
    );
  }

  static String _initials(String name) {
    final t = name.trim();
    if (t.isEmpty) return '?';
    final parts = t.split(RegExp(r'\s+'));
    String take(String s, int n) => s.length <= n ? s : s.substring(0, n);
    if (parts.length == 1) return take(parts.first, 2).toUpperCase();
    return (take(parts[0], 1) + take(parts[1], 1)).toUpperCase();
  }

  static const _palette = [
    Color(0xFF0E7C3A),
    Color(0xFF1565C0),
    Color(0xFFE65100),
    Color(0xFF6A1B9A),
    Color(0xFFC62828),
    Color(0xFF00838F),
    Color(0xFF558B2F),
    Color(0xFF4527A0),
  ];

  static Color _colorFor(String s) {
    int h = 0;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return _palette[h % _palette.length];
  }
}
