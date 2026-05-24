import 'package:shared_preferences/shared_preferences.dart';

/// Persists the player's best score across sessions using on-device storage.
/// Every read and write is failure-tolerant so storage problems can never
/// break the game.
class HighScoreStore {
  static const _key = 'reef_feast_high_score';

  int value = 0;

  /// Loads the saved best score; falls back to 0 if storage is unavailable.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      value = prefs.getInt(_key) ?? 0;
    } catch (_) {
      value = 0;
    }
  }

  /// Stores [score] if it beats the current best. Returns true on a new record.
  Future<bool> submit(int score) async {
    if (score <= value) return false;
    value = score;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key, value);
    } catch (_) {
      // Keep the in-memory value even if it could not be persisted.
    }
    return true;
  }
}
