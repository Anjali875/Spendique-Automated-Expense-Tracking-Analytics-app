import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../transactions/transactions_provider.dart';

class LabelTotal {
  final String label;
  final double total;
  const LabelTotal(this.label, this.total);

  factory LabelTotal.fromJson(Map<String, dynamic> j) =>
      LabelTotal(j['label'] as String, (j['total'] as num).toDouble());
}

class MonthTotal {
  final String month;
  final double income, expense;
  const MonthTotal(this.month, this.income, this.expense);

  factory MonthTotal.fromJson(Map<String, dynamic> j) => MonthTotal(
        j['month'] as String,
        (j['income'] as num).toDouble(),
        (j['expense'] as num).toDouble(),
      );
}

class Insights {
  final double income30d, expense30d;
  final List<LabelTotal> byCategory, topMerchants;
  final List<MonthTotal> monthly;

  const Insights(this.income30d, this.expense30d, this.byCategory, this.topMerchants, this.monthly);

  factory Insights.fromJson(Map<String, dynamic> j) => Insights(
        (j['income_30d'] as num).toDouble(),
        (j['expense_30d'] as num).toDouble(),
        (j['by_category'] as List).map((e) => LabelTotal.fromJson(e as Map<String, dynamic>)).toList(),
        (j['top_merchants'] as List).map((e) => LabelTotal.fromJson(e as Map<String, dynamic>)).toList(),
        (j['monthly'] as List).map((e) => MonthTotal.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

final insightsProvider = FutureProvider.autoDispose<Insights>((ref) async {
  ref.watch(transactionsProvider); // refetch whenever transactions change
  final res = await ref.read(dioProvider).get('/insights');
  return Insights.fromJson(res.data as Map<String, dynamic>);
});