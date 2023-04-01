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
        bodyText1: TextStyle(
          color: Color.fromARGB(255, 138, 104, 35),
        ),
        bodyText2: TextStyle(
          color: Color.fromARGB(255, 138, 104, 35),
        ),
        headline1: TextStyle(
          color: Color.fromARGB(255, 138, 104, 35),
        ),
        headline2: TextStyle(
          color: Color.fromARGB(255, 138, 104, 35),
        ),
        headline3: TextStyle(
          color: Color.fromARGB(255, 138, 104, 35),
        ),
        headline4: TextStyle(
          color: Color.fromARGB(255, 138, 104, 35),
        ),
        headline5: TextStyle(
          color: Color.fromARGB(255, 138, 104, 35),
        ),
        headline6: TextStyle(
          color: Color.fromARGB(255, 138, 104, 35),
        ),
        subtitle1: TextStyle(
          color: Color.fromARGB(255, 138, 104, 35),
        ),
        subtitle2: TextStyle(
          color: Color.fromARGB(255, 138, 104, 35),
        ),
      ),
    );
  }
}
