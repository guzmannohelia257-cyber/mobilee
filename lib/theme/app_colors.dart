import 'package:flutter/material.dart';

/// Paleta de la aplicación, alineada con la del frontend web (estética soft
/// cream): fondo crema, acento terracota mate y acentos pastel. Los nombres de
/// los campos se conservan; solo cambian los valores para igualar al web.
class AppColors {
  AppColors._();

  // Marca · terracota mate
  static const Color brand = Color(0xFFC26849);
  static const Color brandDark = Color(0xFF984B30);
  static const Color brandSoft = Color(0xFFF3DCCF);
  static const Color brandInk = Color(0xFF6D3621);

  // Texto · marrón-grafito cálido (nunca negro puro)
  static const Color ink = Color(0xFF2D2A24);
  static const Color inkSubtle = Color(0xFF5A5246);
  static const Color inkMuted = Color(0xFF8A7E6D);
  static const Color inkFaint = Color(0xFFBEB3A0);

  // Superficies
  static const Color surface = Color(0xFFFBF6E9);
  static const Color surfaceMuted = Color(0xFFF6EFDE);
  static const Color background = Color(0xFFF2ECDC);
  static const Color overlay = Color(0xFFECE3CC);

  // Bordes
  static const Color border = Color(0xFFE0D6BF);
  static const Color borderSubtle = Color(0xFFEBE2CB);
  static const Color borderStrong = Color(0xFFC8BB9D);

  // Acentos · paleta pastel mate (mismos nombres que ya usa la app)
  static const Color amber = Color(0xFFB8923F); // gold
  static const Color amberSoft = Color(0xFFF1E7C8);
  static const Color forest = Color(0xFF7A9277); // sage
  static const Color forestSoft = Color(0xFFE2EBDE);
  static const Color slate = Color(0xFF6F8EAB); // sky
  static const Color slateSoft = Color(0xFFE0E8F0);
  static const Color indigo = Color(0xFF9D8BB4); // lilac
  static const Color indigoSoft = Color(0xFFE8E2EF);

  // Peligro · rosa mate (diferenciado de la marca, como en el web)
  static const Color danger = Color(0xFFB85C68);
  static const Color dangerSoft = Color(0xFFF0D7DA);
  static const Color dangerInk = Color(0xFF6B2B34);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFC26849), Color(0xFF984B30)],
  );

  static const LinearGradient duskGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF5A5246), Color(0xFF2D2A24)],
  );

  static List<BoxShadow> shadowSm = [
    BoxShadow(
      color: const Color(0xFF2D2A24).withValues(alpha: 0.05),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: const Color(0xFF2D2A24).withValues(alpha: 0.03),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> shadowMd = [
    BoxShadow(
      color: const Color(0xFF2D2A24).withValues(alpha: 0.04),
      blurRadius: 14,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: const Color(0xFF2D2A24).withValues(alpha: 0.03),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> shadowLg = [
    BoxShadow(
      color: const Color(0xFF2D2A24).withValues(alpha: 0.05),
      blurRadius: 28,
      offset: const Offset(0, 12),
    ),
    BoxShadow(
      color: const Color(0xFF2D2A24).withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];
}
