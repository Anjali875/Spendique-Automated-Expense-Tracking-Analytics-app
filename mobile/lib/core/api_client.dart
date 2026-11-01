import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storage = FlutterSecureStorage();
const _tokenKey = 'access_token';
const _override = String.fromEnvironment('API_URL');

String get baseUrl {
  if (_override.isNotEmpty) return _override;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8000'; // Android emulator -> your PC
  }
  return 'http://localhost:8000';
}

class TokenStore {
  Future<String?> read() => _storage.read(key: _tokenKey);
  Future<void> save(String token) => _storage.write(key: _tokenKey, value: token);
  Future<void> clear() => _storage.delete(key: _tokenKey);
}

final tokenStoreProvider = Provider((ref) => TokenStore());

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 60),
    receiveTimeout: const Duration(seconds: 60),
  ));
  final store = ref.read(tokenStoreProvider);
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await store.read();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
      handler.next(options);
    },
  ));
  return dio;
});

String apiError(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map && data['detail'] is String) return data['detail'] as String;
    if (data is Map && data['detail'] is List) return 'Please check your input.';
    if (e.response == null) return 'Cannot reach the server. Is the backend running?';
  }
  return 'Something went wrong.';
}