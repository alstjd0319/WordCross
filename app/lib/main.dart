import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/app_config.dart';
import 'features/auth/auth_providers.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/fake_auth_repository.dart';
import 'features/auth/supabase_auth_repository.dart';
import 'features/play/fake_puzzle_repository.dart';
import 'features/play/play_providers.dart';
import 'features/play/puzzle_repository.dart';
import 'features/play/supabase_puzzle_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();
  final AuthRepository auth;
  final PuzzleRepository puzzles;
  if (config.hasSupabase) {
    await Supabase.initialize(url: config.supabaseUrl, publishableKey: config.supabasePublishableKey);
    auth = SupabaseAuthRepository(Supabase.instance.client.auth);
    puzzles = SupabasePuzzleRepository(Supabase.instance.client);
  } else {
    auth = FakeAuthRepository();
    puzzles = FakePuzzleRepository();
  }

  runApp(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        puzzleRepositoryProvider.overrideWithValue(puzzles),
        localModeProvider.overrideWithValue(!config.hasSupabase),
      ],
      child: const WordCrossApp(),
    ),
  );
}
