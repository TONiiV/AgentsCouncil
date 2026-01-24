import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/home/home_screen.dart';
import 'app/theme.dart';
import 'shared/theme_switcher.dart';

void main() {
  runApp(
    const ProviderScope(
      child: AgentsCouncilApp(),
    ),
  );
}

class AgentsCouncilApp extends ConsumerWidget {
  const AgentsCouncilApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch theme variant for dynamic switching
    final themeVariant = ref.watch(themeVariantProvider);
    
    return MaterialApp(
      title: 'AgentsCouncil',
      debugShowCheckedModeBanner: false,
      theme: CyberTheme.forVariant(themeVariant),
      home: const HomeScreen(),
    );
  }
}
