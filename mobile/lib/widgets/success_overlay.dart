import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Shows a full-screen success animation (Lottie checkmark) for ~1.5 seconds
/// then auto-dismisses. Useful after a successful checkout / save.
///
/// Usage:
/// ```dart
/// await showSuccessOverlay(context, message: 'Vente encaissée');
/// ```
Future<void> showSuccessOverlay(BuildContext context,
    {String? message, Duration duration = const Duration(milliseconds: 1500)}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.45),
    transitionDuration: const Duration(milliseconds: 220),
    transitionBuilder: (ctx, anim, _, child) => FadeTransition(
      opacity: anim,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.9, end: 1).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ),
    pageBuilder: (ctx, _, __) {
      // Auto-dismiss after the duration
      Future.delayed(duration, () {
        if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
      });
      return Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 220,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
            decoration: BoxDecoration(
              color: Theme.of(ctx).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black26,
                    blurRadius: 30,
                    offset: Offset(0, 10)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 110,
                  height: 110,
                  child: Lottie.network(
                    // Public CDN — Lottiefiles "success check" animation
                    'https://lottie.host/4d1e2f10-5478-4c5b-9f9a-0fa7b9c6f9b3/iNk9bDdJ4S.json',
                    repeat: false,
                    errorBuilder: (_, __, ___) => _FallbackCheck(
                        color: Theme.of(ctx).colorScheme.primary),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message ?? 'Succès',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Pure-Flutter fallback if the Lottie network call fails (offline).
class _FallbackCheck extends StatefulWidget {
  final Color color;
  const _FallbackCheck({required this.color});
  @override
  State<_FallbackCheck> createState() => _FallbackCheckState();
}

class _FallbackCheckState extends State<_FallbackCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = Curves.easeOutCubic.transform(_ctrl.value);
        return Container(
          decoration: BoxDecoration(
            color: widget.color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Transform.scale(
            scale: t,
            child: Icon(Icons.check_circle,
                color: widget.color, size: 80),
          ),
        );
      },
    );
  }
}
