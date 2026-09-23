import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A very light, slowly rotating gold glow traced around the screen edges.
/// Purely decorative — wrapped in IgnorePointer so it never blocks taps.
class GoldShimmerBorder extends StatefulWidget {
  const GoldShimmerBorder({super.key});

  @override
  State<GoldShimmerBorder> createState() => _GoldShimmerBorderState();
}

class _GoldShimmerBorderState extends State<GoldShimmerBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _ShimmerBorderPainter(_controller.value),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _ShimmerBorderPainter extends CustomPainter {
  final double progress;
  _ShimmerBorderPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final angle = progress * 2 * math.pi;

    // A soft gold band that slowly sweeps around the perimeter. Kept low
    // opacity (max ~0x40 alpha) so it reads as ambient light, not a UI
    // element competing for attention.
    final gradient = SweepGradient(
      transform: GradientRotation(angle),
      colors: const [
        Colors.transparent,
        Color(0x22FFD700),
        Color(0x40FFD700),
        Color(0x22FFD700),
        Colors.transparent,
        Colors.transparent,
      ],
      stops: const [0.0, 0.15, 0.25, 0.35, 0.55, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    canvas.drawRect(rect.deflate(1.25), paint);
  }

  @override
  bool shouldRepaint(covariant _ShimmerBorderPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
