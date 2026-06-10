import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Marca de la app: placa redondeada (squircle) con un pin de ubicación.
/// Silueta propia, distinta del rayo-en-círculo de proyectos hermanos.
class BrandMark extends StatelessWidget {
  final double size;
  final bool onDark;

  const BrandMark({
    super.key,
    this.size = 56,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = onDark ? Colors.white : AppColors.brand;
    final bg = onDark
        ? Colors.white.withValues(alpha: 0.10)
        : AppColors.brandSoft;
    final ringColor = onDark
        ? Colors.white.withValues(alpha: 0.20)
        : AppColors.brand.withValues(alpha: 0.18);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BrandMarkPainter(
          background: bg,
          foreground: fg,
          ring: ringColor,
        ),
      ),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  final Color background;
  final Color foreground;
  final Color ring;

  _BrandMarkPainter({
    required this.background,
    required this.foreground,
    required this.ring,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.shortestSide * 0.30),
    );

    // Placa redondeada de fondo
    canvas.drawRRect(rrect, Paint()..color = background);

    // Anillo interior sutil
    final ringStroke = size.shortestSide * 0.03;
    final ringRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(ringStroke, ringStroke, w - ringStroke * 2, h - ringStroke * 2),
      Radius.circular(size.shortestSide * 0.26),
    );
    canvas.drawRRect(
      ringRect,
      Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringStroke,
    );

    // Pin de ubicación (cabeza + base triangular)
    final fgPaint = Paint()
      ..color = foreground
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final headCenter = Offset(w * 0.5, h * 0.42);
    final headRadius = w * 0.17;

    final stem = Path()
      ..moveTo(w * 0.5 - headRadius * 0.92, h * 0.47)
      ..lineTo(w * 0.5 + headRadius * 0.92, h * 0.47)
      ..lineTo(w * 0.5, h * 0.80)
      ..close();
    canvas.drawPath(stem, fgPaint);
    canvas.drawCircle(headCenter, headRadius, fgPaint);

    // Hueco del pin (en color de fondo)
    canvas.drawCircle(headCenter, headRadius * 0.42, Paint()..color = background);
  }

  @override
  bool shouldRepaint(covariant _BrandMarkPainter oldDelegate) =>
      background != oldDelegate.background ||
      foreground != oldDelegate.foreground ||
      ring != oldDelegate.ring;
}
