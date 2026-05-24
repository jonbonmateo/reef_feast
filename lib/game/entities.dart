import 'dart:ui' show Color;

import 'creature_kind.dart';

/// The player's fish. It swims freely in two dimensions through the world
/// toward the finger; the camera follows it.
class PlayerFish {
  PlayerFish({required this.x, required this.y, required this.radius})
      : targetRadius = radius;

  /// Position in world coordinates.
  double x;
  double y;
  double vx = 0;
  double vy = 0;

  /// Current collision radius in pixels — eased toward [targetRadius] so the
  /// fish visibly grows when it levels up.
  double radius;
  double targetRadius;

  /// Heading in radians, eased toward the direction of travel.
  double angle = 0;

  /// Tail-wag / swim animation phase.
  double phase = 0;

  void reset(double startX, double startY, double startRadius) {
    x = startX;
    y = startY;
    vx = 0;
    vy = 0;
    radius = startRadius;
    targetRadius = startRadius;
    angle = 0;
    phase = 0;
  }
}

/// A sea creature swimming the reef. Edible if smaller than the player,
/// deadly if bigger.
class Creature {
  Creature({
    required this.spec,
    required this.x,
    required this.y,
    required this.radius,
    required this.vx,
    required this.color,
    required this.phase,
    required this.wanderPhase,
  });

  final CreatureSpec spec;

  /// Position in world coordinates.
  double x;
  double y;

  /// Collision radius in pixels (base size times the spawn-time roll).
  final double radius;

  /// Horizontal velocity in px/s; the sign also decides facing.
  double vx;
  double vy = 0;

  final Color color;

  /// Idle-animation phase and a separate phase for the wander wave.
  double phase;
  final double wanderPhase;

  bool get facingLeft => vx < 0;
}

/// A decorative bubble drifting up through the water — pops when the fish
/// swims into it.
class Bubble {
  Bubble({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.phase,
    required this.drift,
  });

  /// Position in world coordinates.
  double x;
  double y;
  double radius;
  double speed;
  double phase;
  double drift;
}

/// The kinds of static scenery scattered along the sea floor.
enum DecorKind { coral, rock, kelp }

/// A fixed piece of world scenery that sits on the sea floor.
class Decor {
  Decor({
    required this.kind,
    required this.x,
    required this.size,
    required this.color,
    required this.phase,
  });

  final DecorKind kind;

  /// World x of the base; the base always rests on the floor.
  final double x;
  final double size;
  final Color color;
  final double phase;
}

/// A short-lived decorative particle (eat splash, hurt debris, bubble pop).
class Particle {
  Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.size,
    required this.color,
    this.gravity = 0,
  }) : maxLife = life;

  double x;
  double y;
  double vx;
  double vy;
  double life;
  final double maxLife;
  final double size;
  final double gravity;
  final Color color;

  void update(double dt) {
    x += vx * dt;
    y += vy * dt;
    vy += gravity * dt;
    vx *= 1 - 0.9 * dt;
    life -= dt;
  }

  double get alpha => (life / maxLife).clamp(0.0, 1.0);
  bool get dead => life <= 0;
}

/// A floating score / status label that rises and fades.
class Floater {
  Floater({
    required this.x,
    required this.y,
    required this.text,
    required this.color,
    this.big = false,
  });

  double x;
  double y;
  final String text;
  final Color color;
  final bool big;
  double life = 1.2;

  void update(double dt) {
    y -= 46 * dt;
    life -= dt;
  }

  double get alpha => (life / 1.2).clamp(0.0, 1.0);
  bool get dead => life <= 0;
}
