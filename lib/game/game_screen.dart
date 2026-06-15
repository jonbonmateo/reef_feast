import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'audio_manager.dart';
import 'game_config.dart';
import 'game_painter.dart';
import 'game_world.dart';
import 'high_score_store.dart';

/// The single screen of the game: hosts the render loop, input and all the
/// menu / HUD / game-over overlays.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  static const _deep = Color(0xFF0A3D62);
  static const _accent = Color(0xFFFF8A3D);

  final GameWorld _world = GameWorld();
  final AudioManager _audio = AudioManager();
  final HighScoreStore _highScore = HighScoreStore();

  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  Size _lastSize = Size.zero;
  bool _newBest = false;

  @override
  void initState() {
    super.initState();
    _world.onEat = _audio.playYum;
    _world.onPop = _audio.playPop;
    _world.onLevelUp = _audio.playLevelUp;
    _world.onHurt = _audio.playHurt;
    _world.onGameOver = _handleGameOver;
    _audio.init();
    _highScore.load().then((_) {
      if (mounted) setState(() {});
    });
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final dt = _lastElapsed == Duration.zero
        ? 0.0
        : (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    _world.update(dt);
    if (mounted) setState(() {});
  }

  void _handleGameOver() {
    _audio.playGameOver();
    _highScore.submit(_world.score).then((isBest) {
      if (mounted) setState(() => _newBest = isBest);
    });
  }

  // --- Input -----------------------------------------------------------------

  void _steer(Offset pos) {
    if (_world.phase == GamePhase.gameOver || _world.paused) return;
    _world.setPointer(pos.dx, pos.dy);
  }

  void _onTapDown(TapDownDetails d) {
    if (_world.phase == GamePhase.menu) {
      _newBest = false;
      setState(_world.start);
    }
    _steer(d.localPosition);
  }

  void _onPanStart(DragStartDetails d) => _steer(d.localPosition);
  void _onPanUpdate(DragUpdateDetails d) => _steer(d.localPosition);

  void _pause() => setState(_world.pause);
  void _resume() => setState(_world.resume);

  void _playAgain() => setState(() {
        _newBest = false;
        _world.start();
      });

  void _goToMenu() => setState(() {
        _newBest = false;
        _world.backToMenu();
      });

  @override
  void dispose() {
    _ticker.dispose();
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _deep,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          if ((size.width - _lastSize.width).abs() > 1 ||
              (size.height - _lastSize.height).abs() > 1) {
            _lastSize = size;
            _world.configure(size.width, size.height);
          }
          return Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: _onTapDown,
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                child: CustomPaint(painter: GamePainter(_world)),
              ),
              SafeArea(
                child: Stack(
                  children: [
                    _buildTopBar(),
                    if (_world.phase == GamePhase.playing) _buildHud(),
                    if (_world.phase == GamePhase.menu) _buildMenu(),
                    if (_world.phase == GamePhase.gameOver) _buildGameOver(),
                  ],
                ),
              ),
              if (_world.paused) _buildPauseOverlay(),
            ],
          );
        },
      ),
    );
  }

  // --- HUD -------------------------------------------------------------------

  Widget _buildTopBar() {
    final playing = _world.phase == GamePhase.playing;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (playing && !_world.paused)
            _RoundIconButton(icon: Icons.pause_rounded, onTap: _pause)
          else
            const SizedBox(width: 46),
          Expanded(
            child: Center(
              child: playing
                  ? Text(
                      '${_world.score}',
                      style: TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1,
                        shadows: _shadow(_deep, 10),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          _RoundIconButton(
            icon: _audio.muted
                ? Icons.volume_off_rounded
                : Icons.volume_up_rounded,
            onTap: () => setState(_audio.toggleMute),
          ),
        ],
      ),
    );
  }

  Widget _buildHud() {
    return Positioned(
      top: 78,
      left: 0,
      right: 0,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFFD166), Color(0xFFF4A300)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _world.apex ? 'Lv MAX' : 'Lv ${_world.level}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF5A3B00),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 150,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.32),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.45), width: 1.5),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: _world.xpProgress.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF8DF0FF), Color(0xFF2BB6E0)],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < GameConfig.startingLives; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Icon(
                    Icons.favorite_rounded,
                    size: 20,
                    color: i < _world.lives
                        ? const Color(0xFFFF6B6B)
                        : Colors.white.withValues(alpha: 0.22),
                  ),
                ),
            ],
          ),
          if (_world.combo >= 2) ...[
            const SizedBox(height: 4),
            Text(
              'Combo x${_world.comboMultiplier}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFFF9A3C),
                shadows: _shadow(_deep, 5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Overlays --------------------------------------------------------------

  Widget _buildMenu() {
    final pulse = 1 + sin(_world.time * 3) * 0.05;
    return Stack(
      children: [
        Positioned(
          top: 48,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Text(
                'REEF FEAST',
                style: TextStyle(
                  fontSize: 46,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: Colors.white,
                  shadows: _shadow(_deep, 12),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Eat. Grow. Rule the reef.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.92),
                  shadows: _shadow(_deep, 6),
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: const Alignment(0, 0.55),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildRuleRow(const Color(0xFF4DFF8C),
                  'Eat creatures smaller than you'),
              const SizedBox(height: 6),
              _buildRuleRow(const Color(0xFFFF5A66),
                  'Dodge anything bigger — it bites back'),
              const SizedBox(height: 30),
              GestureDetector(
                onTap: () => setState(() {
                  _newBest = false;
                  _world.start();
                }),
                child: Transform.scale(
                  scale: pulse,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 14),
                    decoration: BoxDecoration(
                      color: _accent,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x55000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Text(
                      'TAP TO START',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Drag anywhere to swim',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.85),
                  shadows: _shadow(_deep, 5),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Best: ${_highScore.value}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.95),
                  shadows: _shadow(_deep, 6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRuleRow(Color dot, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: dot,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: dot, blurRadius: 7)],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.95),
            shadows: _shadow(_deep, 5),
          ),
        ),
      ],
    );
  }

  Widget _buildGameOver() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 36),
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
        decoration: BoxDecoration(
          color: const Color(0xF20A3D62),
          borderRadius: BorderRadius.circular(28),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.15), width: 2),
          boxShadow: const [
            BoxShadow(
                color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 8)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _world.apex ? 'REEF CONQUERED!' : 'GAME OVER',
              style: TextStyle(
                fontSize: _world.apex ? 26 : 30,
                fontWeight: FontWeight.w900,
                color: _world.apex ? const Color(0xFFFFD166) : Colors.white,
                letterSpacing: 1.5,
              ),
            ),
            if (_newBest) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC83D),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '★ NEW BEST ★',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF7A4A00),
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              '${_world.eaten} creatures eaten',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatBox(label: 'SCORE', value: '${_world.score}'),
                _StatBox(
                    label: 'LEVEL',
                    value: _world.apex ? 'MAX' : '${_world.level}'),
                _StatBox(label: 'BEST', value: '${_highScore.value}'),
              ],
            ),
            const SizedBox(height: 24),
            _WideButton(label: 'PLAY AGAIN', filled: true, onTap: _playAgain),
            const SizedBox(height: 12),
            _WideButton(label: 'MENU', filled: false, onTap: _goToMenu),
          ],
        ),
      ),
    );
  }

  Widget _buildPauseOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: Container(
          color: Colors.black.withValues(alpha: 0.5),
          alignment: Alignment.center,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 48),
            padding: const EdgeInsets.fromLTRB(28, 26, 28, 26),
            decoration: BoxDecoration(
              color: const Color(0xF20A3D62),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15), width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'PAUSED',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 24),
                _WideButton(label: 'RESUME', filled: true, onTap: _resume),
                const SizedBox(height: 12),
                _WideButton(label: 'MENU', filled: false, onTap: _goToMenu),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static List<Shadow> _shadow(Color color, double blur) => [
        Shadow(color: color, blurRadius: blur, offset: const Offset(0, 2)),
      ];
}

/// A circular translucent button used for pause and the mute toggle.
class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.22),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }
}

/// A labelled score figure shown on the game-over card.
class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

/// A full-width pill button for the menu / game-over actions.
class _WideButton extends StatelessWidget {
  const _WideButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? const Color(0xFFFF8A3D) : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
          border: filled
              ? null
              : Border.all(
                  color: Colors.white.withValues(alpha: 0.55), width: 2),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
