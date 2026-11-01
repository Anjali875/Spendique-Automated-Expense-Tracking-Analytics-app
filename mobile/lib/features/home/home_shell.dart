import 'package:flutter/material.dart';

import '../dashboard/dashboard_screen.dart';
import '../transactions/transactions_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(
          index: _index,
          children: const [TransactionsScreen(), DashboardScreen()],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.list_alt), label: 'Transactions'),
            NavigationDestination(icon: Icon(Icons.pie_chart), label: 'Dashboard'),
          ],
        ),
      );
}