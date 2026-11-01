import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import 'transaction.dart';

final transactionsProvider =
    AsyncNotifierProvider.autoDispose<TransactionsNotifier, List<Transaction>>(
  TransactionsNotifier.new,
);

class TransactionsNotifier extends AutoDisposeAsyncNotifier<List<Transaction>> {
  @override
  Future<List<Transaction>> build() => _fetch();

  Future<List<Transaction>> _fetch() async {
    final res = await ref.read(dioProvider).get(
      '/transactions',
      queryParameters: {'limit': 200},
    );
    return (res.data as List)
        .map((j) => Transaction.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<void> add({
    required double amount,
    required String type,
    required String merchant,
    required String category,
    required DateTime date,
    String? description,
  }) async {
    await ref.read(dioProvider).post('/transactions', data: {
      'amount': amount.toStringAsFixed(2),
      'type': type,
      'merchant': merchant,
      'category': category,
      if (description != null && description.isNotEmpty) 'description': description,
      'txn_date': DateFormat('yyyy-MM-dd').format(date),
    });
    state = AsyncData(await _fetch());
  }

  Future<void> remove(int id) async {
    final previous = state.valueOrNull ?? [];
    state = AsyncData(previous.where((t) => t.id != id).toList());
    try {
      await ref.read(dioProvider).delete('/transactions/$id');
    } catch (_) {
      state = AsyncData(previous); // roll back
      rethrow;
    }
  }
    Future<ImportResult> importCsv(List<int> bytes, String filename) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await ref.read(dioProvider).post('/import/csv', data: form);
    state = AsyncData(await _fetch());
    return ImportResult.fromJson(res.data as Map<String, dynamic>);
  }

  Future<ImportResult> importSms(String text) async {
    final res = await ref.read(dioProvider).post('/import/sms', data: {'text': text});
    state = AsyncData(await _fetch());
    return ImportResult.fromJson(res.data as Map<String, dynamic>);
  }
}