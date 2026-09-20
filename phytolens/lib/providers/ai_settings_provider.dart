import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final aiEngineProvider = StateNotifierProvider<AiEngineNotifier, bool>((ref) {
  return AiEngineNotifier();
});

class AiEngineNotifier extends StateNotifier<bool> {
  static const _key = 'ai_engine_enabled';

  AiEngineNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    if (state == enabled) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
    state = enabled;
  }

  Future<void> toggle() async {
    final prefs = await SharedPreferences.getInstance();
    final newState = !state;
    await prefs.setBool(_key, newState);
    state = newState;
  }
}
