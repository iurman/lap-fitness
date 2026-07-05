import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';

final customThemeData = ThemeData(
  primaryColor: const Color.fromARGB(255, 138, 104, 35),
);

/// Root application widget: the routed [MaterialApp] and its theme.
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: customThemeData,
      routerConfig: router,
    );
  }
}
