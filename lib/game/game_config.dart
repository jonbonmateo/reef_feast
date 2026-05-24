/// Central place for gameplay tuning. Creature/player sizes and speeds are
/// fractions of [GameWorld.unit] (the smaller viewport dimension); world and
/// position values are fractions of the viewport width (W) or height (H).
class GameConfig {
  GameConfig._();

  // --- Progression ---------------------------------------------------------
  /// Final level — reaching it makes the player the apex predator.
  static const int maxLevel = 8;

  /// Player collision radius at each level (index 1..8), as a fraction of unit.
  static const List<double> playerRadii = [
    0, 0.058, 0.078, 0.100, 0.126, 0.154, 0.182, 0.210, 0.240,
  ];

  /// XP required to advance *from* the given level (index 1..7).
  static const List<int> xpToNext = [
    0, 12, 20, 34, 54, 84, 128, 190, 1 << 30,
  ];

  /// Lives the player starts a run with.
  static const int startingLives = 3;

  // --- Player movement -----------------------------------------------------
  /// Top swim speed at level 1 and at the max level (unit/s). Bigger fish are
  /// a little slower, the classic Feeding Frenzy trade-off.
  static const double maxSpeedLow = 0.95;
  static const double maxSpeedHigh = 0.62;

  /// How hard the fish steers toward the finger (per second).
  static const double followGain = 5.0;

  /// Velocity easing toward the steering target (per second).
  static const double steerEase = 7.0;

  /// Seconds of blinking invulnerability granted after losing a life.
  static const double invulnSeconds = 2.6;

  // --- Combo ---------------------------------------------------------------
  /// Eating again within this window keeps the combo alive.
  static const double comboWindow = 1.7;

  /// Largest combo multiplier applied to the score.
  static const int maxCombo = 5;

  // --- The vast reef -------------------------------------------------------
  /// The explorable world spans this many screens across and down.
  static const double worldScreensX = 5.0;
  static const double worldScreensY = 3.2;

  /// How quickly the camera catches up to the fish (per second).
  static const double cameraEase = 6.0;

  /// Height of the bright sunlit surface band, as a fraction of H.
  static const double surfaceHeight = 0.16;

  /// Height of the sandy sea floor, as a fraction of H.
  static const double floorHeight = 0.085;

  /// Ambient rising bubbles scattered through the whole world.
  static const int bubbleCount = 64;

  // --- Creatures -----------------------------------------------------------
  /// How many creatures to keep alive around the player at once.
  static const int targetPopulation = 16;

  /// Base horizontal swim speed, scaled per species (unit/s).
  static const double baseSwimSpeed = 0.17;

  /// Smallest / largest random size multiplier applied when a creature spawns.
  static const double minSizeScale = 0.86;
  static const double maxSizeScale = 1.13;

  // --- Juice ---------------------------------------------------------------
  /// Particles flung out when the player is bitten.
  static const int hurtParticles = 26;

  /// Seconds a level-up / combo banner stays on screen.
  static const double bannerSeconds = 1.9;
}
