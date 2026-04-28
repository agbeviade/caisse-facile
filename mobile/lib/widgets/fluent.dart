import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// Monospace text for monetary amounts, quantities and other numeric values.
/// Uses Roboto Mono so columns of numbers align perfectly across rows.
class MoneyText extends StatelessWidget {
  final String text;
  final double fontSize;
  final FontWeight fontWeight;
  final Color? color;
  final TextAlign? textAlign;

  const MoneyText(
    this.text, {
    super.key,
    this.fontSize = 14,
    this.fontWeight = FontWeight.w600,
    this.color,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      style: GoogleFonts.robotoMono(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: -0.2,
      ),
    );
  }
}

/// Brand colors exposed as a convenient `BuildContext` extension so screens
/// don't have to import `AppTheme` directly.
extension BrandColors on BuildContext {
  Color get warningColor => AppTheme.amber;
  Color get dangerColor => AppTheme.danger;
  Color get navyColor => AppTheme.navy;
}

/// Small colored square holding an icon — used everywhere as a "feature badge".
/// Matches the Souvenir AI / shadcn aesthetic: 40x40 rounded container with a
/// 12% tinted background and the icon in the tint color.
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;
  final double iconSize;
  final double radius;

  const IconBadge({
    super.key,
    required this.icon,
    this.color,
    this.size = 40,
    this.iconSize = 22,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: c, size: iconSize),
    );
  }
}

/// Card showing: icon badge + title + subtitle, optionally with content stacked
/// underneath. Mirrors the Souvenir AI "Reglages IA" card pattern.
class FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? badgeColor;
  final Widget? trailing;
  final Widget? content;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  const FeatureCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.badgeColor,
    this.trailing,
    this.content,
    this.onTap,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconBadge(icon: icon, color: badgeColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(subtitle!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13.5,
                        height: 1.4)),
              ],
              if (content != null) ...[
                const SizedBox(height: 14),
                content!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Radio-style choice tile matching the Souvenir AI selection card pattern.
/// Selected state shows a thick colored border (no fill).
class RadioCard<T> extends StatelessWidget {
  final T value;
  final T groupValue;
  final ValueChanged<T> onChanged;
  final String title;
  final String? subtitle;

  const RadioCard({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? scheme.primary
                : scheme.outlineVariant.withOpacity(0.5),
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            // Custom radio dot (cleaner than Material's Radio)
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: selected ? scheme.primary : scheme.outline,
                    width: 1.6),
              ),
              alignment: Alignment.center,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: selected ? 11 : 0,
                height: selected ? 11 : 0,
                decoration: BoxDecoration(
                    color: scheme.primary, shape: BoxShape.circle),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(subtitle!,
                        style: TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            color: scheme.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section header matching the soft uppercase label style of modern apps.
class SectionHeader extends StatelessWidget {
  final String label;
  final EdgeInsetsGeometry padding;
  const SectionHeader(this.label,
      {super.key,
      this.padding = const EdgeInsets.fromLTRB(4, 6, 4, 10)});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(label.toUpperCase(),
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }
}
