import 'dart:math';

import 'package:flutter/material.dart';

import 'creature_kind.dart';
import 'entities.dart';
import 'game_config.dart';
import 'game_world.dart';

/// Draws the whole scrolling reef: depth-shaded water, the sunlit surface,
/// the sea floor with coral, every creature, the player and all the juice.
/// World-space layers are drawn under a camera transform; the water, banner
/// and vignette are screen-fixed.
class GamePainter extends CustomPainter {
  GamePainter(this.world) : super(repaint: null);

  final GameWorld world;

  static const _sand = Color(0xFFE7D7A0);
  static const _sandDark = Color(0xFFC9B878);
  static const _hill = Color(0x66072F4C);
  static const _ink = Color(0xFF16213E);
  static const _white = Color(0xFFFFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    if (world.width <= 0) return;

    _paintWater(canvas, size);
    _paintLightRays(canvas, size);

    // --- World layers, under the camera ------------------------------------
    canvas.save();
    canvas.translate(
        -world.cameraX + world.shakeX, -world.cameraY + world.shakeY);

    _paintSurface(canvas);
    _paintHills(canvas);
    _paintFloor(canvas, size);
    _paintDecor(canvas, size);
    _paintBubbles(canvas, size);

    final sorted = [...world.creatures]
      ..sort((a, b) => b.radius.compareTo(a.radius));
    for (final c in sorted) {
      _paintCreature(canvas, c);
    }
    _paintPlayer(canvas);
    _paintParticles(canvas);
    _paintFloaters(canvas);

    canvas.restore();

    // --- Screen-fixed overlays --------------------------------------------
    _paintBanner(canvas, size);
    _paintVignette(canvas, size);
  }

  // ===========================================================================
  //  Water & atmosphere
  // ===========================================================================
  static Color _waterColor(double t) {
    t = t.clamp(0.0, 1.0);
    const surface = Color(0xFF5AC6E8);
    const mid = Color(0xFF15709E);
    const deep = Color(0xFF06243B);
    if (t < 0.5) return Color.lerp(surface, mid, t / 0.5)!;
    return Color.lerp(mid, deep, (t - 0.5) / 0.5)!;
  }

  void _paintWater(Canvas canvas, Size size) {
    final wh = world.worldHeight;
    final topT = world.cameraY / wh;
    final botT = (world.cameraY + size.height) / wh;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _waterColor(topT),
            _waterColor((topT + botT) / 2),
            _waterColor(botT),
          ],
        ).createShader(rect),
    );
  }

  void _paintLightRays(Canvas canvas, Size size) {
    final fade = (1 - world.depthFraction * 0.85).clamp(0.0, 1.0);
    if (fade <= 0.01) return;
    final paint = Paint()
      ..blendMode = BlendMode.plus
      ..color = Colors.white.withValues(alpha: 0.06 * fade);
    final sway = sin(world.time * 0.6) * size.width * 0.03;
    for (var i = 0; i < 4; i++) {
      final x = size.width * (0.12 + i * 0.26) + sway;
      final w = size.width * 0.12;
      canvas.drawPath(
        Path()
          ..moveTo(x, 0)
          ..lineTo(x + w, 0)
          ..lineTo(x + w * 2.4, size.height)
          ..lineTo(x + w * 1.4, size.height)
          ..close(),
        paint,
      );
    }
  }

  /// The bright sunlit band at the very top of the world.
  void _paintSurface(Canvas canvas) {
    final ww = world.worldWidth;
    final band = GameConfig.surfaceHeight * world.height;
    final path = Path()..moveTo(0, 0);
    path.lineTo(ww, 0);
    path.lineTo(ww, band * 0.7);
    const seg = 28;
    for (var i = seg; i >= 0; i--) {
      final x = ww * (i / seg);
      final y = band * (0.7 + 0.3 * sin(i * 0.7 + world.time * 1.1));
      path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = Colors.white.withValues(alpha: 0.12));
    // Bright shimmer line along the surface.
    final shimmer = Path();
    for (var i = 0; i <= seg; i++) {
      final x = ww * (i / seg);
      final y = band * (0.7 + 0.3 * sin(i * 0.7 + world.time * 1.1));
      i == 0 ? shimmer.moveTo(x, y) : shimmer.lineTo(x, y);
    }
    canvas.drawPath(
      shimmer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = world.unit * 0.012
        ..color = Colors.white.withValues(alpha: 0.3),
    );
  }

  /// Distant hill silhouettes that sit behind the sea floor.
  void _paintHills(Canvas canvas) {
    final ww = world.worldWidth;
    final fy = world.floorY;
    final humpW = world.width * 0.5;
    final humpH = world.height * 0.13;
    final path = Path()..moveTo(-humpW, world.worldHeight);
    path.lineTo(-humpW, fy + world.height * 0.015);
    var x = -humpW;
    while (x < ww + humpW) {
      path.quadraticBezierTo(x + humpW / 2,
          fy + world.height * 0.015 - humpH * 2, x + humpW,
          fy + world.height * 0.015);
      x += humpW;
    }
    path
      ..lineTo(x, world.worldHeight)
      ..close();
    canvas.drawPath(path, Paint()..color = _hill);
  }

  void _paintFloor(Canvas canvas, Size size) {
    final fy = world.floorY;
    final ww = world.worldWidth;
    final path = Path()..moveTo(0, fy);
    const seg = 48;
    for (var i = 0; i <= seg; i++) {
      final x = ww * (i / seg);
      final y = fy + sin(i * 0.7 + 1.2) * size.height * 0.014;
      path.lineTo(x, y);
    }
    path
      ..lineTo(ww, world.worldHeight)
      ..lineTo(0, world.worldHeight)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_sand, _sandDark],
        ).createShader(Rect.fromLTWH(0, fy, ww, world.worldHeight - fy)),
    );
    // Pebbles, only across the visible stretch.
    final pebble = Paint()..color = _sandDark;
    final spacing = size.width * 0.14;
    final startI = (world.cameraX / spacing).floor() - 1;
    final endI = ((world.cameraX + size.width) / spacing).ceil() + 1;
    for (var i = startI; i <= endI; i++) {
      final x = i * spacing;
      final y = fy + size.height * 0.022 + (i.isEven ? 4 : 9);
      canvas.drawCircle(Offset(x, y), size.width * 0.015, pebble);
    }
  }

  void _paintDecor(Canvas canvas, Size size) {
    final fy = world.floorY;
    final left = world.cameraX - size.width * 0.35;
    final right = world.cameraX + size.width * 1.35;
    for (final d in world.decorations) {
      if (d.x < left || d.x > right) continue;
      switch (d.kind) {
        case DecorKind.coral:
          _drawCoral(canvas, d.x, fy, d.size, d.color);
          break;
        case DecorKind.rock:
          _drawRock(canvas, d.x, fy, d.size, d.color);
          break;
        case DecorKind.kelp:
          _drawKelp(canvas, d.x, fy, d.size, d.color, d.phase);
          break;
      }
    }
  }

  void _drawCoral(Canvas canvas, double x, double fy, double s, Color color) {
    final light = _shade(color, 0.28);
    canvas.drawCircle(
        Offset(x - s * 0.34, fy - s * 0.2), s * 0.27, Paint()..color = _shade(color, 0.1));
    canvas.drawCircle(Offset(x + s * 0.33, fy - s * 0.24), s * 0.29,
        Paint()..color = _shade(color, -0.1));
    canvas.drawCircle(
        Offset(x, fy - s * 0.36), s * 0.36, Paint()..color = color);
    canvas.drawCircle(
        Offset(x, fy - s * 0.7), s * 0.24, Paint()..color = light);
    canvas.drawCircle(
        Offset(x - s * 0.42, fy - s * 0.52), s * 0.13, Paint()..color = light);
    canvas.drawCircle(
        Offset(x + s * 0.44, fy - s * 0.58), s * 0.14, Paint()..color = light);
  }

  void _drawRock(Canvas canvas, double x, double fy, double s, Color color) {
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(x, fy - s * 0.1), width: s * 1.5, height: s * 0.72),
      Paint()..color = color,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(x - s * 0.3, fy - s * 0.34),
          width: s * 0.82,
          height: s * 0.62),
      Paint()..color = _shade(color, 0.2),
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(x + s * 0.36, fy - s * 0.2),
          width: s * 0.7,
          height: s * 0.5),
      Paint()..color = _shade(color, -0.22),
    );
  }

  void _drawKelp(
      Canvas canvas, double x, double fy, double s, Color color, double phase) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = s * 0.16;
    for (var strand = 0; strand < 3; strand++) {
      final sx = x + (strand - 1) * s * 0.3;
      final h = s * (1.5 + (strand % 2) * 0.5);
      final path = Path()..moveTo(sx, fy);
      const seg = 7;
      for (var j = 1; j <= seg; j++) {
        final t = j / seg;
        final sway = sin(world.time * 1.6 + phase + strand * 1.2 + t * 3) *
            s *
            0.24 *
            t;
        path.lineTo(sx + sway, fy - h * t);
      }
      canvas.drawPath(path, paint);
    }
  }

  void _paintBubbles(Canvas canvas, Size size) {
    final left = world.cameraX - 40;
    final right = world.cameraX + size.width + 40;
    final top = world.cameraY - 40;
    final bottom = world.cameraY + size.height + 40;
    for (final Bubble b in world.bubbles) {
      if (b.x < left || b.x > right || b.y < top || b.y > bottom) continue;
      canvas.drawCircle(Offset(b.x, b.y), b.radius,
          Paint()..color = Colors.white.withValues(alpha: 0.14));
      canvas.drawCircle(
        Offset(b.x, b.y),
        b.radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = b.radius * 0.18
          ..color = Colors.white.withValues(alpha: 0.32),
      );
      canvas.drawCircle(
        Offset(b.x - b.radius * 0.32, b.y - b.radius * 0.32),
        b.radius * 0.26,
        Paint()..color = Colors.white.withValues(alpha: 0.6),
      );
    }
  }

  void _paintVignette(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.24)],
          stops: const [0.62, 1.0],
        ).createShader(rect),
    );
  }

  // ===========================================================================
  //  Creatures
  // ===========================================================================
  void _paintCreature(Canvas canvas, Creature c) {
    canvas.save();
    canvas.translate(c.x, c.y);

    if (world.phase == GamePhase.playing) {
      _paintGlow(canvas, c.radius, world.isEdible(c));
    }

    canvas.save();
    if (c.spec.flip && c.facingLeft) canvas.scale(-1, 1);
    switch (c.spec.kind) {
      case CreatureKind.shrimp:
        _drawShrimp(canvas, c.radius, c.color, c.phase);
        break;
      case CreatureKind.fish:
        _drawFish(canvas, c.radius, c.color, c.phase);
        break;
      case CreatureKind.crab:
        _drawCrab(canvas, c.radius, c.color, c.phase);
        break;
      case CreatureKind.jellyfish:
        _drawJelly(canvas, c.radius, c.color, c.phase);
        break;
      case CreatureKind.turtle:
        _drawTurtle(canvas, c.radius, c.color, c.phase);
        break;
      case CreatureKind.octopus:
        _drawOctopus(canvas, c.radius, c.color, c.phase);
        break;
      case CreatureKind.whale:
        _drawWhale(canvas, c.radius, c.color, c.phase);
        break;
    }
    canvas.restore();
    canvas.restore();
  }

  void _paintGlow(Canvas canvas, double r, bool edible) {
    final hr = r * 1.62;
    final col = edible ? const Color(0xFF4AFF8C) : const Color(0xFFFF4A56);
    final rect = Rect.fromCircle(center: Offset.zero, radius: hr);
    canvas.drawCircle(
      Offset.zero,
      hr,
      Paint()
        ..shader = RadialGradient(
          colors: [
            col.withValues(alpha: 0),
            col.withValues(alpha: 0),
            col.withValues(alpha: 0.5),
            col.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.66, 0.83, 1.0],
        ).createShader(rect),
    );
  }

  void _drawFish(Canvas canvas, double r, Color color, double phase) {
    final dark = Paint()..color = _shade(color, -0.4);
    final light = _shade(color, 0.35);
    final tw = sin(phase) * 0.4;
    canvas.drawPath(
      Path()
        ..moveTo(-r * 0.55, 0)
        ..lineTo(-r * 1.25, -r * 0.6 + tw * r * 0.35)
        ..quadraticBezierTo(-r * 0.95, 0, -r * 1.25, r * 0.6 + tw * r * 0.35)
        ..close(),
      dark,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-r * 0.15, -r * 0.55)
        ..quadraticBezierTo(r * 0.15, -r * 1.0, r * 0.5, -r * 0.45)
        ..close(),
      dark,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 1.44),
      Paint()..color = color,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(r * 0.05, r * 0.24), width: r * 1.56, height: r * 0.76),
      Paint()..color = light,
    );
    canvas.drawPath(
      Path()
        ..moveTo(r * 0.1, r * 0.15)
        ..quadraticBezierTo(-r * 0.05, r * 0.8, r * 0.45, r * 0.45)
        ..close(),
      dark,
    );
    _eye(canvas, r * 0.52, -r * 0.18, r * 0.2);
  }

  void _drawShrimp(Canvas canvas, double r, Color color, double phase) {
    final dark = _shade(color, -0.35);
    final wig = sin(phase) * 0.3;
    final stroke = Paint()
      ..color = dark
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    stroke.strokeWidth = r * 0.09;
    canvas.drawPath(
      Path()
        ..moveTo(r * 0.55, -r * 0.1)
        ..quadraticBezierTo(r * 1.3, -r * 0.5, r * 1.4, r * 0.2),
      stroke,
    );
    canvas.drawPath(
      Path()
        ..moveTo(r * 0.55, 0)
        ..quadraticBezierTo(r * 1.2, r * 0.15, r * 1.5, r * 0.65),
      stroke,
    );
    stroke.strokeWidth = r * 0.1;
    for (var i = 0; i < 4; i++) {
      final lx = r * (0.32 - i * 0.27);
      canvas.drawPath(
        Path()
          ..moveTo(lx, r * 0.25)
          ..lineTo(lx - r * 0.07, r * 0.62 + wig * r * 0.14),
        stroke,
      );
    }
    canvas.drawPath(
      Path()
        ..moveTo(-r * 0.45, 0)
        ..lineTo(-r * 0.95, -r * 0.42)
        ..lineTo(-r * 0.8, 0)
        ..lineTo(-r * 0.95, r * 0.42)
        ..close(),
      Paint()..color = dark,
    );
    for (var i = 0; i < 5; i++) {
      final t = i / 4;
      final bx = _lerp(r * 0.55, -r * 0.45, t);
      final by = sin(t * 1.5) * -r * 0.13;
      final br = _lerp(r * 0.5, r * 0.22, t);
      canvas.drawCircle(Offset(bx, by), br,
          Paint()..color = i.isOdd ? _shade(color, 0.18) : color);
    }
    canvas.drawCircle(
        Offset(r * 0.62, -r * 0.2), r * 0.12, Paint()..color = _ink);
  }

  void _drawCrab(Canvas canvas, double r, Color color, double phase) {
    final dark = _shade(color, -0.4);
    final light = _shade(color, 0.32);
    final lw = sin(phase) * 0.22;
    final stroke = Paint()
      ..color = dark
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    stroke.strokeWidth = r * 0.13;
    for (var i = 0; i < 3; i++) {
      final ix = -r * 0.5 + i * r * 0.42;
      canvas.drawPath(
        Path()
          ..moveTo(ix, r * 0.2)
          ..lineTo(ix - r * 0.16, r * 0.62 + lw * r * 0.13)
          ..lineTo(ix - r * 0.34, r * 0.46),
        stroke,
      );
    }
    stroke.strokeWidth = r * 0.15;
    canvas.drawPath(
      Path()
        ..moveTo(r * 0.5, -r * 0.1)
        ..lineTo(r * 0.85, -r * 0.32),
      stroke,
    );
    canvas.drawPath(
      Path()
        ..moveTo(r * 0.55, r * 0.18)
        ..lineTo(r * 0.95, r * 0.28),
      stroke,
    );
    final bodyRect =
        Rect.fromCenter(center: Offset.zero, width: r * 1.9, height: r * 1.24);
    canvas.drawOval(
      bodyRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [light, color],
        ).createShader(bodyRect),
    );
    _crabClaw(canvas, r * 0.92, -r * 0.36, r * 0.34, -lw, color, dark);
    _crabClaw(canvas, r * 1.02, r * 0.3, r * 0.3, lw, color, dark);
    stroke.strokeWidth = r * 0.08;
    canvas.drawPath(
      Path()
        ..moveTo(-r * 0.1, -r * 0.4)
        ..lineTo(-r * 0.15, -r * 0.72),
      stroke,
    );
    canvas.drawPath(
      Path()
        ..moveTo(r * 0.18, -r * 0.42)
        ..lineTo(r * 0.24, -r * 0.74),
      stroke,
    );
    _eye(canvas, -r * 0.15, -r * 0.74, r * 0.13);
    _eye(canvas, r * 0.24, -r * 0.76, r * 0.13);
  }

  void _crabClaw(Canvas canvas, double cx, double cy, double cr, double open,
      Color color, Color dark) {
    final fill = Paint()..color = color;
    canvas.drawPath(
      Path()
        ..moveTo(cx, cy)
        ..arcTo(Rect.fromCircle(center: Offset(cx, cy), radius: cr),
            -1.9 - open, 1.65, false)
        ..close(),
      fill,
    );
    canvas.drawPath(
      Path()
        ..moveTo(cx, cy)
        ..arcTo(Rect.fromCircle(center: Offset(cx, cy), radius: cr),
            0.25 + open, 1.65, false)
        ..close(),
      fill,
    );
    canvas.drawCircle(Offset(cx, cy), cr * 0.34, Paint()..color = dark);
  }

  void _drawJelly(Canvas canvas, double r, Color color, double phase) {
    canvas.saveLayer(
      Rect.fromCircle(center: Offset.zero, radius: r * 2.4),
      Paint()..color = Colors.white.withValues(alpha: 0.86),
    );
    final pulse = sin(phase) * 0.13;
    final bw = r * (1 + pulse);
    final bh = r * (0.88 - pulse);

    final thin = Paint()
      ..color = _shade(color, 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.11
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 7; i++) {
      final tx = -bw * 0.7 + i * (bw * 1.4 / 6);
      final sway = sin(phase * 1.3 + i) * r * 0.28;
      canvas.drawPath(
        Path()
          ..moveTo(tx, bh * 0.32)
          ..quadraticBezierTo(tx + sway, bh * 0.95, tx + sway * 0.5, bh * 1.8),
        thin,
      );
    }
    final thick = Paint()
      ..color = _shade(color, -0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final tx = -bw * 0.32 + i * (bw * 0.64 / 3);
      final sway = sin(phase * 1.1 + i * 1.7) * r * 0.16;
      canvas.drawPath(
        Path()
          ..moveTo(tx, bh * 0.3)
          ..quadraticBezierTo(tx + sway, bh * 0.85, tx + sway, bh * 1.3),
        thick,
      );
    }
    final bell = Path()
      ..arcTo(
          Rect.fromCenter(center: Offset.zero, width: bw * 2, height: bh * 2),
          pi, pi, false);
    const segs = 8;
    for (var i = 0; i <= segs; i++) {
      final fx = _lerp(bw, -bw, i / segs);
      final fy = i.isOdd ? bh * 0.3 : bh * 0.08;
      bell.lineTo(fx, fy);
    }
    bell.close();
    final bellRect =
        Rect.fromCenter(center: Offset.zero, width: bw * 2, height: bh * 2);
    canvas.drawPath(
      bell,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_shade(color, 0.38), color],
        ).createShader(bellRect),
    );
    final dot = Paint()..color = _shade(color, 0.55).withValues(alpha: 0.5);
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
          Offset((-0.45 + i * 0.45) * bw * 0.62, -bh * 0.12), r * 0.1, dot);
    }
    canvas.restore();
  }

  void _drawTurtle(Canvas canvas, double r, Color color, double phase) {
    final dark = _shade(color, -0.42);
    final light = _shade(color, 0.34);
    final fw = sin(phase) * 0.4;
    final flipper = Paint()..color = _shade(color, -0.16);

    _rotatedOval(canvas, r * 0.45, r * 0.18, 0.5 + fw * 0.35,
        Offset(r * 0.38, 0), r * 0.92, r * 0.42, flipper);
    _rotatedOval(canvas, -r * 0.5, r * 0.22, -0.45 - fw * 0.3,
        Offset(-r * 0.3, 0), r * 0.64, r * 0.32, flipper);
    _rotatedOval(canvas, r * 0.55, -r * 0.42, -0.6 + fw * 0.25,
        Offset(r * 0.18, 0), r * 0.6, r * 0.3, flipper);

    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(r * 0.82, 0), width: r * 0.56, height: r * 0.46),
      Paint()..color = _shade(color, 0.12),
    );
    canvas.drawCircle(
        Offset(r * 0.96, -r * 0.05), r * 0.07, Paint()..color = _ink);

    final shellRect = Rect.fromCenter(
        center: Offset(0, -r * 0.03), width: r * 1.84, height: r * 1.56);
    canvas.drawOval(
      shellRect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: [light, color],
        ).createShader(shellRect),
    );
    final scute = Paint()..color = _shade(color, 0.2);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(0, -r * 0.1), width: r * 0.6, height: r * 0.6),
      scute,
    );
    for (var i = 0; i < 6; i++) {
      final a = i / 6 * pi * 2 + 0.5;
      _rotatedOval(canvas, cos(a) * r * 0.55, -r * 0.05 + sin(a) * r * 0.46, a,
          Offset.zero, r * 0.4, r * 0.34, scute);
    }
    canvas.drawOval(
      shellRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.05
        ..color = dark,
    );
  }

  void _drawOctopus(Canvas canvas, double r, Color color, double phase) {
    final light = _shade(color, 0.32);
    final arm = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.27
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final a = (i / 7 - 0.5) * 2.5;
      final baseX = sin(a) * r * 0.5;
      final sway = sin(phase + i * 0.7) * r * 0.3;
      final endX = baseX + sin(a) * r * 0.9 + sway;
      final endY = r * 1.2 + cos(i + phase) * r * 0.1;
      canvas.drawPath(
        Path()
          ..moveTo(baseX, r * 0.3)
          ..quadraticBezierTo(
              baseX + sin(a) * r * 0.75, r * 0.9, endX, endY),
        arm,
      );
      canvas.drawCircle(Offset(endX, endY), r * 0.1, Paint()..color = light);
    }
    final headRect = Rect.fromCenter(
        center: Offset(0, -r * 0.16), width: r * 1.44, height: r * 1.6);
    canvas.drawOval(
      headRect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: [light, color],
        ).createShader(headRect),
    );
    final look = sin(phase * 0.5) * r * 0.05;
    _eye(canvas, -r * 0.3, -r * 0.12, r * 0.23, look);
    _eye(canvas, r * 0.3, -r * 0.12, r * 0.23, look);
  }

  void _drawWhale(Canvas canvas, double r, Color color, double phase) {
    final dark = _shade(color, -0.35);
    final belly = _shade(color, 0.58);
    final tw = sin(phase) * 0.3;

    canvas.save();
    canvas.translate(-r * 0.85, 0);
    canvas.rotate(tw * 0.4);
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(-r * 0.4, -r * 0.15, -r * 0.52, -r * 0.55)
        ..quadraticBezierTo(-r * 0.16, -r * 0.25, 0, -r * 0.05)
        ..quadraticBezierTo(-r * 0.16, r * 0.25, -r * 0.52, r * 0.55)
        ..quadraticBezierTo(-r * 0.4, r * 0.15, 0, 0)
        ..close(),
      Paint()..color = dark,
    );
    canvas.restore();

    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 1.32),
      Paint()..color = color,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(r * 0.06, r * 0.3), width: r * 1.64, height: r * 0.66),
      Paint()..color = belly,
    );
    final groove = Paint()
      ..color = _shade(color, 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.025;
    for (var i = 0; i < 4; i++) {
      canvas.drawLine(Offset(r * 0.55, r * 0.08 + i * r * 0.11),
          Offset(0, r * 0.08 + i * r * 0.11), groove);
    }
    _rotatedOval(canvas, r * 0.12, r * 0.3, 0.5 + tw * 0.2,
        Offset(0, r * 0.22), r * 0.34, r * 0.8, Paint()..color = dark);
    _eye(canvas, r * 0.62, -r * 0.12, r * 0.13);
    canvas.drawPath(
      Path()
        ..moveTo(r * 0.96, r * 0.04)
        ..quadraticBezierTo(r * 0.7, r * 0.26, r * 0.32, r * 0.2),
      Paint()
        ..color = dark
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.045
        ..strokeCap = StrokeCap.round,
    );
  }

  // ===========================================================================
  //  Player
  // ===========================================================================
  void _paintPlayer(Canvas canvas) {
    final p = world.player;
    final blink = world.invuln > 0 &&
        world.phase == GamePhase.playing &&
        (world.time * 12).floor().isEven;

    canvas.save();
    canvas.translate(p.x, p.y);
    canvas.rotate(p.angle);
    if (cos(p.angle) < 0) canvas.scale(1, -1);

    if (blink) {
      canvas.saveLayer(
        Rect.fromCircle(center: Offset.zero, radius: p.radius * 2),
        Paint()..color = Colors.white.withValues(alpha: 0.35),
      );
    }
    _drawPlayerFish(canvas, p.radius, p.phase);
    if (blink) canvas.restore();

    canvas.restore();
  }

  void _drawPlayerFish(Canvas canvas, double r, double phase) {
    const color = Color(0xFFFF7A33);
    const dark = Color(0xFFD8541A);
    final darkP = Paint()..color = dark;
    final tw = sin(phase) * 0.5;

    canvas.drawPath(
      Path()
        ..moveTo(-r * 0.55, 0)
        ..lineTo(-r * 1.3, -r * 0.62 + tw * r * 0.4)
        ..quadraticBezierTo(-r * 0.95, 0, -r * 1.3, r * 0.62 + tw * r * 0.4)
        ..close(),
      darkP,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-r * 0.2, -r * 0.55)
        ..quadraticBezierTo(r * 0.2, -r * 1.08, r * 0.55, -r * 0.4)
        ..close(),
      darkP,
    );
    final bodyRect =
        Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 1.48);
    canvas.drawOval(bodyRect, Paint()..color = color);

    canvas.save();
    canvas.clipPath(Path()..addOval(bodyRect));
    final stripe = Paint()..color = _white;
    for (var i = 0; i < 2; i++) {
      final sx = r * (0.2 - i * 0.62);
      canvas.drawPath(
        Path()
          ..moveTo(sx, -r)
          ..quadraticBezierTo(sx + r * 0.16, 0, sx, r)
          ..lineTo(sx - r * 0.24, r)
          ..quadraticBezierTo(sx - r * 0.08, 0, sx - r * 0.24, -r)
          ..close(),
        stripe,
      );
    }
    canvas.restore();

    canvas.drawPath(
      Path()
        ..moveTo(r * 0.1, r * 0.2)
        ..quadraticBezierTo(-r * 0.1, r * 0.88, r * 0.5, r * 0.48)
        ..close(),
      darkP,
    );
    _eye(canvas, r * 0.54, -r * 0.2, r * 0.22);
  }

  // ===========================================================================
  //  Effects
  // ===========================================================================
  void _paintParticles(Canvas canvas) {
    for (final p in world.particles) {
      canvas.drawCircle(
        Offset(p.x, p.y),
        p.size * (0.4 + p.alpha * 0.6),
        Paint()..color = p.color.withValues(alpha: p.alpha),
      );
    }
  }

  void _paintFloaters(Canvas canvas) {
    for (final f in world.floaters) {
      final size = (f.big ? 0.058 : 0.046) * world.unit;
      _text(canvas, f.text, Offset(f.x, f.y), size,
          Colors.black.withValues(alpha: 0.45 * f.alpha),
          weight: FontWeight.w900);
      _text(canvas, f.text, Offset(f.x - 1.5, f.y - 1.5), size,
          f.color.withValues(alpha: f.alpha),
          weight: FontWeight.w900);
    }
  }

  void _paintBanner(Canvas canvas, Size size) {
    if (world.bannerTime <= 0) return;
    final age = GameConfig.bannerSeconds - world.bannerTime;
    double alpha;
    if (age < 0.15) {
      alpha = age / 0.15;
    } else if (world.bannerTime < 0.4) {
      alpha = world.bannerTime / 0.4;
    } else {
      alpha = 1.0;
    }
    double scale;
    if (age < 0.25) {
      scale = 0.6 + (age / 0.25) * 0.5;
    } else if (age < 0.4) {
      scale = 1.1 - ((age - 0.25) / 0.15) * 0.1;
    } else {
      scale = 1.0;
    }
    canvas.save();
    canvas.translate(size.width / 2, size.height * 0.3);
    canvas.scale(scale);
    _text(canvas, world.bannerText, Offset.zero, world.unit * 0.11,
        Colors.black.withValues(alpha: 0.4 * alpha),
        weight: FontWeight.w900);
    _text(canvas, world.bannerText, const Offset(-2, -2), world.unit * 0.11,
        world.bannerColor.withValues(alpha: alpha),
        weight: FontWeight.w900);
    canvas.restore();
  }

  // ===========================================================================
  //  Helpers
  // ===========================================================================
  void _eye(Canvas canvas, double x, double y, double r, [double look = 0]) {
    canvas.drawCircle(Offset(x, y), r, Paint()..color = _white);
    canvas.drawCircle(Offset(x + r * 0.3 + look, y + r * 0.1), r * 0.46,
        Paint()..color = _ink);
    canvas.drawCircle(Offset(x + r * 0.45 + look, y - r * 0.2), r * 0.18,
        Paint()..color = _white);
  }

  void _rotatedOval(Canvas canvas, double cx, double cy, double rot,
      Offset localCenter, double w, double h, Paint paint) {
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(rot);
    canvas.drawOval(
      Rect.fromCenter(center: localCenter, width: w, height: h),
      paint,
    );
    canvas.restore();
  }

  void _text(Canvas canvas, String text, Offset center, double size,
      Color color,
      {FontWeight weight = FontWeight.w800}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: size, fontWeight: weight, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  static Color _shade(Color c, double amt) {
    final t = amt.abs();
    final target = amt < 0 ? 0.0 : 1.0;
    double mix(double v) => v + (target - v) * t;
    return Color.from(
        alpha: c.a, red: mix(c.r), green: mix(c.g), blue: mix(c.b));
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => true;
}
