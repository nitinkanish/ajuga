import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

enum BackdropTone { welcome, night, card }

class Grain {
  static final image = ValueNotifier<ui.Image?>(null);

  static Future<void> warm() async {
    if (image.value != null) return;
    const size = 160;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final random = math.Random(42);
    final paint = Paint();
    for (var i = 0; i < 2600; i++) {
      final shade = random.nextInt(255);
      final alpha = 30 + random.nextInt(150);
      paint.color = Color.fromARGB(alpha, shade, shade, shade);
      canvas.drawRect(
        Rect.fromLTWH(
          random.nextDouble() * size,
          random.nextDouble() * size,
          1.15,
          1.15,
        ),
        paint,
      );
    }
    final picture = recorder.endRecording();
    image.value = await picture.toImage(size, size);
  }
}

class FintechBackdrop extends StatelessWidget {
  const FintechBackdrop({
    super.key,
    required this.tone,
    this.child,
    this.expand = false,
  });

  final BackdropTone tone;
  final Widget? child;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: expand ? StackFit.expand : StackFit.passthrough,
      clipBehavior: Clip.hardEdge,
      children: [
        const Positioned.fill(child: SizedBox.expand()),
        Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: _linear))),
        Positioned.fill(child: CustomPaint(painter: _GlowPainter(tone))),
        Positioned.fill(child: CustomPaint(painter: _PolygonPainter(tone))),
        const Positioned.fill(child: GrainOverlay()),
        ?child,
      ],
    );
  }

  LinearGradient get _linear {
    switch (tone) {
      case BackdropTone.welcome:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFD9F7FF),
            Color(0xFFB7ECFF),
            Color(0xFF6CB6FF),
            Color(0xFF2A63F0),
            Color(0xFF12306A),
            Color(0xFF070E24),
          ],
          stops: [0.0, 0.16, 0.36, 0.56, 0.78, 1],
        );
      case BackdropTone.night:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF070B14),
            Color(0xFF0A1636),
            Color(0xFF12285C),
            Color(0xFF1A3A86),
          ],
          stops: [0.0, 0.34, 0.72, 1],
        );
      case BackdropTone.card:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF8ED0FF),
            Color(0xFF4C86FF),
            Color(0xFF1E4EC8),
            Color(0xFF0E2260),
          ],
          stops: [0.0, 0.28, 0.62, 1],
        );
    }
  }
}

class GrainOverlay extends StatelessWidget {
  const GrainOverlay({super.key, this.opacity = 0.2});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ValueListenableBuilder<ui.Image?>(
        valueListenable: Grain.image,
        builder: (context, image, child) {
          if (image == null) return const SizedBox.expand();
          return CustomPaint(
            painter: _GrainPainter(image, opacity),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  _GrainPainter(this.image, this.opacity);

  final ui.Image image;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final shader = ui.ImageShader(
      image,
      TileMode.repeated,
      TileMode.repeated,
      Matrix4.identity().storage,
    );
    final rect = Offset.zero & size;
    canvas.saveLayer(
      rect,
      Paint()
        ..color = Colors.white.withValues(alpha: opacity)
        ..blendMode = BlendMode.softLight,
    );
    canvas.drawRect(rect, Paint()..shader = shader);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GrainPainter oldDelegate) {
    return oldDelegate.image != image || oldDelegate.opacity != opacity;
  }
}

class _GlowPainter extends CustomPainter {
  _GlowPainter(this.tone);

  final BackdropTone tone;

  @override
  void paint(Canvas canvas, Size size) {
    void glow(Offset center, double radius, Color color) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = ui.Gradient.radial(
            center,
            radius,
            [color, color.withValues(alpha: 0)],
          ),
      );
    }

    switch (tone) {
      case BackdropTone.welcome:
        glow(
          Offset(size.width * 0.48, size.height * 0.2),
          size.width * 0.85,
          const Color(0xB3F4FCFF),
        );
        glow(
          Offset(size.width * 0.08, size.height * 0.48),
          size.width * 0.6,
          const Color(0x55357DFF),
        );
        glow(
          Offset(size.width * 0.9, size.height * 0.72),
          size.width * 0.55,
          const Color(0x44102866),
        );
      case BackdropTone.night:
        glow(
          Offset(size.width * 0.5, size.height * 0.72),
          size.width * 0.85,
          const Color(0x66356DFF),
        );
        glow(
          Offset(size.width * 0.15, size.height * 0.2),
          size.width * 0.45,
          const Color(0x332E6BFF),
        );
      case BackdropTone.card:
        glow(
          Offset(size.width * 0.5, size.height * 0.16),
          size.width * 0.7,
          const Color(0x88E5F7FF),
        );
        glow(
          Offset(size.width * 0.85, size.height * 0.28),
          size.width * 0.5,
          const Color(0x44285CFF),
        );
    }
  }

  @override
  bool shouldRepaint(covariant _GlowPainter oldDelegate) => oldDelegate.tone != tone;
}

class _PolygonPainter extends CustomPainter {
  _PolygonPainter(this.tone);

  final BackdropTone tone;

  @override
  void paint(Canvas canvas, Size size) {
    final lift = tone == BackdropTone.night ? 0.28 : 1.0;
    void poly(List<Offset> points, Color color) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = color);
    }

    final w = size.width;
    final h = size.height;
    poly(
      [
        Offset(-w * 0.12, h * 0.02),
        Offset(w * 0.78, -h * 0.04),
        Offset(w * 0.34, h * 0.46),
        Offset(-w * 0.08, h * 0.28),
      ],
      Colors.white.withValues(alpha: 0.16 * lift),
    );
    poly(
      [
        Offset(w * 0.28, -h * 0.02),
        Offset(w * 1.12, h * 0.16),
        Offset(w * 0.86, h * 0.4),
        Offset(w * 0.12, h * 0.14),
      ],
      const Color(0xFFD7F4FF).withValues(alpha: 0.2 * lift),
    );
    poly(
      [
        Offset(w * 0.42, h * 0.22),
        Offset(w * 1.05, h * 0.08),
        Offset(w * 1.08, h * 0.62),
        Offset(w * 0.18, h * 0.5),
      ],
      const Color(0xFF071433).withValues(alpha: 0.14 * lift),
    );
  }

  @override
  bool shouldRepaint(covariant _PolygonPainter oldDelegate) {
    return oldDelegate.tone != tone;
  }
}
