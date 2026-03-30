import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'providers/storage_provider.dart';
import 'services/local_storage.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init Supabase
  await SupabaseService.init();

  // Init Hive
  final storage = LocalStorage();
  await storage.init();

  runApp(
    ProviderScope(
      overrides: [
        localStorageProvider.overrideWithValue(storage),
      ],
      child: const FitGoApp(),
    ),
  );
}
