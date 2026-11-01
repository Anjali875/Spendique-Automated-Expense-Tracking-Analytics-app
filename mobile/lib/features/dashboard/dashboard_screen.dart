import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import 'insights_provider.dart';

final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
const _palette = <Color>[
  Colors.teal, Colors.orange, Colors.indigo, Colors.pink,
  Colors.amber, Colors.cyan, Colors.deepPurple, Colors.brown,
];

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref.watch(insightsProvider);
    final titleStyle = Theme.of(context).textTheme.titleMedium;

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: insights.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(apiError(e)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(insightsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (d) => RefreshIndicator(
          onRefresh: () => ref.refresh(insightsProvider.future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(child: _StatCard('Spent (30 days)', d.expense30d, Colors.red.shade700)),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard('Income (30 days)', d.income30d, Colors.green.shade700)),
                ],
              ),
              const SizedBox(height: 24),
              Text('Income (green) vs spending (red)', style: titleStyle),
              const SizedBox(height: 12),
              SizedBox(height: 200, child: _MonthlyChart(d.monthly)),
              const SizedBox(height: 24),
              Text('Spending by category (30 days)', style: titleStyle),
              const SizedBox(height: 12),
              _CategorySection(d.byCategory),
              const SizedBox(height: 24),
              Text('Top merchants (30 days)', style: titleStyle),
              if (d.topMerchants.isEmpty) const Text('No spending in the last 30 days.'),
              for (final m in d.topMerchants)
                ListTile(
                  dense: true,
                  title: Text(m.label),
                  trailing: Text(_money.format(m.total)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 6),
              Text(
                _money.format(value),
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
        ),
      );
}

class _MonthlyChart extends StatelessWidget {
  const _MonthlyChart(this.months);
  final List<MonthTotal> months;

  @override
  Widget build(BuildContext context) {
    var maxY = 0.0;
    for (final m in months) {
      if (m.income > maxY) maxY = m.income;
      if (m.expense > maxY) maxY = m.expense;
    }
    if (maxY == 0) maxY = 1;

    const hidden = AxisTitles(sideTitles: SideTitles(showTitles: false));
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.15,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: hidden,
          rightTitles: hidden,
          topTitles: hidden,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= months.length) return const SizedBox.shrink();
                final label = DateFormat('MMM').format(DateTime.parse('${months[i].month}-01'));
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(label, style: const TextStyle(fontSize: 11)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < months.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(toY: months[i].income, color: Colors.green.shade600, width: 10),
                BarChartRodData(toY: months[i].expense, color: Colors.red.shade600, width: 10),
              ],
            ),
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection(this.items);
  final List<LabelTotal> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No spending in the last 30 days.');
    final total = items.fold<double>(0, (s, e) => s + e.total);
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 36,
              sections: [
                for (var i = 0; i < items.length; i++)
                  PieChartSectionData(
                    value: items[i].total,
                    color: _palette[i % _palette.length],
                    title: '${(items[i].total / total * 100).round()}%',
                    radius: 56,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < items.length; i++)
          ListTile(
            dense: true,
            leading: CircleAvatar(radius: 6, backgroundColor: _palette[i % _palette.length]),
            title: Text(items[i].label),
            trailing: Text(_money.format(items[i].total)),
          ),
      ],
    );
  }
}