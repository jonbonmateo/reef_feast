import 'dart:ui' show Color;

/// The seven sea creatures that swim the reef, smallest to largest.
enum CreatureKind { shrimp, fish, crab, jellyfish, turtle, octopus, whale }

/// Immutable description of a creature species. Every spawned [creature]
/// references one of these via [kCreatureSpecs].
class CreatureSpec {
  const CreatureSpec({
    required this.kind,
    required this.name,
    required this.tier,
    required this.baseRadius,
    required this.speed,
    required this.xp,
    required this.colors,
    required this.flip,
    required this.wanderAmp,
    required this.wanderFreq,
    required this.animSpeed,
  });

  final CreatureKind kind;
  final String name;

  /// Size rank, 1 (shrimp) .. 7 (whale). Drives spawn weighting.
  final int tier;

  /// Collision radius before the random size roll, as a fraction of W.
  final double baseRadius;

  /// Swim-speed multiplier applied to [GameConfig.baseSwimSpeed].
  final double speed;

  /// XP and (x10) score awarded for eating one.
  final int xp;

  /// Palette — one colour is picked at random per spawn.
  final List<Color> colors;

  /// Whether the sprite should be mirrored when swimming left.
  final bool flip;

  /// Vertical wander amplitude (W/s) and frequency.
  final double wanderAmp;
  final double wanderFreq;

  /// Multiplier on the idle animation phase (tail wag, tentacle sway…).
  final double animSpeed;
}

/// Every species, keyed by kind.
const Map<CreatureKind, CreatureSpec> kCreatureSpecs = {
  CreatureKind.shrimp: CreatureSpec(
    kind: CreatureKind.shrimp,
    name: 'Shrimp',
    tier: 1,
    baseRadius: 0.036,
    speed: 1.55,
    xp: 1,
    colors: [Color(0xFFFF9A76), Color(0xFFFFB38A), Color(0xFFFF8E9E)],
    flip: true,
    wanderAmp: 0.085,
    wanderFreq: 3.2,
    animSpeed: 9.0,
  ),
  CreatureKind.fish: CreatureSpec(
    kind: CreatureKind.fish,
    name: 'Fish',
    tier: 2,
    baseRadius: 0.050,
    speed: 1.15,
    xp: 2,
    colors: [
      Color(0xFFFFD166),
      Color(0xFF69D2E7),
      Color(0xFFF78FB3),
      Color(0xFF9BE39B),
      Color(0xFFF6C1FF),
    ],
    flip: true,
    wanderAmp: 0.07,
    wanderFreq: 2.4,
    animSpeed: 10.0,
  ),
  CreatureKind.crab: CreatureSpec(
    kind: CreatureKind.crab,
    name: 'Crab',
    tier: 3,
    baseRadius: 0.068,
    speed: 0.78,
    xp: 4,
    colors: [Color(0xFFEF476F), Color(0xFFE8503A)],
    flip: true,
    wanderAmp: 0.0,
    wanderFreq: 0.0,
    animSpeed: 7.0,
  ),
  CreatureKind.jellyfish: CreatureSpec(
    kind: CreatureKind.jellyfish,
    name: 'Jellyfish',
    tier: 4,
    baseRadius: 0.086,
    speed: 0.5,
    xp: 7,
    colors: [Color(0xFFC792EA), Color(0xFF9D8DF1), Color(0xFFF3A0C9)],
    flip: false,
    wanderAmp: 0.0,
    wanderFreq: 0.0,
    animSpeed: 2.4,
  ),
  CreatureKind.turtle: CreatureSpec(
    kind: CreatureKind.turtle,
    name: 'Turtle',
    tier: 5,
    baseRadius: 0.112,
    speed: 0.64,
    xp: 11,
    colors: [Color(0xFF2EC4A0), Color(0xFF27A96C)],
    flip: true,
    wanderAmp: 0.04,
    wanderFreq: 1.5,
    animSpeed: 3.5,
  ),
  CreatureKind.octopus: CreatureSpec(
    kind: CreatureKind.octopus,
    name: 'Octopus',
    tier: 6,
    baseRadius: 0.146,
    speed: 0.72,
    xp: 17,
    colors: [Color(0xFF9B5DE5), Color(0xFFB5547E)],
    flip: false,
    wanderAmp: 0.035,
    wanderFreq: 1.2,
    animSpeed: 2.6,
  ),
  CreatureKind.whale: CreatureSpec(
    kind: CreatureKind.whale,
    name: 'Whale',
    tier: 7,
    baseRadius: 0.208,
    speed: 0.42,
    xp: 34,
    colors: [Color(0xFF4EA8DE), Color(0xFF5E8BB0)],
    flip: true,
    wanderAmp: 0.025,
    wanderFreq: 0.8,
    animSpeed: 1.6,
  ),
};

/// All specs as a list, smallest first.
const List<CreatureKind> kCreatureOrder = [
  CreatureKind.shrimp,
  CreatureKind.fish,
  CreatureKind.crab,
  CreatureKind.jellyfish,
  CreatureKind.turtle,
  CreatureKind.octopus,
  CreatureKind.whale,
];
