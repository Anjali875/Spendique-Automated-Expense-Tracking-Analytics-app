import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

class AuthNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final store = ref.read(tokenStoreProvider);
    final token = await store.read();
    if (token == null) return false;
    try {
      await ref.read(dioProvider).get('/auth/me');
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) await store.clear();
      return false;
    }
  }

  Future<void> login(String email, String password) async {
    final res = await ref.read(dioProvider).post(
          '/auth/login',
          data: {'username': email, 'password': password},
          options: Options(contentType: Headers.formUrlEncodedContentType),
        );
    await ref.read(tokenStoreProvider).save(res.data['access_token'] as String);
    state = const AsyncData(true);
  }

  Future<void> signup(String email, String password) async {
    await ref.read(dioProvider).post(
      '/auth/signup',
      data: {'email': email, 'password': password},
    );
    await login(email, password);
  }

  Future<void> logout() async {
    await ref.read(tokenStoreProvider).clear();
    state = const AsyncData(false);
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, bool>(AuthNotifier.new);