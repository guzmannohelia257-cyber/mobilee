import 'package:shared_preferences/shared_preferences.dart';

class TourService {
  static const String _key = 'tour_solicitar_paso';

  Future<bool> yaVisto() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> marcarVisto() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }

  /// El usuario tocó "Saltar": termina el tour de inmediato (mismo efecto que
  /// completarlo, para que no vuelva a aparecer solo).
  Future<void> saltarTour() async {
    await marcarVisto();
  }

  Future<void> reiniciar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
