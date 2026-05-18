import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/api_client.dart';
import '../api/token_store.dart';
import '../config/env.dart';
import '../network/connectivity.dart';

final envProvider = Provider<AppEnv>((ref) => AppEnv.current);

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final tokenStoreProvider = Provider<TokenStore>((ref) {
  return TokenStore(ref.read(secureStorageProvider));
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    env: ref.read(envProvider),
    tokens: ref.read(tokenStoreProvider),
    // Closure (not snapshot) so the retry interceptor always reads
    // the latest connectivity state when a failed request arrives,
    // not the state at the moment ApiClient was instantiated.
    isOnline: () async => isOnline(ref.read(connectivityProvider)),
  );
});
