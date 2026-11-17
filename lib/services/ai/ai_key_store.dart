import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores a user's Gemini API key in the platform keystore.
///
/// The key is namespaced by the active local account and never written to Hive,
/// Supabase, logs, or a FitGo server. An injected implementation is used by
/// tests so no platform channel is required.
abstract interface class AiKeyStore {
  Future<String?> readKey(String namespace);
  Future<void> writeKey(String namespace, String key);
  Future<void> deleteKey(String namespace);
}

class SecureAiKeyStore implements AiKeyStore {
  SecureAiKeyStore({FlutterSecureStorage? storage})
    : _storage = storage ?? _defaultStorage;

  static const _defaultStorage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const keyPrefix = 'fitgo_ai_gemini_key_';

  final FlutterSecureStorage _storage;

  String _storageKey(String namespace) => '$keyPrefix$namespace';

  @override
  Future<String?> readKey(String namespace) async {
    final value = await _storage.read(key: _storageKey(namespace));
    final key = value?.trim() ?? '';
    return key.isEmpty ? null : key;
  }

  @override
  Future<void> writeKey(String namespace, String key) {
    return _storage.write(key: _storageKey(namespace), value: key.trim());
  }

  @override
  Future<void> deleteKey(String namespace) {
    return _storage.delete(key: _storageKey(namespace));
  }
}
