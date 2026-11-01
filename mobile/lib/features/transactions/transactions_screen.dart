import 'import_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../auth/auth_provider.dart';
import 'add_transaction_screen.dart';
import 'transactions_provider.dart';

final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
final _dateFmt = DateFormat('d MMM y');

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txns = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
  IconButton(
    icon: const Icon(Icons.upload_file),
    tooltip: 'Import',
    onPressed: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ImportScreen()),
    ),
  ),
  IconButton(
    icon: const Icon(Icons.logout),
    tooltip: 'Log out',
    onPressed: () => ref.read(authProvider.notifier).logout(),
  ),
],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: txns.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(apiError(e)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(transactionsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No transactions yet. Tap Add.'));
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(transactionsProvider.future),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final t = list[i];
                final color = t.isDebit ? Colors.red.shade700 : Colors.green.shade700;
                return Dismissible(
                  key: ValueKey(t.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) async {
                    try {
                      await ref.read(transactionsProvider.notifier).remove(t.id);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(apiError(e))));
                      }
                    }
                  },
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(t.merchant.substring(0, 1).toUpperCase()),
                    ),
                    title: Text(t.merchant),
                    subtitle: Text('${t.category} • ${_dateFmt.format(t.txnDate)}'),
                    trailing: Text(
                      '${t.isDebit ? '-' : '+'}${_money.format(t.amount)}',
                      style: TextStyle(color: color, fontWeight: FontWeight.w600),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}