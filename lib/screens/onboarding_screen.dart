import 'package:flutter/material.dart';

import '../services/onboarding_service.dart';
import '../theme/app_colors.dart';

class _Slide {
  final IconData icono;
  final String titulo;
  final String texto;
  const _Slide(this.icono, this.titulo, this.texto);
}

const _slides = <_Slide>[
  _Slide(
    Icons.car_crash,
    'Ayuda en carretera, al instante',
    'Reporta tu emergencia y recibe asistencia cercana en minutos.',
  ),
  _Slide(
    Icons.mic,
    'Cuéntanos qué pasó',
    'Describe el problema con texto, fotos o audio. La IA prioriza tu caso.',
  ),
  _Slide(
    Icons.location_on,
    'Sigue al técnico en tiempo real',
    'Observa en el mapa cómo la ayuda avanza hacia ti.',
  ),
  _Slide(
    Icons.verified_user,
    'Paga seguro en la app',
    'Cotización clara y pago protegido. ¡Listo para empezar!',
  ),
];

/// Tutorial inicial de 4 pantallas. Se muestra una sola vez, antes del login
/// (ver el gate en main.dart -> _InitialScreenState._checkAuthentication).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pc = PageController();
  int _pagina = 0;
  bool get _ultima => _pagina == _slides.length - 1;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Future<void> _terminar() async {
    await OnboardingService().marcarVisto();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: _ultima
                  ? const SizedBox(height: 48)
                  : TextButton(
                      onPressed: _terminar,
                      child: const Text('Saltar'),
                    ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pc,
                onPageChanged: (i) => setState(() => _pagina = i),
                itemCount: _slides.length,
                itemBuilder: (context, i) {
                  final s = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(s.icono, size: 96, color: AppColors.brand),
                        const SizedBox(height: 32),
                        Text(
                          s.titulo,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          s.texto,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.inkMuted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _pagina ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _pagina ? AppColors.brand : AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_ultima) {
                      _terminar();
                    } else {
                      _pc.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                  child: Text(_ultima ? 'Empezar' : 'Siguiente'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
