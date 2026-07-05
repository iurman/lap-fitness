import 'package:flutter/material.dart';

import '../features/auth/presentation/main_page.dart';

final customThemeData = ThemeData(
  primaryColor: const Color.fromARGB(255, 138, 104, 35),
);

/// Root application widget: the [MaterialApp] and its theme.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: customThemeData,
      home: const MainPage(),
    );
  }
}
