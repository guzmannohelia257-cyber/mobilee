import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_emergencias/screens/onboarding_screen.dart';

void main() {
  testWidgets('avanza por los slides hasta Empezar', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));

    expect(find.text('Ayuda en carretera, al instante'), findsOneWidget);
    expect(find.text('Siguiente'), findsOneWidget);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Empezar'), findsOneWidget);
    expect(find.text('Saltar'), findsNothing);
  });

  testWidgets('Saltar solo aparece antes del último slide', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));

    expect(find.text('Saltar'), findsOneWidget);
  });
}
