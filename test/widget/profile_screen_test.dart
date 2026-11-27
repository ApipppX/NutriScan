import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriscan/core/theme/app_theme.dart';
import 'package:nutriscan/features/user_profile/data/repositories/in_memory_user_profile_repository.dart';
import 'package:nutriscan/features/user_profile/domain/entities/user_profile.dart';
import 'package:nutriscan/features/user_profile/presentation/providers/user_profile_providers.dart';
import 'package:nutriscan/features/user_profile/presentation/screens/profile_screen.dart';

Future<ProviderContainer> _pumpProfile(
  WidgetTester tester, {
  UserProfile? initialProfile,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final repository = InMemoryUserProfileRepository(
    initialProfile: initialProfile,
  );
  final container = ProviderContainer(
    overrides: [userProfileRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.light, home: const ProfileScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('shows the default profile and its TDEE', (tester) async {
    await _pumpProfile(tester);

    expect(find.text('Profil & Target Kalori'), findsOneWidget);
    expect(find.text('Profil Pengguna'), findsOneWidget);
    expect(find.text('1971 kkal'), findsOneWidget);
    expect(find.textContaining('Sebagian besar waktu duduk'), findsOneWidget);
    expect(find.textContaining('×1,2'), findsOneWidget);
  });

  testWidgets('shows a previously saved profile', (tester) async {
    await _pumpProfile(
      tester,
      initialProfile: const UserProfile(
        weightKg: 60,
        heightCm: 160,
        age: 30,
        gender: Gender.female,
        activityLevel: ActivityLevel.moderatelyActive,
      ),
    );

    expect(find.text('1998 kkal'), findsOneWidget);
    expect(find.text('Wanita'), findsOneWidget);
    expect(find.text('Olahraga sedang (3-5 hari/minggu)'), findsOneWidget);
    expect(
      find.textContaining('Olahraga sedang 3–5 hari per minggu'),
      findsOneWidget,
    );
    expect(find.textContaining('×1,55'), findsOneWidget);
  });

  testWidgets('saves edits and refreshes the TDEE', (tester) async {
    final container = await _pumpProfile(tester);

    await tester.enterText(find.byType(TextFormField).at(0), '80');
    final saveButton = find.text('Simpan Profil');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    final repository = container.read(userProfileRepositoryProvider);
    final stored = await repository.loadProfile();
    expect(stored, isNotNull);
    expect(stored!.weightKg, closeTo(80, 1e-9));
    expect(find.text('2091 kkal'), findsOneWidget);
    expect(find.text('Profil tersimpan.'), findsOneWidget);
  });

  testWidgets('rejects out-of-range values without saving', (tester) async {
    final container = await _pumpProfile(tester);

    await tester.enterText(find.byType(TextFormField).at(0), '10');
    final saveButton = find.text('Simpan Profil');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    final repository = container.read(userProfileRepositoryProvider);
    expect(await repository.loadProfile(), isNull);
    expect(
      find.text('Masukkan berat, tinggi, dan usia yang valid.'),
      findsOneWidget,
    );
  });
}
