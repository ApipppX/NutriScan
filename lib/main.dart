import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/daily_diary/data/repositories/sqflite_diary_repository.dart';
import 'features/daily_diary/presentation/providers/diary_providers.dart';
import 'features/user_profile/data/repositories/sqflite_user_profile_repository.dart';
import 'features/user_profile/presentation/providers/user_profile_providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      overrides: [
        diaryRepositoryProvider.overrideWithValue(SqfliteDiaryRepository()),
        userProfileRepositoryProvider.overrideWithValue(
          SqfliteUserProfileRepository(),
        ),
      ],
      child: const NutriScanApp(),
    ),
  );
}
