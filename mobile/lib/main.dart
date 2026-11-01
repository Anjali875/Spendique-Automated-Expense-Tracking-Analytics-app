import 'features/home/home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/auth_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/transactions/transactions_screen.dart';

void main() => runApp(const ProviderScope(child: App()));

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Tracker',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(authProvider).when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (_, __) => const LoginScreen(),
          data: (loggedIn) => loggedIn ? const HomeShell() : const LoginScreen(),
        );
  }
}