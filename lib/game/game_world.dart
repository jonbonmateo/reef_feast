import 'dart:math';
import 'dart:ui' show Color;

import 'creature_kind.dart';
import 'entities.dart';
import 'game_config.dart';

enum GamePhase { menu, playing, gameOver }

/// Holds all mutable game state and advances the simulation one frame at a
/// time. The reef is a large scrolling world; a camera follows the fish.
/// Rendering and input live elsewhere — this class is pure logic.
class GameWorld {
  GameWorld();

  final Random _rng = Random();

  /// Viewport size in pixels (one screen).
  double width = 0;
  double height = 0;

  /// The explorable world, several screens across and down.
  double worldWidth = 0;
  double worldHeight = 0;

  /// Top-left of the visible viewport, in world coordinates.
  double cameraX = 0;
  double cameraY = 0;

  bool _ready = false;
  bool _spawnedPlayer = false;

  GamePhase phase = GamePhase.menu;
  bool paused = false;

  // --- Run state -----------------------------------------------------------
  int level = 1;
  int xp = 0;
  int score = 0;
  int lives = GameConfig.startingLives;
  int eaten = 0;
  bool apex = false;

  int combo = 0;
  double comboTimer = 0;
  double invuln = 0;

  double time = 0;
  double _popCooldown = 0;

  // --- Banner --------------------------------------------------------------
  String bannerText = '';
  Color bannerColor = const Color(0xFFFFFFFF);
  double bannerTime = 0;

  // --- Juice ---------------------------------------------------------------
  double shake = 0;
  double shakeX = 0;
  double shakeY = 0;

  // --- Steering target (the finger), in *screen* coordinates --------------
  double pointerX = 0;
  double pointerY = 0;
  bool hasPointer = false;

  late PlayerFish player;
  final List<Creature> creatures = [];
  final List<Bubble> bubbles = [];
  final List<Decor> decorations = [];
  final List<Particle> particles = [];
  final List<Floater> floaters = [];

  // --- Callbacks (set by the screen to play sounds) -----------------------
  void Function()? onEat;
  void Function()? onPop;
  void Function()? onLevelUp;
  void Function()? onHurt;
  void Function()? onGameOver;

  // --- Derived values ------------------------------------------------------
  /// Reference scale for creature sizes and speeds — the smaller viewport
  /// dimension, so the reef stays correctly proportioned on any aspect ratio.
  double get unit => width < height ? width : height;

  double get _floorBand => GameConfig.floorHeight * height;
  double get _surfaceBand => GameConfig.surfaceHeight * height;

  /// World y of the top of the sandy floor.
  double get floorY => worldHeight - _floorBand;

  double playerRadiusFor(int lvl) => GameConfig.playerRadii[lvl] * unit;

  double get _maxSpeed {
    final t = (level - 1) / (GameConfig.maxLevel - 1);
    return (GameConfig.maxSpeedLow +
            (GameConfig.maxSpeedHigh - GameConfig.maxSpeedLow) * t) *
        unit;
  }

  int get comboMultiplier => combo.clamp(1, GameConfig.maxCombo);

  double get xpProgress =>
      apex ? 1.0 : (xp / GameConfig.xpToNext[level]).clamp(0.0, 1.0);

  bool isEdible(Creature c) => player.radius >= c.radius;

  /// How deep the camera is, 0 at the surface .. 1 at the sea floor.
  double get depthFraction {
    final span = worldHeight - height;
    return span <= 0 ? 0.0 : (cameraY / span).clamp(0.0, 1.0);
  }

  // --- Setup ---------------------------------------------------------------

  /// Sets up (or rebuilds) the world for the given viewport size.
  void configure(double w, double h) {
    if (w <= 0 || h <= 0) return;
    final firstTime = !_ready;
    width = w;
    height = h;
    worldWidth = w * GameConfig.worldScreensX;
    worldHeight = h * GameConfig.worldScreensY;
    _ready = true;

    if (!_spawnedPlayer) {
      player = PlayerFish(
        x: worldWidth / 2,
        y: worldHeight / 2,
        radius: playerRadiusFor(1),
      );
      pointerX = w / 2;
      pointerY = h / 2;
      _spawnedPlayer = true;
    }
    _snapCamera();
    _seedBubbles();
    _seedDecor();
    if (firstTime) {
      phase = GamePhase.menu;
      _populateAmbient();
    }
  }

  void _seedBubbles() {
    bubbles.clear();
    for (var i = 0; i < GameConfig.bubbleCount; i++) {
      bubbles.add(_newBubble(_rng.nextDouble() * worldHeight));
    }
  }

  Bubble _newBubble(double y) => Bubble(
        x: _rng.nextDouble() * worldWidth,
        y: y,
        radius: unit * (0.012 + _rng.nextDouble() * 0.022),
        speed: height * (0.05 + _rng.nextDouble() * 0.11),
        phase: _rng.nextDouble() * pi * 2,
        drift: unit * (0.02 + _rng.nextDouble() * 0.05),
      );

  void _seedDecor() {
    decorations.clear();
    final count = max(6, (worldWidth / (width * 0.46)).round());
    const coralColors = [
      Color(0xFFEF6FA5), Color(0xFFFF8A5C), Color(0xFFB57BE0), Color(0xFF54C9BE),
    ];
    const rockColors = [Color(0xFF4A5A6A), Color(0xFF5B6B72)];
    const kelpColors = [Color(0xFF2E7D4F), Color(0xFF3A8C57)];
    for (var i = 0; i < count; i++) {
      final roll = _rng.nextDouble();
      final DecorKind kind;
      final Color color;
      if (roll < 0.5) {
        kind = DecorKind.coral;
        color = coralColors[_rng.nextInt(coralColors.length)];
      } else if (roll < 0.78) {
        kind = DecorKind.kelp;
        color = kelpColors[_rng.nextInt(kelpColors.length)];
      } else {
        kind = DecorKind.rock;
        color = rockColors[_rng.nextInt(rockColors.length)];
      }
      final slot = (i + 0.5) * worldWidth / count;
      decorations.add(Decor(
        kind: kind,
        x: slot + (_rng.nextDouble() * 2 - 1) * width * 0.14,
        size: unit * (0.13 + _rng.nextDouble() * 0.20),
        color: color,
        phase: _rng.nextDouble() * pi * 2,
      ));
    }
  }

  void _populateAmbient() {
    creatures.clear();
    for (var i = 0; i < GameConfig.targetPopulation - 3; i++) {
      _spawnCreature(onScreen: true);
    }
  }

  /// Begins a fresh run.
  void start() {
    level = 1;
    xp = 0;
    score = 0;
    lives = GameConfig.startingLives;
    eaten = 0;
    apex = false;
    combo = 0;
    comboTimer = 0;
    invuln = 0;
    shake = 0;
    bannerTime = 0;
    paused = false;
    player.reset(worldWidth / 2, worldHeight / 2, playerRadiusFor(1));
    pointerX = width / 2;
    pointerY = height / 2;
    hasPointer = false;
    _snapCamera();
    creatures.clear();
    particles.clear();
    floaters.clear();
    for (var i = 0; i < GameConfig.targetPopulation; i++) {
      _spawnCreature(onScreen: true);
    }
    phase = GamePhase.playing;
  }

  void pause() {
    if (phase == GamePhase.playing) paused = true;
  }

  void resume() => paused = false;

  void backToMenu() {
    phase = GamePhase.menu;
    paused = false;
    particles.clear();
    floaters.clear();
    bannerTime = 0;
    player.reset(worldWidth / 2, worldHeight / 2, playerRadiusFor(1));
    hasPointer = false;
    _snapCamera();
    _populateAmbient();
  }

  /// Records where the finger is (screen coordinates) so the fish can steer.
  void setPointer(double x, double y) {
    pointerX = x;
    pointerY = y;
    hasPointer = true;
  }

  // --- Frame ---------------------------------------------------------------

  /// Advances the simulation by [dt] seconds.
  void update(double dt) {
    if (!_ready || paused) return;
    dt = dt.clamp(0.0, 1 / 30);
    time += dt;

    _updateBubbles(dt);
    for (final p in particles) {
      p.update(dt);
    }
    particles.removeWhere((p) => p.dead);
    for (final f in floaters) {
      f.update(dt);
    }
    floaters.removeWhere((f) => f.dead);
    if (bannerTime > 0) bannerTime = max(0, bannerTime - dt);
    if (_popCooldown > 0) _popCooldown -= dt;

    if (shake > 0) {
      shake = max(0, shake - dt * 2.6);
      shakeX = (_rng.nextDouble() * 2 - 1) * shake * unit * 0.03;
      shakeY = (_rng.nextDouble() * 2 - 1) * shake * unit * 0.03;
    } else {
      shakeX = 0;
      shakeY = 0;
    }

    switch (phase) {
      case GamePhase.menu:
        _updateMenu(dt);
        break;
      case GamePhase.playing:
        _updatePlaying(dt);
        break;
      case GamePhase.gameOver:
        _updateGameOver(dt);
        break;
    }
    _updateCamera(dt);
  }

  void _updateBubbles(double dt) {
    for (final b in bubbles) {
      b.y -= b.speed * dt;
      b.phase += dt * 2.4;
      b.x += sin(b.phase) * b.drift * dt;
      if (b.y + b.radius < 0) {
        _recycleBubble(b);
      }
    }
  }

  void _recycleBubble(Bubble b) {
    b.y = worldHeight + b.radius;
    b.x = _rng.nextDouble() * worldWidth;
    b.radius = unit * (0.012 + _rng.nextDouble() * 0.022);
    b.speed = height * (0.05 + _rng.nextDouble() * 0.11);
  }

  void _updateMenu(double dt) {
    _moveCreatures(dt);
    _maintainPopulation();
    player.x = worldWidth / 2;
    player.y = worldHeight / 2 + sin(time * 1.8) * height * 0.02;
    player.angle = sin(time * 1.8) * 0.12;
    player.phase += dt * 5;
    player.radius = playerRadiusFor(1);
  }

  void _updatePlaying(double dt) {
    if (invuln > 0) invuln = max(0, invuln - dt);
    if (comboTimer > 0) {
      comboTimer = max(0, comboTimer - dt);
      if (comboTimer == 0) combo = 0;
    }
    _updatePlayer(dt);
    _moveCreatures(dt);
    _handleCollisions();
    _popBubbles();
    _maintainPopulation();
  }

  void _updateGameOver(double dt) {
    _moveCreatures(dt);
    _maintainPopulation();
    final drag = (dt * 2).clamp(0.0, 1.0);
    player.vx *= 1 - drag;
    player.vy *= 1 - drag;
    player.x += player.vx * dt;
    player.y += player.vy * dt;
    player.phase += dt * 3;
  }

  void _snapCamera() {
    cameraX = (player.x - width / 2).clamp(0.0, max(0.0, worldWidth - width));
    cameraY = (player.y - height / 2).clamp(0.0, max(0.0, worldHeight - height));
  }

  void _updateCamera(double dt) {
    final tx = (player.x - width / 2).clamp(0.0, max(0.0, worldWidth - width));
    final ty =
        (player.y - height / 2).clamp(0.0, max(0.0, worldHeight - height));
    final k = (dt * GameConfig.cameraEase).clamp(0.0, 1.0);
    cameraX += (tx - cameraX) * k;
    cameraY += (ty - cameraY) * k;
  }

  void _updatePlayer(double dt) {
    final p = player;
    final speed = sqrt(p.vx * p.vx + p.vy * p.vy);
    p.phase += dt * (6 + speed * 0.012);

    final maxSpeed = _maxSpeed;
    var tvx = 0.0;
    var tvy = 0.0;
    if (hasPointer) {
      // The finger is a screen point; its world target moves with the camera,
      // so holding it off-centre keeps the fish exploring in that direction.
      final dx = pointerX + cameraX - p.x;
      final dy = pointerY + cameraY - p.y;
      final d = sqrt(dx * dx + dy * dy);
      if (d > unit * 0.012) {
        final desired = min(d * GameConfig.followGain, maxSpeed);
        tvx = dx / d * desired;
        tvy = dy / d * desired;
      }
    }
    final k = (dt * GameConfig.steerEase).clamp(0.0, 1.0);
    p.vx += (tvx - p.vx) * k;
    p.vy += (tvy - p.vy) * k;

    p.radius += (p.targetRadius - p.radius) * (dt * 5).clamp(0.0, 1.0);

    p.x = (p.x + p.vx * dt).clamp(p.radius, worldWidth - p.radius);
    p.y = (p.y + p.vy * dt).clamp(p.radius, floorY - p.radius);

    final movedSpeed = sqrt(p.vx * p.vx + p.vy * p.vy);
    if (movedSpeed > unit * 0.04) {
      final targetAngle = atan2(p.vy, p.vx);
      var da = targetAngle - p.angle;
      while (da > pi) {
        da -= pi * 2;
      }
      while (da < -pi) {
        da += pi * 2;
      }
      p.angle += da * (dt * 9).clamp(0.0, 1.0);
    }
  }

  void _moveCreatures(double dt) {
    final topBand = _surfaceBand * 0.4;
    final botBand = floorY - _floorBand * 0.2;
    final cullL = cameraX - width * 0.7;
    final cullR = cameraX + width * 1.7;
    final cullT = cameraY - height * 0.8;
    final cullB = cameraY + height * 1.8;
    for (var i = creatures.length - 1; i >= 0; i--) {
      final c = creatures[i];
      c.phase += dt * c.spec.animSpeed;
      c.x += c.vx * dt;
      switch (c.spec.kind) {
        case CreatureKind.crab:
          c.y += sin(time * 2 + c.wanderPhase) * unit * 0.02 * dt;
          c.y = c.y.clamp(floorY - height * 0.24,
              max(floorY - height * 0.24, floorY - c.radius));
          break;
        case CreatureKind.jellyfish:
          c.y += sin(time * 1.5 + c.wanderPhase) * unit * 0.12 * dt;
          c.y = c.y.clamp(
              topBand + c.radius, max(topBand + c.radius, botBand - c.radius));
          break;
        default:
          c.y += sin(time * c.spec.wanderFreq + c.wanderPhase) *
              c.spec.wanderAmp *
              unit *
              dt;
          c.y = c.y.clamp(
              topBand + c.radius, max(topBand + c.radius, botBand - c.radius));
      }
      if (c.x < cullL - c.radius ||
          c.x > cullR + c.radius ||
          c.y < cullT ||
          c.y > cullB) {
        creatures.removeAt(i);
      }
    }
  }

  void _handleCollisions() {
    for (var i = creatures.length - 1; i >= 0; i--) {
      final c = creatures[i];
      final dx = c.x - player.x;
      final dy = c.y - player.y;
      final d = sqrt(dx * dx + dy * dy);
      if (player.radius >= c.radius) {
        if (d < player.radius * 0.94) {
          _eat(c);
          creatures.removeAt(i);
        }
      } else if (invuln <= 0 && d < c.radius * 0.86) {
        _hurt();
        return; // at most one bite per frame
      }
    }
  }

  void _popBubbles() {
    for (final b in bubbles) {
      final dx = b.x - player.x;
      final dy = b.y - player.y;
      final reach = player.radius * 0.85 + b.radius;
      if (dx * dx + dy * dy < reach * reach) {
        _burst(b.x, b.y, const Color(0xFFCDEBFF), 7, grav: -0.3);
        _recycleBubble(b);
        if (_popCooldown <= 0) {
          onPop?.call();
          _popCooldown = 0.07;
        }
      }
    }
  }

  void _eat(Creature c) {
    eaten++;
    combo = comboTimer > 0 ? combo + 1 : 1;
    comboTimer = GameConfig.comboWindow;
    final mult = combo.clamp(1, GameConfig.maxCombo);
    final gained = c.spec.xp * 10 * mult;
    score += gained;
    if (!apex) xp += c.spec.xp;

    _burst(c.x, c.y, c.color, (10 + c.radius * 0.18).clamp(10.0, 30.0).round());
    floaters.add(Floater(
      x: c.x,
      y: c.y - c.radius * 0.6,
      text: '+$gained',
      color: mult > 1 ? const Color(0xFFFFD166) : const Color(0xFFBFF7D0),
    ));
    if (mult >= 3) {
      floaters.add(Floater(
        x: c.x,
        y: c.y - c.radius - height * 0.03,
        text: 'COMBO x$mult',
        color: const Color(0xFFFF9A3C),
        big: true,
      ));
    }
    onEat?.call();

    while (!apex && xp >= GameConfig.xpToNext[level]) {
      xp -= GameConfig.xpToNext[level];
      level++;
      player.targetRadius = playerRadiusFor(level);
      _burst(player.x, player.y, const Color(0xFFFFE08A), 30, grav: -0.2);
      onLevelUp?.call();
      if (level >= GameConfig.maxLevel) {
        apex = true;
        xp = 0;
        _showBanner('APEX PREDATOR!', const Color(0xFFFFD166));
      } else {
        _showBanner('LEVEL $level!', const Color(0xFF8DF0FF));
      }
    }
  }

  void _hurt() {
    lives--;
    invuln = GameConfig.invulnSeconds;
    combo = 0;
    comboTimer = 0;
    shake = 1.0;
    _burst(player.x, player.y, const Color(0xFFFF6B6B),
        GameConfig.hurtParticles, grav: 0.25);
    floaters.add(Floater(
      x: player.x,
      y: player.y - player.radius - height * 0.02,
      text: '-1 LIFE',
      color: const Color(0xFFFF6B6B),
      big: true,
    ));
    onHurt?.call();
    if (lives <= 0) {
      phase = GamePhase.gameOver;
      onGameOver?.call();
    } else {
      _showBanner('CHOMP!  $lives LEFT', const Color(0xFFFF6B6B));
    }
  }

  void _showBanner(String text, Color color) {
    bannerText = text;
    bannerColor = color;
    bannerTime = GameConfig.bannerSeconds;
  }

  void _burst(double x, double y, Color color, int count,
      {double grav = -0.12}) {
    for (var i = 0; i < count; i++) {
      final ang = _rng.nextDouble() * pi * 2;
      final spd = unit * (0.12 + _rng.nextDouble() * 0.5);
      particles.add(Particle(
        x: x,
        y: y,
        vx: cos(ang) * spd,
        vy: sin(ang) * spd - height * 0.05,
        life: 0.4 + _rng.nextDouble() * 0.55,
        size: unit * (0.008 + _rng.nextDouble() * 0.016),
        color: color,
        gravity: grav * height,
      ));
    }
  }

  // --- Spawning ------------------------------------------------------------

  void _maintainPopulation() {
    while (creatures.length < GameConfig.targetPopulation) {
      _spawnCreature();
    }
    if (phase == GamePhase.playing) {
      var hasEdible = false;
      for (final c in creatures) {
        if (c.radius <= player.radius) {
          hasEdible = true;
          break;
        }
      }
      if (!hasEdible) {
        _spawnCreature(
            force: _rng.nextBool() ? CreatureKind.shrimp : CreatureKind.fish);
      }
    }
  }

  void _spawnCreature({bool onScreen = false, CreatureKind? force}) {
    final kind = force ?? _pickKind();
    final spec = kCreatureSpecs[kind]!;
    final scale = GameConfig.minSizeScale +
        _rng.nextDouble() *
            (GameConfig.maxSizeScale - GameConfig.minSizeScale);
    final radius = spec.baseRadius * unit * scale;
    final dir = _rng.nextBool() ? 1 : -1;

    final topBand = _surfaceBand * 0.4 + radius;
    final botBand = floorY - radius - _floorBand * 0.2;

    double x;
    if (onScreen) {
      x = cameraX + radius + _rng.nextDouble() * max(1.0, width - 2 * radius);
    } else {
      x = dir > 0
          ? cameraX - radius - unit * 0.12
          : cameraX + width + radius + unit * 0.12;
    }

    double y;
    if (kind == CreatureKind.crab) {
      final ct = floorY - height * 0.22;
      final cb = floorY - radius - _floorBand * 0.3;
      y = ct + _rng.nextDouble() * max(1.0, cb - ct);
    } else {
      y = cameraY + (-0.12 + _rng.nextDouble() * 1.24) * height;
      y = y.clamp(topBand, max(topBand, botBand));
    }

    final speed = GameConfig.baseSwimSpeed *
        unit *
        spec.speed *
        (0.85 + _rng.nextDouble() * 0.3) /
        sqrt(scale);

    creatures.add(Creature(
      spec: spec,
      x: x,
      y: y,
      radius: radius,
      vx: dir * speed,
      color: spec.colors[_rng.nextInt(spec.colors.length)],
      phase: _rng.nextDouble() * pi * 2,
      wanderPhase: _rng.nextDouble() * pi * 2,
    ));
  }

  /// Picks a species weighted toward the player's current level, so there is
  /// always food in reach and a credible threat nearby.
  CreatureKind _pickKind() {
    final weights = <double>[];
    var total = 0.0;
    for (final kind in kCreatureOrder) {
      final spec = kCreatureSpecs[kind]!;
      final diff = spec.tier - level;
      double w;
      if (diff <= 0) {
        w = 3.2;
      } else if (diff == 1) {
        w = 2.6;
      } else if (diff == 2) {
        w = 1.6;
      } else if (diff == 3) {
        w = 0.7;
      } else {
        w = 0.22;
      }
      if (spec.tier <= 2 && w < 1.5) w = 1.5;
      weights.add(w);
      total += w;
    }
    var r = _rng.nextDouble() * total;
    for (var i = 0; i < kCreatureOrder.length; i++) {
      r -= weights[i];
      if (r <= 0) return kCreatureOrder[i];
    }
    return kCreatureOrder.first;
  }
}
