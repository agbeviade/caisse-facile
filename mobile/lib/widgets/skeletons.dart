import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Generic shimmer placeholder line.
class SkeletonLine extends StatelessWidget {
  final double height;
  final double width;
  final double radius;
  const SkeletonLine(
      {super.key,
      this.height = 14,
      this.width = double.infinity,
      this.radius = 6});
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: dark ? Colors.white : Colors.black,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Wraps a widget tree with a Shimmer effect tuned for the active theme.
class ShimmerWrap extends StatelessWidget {
  final Widget child;
  const ShimmerWrap({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: dark
          ? Colors.white.withOpacity(0.06)
          : Colors.black.withOpacity(0.06),
      highlightColor: dark
          ? Colors.white.withOpacity(0.12)
          : Colors.black.withOpacity(0.03),
      child: child,
    );
  }
}

/// Skeleton list row: square thumbnail + 2 lines + trailing.
class SkeletonProductList extends StatelessWidget {
  final int itemCount;
  const SkeletonProductList({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrap(
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: const [
              SkeletonLine(height: 52, width: 52, radius: 10),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonLine(height: 14, width: 180),
                    SizedBox(height: 8),
                    SkeletonLine(height: 12, width: 120),
                  ],
                ),
              ),
              SizedBox(width: 12),
              SkeletonLine(height: 14, width: 60),
            ],
          ),
        ),
      ),
    );
  }
}

/// Big empty state with icon + title + optional action button.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 48, color: scheme.primary),
            ),
            const SizedBox(height: 20),
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant)),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.add),
                  label: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
