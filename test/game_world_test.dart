import 'package:flutter_test/flutter_test.dart';
import 'package:reef_feast/game/game_config.dart';
import 'package:reef_feast/game/game_world.dart';

void main() {
  GameWorld freshWorld() => GameWorld()..configure(400, 800);

  test('a configured world starts in the menu with creatures swimming', () {
    final world = freshWorld();
    expect(world.phase, GamePhase.menu);
    expect(world.creatures, isNotEmpty);
  });

  test('starting a run resets all progression', () {
    final world = freshWorld()..start();
    expect(world.phase, GamePhase.playing);
    expect(world.level, 1);
    expect(world.score, 0);
    expect(world.xp, 0);
    expect(world.lives, GameConfig.startingLives);
    expect(world.apex, isFalse);
  });

  test('the reef stays populated as the simulation runs', () {
    final world = freshWorld()..start();
    for (var i = 0; i < 300; i++) {
      world.update(1 / 60);
    }
    expect(world.creatures.length,
        greaterThanOrEqualTo(GameConfig.targetPopulation));
    expect(world.time, greaterThan(0));
  });

  test('the camera stays within the world bounds', () {
    final world = freshWorld()..start();
    for (var i = 0; i < 300; i++) {
      world.update(1 / 60);
      expect(world.cameraX, inInclusiveRange(0.0, world.worldWidth));
      expect(world.cameraY, inInclusiveRange(0.0, world.worldHeight));
    }
  });

  test('xp progress stays within 0..1', () {
    final world = freshWorld()..start();
    for (var i = 0; i < 600; i++) {
      world.update(1 / 60);
      expect(world.xpProgress, inInclusiveRange(0.0, 1.0));
    }
  });
}
