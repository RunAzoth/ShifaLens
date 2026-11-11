import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

/// Medicine identity badge: renders a unique color + geometric shape + bold letter for
/// each [MedicineLine.identityIndex] (0..9).
/// Never relies on color alone — always combines distinct geometry + high-contrast letter.
/// Used identically on timeline, review cards, strip matching, and print stickers.
class PillBadge extends StatelessWidget {
  final int identityIndex;
  final double size;
  final bool showBorder;

  const PillBadge(
    this.identityIndex, {
    super.key,
    this.size = 52.0,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final identity = MedicineIdentity.of(identityIndex);

    return Semantics(
      label:
          'Medicine symbol ${identity.letter}, ${identity.labelEn}, ${identity.labelUr}',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _PillShapePainter(
            identity: identity,
            showBorder: showBorder,
          ),
          child: Center(
            child: Text(
              identity.letter,
              style: TextStyle(
                fontFamily: AppTokens.fontEnglish,
                fontSize: size * 0.42,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PillShapePainter extends CustomPainter {
  final MedicineIdentity identity;
  final bool showBorder;

  const _PillShapePainter({
    required this.identity,
    required this.showBorder,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (math.min(size.width, size.height) / 2) - 2;

    // Outer soft halo
    final haloPaint = Paint()
      ..color = identity.tintColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius + 2, haloPaint);

    final fillPaint = Paint()
      ..color = identity.primaryColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..isAntiAlias = true;

    final path = _buildShapePath(identity.shape, center, radius * 0.86);
    canvas.drawPath(path, fillPaint);
    if (showBorder) {
      canvas.drawPath(path, borderPaint);
    }
  }

  Path _buildShapePath(PillShapeType shape, Offset center, double r) {
    final path = Path();
    switch (shape) {
      case PillShapeType.circle:
        path.addOval(Rect.fromCircle(center: center, radius: r));
        return path;
      case PillShapeType.capsule:
        final rect = Rect.fromCenter(
          center: center,
          width: r * 1.95,
          height: r * 1.32,
        );
        path.addRRect(RRect.fromRectAndRadius(rect, Radius.circular(r)));
        return path;
      case PillShapeType.square:
        final rect = Rect.fromCenter(
          center: center,
          width: r * 1.65,
          height: r * 1.65,
        );
        path.addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)));
        return path;
      case PillShapeType.diamond:
        return _polygonPath(center, r * 1.05, 4, rotation: 0);
      case PillShapeType.triangle:
        return _polygonPath(center, r * 1.08, 3, rotation: -math.pi / 2);
      case PillShapeType.pentagon:
        return _polygonPath(center, r * 1.02, 5, rotation: -math.pi / 2);
      case PillShapeType.hexagon:
        return _polygonPath(center, r * 1.02, 6, rotation: -math.pi / 6);
      case PillShapeType.octagon:
        return _polygonPath(center, r * 1.02, 8, rotation: math.pi / 8);
      case PillShapeType.shield:
        path.moveTo(center.dx, center.dy - r);
        path.lineTo(center.dx + r * 0.88, center.dy - r * 0.55);
        path.lineTo(center.dx + r * 0.78, center.dy + r * 0.25);
        path.quadraticBezierTo(
          center.dx + r * 0.45,
          center.dy + r * 0.85,
          center.dx,
          center.dy + r * 1.04,
        );
        path.quadraticBezierTo(
          center.dx - r * 0.45,
          center.dy + r * 0.85,
          center.dx - r * 0.78,
          center.dy + r * 0.25,
        );
        path.lineTo(center.dx - r * 0.88, center.dy - r * 0.55);
        path.close();
        return path;
      case PillShapeType.star:
        const points = 5;
        final innerR = r * 0.54;
        for (int i = 0; i < points * 2; i++) {
          final rad = (i.isEven ? r * 1.05 : innerR);
          final angle = -math.pi / 2 + (i * math.pi / points);
          final pt = Offset(
            center.dx + rad * math.cos(angle),
            center.dy + rad * math.sin(angle),
          );
          if (i == 0) {
            path.moveTo(pt.dx, pt.dy);
          } else {
            path.lineTo(pt.dx, pt.dy);
          }
        }
        path.close();
        return path;
    }
  }

  Path _polygonPath(
    Offset center,
    double radius,
    int sides, {
    double rotation = 0,
  }) {
    final path = Path();
    for (int i = 0; i < sides; i++) {
      final angle = rotation + (2 * math.pi * i / sides);
      final pt = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _PillShapePainter oldDelegate) {
    return oldDelegate.identity.index != identity.index ||
        oldDelegate.showBorder != showBorder;
  }
}
