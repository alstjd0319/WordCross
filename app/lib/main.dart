import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/app_config.dart';
import 'features/auth/auth_providers.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/fake_auth_repository.dart';
import 'features/auth/supabase_auth_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();
  final AuthRepository auth;
  if (config.hasSupabase) {
    await Supabase.initialize(url: config.supabaseUrl, publishableKey: config.supabasePublishableKey);
    auth = SupabaseAuthRepository(Supabase.instance.client.auth);
  } else {
    auth = FakeAuthRepository();
  }

  runApp(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        localModeProvider.overrideWithValue(!config.hasSupabase),
      ],
      child: const WordCrossApp(),
    ),
  );
}
