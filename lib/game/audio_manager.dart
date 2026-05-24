import 'package:audioplayers/audioplayers.dart';

/// Plays the game's sound effects. Every call is wrapped in error handling so
/// an audio problem on any platform can never interrupt gameplay.
class AudioManager {
  final AudioPlayer _yum = AudioPlayer();
  final AudioPlayer _pop = AudioPlayer();
  final AudioPlayer _levelUp = AudioPlayer();
  final AudioPlayer _hurt = AudioPlayer();
  final AudioPlayer _gameOver = AudioPlayer();

  bool muted = false;
  bool _ready = false;

  List<AudioPlayer> get _all => [_yum, _pop, _levelUp, _hurt, _gameOver];

  /// Loads each effect once. Safe to call even if audio is unavailable.
  Future<void> init() async {
    try {
      for (final p in _all) {
        await p.setReleaseMode(ReleaseMode.stop);
      }
      await _yum.setSource(AssetSource('sounds/yum.wav'));
      await _pop.setSource(AssetSource('sounds/pop.wav'));
      await _levelUp.setSource(AssetSource('sounds/levelup.wav'));
      await _hurt.setSource(AssetSource('sounds/hurt.wav'));
      await _gameOver.setSource(AssetSource('sounds/gameover.wav'));
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  /// "Yum!" — played when the fish eats a creature.
  void playYum() => _play(_yum);

  /// "Pop!" — played when the fish pops a bubble.
  void playPop() => _play(_pop);

  void playLevelUp() => _play(_levelUp);
  void playHurt() => _play(_hurt);
  void playGameOver() => _play(_gameOver);

  void toggleMute() => muted = !muted;

  /// Restarts the clip from the beginning — fire-and-forget, never throws.
  void _play(AudioPlayer player) {
    if (muted || !_ready) return;
    () async {
      try {
        await player.seek(Duration.zero);
        await player.resume();
      } catch (_) {
        // Ignore — gameplay must continue regardless of audio state.
      }
    }();
  }

  Future<void> dispose() async {
    for (final p in _all) {
      try {
        await p.dispose();
      } catch (_) {}
    }
  }
}
