// ignore_for_file: use_key_in_widget_constructors, prefer_const_constructors, deprecated_member_use
// ignore_for_file: unused_import

import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      appBarTheme: AppBarTheme(
        color: Color.fromARGB(255, 138, 104, 35),
      ),
      buttonTheme: ButtonThemeData(
        buttonColor: Color.fromARGB(255, 138, 104, 35),
        textTheme: ButtonTextTheme.primary,
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(
          color: Color.fromARGB(255, 138, 104, 35),
        ),
        bodyMedium: TextStyle(
          color: Color.fromARGB(255, 138, 104, 35),
        ),
        displayLarge: TextStyle(
          color: Color.fromARGB(255, 138, 104, 35),
        ),
        displayMedium: TextStyle(
          color: Color.fromARGB(255, 138, 104, 35),
        ),
        displaySmall: TextStyle(
          color: Color.fromARGB(255, 138, 104, 35),
        ),
        headlineMedium: TextStyle(
          color: Color.fromARGB(255, 138, 104, 35),
        ),
        headlineSmall: TextStyle(
          color: Color.fromARGB(255, 138, 104, 35),
        ),
        titleLarge: TextStyle(
          color: Color.fromARGB(255, 138, 104, 35),
        ),
        titleMedium: TextStyle(
          color: Color.fromARGB(255, 138, 104, 35),
        ),
        titleSmall: TextStyle(
          color: Color.fromARGB(255, 138, 104, 35),
        ),
      ),
    );
  }
}
