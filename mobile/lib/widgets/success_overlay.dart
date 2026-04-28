import 'package:flutter/material.dart';

/// Shows a full-screen success animation (animated checkmark) for ~1.5 seconds
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
                  child: _FallbackCheck(
                      color: Theme.of(ctx).colorScheme.primary),
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

/// Custom checkmark animation: circle expands, then check stroke draws in.
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
        vsync: this, duration: const Duration(milliseconds: 750))
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
        // Two-phase animation: 0..0.45 = circle scale, 0.45..1 = check stroke
        final v = _ctrl.value;
        final circleT =
            Curves.easeOutBack.transform((v / 0.45).clamp(0, 1));
        final checkT = ((v - 0.45) / 0.55).clamp(0.0, 1.0);
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: circleT,
              child: Container(
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            CustomPaint(
              size: const Size(64, 64),
              painter: _CheckPainter(
                  color: widget.color,
                  progress: Curves.easeOutCubic.transform(checkT)),
            ),
          ],
        );
      },
    );
  }
}

class _CheckPainter extends CustomPainter {
  final Color color;
  final double progress;
  _CheckPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    // Standard 3-point checkmark inside the size box
    final p1 = Offset(size.width * 0.22, size.height * 0.55);
    final p2 = Offset(size.width * 0.42, size.height * 0.74);
    final p3 = Offset(size.width * 0.78, size.height * 0.32);

    // Total length: leg1 + leg2
    final leg1Len = (p2 - p1).distance;
    final leg2Len = (p3 - p2).distance;
    final total = leg1Len + leg2Len;
    final drawn = total * progress;

    final path = Path()..moveTo(p1.dx, p1.dy);
    if (drawn <= leg1Len) {
      final t = drawn / leg1Len;
      final mid = Offset.lerp(p1, p2, t)!;
      path.lineTo(mid.dx, mid.dy);
    } else {
      path.lineTo(p2.dx, p2.dy);
      final t = (drawn - leg1Len) / leg2Len;
      final mid = Offset.lerp(p2, p3, t)!;
      path.lineTo(mid.dx, mid.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckPainter old) =>
      old.progress != progress || old.color != color;
}
