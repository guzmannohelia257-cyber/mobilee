import 'package:shared_preferences/shared_preferences.dart';

/// Controla si el tutorial inicial ya fue visto. Se persiste en el mismo
/// SharedPreferences que usa AuthService, pero con una key propia que NO se
/// borra en logout (para no repetir el onboarding al cerrar sesión).
class OnboardingService {
  static const String _key = 'onboarding_visto';

  Future<bool> yaVisto() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> marcarVisto() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }

  /// Solo para QA / botón "volver a ver tutorial".
  Future<void> reiniciar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
