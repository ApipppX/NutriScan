import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriscan/core/theme/app_theme.dart';
import 'package:nutriscan/features/food_scan/presentation/widgets/scanner_onboarding.dart';

void main() {
  testWidgets('onboarding explains the three-step flow', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: ScannerOnboarding(),
          ),
        ),
      ),
    );

    expect(find.text('Cara pakai'), findsOneWidget);
    expect(find.text('Ambil atau pilih foto'), findsOneWidget);
    expect(find.text('AI mengenali makanan'), findsOneWidget);
    expect(find.text('Lihat estimasi gizi'), findsOneWidget);
    expect(find.text('Cahaya terang'), findsOneWidget);
  });
}
